import 'package:csv/csv.dart';

import '../models/extinguisher.dart';
import '../models/extinguisher_import_result.dart';
import '../models/extinguisher_model_catalog.dart';
import '../models/extinguisher_type.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/territory.dart';
import 'database_service.dart';

/// BOM (byte order mark) на початку файлу — без нього Excel на Windows
/// вгадує кодування за системною локаллю замість UTF-8 і показує кракозябри
/// для кирилиці; з BOM Excel, WPS і Android однаково коректно розпізнають
/// UTF-8. `writeAsString`/`csv.decode` працюють з цим символом прозоро —
/// байти BOM (EF BB BF) виходять з кодування самого символу U+FEFF.
const String _bom = '\uFEFF';

const String rowTypeExtinguisher = 'Вогнегасник';
const String rowTypeDivision = 'Управління';
const String rowTypeBuilding = 'Будівля';
const String rowTypeFloor = 'Поверх';
const String rowTypeRoom = 'Кабінет';
const String rowTypeTerritory = 'Територія';

const List<String> csvHeaders = [
  'Тип рядка',
  'Управління',
  'Будівля',
  'Поверх',
  'Площа поверху',
  'Кабінет',
  'Площа кабінету',
  'Кабінет з ПК',
  'Територія',
  'Площа території',
  'Тип',
  'Модель',
  'Ємність',
  'Одиниця',
  'Заводський номер',
  'Інвентарний номер',
  'Ідентифікатор',
];

/// Формує/читає повне дерево даних (управління → будівлі → поверхи →
/// кабінети → вогнегасники, і окремо території/щити) в одному CSV-файлі.
/// Кожен рядок має один із шести "типів" (перша колонка) — так порожні
/// управління/будівлі/поверхи/кабінети (без жодного вкладеного об'єкта)
/// теж передаються, а не губляться.
class CsvService {
  /// Формує CSV. Без параметрів — по всіх управліннях (глобальний звіт). З
  /// `divisionId`/`buildingId`/`floorId`/`roomId` — обмежується відповідним
  /// рівнем ієрархії. Території входять у звіт лише на рівні управління чи
  /// вище (вони не належать конкретній будівлі/поверху).
  static Future<String> buildCsv({
    int? divisionId,
    int? buildingId,
    int? floorId,
    int? roomId,
  }) async {
    final db = DatabaseService.instance;
    final rows = <List<String>>[csvHeaders];
    final customModels = (await db.getCustomExtinguisherModels()).map((c) => c.asModel).toList();

    final divisions = await db.getDivisions();
    for (final division in divisions) {
      if (divisionId != null && division.id != divisionId) continue;
      final buildings = await db.getBuildingsForDivision(division.id!);
      for (final building in buildings) {
        if (buildingId != null && building.id != buildingId) continue;
        final floors = await db.getFloorsForBuilding(building.id!);
        if (floorId == null && roomId == null && floors.isEmpty) {
          rows.add(_buildingPlaceholderRow(division.name, building.name));
        }
        for (final floor in floors) {
          if (floorId != null && floor.id != floorId) continue;

          var floorHasExtinguisherRow = false;
          if (roomId == null) {
            final floorExtinguishers = await db.getExtinguishersForFloor(floor.id!);
            for (final e in floorExtinguishers) {
              rows.add(_extinguisherRow(e, division.name, building.name, floor, null, customModels));
              floorHasExtinguisherRow = true;
            }
            if (!floorHasExtinguisherRow) {
              rows.add(_floorPlaceholderRow(division.name, building.name, floor));
            }
          }

          final rooms = await db.getRoomsForFloor(floor.id!);
          for (final room in rooms) {
            if (roomId != null && room.id != roomId) continue;
            final roomExtinguishers = room.hasComputer ? await db.getExtinguishersForRoom(room.id!) : <Extinguisher>[];
            if (roomExtinguishers.isEmpty) {
              rows.add(_roomPlaceholderRow(division.name, building.name, floor, room));
            } else {
              for (final e in roomExtinguishers) {
                rows.add(_extinguisherRow(e, division.name, building.name, floor, room, customModels));
              }
            }
          }
        }
      }

      if (buildingId == null && floorId == null && roomId == null) {
        final territories = await db.getTerritoriesForDivision(division.id!);
        for (final t in territories) {
          rows.add(_territoryRow(division.name, t));
        }
        if (buildings.isEmpty && territories.isEmpty) {
          rows.add(_divisionPlaceholderRow(division.name));
        }
      }
    }

    return _bom + csv.encode(rows);
  }

  static List<String> _blankRow() => List<String>.filled(csvHeaders.length, '');

