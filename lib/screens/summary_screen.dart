import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/extinguisher.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/territory.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';
import '../widgets/page_help.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class SummaryData {
  double totalLiters = 0;
  double totalShortageLiters = 0;
  int totalMissingRoomExtinguishers = 0;
  final Map<String, int> extinguisherCounts = {};
  final List<TerritoryCalculation> territoryCalcs = [];
  final List<FloorSummary> floors = [];
}

class FloorSummary {
  final String divisionName;
  final String buildingName;
  final String floorName;
  final FloorCalculation calc;

  FloorSummary({
    required this.divisionName,
    required this.buildingName,
    required this.floorName,
    required this.calc,
  });
}

class _SummaryScreenState extends State<SummaryScreen> {
  late Future<SummaryData> _future;
  int? _territoryFilterId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SummaryData> _load() async {
    final db = DatabaseService.instance;
    final buildings = await db.getBuildings();
    final divisions = await db.getDivisions();
    final divisionNameById = {for (final d in divisions) d.id!: d.name};
    final data = SummaryData();

    for (final Building building in buildings) {
      final floors = await db.getFloorsForBuilding(building.id!);
      for (final Floor floor in floors) {
        final List<Room> rooms = await db.getRoomsForFloor(floor.id!);
        final List<Extinguisher> floorExtinguishers = await db.getExtinguishersForFloor(floor.id!);
        final byRoom = <int, List<Extinguisher>>{};
        for (final room in rooms) {
          if (room.hasComputer && room.id != null) {
            byRoom[room.id!] = await db.getExtinguishersForRoom(room.id!);
          }
        }
        final calc = CalculationService.calculateFloor(
          floor,
          rooms,
          floorExtinguishers: floorExtinguishers,
          extinguishersByRoomId: byRoom,
        );
        data.totalLiters += calc.requiredLiters;
        data.totalShortageLiters += calc.shortageLiters;
        for (final req in calc.computerRooms) {
          data.extinguisherCounts.update(req.extinguisherClass, (v) => v + 1, ifAbsent: () => 1);
          data.totalMissingRoomExtinguishers += req.shortageCount;
        }
        data.floors.add(FloorSummary(
          divisionName: divisionNameById[building.divisionId] ?? '',
          buildingName: building.name,
          floorName: floor.name,
          calc: calc,
        ));
      }
    }

    final territories = await db.getTerritories();
    for (final Territory territory in territories) {
      data.territoryCalcs.add(CalculationService.calculateTerritory(territory));
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Зведений звіт'),
        actions: [
          PageHelpAction(
            title: 'Зведений звіт',
            points: [
              'Розрахунок по всіх управліннях разом: скільки вогнегасної речовини бракує в звичайних '
                  'приміщеннях і скільки вогнегасників ВВК бракує в кабінетах з ПК.',
              'Фільтр за територією нижче — переглянути потрібну кількість щитів по конкретній '
                  'території замість суми по всіх.',
              'Деталізація по поверхах внизу — кожен рядок підписаний управлінням/будівлею/поверхом.',
              'Це лише розрахунок норми — сюди нічого не редагується, зміни вносяться на відповідних '
                  'сторінках будівель/кабінетів/територій.',
            ],
          ),
        ],
      ),
      body: FutureBuilder<SummaryData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final hasShortage = data.totalShortageLiters > 0 || data.totalMissingRoomExtinguishers > 0;

          final filteredTerritoryCalcs = _territoryFilterId == null
              ? data.territoryCalcs
              : data.territoryCalcs.where((t) => t.territory.id == _territoryFilterId).toList();
          final shownShields = filteredTerritoryCalcs.fold<int>(0, (sum, t) => sum + t.requiredShields);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (hasShortage)
                Card(
                  color: Colors.red.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              'Виявлено недостачу',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (data.totalShortageLiters > 0)
                          Text('Бракує вогнегасної речовини (загальні приміщення): '
                              '${data.totalShortageLiters.toStringAsFixed(1)} од.'),
                        if (data.totalMissingRoomExtinguishers > 0)
                          Text('Бракує вогнегасників ВВК у кабінетах з ПК: '
                              '${data.totalMissingRoomExtinguishers} шт.'),
                      ],
                    ),
                  ),
                ),
              if (hasShortage) const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Загалом по будівлях', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Вогнегасна речовина (звичайні приміщення): ${data.totalLiters.toStringAsFixed(0)} л'),
                      const SizedBox(height: 4),
                      const Text('Вогнегасники для кабінетів з ПК (за нормою):'),
                      if (data.extinguisherCounts.isEmpty) const Text('  — немає кабінетів з ПК'),
                      for (final entry in data.extinguisherCounts.entries)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text('• ${entry.value} шт. — ${entry.key}'),
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
                      Text('Територія (ТВУЗ)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (data.territoryCalcs.length > 1)
                        DropdownButtonFormField<int?>(
                          initialValue: _territoryFilterId,
                          decoration: const InputDecoration(labelText: 'Фільтр за площею (територією)'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Усі території (сума)')),
                            for (final t in data.territoryCalcs)
                              DropdownMenuItem<int?>(value: t.territory.id, child: Text(t.territory.name)),
                          ],
                          onChanged: (v) => setState(() => _territoryFilterId = v),
                        ),
                      const SizedBox(height: 8),
                      Text('Потрібно пожежних щитів: $shownShields'),
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
                    title: Text('${floorSummary.divisionName} / ${floorSummary.buildingName} — ${floorSummary.floorName}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Залишкова площа: ${floorSummary.calc.remainingArea.toStringAsFixed(0)} м²'),
                        Text('Потрібно: ${floorSummary.calc.requiredLiters.toStringAsFixed(0)} л'),
                        Text('Наявно: ${floorSummary.calc.assignedCapacityLiters.toStringAsFixed(1)} од.'),
                        if (floorSummary.calc.shortageLiters > 0)
                          Text(
                            'Недостача: ${floorSummary.calc.shortageLiters.toStringAsFixed(1)} од.',
                            style: const TextStyle(color: Colors.red),
                          ),
                        Text(
                          'Кабінетів з ПК: ${floorSummary.calc.computerRooms.length}'
                          '${floorSummary.calc.computerRooms.any((r) => r.shortageCount > 0) ? " (бракує вогнегасників у ${floorSummary.calc.computerRooms.where((r) => r.shortageCount > 0).length})" : ""}',
                        ),
                      ],
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
