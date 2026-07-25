import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/territory.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class SummaryData {
  double totalLiters = 0;
  final Map<String, int> extinguisherCounts = {};
  int totalShields = 0;
  final List<FloorSummary> floors = [];
}

class FloorSummary {
  final String buildingName;
  final String floorName;
  final FloorCalculation calc;

  FloorSummary({required this.buildingName, required this.floorName, required this.calc});
}

class _SummaryScreenState extends State<SummaryScreen> {
  late Future<SummaryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SummaryData> _load() async {
    final db = DatabaseService.instance;
    final buildings = await db.getBuildings();
    final data = SummaryData();

    for (final Building building in buildings) {
      final floors = await db.getFloorsForBuilding(building.id!);
      for (final Floor floor in floors) {
        final List<Room> rooms = await db.getRoomsForFloor(floor.id!);
        final calc = CalculationService.calculateFloor(floor, rooms);
        data.totalLiters += calc.requiredLiters;
        for (final req in calc.computerRooms) {
          data.extinguisherCounts.update(req.extinguisherClass, (v) => v + 1, ifAbsent: () => 1);
        }
        data.floors.add(FloorSummary(buildingName: building.name, floorName: floor.name, calc: calc));
      }
    }

    final territories = await db.getTerritories();
    for (final Territory territory in territories) {
      data.totalShields += CalculationService.calculateTerritory(territory).requiredShields;
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Зведений звіт')),
      body: FutureBuilder<SummaryData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Загалом по будівлях', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Вогнегасна речовина (звичайні приміщення): ${data.totalLiters.toStringAsFixed(0)} л'),
                      const SizedBox(height: 4),
                      const Text('Вогнегасники для кабінетів з ПК:'),
                      if (data.extinguisherCounts.isEmpty) const Text('  — немає кабінетів з ПК'),
                      for (final entry in data.extinguisherCounts.entries)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text('• ${entry.value} шт. — ${entry.key}'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Територія (ТУЗ)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Потрібно пожежних щитів: ${data.totalShields}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Деталізація по поверхах', style: Theme.of(context).textTheme.titleMedium),
              for (final floorSummary in data.floors)
                Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    title: Text('${floorSummary.buildingName} — ${floorSummary.floorName}'),
                    subtitle: Text(
                      'Залишкова площа: ${floorSummary.calc.remainingArea.toStringAsFixed(0)} м² · '
                      'потрібно: ${floorSummary.calc.requiredLiters.toStringAsFixed(0)} л · '
                      'кабінетів з ПК: ${floorSummary.calc.computerRooms.length}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
