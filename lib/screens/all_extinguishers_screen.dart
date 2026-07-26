import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/extinguisher.dart';
import '../models/extinguisher_type.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../services/database_service.dart';
import 'extinguisher_form_screen.dart';
import 'select_extinguisher_target_screen.dart';

class ExtinguisherEntry {
  final Extinguisher extinguisher;
  final int buildingId;
  final int floorId;
  final int? roomId;
  final String contextLabel;
  final List<ExtinguisherType> allowedTypesForEdit;

  const ExtinguisherEntry({
    required this.extinguisher,
    required this.buildingId,
    required this.floorId,
    required this.roomId,
    required this.contextLabel,
    required this.allowedTypesForEdit,
  });
}

class AllExtinguishersScreen extends StatefulWidget {
  final int? initialBuildingId;
  final int? initialFloorId;
  final int? initialRoomId;

  const AllExtinguishersScreen({
    super.key,
    this.initialBuildingId,
    this.initialFloorId,
    this.initialRoomId,
  });

  @override
  State<AllExtinguishersScreen> createState() => _AllExtinguishersScreenState();
}

class _AllExtinguishersScreenState extends State<AllExtinguishersScreen> {
  final _db = DatabaseService.instance;
  bool _loading = true;
  List<Building> _buildings = [];
  Map<int, List<Floor>> _floorsByBuilding = {};
  Map<int, List<Room>> _computerRoomsByFloor = {};
  List<ExtinguisherEntry> _allEntries = [];

  int? _filterBuildingId;
  int? _filterFloorId;
  int? _filterRoomId;

  @override
  void initState() {
    super.initState();
    _filterBuildingId = widget.initialBuildingId;
    _filterFloorId = widget.initialFloorId;
    _filterRoomId = widget.initialRoomId;
    _reload();
  }

  Future<void> _reload() async {
    final buildings = await _db.getBuildings();
    final allowedGeneralTypes = await _db.getAllowedGeneralTypes();
    final floorsByBuilding = <int, List<Floor>>{};
    final computerRoomsByFloor = <int, List<Room>>{};
    final entries = <ExtinguisherEntry>[];

    for (final Building building in buildings) {
      final floors = await _db.getFloorsForBuilding(building.id!);
      floorsByBuilding[building.id!] = floors;
      for (final Floor floor in floors) {
        final floorExtinguishers = await _db.getExtinguishersForFloor(floor.id!);
        for (final e in floorExtinguishers) {
          entries.add(ExtinguisherEntry(
            extinguisher: e,
            buildingId: building.id!,
            floorId: floor.id!,
            roomId: null,
            contextLabel: '${building.name} / ${floor.name} / Загальна площа',
            allowedTypesForEdit: allowedGeneralTypes,
          ));
        }

        final rooms = await _db.getRoomsForFloor(floor.id!);
        final computerRooms = rooms.where((r) => r.hasComputer).toList();
        computerRoomsByFloor[floor.id!] = computerRooms;
        for (final Room room in computerRooms) {
          final roomExtinguishers = await _db.getExtinguishersForRoom(room.id!);
          for (final e in roomExtinguishers) {
            entries.add(ExtinguisherEntry(
              extinguisher: e,
              buildingId: building.id!,
              floorId: floor.id!,
              roomId: room.id,
              contextLabel: '${building.name} / ${floor.name} / ${room.name}',
              allowedTypesForEdit: const [ExtinguisherType.vvk],
            ));
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _buildings = buildings;
      _floorsByBuilding = floorsByBuilding;
      _computerRoomsByFloor = computerRoomsByFloor;
      _allEntries = entries;
      _loading = false;
    });
  }

  Future<void> _delete(Extinguisher e) async {
    await _db.deleteExtinguisher(e.id!);
    _reload();
  }

  List<ExtinguisherEntry> get _filteredEntries {
    return _allEntries.where((entry) {
      if (_filterBuildingId != null && entry.buildingId != _filterBuildingId) return false;
      if (_filterFloorId != null && entry.floorId != _filterFloorId) return false;
      if (_filterRoomId != null && entry.roomId != _filterRoomId) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final floors = _filterBuildingId != null ? (_floorsByBuilding[_filterBuildingId!] ?? []) : <Floor>[];
    final rooms = _filterFloorId != null ? (_computerRoomsByFloor[_filterFloorId!] ?? []) : <Room>[];
    final entries = _filteredEntries;

    return Scaffold(
      appBar: AppBar(title: const Text('Вогнегасники')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: _filterBuildingId,
                        decoration: const InputDecoration(labelText: 'Будівля'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Усі будівлі')),
                          for (final b in _buildings) DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
                        ],
                        onChanged: (v) => setState(() {
                          _filterBuildingId = v;
                          _filterFloorId = null;
                          _filterRoomId = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: _filterFloorId,
                        decoration: const InputDecoration(labelText: 'Поверх'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Усі поверхи')),
                          for (final f in floors) DropdownMenuItem<int?>(value: f.id, child: Text(f.name)),
                        ],
                        onChanged: _filterBuildingId == null
                            ? null
                            : (v) => setState(() {
                                  _filterFloorId = v;
                                  _filterRoomId = null;
                                }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: _filterRoomId,
                        decoration: const InputDecoration(labelText: 'Кабінет'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Усі кабінети (+ загальна площа)')),
                          for (final r in rooms) DropdownMenuItem<int?>(value: r.id, child: Text(r.name)),
                        ],
                        onChanged: _filterFloorId == null ? null : (v) => setState(() => _filterRoomId = v),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: entries.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Немає вогнегасників за обраним фільтром. Натисни "+" щоб додати.'),
                        )
                      : ListView(
                          children: [
                            for (final entry in entries)
                              ListTile(
                                leading: const Icon(Icons.local_fire_department_outlined),
                                title: Text(
                                  '№${entry.extinguisher.id} · ${entry.extinguisher.type.code} · '
                                  '${entry.extinguisher.capacityLiters.toStringAsFixed(1)} ${entry.extinguisher.type.unit}',
                                ),
                                subtitle: Text(
                                  '${entry.contextLabel}\n'
                                  'Заводський: ${entry.extinguisher.serialNumber} · '
                                  'Інвентарний: ${entry.extinguisher.inventoryNumber}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ExtinguisherFormScreen(
                                              roomId: entry.extinguisher.roomId,
                                              floorId: entry.extinguisher.floorId,
                                              allowedTypes: entry.allowedTypesForEdit,
                                              extinguisher: entry.extinguisher,
                                            ),
                                          ),
                                        );
                                        _reload();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _delete(entry.extinguisher),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 80),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Вогнегасник'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SelectExtinguisherTargetScreen()),
          );
          _reload();
        },
      ),
    );
  }
}
