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

/// Один рядок таблиці-воронки: об'єкт — потреба — наявно — недостача.
class FunnelRow {
  final String object;
  final num need;
  final num available;
  final num shortage;

  const FunnelRow({
    required this.object,
    required this.need,
    required this.available,
    required this.shortage,
  });
}

/// Таблиця-воронка для однієї категорії майна (речовина/ВВК/щити):
/// підсумковий рядок "Всього" + розбивка по об'єктах наступного рівня вниз.
class FunnelTable {
  final String title;
  final String unit;
  final FunnelRow total;
  final List<FunnelRow> rows;

  const FunnelTable({
    required this.title,
    required this.unit,
    required this.total,
    required this.rows,
  });

  bool get hasShortage => total.shortage > 0;
}

/// Будує таблиці-воронки для поточного рівня фільтра. На кожному рівні —
/// підсумок і розбивка по НАСТУПНОМУ рівню вниз:
/// усе → по управліннях → по будівлях (і територіях) → по поверхах →
/// по кабінетах.
class FunnelBuilder {
  static List<FunnelTable> build({
    required List<FloorSummaryEntry> floorEntries,
    required List<TerritorySummaryEntry> territoryEntries,
    int? filterDivisionId,
    int? filterBuildingId,
    int? filterFloorId,
  }) {
    final tables = <FunnelTable>[];

    if (filterFloorId != null) {
      if (floorEntries.isNotEmpty) {
        final floorEntry = floorEntries.first;
        tables.add(_substanceSingle(floorEntry));
        tables.add(_vvkByRoom(floorEntry));
      }
    } else if (filterBuildingId != null) {
      tables.add(_substanceGrouped(floorEntries, (e) => e.floor.name, 'Вогнегасна речовина — по поверхах'));
      tables.add(_vvkGrouped(floorEntries, (e) => e.floor.name, 'Вогнегасники ВВК — по поверхах'));
    } else if (filterDivisionId != null) {
      tables.add(_substanceGrouped(floorEntries, (e) => e.buildingName, 'Вогнегасна речовина — по будівлях'));
      tables.add(_vvkGrouped(floorEntries, (e) => e.buildingName, 'Вогнегасники ВВК — по будівлях'));
      if (territoryEntries.isNotEmpty) {
        tables.add(_shieldsGrouped(territoryEntries, (e) => e.calc.territory.name, 'Пожежні щити — по територіях'));
      }
    } else {
      tables.add(_substanceGrouped(floorEntries, (e) => e.divisionName, 'Вогнегасна речовина — по управліннях'));
      tables.add(_vvkGrouped(floorEntries, (e) => e.divisionName, 'Вогнегасники ВВК — по управліннях'));
      if (territoryEntries.isNotEmpty) {
        tables.add(_shieldsGrouped(territoryEntries, (e) => e.divisionName, 'Пожежні щити — по управліннях'));
      }
    }

    return tables;
  }

  static FunnelTable _substanceSingle(FloorSummaryEntry e) {
    final row = FunnelRow(
      object: e.floor.name,
      need: e.calc.requiredLiters,
      available: e.calc.assignedCapacityLiters,
      shortage: e.calc.shortageLiters,
    );
    return FunnelTable(title: 'Вогнегасна речовина (загальна площа)', unit: 'л', total: row, rows: const []);
  }

  static FunnelTable _vvkByRoom(FloorSummaryEntry e) {
    final rows = e.calc.computerRooms
        .map((r) => FunnelRow(object: r.room.name, need: 1, available: r.assignedCount, shortage: r.shortageCount))
        .toList();
    final total = FunnelRow(
      object: 'Всього',
      need: rows.fold<num>(0, (s, r) => s + r.need),
      available: rows.fold<num>(0, (s, r) => s + r.available),
      shortage: rows.fold<num>(0, (s, r) => s + r.shortage),
    );
    return FunnelTable(title: 'Вогнегасники ВВК — по кабінетах', unit: 'шт', total: total, rows: rows);
  }

  static FunnelTable _substanceGrouped(
    List<FloorSummaryEntry> entries,
    String Function(FloorSummaryEntry) keyOf,
    String title,
  ) {
    final groups = <String, List<FloorSummaryEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(keyOf(e), () => []).add(e);
    }
    final rows = groups.entries.map((g) {
      final need = g.value.fold<num>(0, (s, e) => s + e.calc.requiredLiters);
      final available = g.value.fold<num>(0, (s, e) => s + e.calc.assignedCapacityLiters);
      final shortage = g.value.fold<num>(0, (s, e) => s + e.calc.shortageLiters);
      return FunnelRow(object: g.key, need: need, available: available, shortage: shortage);
    }).toList()
      ..sort((a, b) => a.object.compareTo(b.object));
    final total = FunnelRow(
      object: 'Всього',
      need: rows.fold<num>(0, (s, r) => s + r.need),
      available: rows.fold<num>(0, (s, r) => s + r.available),
      shortage: rows.fold<num>(0, (s, r) => s + r.shortage),
    );
    return FunnelTable(title: title, unit: 'л', total: total, rows: rows);
  }

  static FunnelTable _vvkGrouped(
    List<FloorSummaryEntry> entries,
    String Function(FloorSummaryEntry) keyOf,
    String title,
  ) {
    final groups = <String, List<FloorSummaryEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(keyOf(e), () => []).add(e);
    }
    final rows = groups.entries.map((g) {
      final need = g.value.fold<num>(0, (s, e) => s + e.calc.computerRooms.length);
      final available = g.value.fold<num>(
        0,
        (s, e) => s + e.calc.computerRooms.fold<num>(0, (s2, r) => s2 + r.assignedCount),
      );
      final shortage = g.value.fold<num>(
        0,
        (s, e) => s + e.calc.computerRooms.fold<num>(0, (s2, r) => s2 + r.shortageCount),
      );
      return FunnelRow(object: g.key, need: need, available: available, shortage: shortage);
    }).toList()
      ..sort((a, b) => a.object.compareTo(b.object));
    final total = FunnelRow(
      object: 'Всього',
      need: rows.fold<num>(0, (s, r) => s + r.need),
      available: rows.fold<num>(0, (s, r) => s + r.available),
      shortage: rows.fold<num>(0, (s, r) => s + r.shortage),
    );
    return FunnelTable(title: title, unit: 'шт', total: total, rows: rows);
  }

  static FunnelTable _shieldsGrouped(
    List<TerritorySummaryEntry> entries,
    String Function(TerritorySummaryEntry) keyOf,
    String title,
  ) {
    final groups = <String, List<TerritorySummaryEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(keyOf(e), () => []).add(e);
    }
    final rows = groups.entries.map((g) {
      final need = g.value.fold<num>(0, (s, e) => s + e.calc.requiredShields);
      final available = g.value.fold<num>(0, (s, e) => s + e.calc.territory.assignedShields);
      final shortage = g.value.fold<num>(0, (s, e) => s + e.calc.shortageShields);
      return FunnelRow(object: g.key, need: need, available: available, shortage: shortage);
    }).toList()
      ..sort((a, b) => a.object.compareTo(b.object));
    final total = FunnelRow(
      object: 'Всього',
      need: rows.fold<num>(0, (s, r) => s + r.need),
      available: rows.fold<num>(0, (s, r) => s + r.available),
      shortage: rows.fold<num>(0, (s, r) => s + r.shortage),
    );
    return FunnelTable(title: title, unit: 'щитів', total: total, rows: rows);
  }
}