  static List<String> _extinguisherRow(
    Extinguisher e,
    String division,
    String building,
    Floor floor,
    Room? room,
    List<ExtinguisherModel> customModels,
  ) {
    final model = ExtinguisherModelCatalog.findByTypeAndCapacityWithCustom(e.type, e.capacityLiters, customModels);
    final row = _blankRow();
    row[0] = rowTypeExtinguisher;
    row[1] = division;
    row[2] = building;
    row[3] = floor.name;
    row[4] = _formatNumber(floor.totalArea);
    if (room != null) {
      row[5] = room.name;
      row[6] = _formatNumber(room.area);
      row[7] = room.hasComputer ? 'так' : 'ні';
    }
    row[10] = e.type.code;
    row[11] = model?.code ?? '';
    row[12] = _formatNumber(e.capacityLiters);
    row[13] = e.type.unit;
    row[14] = e.serialNumber;
    row[15] = e.inventoryNumber;
    row[16] = e.id?.toString() ?? '';
    return row;
  }

  static List<String> _divisionPlaceholderRow(String division) {
    final row = _blankRow();
    row[0] = rowTypeDivision;
    row[1] = division;
    return row;
  }

  static List<String> _buildingPlaceholderRow(String division, String building) {
    final row = _blankRow();
    row[0] = rowTypeBuilding;
    row[1] = division;
    row[2] = building;
    return row;
  }

  static List<String> _floorPlaceholderRow(String division, String building, Floor floor) {
    final row = _blankRow();
    row[0] = rowTypeFloor;
    row[1] = division;
    row[2] = building;
    row[3] = floor.name;
    row[4] = _formatNumber(floor.totalArea);
    return row;
  }

  static List<String> _roomPlaceholderRow(String division, String building, Floor floor, Room room) {
    final row = _blankRow();
    row[0] = rowTypeRoom;
    row[1] = division;
    row[2] = building;
    row[3] = floor.name;
    row[4] = _formatNumber(floor.totalArea);
    row[5] = room.name;
    row[6] = _formatNumber(room.area);
    row[7] = room.hasComputer ? 'так' : 'ні';
    return row;
  }

  static List<String> _territoryRow(String division, Territory t) {
    final row = _blankRow();
    row[0] = rowTypeTerritory;
    row[1] = division;
    row[8] = t.name;
    row[9] = _formatNumber(t.area);
    return row;
  }

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  /// Імпортує повне дерево даних з CSV. Управління/будівля/поверх/кабінет/
  /// територія створюються автоматично за назвою, якщо їх ще немає; якщо
  /// вже існують — їхня площа (і ознака ПК для кабінету) оновлюється
  /// значенням з файлу. Вогнегасники дедуплікуються за інвентарним номером
  /// у межах кабінету/поверху — повторний імпорт того самого файлу
  /// оновлює наявні записи, а не плодить дублікати.
  static Future<ExtinguisherImportResult> importCsv(String csvTextRaw) async {
    final db = DatabaseService.instance;
    final csvText = csvTextRaw.startsWith(_bom) ? csvTextRaw.substring(1) : csvTextRaw;
    final rows = csv.decode(csvText);
    if (rows.isEmpty) return const ExtinguisherImportResult(imported: 0, skipped: []);

    var imported = 0;
    final skipped = <String>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < csvHeaders.length) {
        skipped.add('Рядок ${i + 1}: недостатньо колонок');
        continue;
      }
      final rowType = row[0].toString().trim();
      final divisionName = row[1].toString().trim();
      if (divisionName.isEmpty) {
        skipped.add('Рядок ${i + 1}: не вказано управління');
        continue;
      }

