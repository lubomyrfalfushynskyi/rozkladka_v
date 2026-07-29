import '../services/calculation_service.dart';
import 'floor.dart';

/// Розрахунок по одному поверху разом з контекстом (яке управління/будівля),
/// потрібним для відображення й PDF/CSV-звітів на будь-якому рівні ієрархії.
class FloorSummaryEntry {
  final int divisionId;
  final String divisionName;
  final int buildingId;
  final String buildingName;
  final Floor floor;
  final FloorCalculation calc;

  const FloorSummaryEntry({
    required this.divisionId,
    required this.divisionName,
    required this.buildingId,
    required this.buildingName,
    required this.floor,
    required this.calc,
  });
}

/// Розрахунок по одній території разом з контекстом управління.
class TerritorySummaryEntry {
  final int divisionId;
  final String divisionName;
  final TerritoryCalculation calc;

  const TerritorySummaryEntry({required this.divisionId, required this.divisionName, required this.calc});
}

/// Агреговані підсумки по набору поверхів (уже відфільтрованому за
/// потрібним рівнем — управління/будівля/поверх/усе разом).
class SummaryTotals {
  final double totalLiters;
  final double totalShortageLiters;
  final int totalMissingRoomExtinguishers;
  final Map<String, int> extinguisherCounts;

  const SummaryTotals({
    required this.totalLiters,
    required this.totalShortageLiters,
    required this.totalMissingRoomExtinguishers,
    required this.extinguisherCounts,
  });

  bool get hasShortage => totalShortageLiters > 0 || totalMissingRoomExtinguishers > 0;

  factory SummaryTotals.fromFloorEntries(List<FloorSummaryEntry> entries) {
    var totalLiters = 0.0;
    var totalShortageLiters = 0.0;
    var totalMissingRoomExtinguishers = 0;
    final extinguisherCounts = <String, int>{};
    for (final entry in entries) {
      totalLiters += entry.calc.requiredLiters;
      totalShortageLiters += entry.calc.shortageLiters;
      for (final req in entry.calc.computerRooms) {
        extinguisherCounts.update(req.extinguisherClass, (v) => v + 1, ifAbsent: () => 1);
        totalMissingRoomExtinguishers += req.shortageCount;
      }
    }
    return SummaryTotals(
      totalLiters: totalLiters,
      totalShortageLiters: totalShortageLiters,
      totalMissingRoomExtinguishers: totalMissingRoomExtinguishers,
      extinguisherCounts: extinguisherCounts,
    );
  }
}
