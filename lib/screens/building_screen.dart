import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';
import 'floor_screen.dart';

class BuildingScreen extends StatefulWidget {
  final Building building;

  const BuildingScreen({super.key, required this.building});

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> {
  final _db = DatabaseService.instance;
  List<Floor> _floors = [];
  Map<int, List<Room>> _roomsByFloor = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final floors = await _db.getFloorsForBuilding(widget.building.id!);
    final roomsByFloor = <int, List<Room>>{};
    for (final floor in floors) {
      roomsByFloor[floor.id!] = await _db.getRoomsForFloor(floor.id!);
    }
    if (!mounted) return;
    setState(() {
      _floors = floors;
      _roomsByFloor = roomsByFloor;
      _loading = false;
    });
  }

  Future<void> _addOrEditFloor({Floor? floor}) async {
    final nameController = TextEditingController(text: floor?.name ?? '');
    final areaController = TextEditingController(
      text: floor != null ? floor.totalArea.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(floor == null ? 'Новий поверх' : 'Редагувати поверх'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Назва поверху (напр. "1 поверх")'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обовʼязково' : null,
              ),
              TextFormField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Загальна площа поверху, м²'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (value == null || value <= 0) return 'Вкажіть коректну площу';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );

    if (result != true) return;
    final area = double.parse(areaController.text.replaceAll(',', '.'));
    if (floor == null) {
      await _db.insertFloor(Floor(buildingId: widget.building.id!, name: nameController.text.trim(), totalArea: area));
    } else {
      await _db.updateFloor(floor.copyWith(name: nameController.text.trim(), totalArea: area));
    }
    _reload();
  }

  Future<void> _deleteFloor(Floor floor) async {
    await _db.deleteFloor(floor.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.building.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_floors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Ще немає жодного поверху'),
                  ),
                for (final floor in _floors)
                  Builder(builder: (context) {
                    final rooms = _roomsByFloor[floor.id!] ?? [];
                    final calc = CalculationService.calculateFloor(floor, rooms);
                    return ListTile(
                      leading: const Icon(Icons.layers),
                      title: Text(floor.name),
                      subtitle: Text(
                        '${floor.totalArea.toStringAsFixed(0)} м² · кабінетів з ПК: ${calc.computerRooms.length} · '
                        'потрібно л. на решту: ${calc.requiredLiters.toStringAsFixed(0)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _addOrEditFloor(floor: floor)),
                          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteFloor(floor)),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FloorScreen(floor: floor)),
                        );
                        _reload();
                      },
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Поверх'),
        onPressed: () => _addOrEditFloor(),
      ),
    );
  }
}
