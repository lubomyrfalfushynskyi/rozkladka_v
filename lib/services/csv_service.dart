import 'package:csv/csv.dart';

import '../models/extinguisher.dart';
import '../models/extinguisher_import_result.dart';
import '../models/extinguisher_model_catalog.dart';
import '../models/extinguisher_type.dart';
import 'database_service.dart';

const String generalAreaLabel = 'Загальна площа';

const List<String> csvHeaders = [
  'Ідентифікатор',
  'Управління',
  'Будівля',
  'Поверх',
  'Кабінет',
  'Тип',
  'Модель',
  'Ємність',
  'Одиниця',
  'Заводський номер',
  'Інвентарний номер',
];

class CsvService {
  /// Формує CSV-звіт по вогнегасниках. Без параметрів — по всіх управліннях
  /// (глобальний звіт). З `divisionId`/`buildingId`/`floorId`/`roomId` —
  /// звіт обмежується відповідним рівнем ієрархії (звіт "на цьому рівні").
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
        for (final floor in floors) {
          if (floorId != null && floor.id != floorId) continue;
          if (roomId == null) {
            final floorExtinguishers = await db.getExtinguishersForFloor(floor.id!);
            for (final e in floorExtinguishers) {
              rows.add(_row(e, division.name, building.name, floor.name, generalAreaLabel, customModels));
            }
          }
          final rooms = await db.getRoomsForFloor(floor.id!);
          for (final room in rooms.where((r) => r.hasComputer)) {
            if (roomId != null && room.id != roomId) continue;
            final roomExtinguishers = await db.getExtinguishersForRoom(room.id!);
            for (final e in roomExtinguishers) {
              rows.add(_row(e, division.name, building.name, floor.name, room.name, customModels));
            }
          }
        }
      }
    }

    return csv.encode(rows);
  }

  static List<String> _row(
    Extinguisher e,
    String division,
    String building,
    String floor,
    String room,
    List<ExtinguisherModel> customModels,
  ) {
    final model = ExtinguisherModelCatalog.findByTypeAndCapacityWithCustom(e.type, e.capacityLiters, customModels);
    return [
      e.id?.toString() ?? '',
      division,
      building,
      floor,
      room,
      e.type.code,
      model?.code ?? '',
      _formatCapacity(e.capacityLiters),
      e.type.unit,
      e.serialNumber,
      e.inventoryNumber,
    ];
  }

  static String _formatCapacity(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  /// Імпортує вогнегасники з CSV. Управління/будівля створюються
  /// автоматично за назвою, якщо їх ще немає. Поверх і кабінет мають вже
  /// існувати (їхню площу неможливо відновити з CSV) — якщо не знайдено,
  /// рядок пропускається і потрапляє у список skipped.
  static Future<ExtinguisherImportResult> importCsv(String csvText) async {
    final db = DatabaseService.instance;
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
      final divisionName = row[1].toString().trim();
      final buildingName = row[2].toString().trim();
      final floorName = row[3].toString().trim();
      final roomName = row[4].toString().trim();
      final typeCode = row[5].toString().trim();
      final capacityText = row[7].toString().trim().replaceAll(',', '.');
      final serial = row[9].toString().trim();
      final inventory = row[10].toString().trim();

      final capacity = double.tryParse(capacityText);
      if (divisionName.isEmpty || buildingName.isEmpty || floorName.isEmpty || capacity == null) {
        skipped.add('Рядок ${i + 1}: відсутні обовʼязкові поля');
        continue;
      }

      final divisionId = await db.findOrCreateDivision(divisionName);
      final buildingId = await db.findOrCreateBuilding(divisionId, buildingName);
      final floor = await db.findFloorByName(buildingId, floorName);
      if (floor == null) {
        skipped.add('Рядок ${i + 1}: поверх "$floorName" не знайдено в будівлі "$buildingName" — спочатку створи його');
        continue;
      }

      int? roomId;
      if (roomName.isNotEmpty && roomName != generalAreaLabel) {
        final room = await db.findRoomByName(floor.id!, roomName);
        if (room == null) {
          skipped.add('Рядок ${i + 1}: кабінет "$roomName" не знайдено на поверсі "$floorName" — спочатку створи його');
          continue;
        }
        roomId = room.id;
      }

      final extinguisher = Extinguisher(
        serialNumber: serial,
        inventoryNumber: inventory,
        type: ExtinguisherType.fromCode(typeCode),
        capacityLiters: capacity,
        roomId: roomId,
        floorId: roomId == null ? floor.id : null,
      );
      await db.insertExtinguisher(extinguisher);
      imported++;
    }

    return ExtinguisherImportResult(imported: imported, skipped: skipped);
  }
}
