import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/division.dart';
import '../models/extinguisher_type.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../services/database_service.dart';
import '../widgets/page_help.dart';
import 'extinguisher_form_screen.dart';

/// Майстер вибору місця прив'язки нового вогнегасника: управління →
/// будівля → поверх → загальна площа поверху або конкретний кабінет з ПК.
class SelectExtinguisherTargetScreen extends StatefulWidget {
  final int? initialDivisionId;

  const SelectExtinguisherTargetScreen({super.key, this.initialDivisionId});

  @override
  State<SelectExtinguisherTargetScreen> createState() => _SelectExtinguisherTargetScreenState();
}

class _GeneralAreaTarget {
  const _GeneralAreaTarget();
}

class _SelectExtinguisherTargetScreenState extends State<SelectExtinguisherTargetScreen> {
  final _db = DatabaseService.instance;
  bool _loading = true;
  List<Division> _divisions = [];
  Map<int, List<Building>> _buildingsByDivision = {};
  Map<int, List<Floor>> _floorsByBuilding = {};
  Map<int, List<Room>> _computerRoomsByFloor = {};
  List<ExtinguisherType> _allowedGeneralTypes = [ExtinguisherType.vp];

  int? _selectedDivisionId;
  Building? _selectedBuilding;
  Floor? _selectedFloor;
  Object? _selectedTarget; // Room or _GeneralAreaTarget

  @override
  void initState() {
    super.initState();
    _selectedDivisionId = widget.initialDivisionId;
    _load();
  }

  Future<void> _load() async {
    final divisions = await _db.getDivisions();
    final buildingsByDivision = <int, List<Building>>{};
    final floorsByBuilding = <int, List<Floor>>{};
    final computerRoomsByFloor = <int, List<Room>>{};
    for (final division in divisions) {
      final buildings = await _db.getBuildingsForDivision(division.id!);
      buildingsByDivision[division.id!] = buildings;
      for (final building in buildings) {
        final floors = await _db.getFloorsForBuilding(building.id!);
        floorsByBuilding[building.id!] = floors;
        for (final floor in floors) {
          final rooms = await _db.getRoomsForFloor(floor.id!);
          computerRoomsByFloor[floor.id!] = rooms.where((r) => r.hasComputer).toList();
        }
      }
    }
    final allowedTypes = await _db.getAllowedGeneralTypes();
    if (!mounted) return;
    setState(() {
      _divisions = divisions;
      _buildingsByDivision = buildingsByDivision;
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
    if (_divisions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Новий вогнегасник')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Спочатку додай хоча б одне управління з будівлею та поверхом на головному екрані.'),
        ),
      );
    }

    final buildings = _selectedDivisionId != null ? (_buildingsByDivision[_selectedDivisionId!] ?? []) : <Building>[];
    final floors = _selectedBuilding != null ? (_floorsByBuilding[_selectedBuilding!.id!] ?? []) : <Floor>[];
    final computerRooms = _selectedFloor != null ? (_computerRoomsByFloor[_selectedFloor!.id!] ?? []) : <Room>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новий вогнегасник — обрати місце'),
        actions: [
          PageHelpAction(
            title: 'Обрати місце',
            points: [
              'Обери управління → будівлю → поверх, а тоді — загальну площу поверху чи конкретний '
                  'кабінет з ПК, куди прив\'язати новий вогнегасник.',
              'Кабінет з ПК завжди отримує ВВК; загальна площа — один з дозволених у Налаштуваннях типів.',
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int?>(
              initialValue: _selectedDivisionId,
              decoration: const InputDecoration(labelText: 'Управління'),
              items: [
                for (final d in _divisions) DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) => setState(() {
                _selectedDivisionId = v;
                _selectedBuilding = null;
                _selectedFloor = null;
                _selectedTarget = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_selectedDivisionId != null)
              buildings.isEmpty
                  ? const Text('У цьому управлінні ще немає будівель')
                  : DropdownButtonFormField<Building>(
                      initialValue: _selectedBuilding,
                      decoration: const InputDecoration(labelText: 'Будівля'),
                      items: buildings.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
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
