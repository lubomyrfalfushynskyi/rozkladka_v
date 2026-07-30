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

String formatFunnelNumber(num value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

/// Категорія майна — фіксовані три; воронка завжди показує всі три на
/// кожному рівні (з поясненням замість таблиці, якщо на цьому рівні для
/// категорії нема об'єктів), щоб користувач ніколи не губив інформацію.
enum FunnelCategory { substance, vvk, shields }

/// Один рядок таблиці-воронки: об'єкт — наявно/потреба (недостача виражена
/// кольором і форматованим дробом, а не окремою колонкою — менше ручних
/// обчислень для читача).
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

  /// "5 / 11" — наявно / потреба, з нерозривними пробілами навколо "/", щоб
  /// дріб ніколи не розривався на дві строки.
  String get fractionLabel =>
      '${formatFunnelNumber(available)} / ${formatFunnelNumber(need)}';
}

/// Таблиця-воронка для однієї категорії майна (речовина/ВВК/щити):
/// підсумковий рядок "Всього" + розбивка по об'єктах наступного рівня вниз.
/// Якщо на поточному рівні для категорії нема жодного об'єкта —
/// `emptyMessage` пояснює чому, а не мовчки зникає таблиця чи рядок.
class FunnelTable {
  final FunnelCategory category;
  final String title;
  final String unit;
  final FunnelRow total;
  final List<FunnelRow> rows;
  final String? emptyMessage;

  const FunnelTable({
    required this.category,
    required this.title,
    required this.unit,
    required this.total,
    required this.rows,
    this.emptyMessage,
  });

  bool get isEmpty => emptyMessage != null;
  bool get hasShortage => !isEmpty && total.shortage > 0;
}

const _zeroRow = FunnelRow(object: 'Всього', need: 0, available: 0, shortage: 0);

