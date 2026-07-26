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
  final String contextLabel;
  final List<ExtinguisherType> allowedTypesForEdit;

  const ExtinguisherEntry({
    required this.extinguisher,
    required this.contextLabel,
    required this.allowedTypesForEdit,
  });
}

class AllExtinguishersScreen extends StatefulWidget {
  const AllExtinguishersScreen({super.key});

  @override
  State<AllExtinguishersScreen> createState() => _AllExtinguishersScreenState();
}

class _AllExtinguishersScreenState extends State<AllExtinguishersScreen> {
  final _db = DatabaseService.instance;
  bool _loading = true;
  List<ExtinguisherEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final buildings = await _db.getBuildings();
    final allowedGeneralTypes = await _db.getAllowedGeneralTypes();
    final entries = <ExtinguisherEntry>[];

    for (final Building building in buildings) {
      final floors = await _db.getFloorsForBuilding(building.id!);
      for (final Floor floor in floors) {
        final floorExtinguishers = await _db.getExtinguishersForFloor(floor.id!);
        for (final e in floorExtinguishers) {
          entries.add(ExtinguisherEntry(
            extinguisher: e,
            contextLabel: '${building.name} / ${floor.name} / Загальна площа',
            allowedTypesForEdit: allowedGeneralTypes,
          ));
        }

        final rooms = await _db.getRoomsForFloor(floor.id!);
        for (final Room room in rooms.where((r) => r.hasComputer)) {
          final roomExtinguishers = await _db.getExtinguishersForRoom(room.id!);
          for (final e in roomExtinguishers) {
            entries.add(ExtinguisherEntry(
              extinguisher: e,
              contextLabel: '${building.name} / ${floor.name} / ${room.name}',
              allowedTypesForEdit: const [ExtinguisherType.vvk],
            ));
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _delete(Extinguisher e) async {
    await _db.deleteExtinguisher(e.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вогнегасники')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Ще немає жодного вогнегасника. Натисни "+" щоб додати перший.'),
                )
              : ListView(
                  children: [
                    for (final entry in _entries)
                      ListTile(
                        leading: const Icon(Icons.local_fire_department_outlined),
                        title: Text(
                          '№${entry.extinguisher.id} · ${entry.extinguisher.type.code} · '
                          '${entry.extinguisher.capacityLiters.toStringAsFixed(1)} ${entry.extinguisher.type.unit}',
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
