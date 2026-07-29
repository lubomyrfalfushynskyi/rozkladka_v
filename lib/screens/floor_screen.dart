import 'package:flutter/material.dart';

import '../models/extinguisher.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/page_help.dart';
import 'all_extinguishers_screen.dart';
import 'room_form_screen.dart';
import 'summary_screen.dart';

class FloorScreen extends StatefulWidget {
  final Floor floor;

  const FloorScreen({super.key, required this.floor});

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  final _db = DatabaseService.instance;
  List<Room> _rooms = [];
  List<Extinguisher> _floorExtinguishers = [];
  Map<int, List<Extinguisher>> _extinguishersByRoomId = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rooms = await _db.getRoomsForFloor(widget.floor.id!);
    final floorExtinguishers = await _db.getExtinguishersForFloor(widget.floor.id!);
    final byRoom = <int, List<Extinguisher>>{};
    for (final room in rooms) {
      if (room.hasComputer && room.id != null) {
        byRoom[room.id!] = await _db.getExtinguishersForRoom(room.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _floorExtinguishers = floorExtinguishers;
      _extinguishersByRoomId = byRoom;
      _loading = false;
    });
  }

  Future<void> _deleteRoom(Room room) async {
    if (!await confirmDelete(context, room.name)) return;
    await _db.deleteRoom(room.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final calc = CalculationService.calculateFloor(
      widget.floor,
      _rooms,
      floorExtinguishers: _floorExtinguishers,
      extinguishersByRoomId: _extinguishersByRoomId,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floor.name),
        actions: [
          PageHelpAction(
            title: widget.floor.name,
            points: [
              '"Вогнегасники загальної площі" — вогнегасники поверху поза кабінетами з ПК.',
              'Кабінети — список, іконка вогню поруч показує стан (червона — не встановлено, зелена — є); '
                  'олівець — редагувати назву/площу/ознаку ПК; кошик — видалити.',
              'Іконка 📊 вгорі — статистика саме цього поверху, з CSV-експортом/імпортом і PDF-звітом.',
              '"+ Кабінет" внизу — додати новий кабінет.',
            ],
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Статистика поверху',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SummaryScreen(
                    initialBuildingId: widget.floor.buildingId,
                    initialFloorId: widget.floor.id,
                  ),
                ),
              );
              _reload();
            },
          ),
        ],
      ),
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
                        Text('Загальна площа: ${widget.floor.totalArea.toStringAsFixed(0)} м²'),
                        Text('Площа кабінетів з ПК: ${calc.computerRoomsArea.toStringAsFixed(0)} м²'),
                        Text('Залишкова площа (звичайні приміщення): ${calc.remainingArea.toStringAsFixed(0)} м²'),
                        const SizedBox(height: 4),
                        Text(
                          'Потрібно вогнегасної речовини: ${calc.requiredLiters.toStringAsFixed(0)} л',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Наявна ємність (загальна площа): ${calc.assignedCapacityLiters.toStringAsFixed(1)} од.'),
                        if (calc.shortageLiters > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Недостача: ${calc.shortageLiters.toStringAsFixed(1)} од.',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Забезпечено достатньо', style: TextStyle(color: Colors.green)),
                          ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.local_fire_department_outlined),
                  title: const Text('Вогнегасники загальної площі'),
                  subtitle: Text('${_floorExtinguishers.length} шт.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllExtinguishersScreen(
                          initialBuildingId: widget.floor.buildingId,
                          initialFloorId: widget.floor.id,
                        ),
                      ),
                    );
                    _reload();
                  },
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
                  Builder(builder: (context) {
                    final assigned = room.id != null ? (_extinguishersByRoomId[room.id!] ?? const []) : const [];
                    return ListTile(
                      leading: Icon(room.hasComputer ? Icons.computer : Icons.meeting_room_outlined),
                      title: Text(room.name),
                      subtitle: Text(
                        room.hasComputer
                            ? '${room.area.toStringAsFixed(0)} м² · ${CalculationService.extinguisherClassFor(room.area)} · '
                                '${assigned.isEmpty ? "вогнегасник не встановлено" : "встановлено: ${assigned.length} шт."}'
                            : '${room.area.toStringAsFixed(0)} м² · без ПК (входить у загальний розрахунок)',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (room.hasComputer)
                            IconButton(
                              icon: Icon(
                                Icons.local_fire_department_outlined,
                                color: assigned.isEmpty ? Colors.red : Colors.green,
                              ),
                              tooltip: 'Вогнегасники кабінету',
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AllExtinguishersScreen(
                                      initialBuildingId: widget.floor.buildingId,
                                      initialFloorId: widget.floor.id,
                                      initialRoomId: room.id,
                                    ),
                                  ),
                                );
                                _reload();
                              },
                            ),
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
                    );
                  }),
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
