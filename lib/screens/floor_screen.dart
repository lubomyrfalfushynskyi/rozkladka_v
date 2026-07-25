import 'package:flutter/material.dart';

import '../models/floor.dart';
import '../models/room.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';
import 'room_form_screen.dart';

class FloorScreen extends StatefulWidget {
  final Floor floor;

  const FloorScreen({super.key, required this.floor});

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  final _db = DatabaseService.instance;
  List<Room> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rooms = await _db.getRoomsForFloor(widget.floor.id!);
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _loading = false;
    });
  }

  Future<void> _deleteRoom(Room room) async {
    await _db.deleteRoom(room.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final calc = CalculationService.calculateFloor(widget.floor, _rooms);
    return Scaffold(
      appBar: AppBar(title: Text(widget.floor.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Розрахунок поверху', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Загальна площа: ${widget.floor.totalArea.toStringAsFixed(0)} м²'),
                        Text('Площа кабінетів з ПК: ${calc.computerRoomsArea.toStringAsFixed(0)} м²'),
                        Text('Залишкова площа (звичайні приміщення): ${calc.remainingArea.toStringAsFixed(0)} м²'),
                        const SizedBox(height: 4),
                        Text(
                          'Потрібно вогнегасної речовини: ${calc.requiredLiters.toStringAsFixed(0)} л',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Кабінети', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (_rooms.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Ще немає жодного кабінету'),
                  ),
                for (final room in _rooms)
                  ListTile(
                    leading: Icon(room.hasComputer ? Icons.computer : Icons.meeting_room_outlined),
                    title: Text(room.name),
                    subtitle: Text(
                      room.hasComputer
                          ? '${room.area.toStringAsFixed(0)} м² · ${CalculationService.extinguisherClassFor(room.area)}'
                          : '${room.area.toStringAsFixed(0)} м² · без ПК (входить у загальний розрахунок)',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => RoomFormScreen(floor: widget.floor, room: room)),
                            );
                            _reload();
                          },
                        ),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteRoom(room)),
                      ],
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Кабінет'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RoomFormScreen(floor: widget.floor)),
          );
          _reload();
        },
      ),
    );
  }
}