      try {
        switch (rowType) {
          case rowTypeDivision:
            await db.findOrCreateDivision(divisionName);
            imported++;
            break;
          case rowTypeBuilding:
            await _importBuildingRow(db, row, i, divisionName, skipped);
            imported++;
            break;
          case rowTypeTerritory:
            await _importTerritoryRow(db, row, i, divisionName, skipped);
            imported++;
            break;
          case rowTypeFloor:
            await _importFloorRow(db, row, i, divisionName, skipped);
            imported++;
            break;
          case rowTypeRoom:
            await _importRoomRow(db, row, i, divisionName, skipped);
            imported++;
            break;
          default:
            // Порожній "Тип рядка" (сумісність зі старими файлами без цієї
            // колонки) теж трактується як вогнегасник.
            await _importExtinguisherRow(db, row, i, divisionName, skipped);
            imported++;
        }
      } on _SkipRow {
        // причина вже додана в skipped всередині _import*Row
      }
    }

    return ExtinguisherImportResult(imported: imported, skipped: skipped);
  }

  static Future<void> _importBuildingRow(
    DatabaseService db,
    List<dynamic> row,
    int i,
    String divisionName,
    List<String> skipped,
  ) async {
    final buildingName = row[2].toString().trim();
    if (buildingName.isEmpty) {
      skipped.add('Рядок ${i + 1}: відсутня назва будівлі');
      throw _SkipRow();
    }
    final divisionId = await db.findOrCreateDivision(divisionName);
    await db.findOrCreateBuilding(divisionId, buildingName);
  }

  static Future<void> _importTerritoryRow(
    DatabaseService db,
    List<dynamic> row,
    int i,
    String divisionName,
    List<String> skipped,
  ) async {
    final name = row[8].toString().trim();
    final area = double.tryParse(row[9].toString().trim().replaceAll(',', '.'));
    if (name.isEmpty || area == null) {
      skipped.add('Рядок ${i + 1}: відсутні дані території');
      throw _SkipRow();
    }
    final divisionId = await db.findOrCreateDivision(divisionName);
    await db.findOrCreateTerritory(divisionId, name, area);
  }

  static Future<void> _importFloorRow(
    DatabaseService db,
    List<dynamic> row,
    int i,
    String divisionName,
    List<String> skipped,
  ) async {
    final buildingName = row[2].toString().trim();
    final floorName = row[3].toString().trim();
    final floorArea = double.tryParse(row[4].toString().trim().replaceAll(',', '.'));
    if (buildingName.isEmpty || floorName.isEmpty || floorArea == null) {
      skipped.add('Рядок ${i + 1}: відсутні дані поверху');
      throw _SkipRow();
    }
    final divisionId = await db.findOrCreateDivision(divisionName);
    final buildingId = await db.findOrCreateBuilding(divisionId, buildingName);
    await db.findOrCreateFloor(buildingId, floorName, floorArea);
  }

  static Future<void> _importRoomRow(
    DatabaseService db,
    List<dynamic> row,
    int i,
    String divisionName,
    List<String> skipped,
  ) async {
    final buildingName = row[2].toString().trim();
    final floorName = row[3].toString().trim();
    final floorArea = double.tryParse(row[4].toString().trim().replaceAll(',', '.'));
    final roomName = row[5].toString().trim();
    final roomArea = double.tryParse(row[6].toString().trim().replaceAll(',', '.'));
    final hasComputer = row[7].toString().trim().toLowerCase() == 'так';
    if (buildingName.isEmpty || floorName.isEmpty || floorArea == null || roomName.isEmpty || roomArea == null) {
      skipped.add('Рядок ${i + 1}: відсутні дані кабінету');
      throw _SkipRow();
    }
    final divisionId = await db.findOrCreateDivision(divisionName);
    final buildingId = await db.findOrCreateBuilding(divisionId, buildingName);
    final floor = await db.findOrCreateFloor(buildingId, floorName, floorArea);
    await db.findOrCreateRoom(floor.id!, roomName, roomArea, hasComputer);
  }

  static Future<void> _importExtinguisherRow(
    DatabaseService db,
    List<dynamic> row,
    int i,
    String divisionName,
    List<String> skipped,
  ) async {
    final buildingName = row[2].toString().trim();
    final floorName = row[3].toString().trim();
    final floorArea = double.tryParse(row[4].toString().trim().replaceAll(',', '.'));
    final roomName = row[5].toString().trim();
    final typeCode = row[10].toString().trim();
    final capacity = double.tryParse(row[12].toString().trim().replaceAll(',', '.'));
    final serial = row[14].toString().trim();
    final inventory = row[15].toString().trim();

    if (buildingName.isEmpty || floorName.isEmpty || floorArea == null || capacity == null) {
      skipped.add('Рядок ${i + 1}: відсутні обовʼязкові поля вогнегасника');
      throw _SkipRow();
    }

    final divisionId = await db.findOrCreateDivision(divisionName);
    final buildingId = await db.findOrCreateBuilding(divisionId, buildingName);
    final floor = await db.findOrCreateFloor(buildingId, floorName, floorArea);

    int? roomId;
    if (roomName.isNotEmpty) {
      final roomArea = double.tryParse(row[6].toString().trim().replaceAll(',', '.')) ?? 0;
      final hasComputer = row[7].toString().trim().toLowerCase() == 'так';
      final room = await db.findOrCreateRoom(floor.id!, roomName, roomArea, hasComputer);
      roomId = room.id;
    }

    // Дедуплікація за інвентарним номером у межах кабінету/поверху.
    final existingList =
        roomId != null ? await db.getExtinguishersForRoom(roomId) : await db.getExtinguishersForFloor(floor.id!);
    final existing = existingList.where((e) => e.inventoryNumber == inventory);

    final extinguisher = Extinguisher(
      id: existing.isNotEmpty ? existing.first.id : null,
      serialNumber: serial,
      inventoryNumber: inventory,
      type: ExtinguisherType.fromCode(typeCode),
      capacityLiters: capacity,
      roomId: roomId,
      floorId: roomId == null ? floor.id : null,
    );
    if (existing.isNotEmpty) {
      await db.updateExtinguisher(extinguisher);
    } else {
      await db.insertExtinguisher(extinguisher);
    }
  }
}

class _SkipRow implements Exception {}
