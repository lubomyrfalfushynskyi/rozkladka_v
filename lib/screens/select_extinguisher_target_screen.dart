import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/extinguisher_type.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../services/database_service.dart';
import 'extinguisher_form_screen.dart';

/// Майстер вибору місця прив'язки нового вогнегасника: будівля → поверх →
/// загальна площа поверху або конкретний кабінет з ПК.
class SelectExtinguisherTargetScreen extends StatefulWidget {
  const SelectExtinguisherTargetScreen({super.key});

  @override
  State<SelectExtinguisherTargetScreen> createState() => _SelectExtinguisherTargetScreenState();
}

class _GeneralAreaTarget {
  const _GeneralAreaTarget();
}

class _SelectExtinguisherTargetScreenState extends State<SelectExtinguisherTargetScreen> {
  final _db = DatabaseService.instance;
  bool _loading = true;
  List<Building> _buildings = [];
  Map<int, List<Floor>> _floorsByBuilding = {};
  Map<int, List<Room>> _computerRoomsByFloor = {};
  List<ExtinguisherType> _allowedGeneralTypes = [ExtinguisherType.vp];

  Building? _selectedBuilding;
  Floor? _selectedFloor;
  Object? _selectedTarget; // Room or _GeneralAreaTarget

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final buildings = await _db.getBuildings();
    final floorsByBuilding = <int, List<Floor>>{};
    final computerRoomsByFloor = <int, List<Room>>{};
    for (final building in buildings) {
      final floors = await _db.getFloorsForBuilding(building.id!);
      floorsByBuilding[building.id!] = floors;
      for (final floor in floors) {
        final rooms = await _db.getRoomsForFloor(floor.id!);
        computerRoomsByFloor[floor.id!] = rooms.where((r) => r.hasComputer).toList();
      }
    }
    final allowedTypes = await _db.getAllowedGeneralTypes();
    if (!mounted) return;
    setState(() {
      _buildings = buildings;
      _floorsByBuilding = floorsByBuilding;
      _computerRoomsByFloor = computerRoomsByFloor;
      _allowedGeneralTypes = allowedTypes;
      _loading = false;
    });
  }

  void _continue() {
    final target = _selectedTarget;
    if (_selectedFloor == null || target == null) return;

    final Widget formScreen;
    if (target is Room) {
      formScreen = ExtinguisherFormScreen(roomId: target.id, allowedTypes: const [ExtinguisherType.vvk]);
    } else {
      formScreen = ExtinguisherFormScreen(floorId: _selectedFloor!.id, allowedTypes: _allowedGeneralTypes);
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => formScreen));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_buildings.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Новий вогнегасник')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Спочатку додай хоча б одну будівлю з поверхом на головному екрані.'),
        ),
      );
    }

    final floors = _selectedBuilding != null ? (_floorsByBuilding[_selectedBuilding!.id!] ?? []) : <Floor>[];
    final computerRooms = _selectedFloor != null ? (_computerRoomsByFloor[_selectedFloor!.id!] ?? []) : <Room>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Новий вогнегасник — обрати місце')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Building>(
              initialValue: _selectedBuilding,
              decoration: const InputDecoration(labelText: 'Будівля'),
              items: _buildings.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
              onChanged: (b) => setState(() {
                _selectedBuilding = b;
                _selectedFloor = null;
                _selectedTarget = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_selectedBuilding != null)
              floors.isEmpty
                  ? const Text('У цій будівлі ще немає поверхів')
                  : DropdownButtonFormField<Floor>(
                      initialValue: _selectedFloor,
                      decoration: const InputDecoration(labelText: 'Поверх'),
                      items: floors.map((f) => DropdownMenuItem(value: f, child: Text(f.name))).toList(),
                      onChanged: (f) => setState(() {
                        _selectedFloor = f;
                        _selectedTarget = null;
                      }),
                    ),
            const SizedBox(height: 12),
            if (_selectedFloor != null)
              DropdownButtonFormField<Object>(
                initialValue: _selectedTarget,
                decoration: const InputDecoration(labelText: 'Куди прив\'язати'),
                items: [
                  const DropdownMenuItem<Object>(
                    value: _GeneralAreaTarget(),
                    child: Text('Загальна площа поверху'),
                  ),
                  for (final room in computerRooms)
                    DropdownMenuItem<Object>(value: room, child: Text('Кабінет: ${room.name}')),
                ],
                onChanged: (t) => setState(() => _selectedTarget = t),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_selectedFloor != null && _selectedTarget != null) ? _continue : null,
              child: const Text('Далі'),
            ),
          ],
        ),
      ),
    );
  }
}