/// Будує таблиці-воронки для поточного рівня фільтра. На кожному рівні —
/// підсумок і розбивка по НАСТУПНОМУ рівню вниз: усе → по управліннях →
/// по будівлях (і територіях) → по поверхах → по кабінетах.
///
/// Завжди повертає рівно 3 таблиці (речовина/ВВК/щити), незалежно від
/// того, чи є на цьому рівні дані для кожної — порожня категорія отримує
/// `emptyMessage` замість того, щоб зникнути.
class FunnelBuilder {
  static List<FunnelTable> build({
    required List<FloorSummaryEntry> floorEntries,
    required List<TerritorySummaryEntry> territoryEntries,
    int? filterDivisionId,
    int? filterBuildingId,
    int? filterFloorId,
  }) {
    if (filterFloorId != null) {
      return [
        floorEntries.isNotEmpty
            ? _substanceSingle(floorEntries.first)
            : _empty(FunnelCategory.substance, 'Вогнегасна речовина (загальна площа)', 'л', 'Поверх не знайдено.'),
        floorEntries.isNotEmpty && floorEntries.first.calc.computerRooms.isNotEmpty
            ? _vvkByRoom(floorEntries.first)
            : _empty(
                FunnelCategory.vvk,
                'Вогнегасники ВВК — по кабінетах',
                'шт',
                'На цьому поверсі немає кабінетів з комп\'ютерною технікою.',
              ),
        _empty(
          FunnelCategory.shields,
          'Пожежні щити',
          'щитів',
          'Пожежні щити рахуються лише на рівні управління — територія не належить конкретній будівлі чи поверху.',
        ),
      ];
    }

    if (filterBuildingId != null) {
      return [
        floorEntries.isNotEmpty
            ? _substanceGrouped(floorEntries, (e) => e.floor.name, FunnelCategory.substance, 'Вогнегасна речовина — по поверхах')
            : _empty(FunnelCategory.substance, 'Вогнегасна речовина — по поверхах', 'л', 'У цій будівлі немає поверхів.'),
        _hasComputerRooms(floorEntries)
            ? _vvkGrouped(floorEntries, (e) => e.floor.name, 'Вогнегасники ВВК — по поверхах')
            : _empty(
                FunnelCategory.vvk,
                'Вогнегасники ВВК — по поверхах',
                'шт',
                'У цій будівлі немає кабінетів з комп\'ютерною технікою.',
              ),
        _empty(
          FunnelCategory.shields,
          'Пожежні щити',
          'щитів',
          'Пожежні щити рахуються лише на рівні управління — територія не належить конкретній будівлі чи поверху.',
        ),
      ];
    }

    if (filterDivisionId != null) {
      return [
        floorEntries.isNotEmpty
            ? _substanceGrouped(floorEntries, (e) => e.buildingName, FunnelCategory.substance, 'Вогнегасна речовина — по будівлях')
            : _empty(FunnelCategory.substance, 'Вогнегасна речовина — по будівлях', 'л', 'У цьому управлінні немає будівель/поверхів.'),
        _hasComputerRooms(floorEntries)
            ? _vvkGrouped(floorEntries, (e) => e.buildingName, 'Вогнегасники ВВК — по будівлях')
            : _empty(
                FunnelCategory.vvk,
                'Вогнегасники ВВК — по будівлях',
                'шт',
                'У цьому управлінні немає кабінетів з комп\'ютерною технікою.',
              ),
        territoryEntries.isNotEmpty
            ? _shieldsGrouped(territoryEntries, (e) => e.calc.territory.name, 'Пожежні щити — по територіях')
            : _empty(FunnelCategory.shields, 'Пожежні щити — по територіях', 'щитів', 'У цьому управлінні немає зареєстрованих територій.'),
      ];
    }

    return [
      floorEntries.isNotEmpty
          ? _substanceGrouped(floorEntries, (e) => e.divisionName, FunnelCategory.substance, 'Вогнегасна речовина — по управліннях')
          : _empty(FunnelCategory.substance, 'Вогнегасна речовина — по управліннях', 'л', 'У системі ще немає жодного управління/будівлі/поверху.'),
      _hasComputerRooms(floorEntries)
          ? _vvkGrouped(floorEntries, (e) => e.divisionName, 'Вогнегасники ВВК — по управліннях')
          : _empty(FunnelCategory.vvk, 'Вогнегасники ВВК — по управліннях', 'шт', 'У системі немає кабінетів з комп\'ютерною технікою.'),
      territoryEntries.isNotEmpty
          ? _shieldsGrouped(territoryEntries, (e) => e.divisionName, 'Пожежні щити — по управліннях')
          : _empty(FunnelCategory.shields, 'Пожежні щити — по управліннях', 'щитів', 'У системі ще немає жодної зареєстрованої території.'),
    ];
  }

  static bool _hasComputerRooms(List<FloorSummaryEntry> entries) =>
      entries.any((e) => e.calc.computerRooms.isNotEmpty);

  static FunnelTable _empty(FunnelCategory category, String title, String unit, String message) => FunnelTable(
        category: category,
        title: title,
        unit: unit,
        total: _zeroRow,
        rows: const [],
        emptyMessage: message,
      );

  static FunnelTable _substanceSingle(FloorSummaryEntry e) {
    final row = FunnelRow(
      object: e.floor.name,
      need: e.calc.requiredLiters,
      available: e.calc.assignedCapacityLiters,
      shortage: e.calc.shortageLiters,
    );
    return FunnelTable(
      category: FunnelCategory.substance,
      title: 'Вогнегасна речовина (загальна площа)',
      unit: 'л',
      total: row,
      rows: const [],
    );
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
    return FunnelTable(category: FunnelCategory.vvk, title: 'Вогнегасники ВВК — по кабінетах', unit: 'шт', total: total, rows: rows);
  }

  static FunnelTable _substanceGrouped(
    List<FloorSummaryEntry> entries,
    String Function(FloorSummaryEntry) keyOf,
    FunnelCategory category,
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
    return FunnelTable(category: category, title: title, unit: 'л', total: total, rows: rows);
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
    return FunnelTable(category: FunnelCategory.vvk, title: title, unit: 'шт', total: total, rows: rows);
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
    return FunnelTable(category: FunnelCategory.shields, title: title, unit: 'щитів', total: total, rows: rows);
  }
}
