import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/division.dart';
import '../models/extinguisher.dart';
import '../models/extinguisher_type.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../services/database_service.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/page_help.dart';
import 'extinguisher_form_screen.dart';
import 'select_extinguisher_target_screen.dart';

class ExtinguisherEntry {
  final Extinguisher extinguisher;
  final int divisionId;
  final int buildingId;
  final int floorId;
  final int? roomId;
  final String contextLabel;
  final List<ExtinguisherType> allowedTypesForEdit;

  const ExtinguisherEntry({
    required this.extinguisher,
    required this.divisionId,
    required this.buildingId,
    required this.floorId,
    required this.roomId,
    required this.contextLabel,
    required this.allowedTypesForEdit,
  });
}

class AllExtinguishersScreen extends StatefulWidget {
  final int? initialDivisionId;
  final int? initialBuildingId;
  final int? initialFloorId;
  final int? initialRoomId;

  const AllExtinguishersScreen({
    super.key,
    this.initialDivisionId,
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
  List<Division> _divisions = [];
  Map<int, List<Building>> _buildingsByDivision = {};
  Map<int, List<Floor>> _floorsByBuilding = {};
  Map<int, List<Room>> _computerRoomsByFloor = {};
  List<ExtinguisherEntry> _allEntries = [];

  int? _filterDivisionId;
  int? _filterBuildingId;
  int? _filterFloorId;
  int? _filterRoomId;

  @override
  void initState() {
    super.initState();
    _filterDivisionId = widget.initialDivisionId;
    _filterBuildingId = widget.initialBuildingId;
    _filterFloorId = widget.initialFloorId;
    _filterRoomId = widget.initialRoomId;
    _reload();
  }

  Future<void> _reload() async {
    final divisions = await _db.getDivisions();
    final allowedGeneralTypes = await _db.getAllowedGeneralTypes();
    final buildingsByDivision = <int, List<Building>>{};
    final floorsByBuilding = <int, List<Floor>>{};
    final computerRoomsByFloor = <int, List<Room>>{};
    final entries = <ExtinguisherEntry>[];

    for (final Division division in divisions) {
      final buildings = await _db.getBuildingsForDivision(division.id!);
      buildingsByDivision[division.id!] = buildings;
      for (final Building building in buildings) {
        final floors = await _db.getFloorsForBuilding(building.id!);
        floorsByBuilding[building.id!] = floors;
        for (final Floor floor in floors) {
          final floorExtinguishers = await _db.getExtinguishersForFloor(floor.id!);
          for (final e in floorExtinguishers) {
            entries.add(ExtinguisherEntry(
              extinguisher: e,
              divisionId: division.id!,
              buildingId: building.id!,
              floorId: floor.id!,
              roomId: null,
              contextLabel: '${division.name} / ${building.name} / ${floor.name} / Загальна площа',
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
                divisionId: division.id!,
                buildingId: building.id!,
                floorId: floor.id!,
                roomId: room.id,
                contextLabel: '${division.name} / ${building.name} / ${floor.name} / ${room.name}',
                allowedTypesForEdit: const [ExtinguisherType.vvk],
              ));
            }
          }
        }
      }
    }

    // Якщо задано лише buildingId (без divisionId) — довизначаємо управління.
    if (_filterDivisionId == null && _filterBuildingId != null) {
      for (final entry in buildingsByDivision.entries) {
        if (entry.value.any((b) => b.id == _filterBuildingId)) {
          _filterDivisionId = entry.key;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _divisions = divisions;
      _buildingsByDivision = buildingsByDivision;
      _floorsByBuilding = floorsByBuilding;
      _computerRoomsByFloor = computerRoomsByFloor;
      _allEntries = entries;
      _loading = false;
    });
  }

  Future<void> _delete(Extinguisher e) async {
    if (!await confirmDelete(context, 'вогнегасник №${e.id}')) return;
    await _db.deleteExtinguisher(e.id!);
    _reload();
  }

  List<ExtinguisherEntry> get _filteredEntries {
    return _allEntries.where((entry) {
      if (_filterDivisionId != null && entry.divisionId != _filterDivisionId) return false;
      if (_filterBuildingId != null && entry.buildingId != _filterBuildingId) return false;
      if (_filterFloorId != null && entry.floorId != _filterFloorId) return false;
      if (_filterRoomId != null && entry.roomId != _filterRoomId) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final buildings = _filterDivisionId != null ? (_buildingsByDivision[_filterDivisionId!] ?? []) : <Building>[];
    final floors = _filterBuildingId != null ? (_floorsByBuilding[_filterBuildingId!] ?? []) : <Floor>[];
    final rooms = _filterFloorId != null ? (_computerRoomsByFloor[_filterFloorId!] ?? []) : <Room>[];
    final entries = _filteredEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вогнегасники'),
        actions: [
          PageHelpAction(
            title: 'Вогнегасники',
            points: [
              'Фільтри Управління/Будівля/Поверх/Кабінет звужують список каскадно.',
              'Олівець і кошик на записі — редагувати чи видалити конкретний вогнегасник.',
              'Експорт/імпорт CSV і PDF-звіт — на сторінці "Статистика" (іконка 📊), не тут: '
                  'не всі об\'єкти мають вогнегасники, а статистика потрібна на кожному рівні.',
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: _filterDivisionId,
                        decoration: const InputDecoration(labelText: 'Управління'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Усі управління')),
                          for (final d in _divisions) DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
                        ],
                        onChanged: (v) => setState(() {
                          _filterDivisionId = v;
                          _filterBuildingId = null;
                          _filterFloorId = null;
                          _filterRoomId = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: _filterBuildingId,
                        decoration: const InputDecoration(labelText: 'Будівля'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Усі будівлі')),
                          for (final b in buildings) DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
                        ],
                        onChanged: _filterDivisionId == null
                            ? null
                            : (v) => setState(() {
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
                                  '${entry.extinguisher.capacityLiters.toStringAsFixed(1)} ${entry.extinguisher.type.unit}',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.contextLabel),
                                    Text('Заводський: ${entry.extinguisher.serialNumber}'),
                                    Text('Інвентарний: ${entry.extinguisher.inventoryNumber}'),
                                  ],
                                ),
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
            MaterialPageRoute(
              builder: (context) => SelectExtinguisherTargetScreen(initialDivisionId: _filterDivisionId),
            ),
          );
          _reload();
        },
      ),
    );
  }
}
