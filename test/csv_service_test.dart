import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:rozkladka_v/models/building.dart';
import 'package:rozkladka_v/models/custom_extinguisher_model.dart';
import 'package:rozkladka_v/models/division.dart';
import 'package:rozkladka_v/models/extinguisher.dart';
import 'package:rozkladka_v/models/extinguisher_model_catalog.dart';
import 'package:rozkladka_v/models/extinguisher_type.dart';
import 'package:rozkladka_v/models/floor.dart';
import 'package:rozkladka_v/models/room.dart';
import 'package:rozkladka_v/models/territory.dart';
import 'package:rozkladka_v/services/csv_service.dart';
import 'package:rozkladka_v/services/database_service.dart';

/// Будує один рядок CSV за назвами колонок (а не позиційно), щоб тестові
/// дані не залежали від точного порядку колонок і не ламались мовчки при
/// підрахунку ком вручну.
String _row(Map<String, String> values) {
  final row = List<String>.filled(csvHeaders.length, '');
  values.forEach((key, value) {
    final index = csvHeaders.indexOf(key);
    if (index == -1) throw ArgumentError('Невідома колонка: $key');
    row[index] = value;
  });
  return row.join(',');
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    // Тестова БД — окремий файл (унікальний для цього тестового файлу, щоб
    // паралельний запуск різних *_test.dart не ділив один файл — інакше
    // "database is locked"), який чистимо перед кожним прогоном тестів,
    // інакше дані з попередніх запусків "flutter test" накопичуються і
    // плутають пошук за назвою (findOrCreate*).
    DatabaseService.dbFileName = 'vohnegasnyky_csv_test.db';
    final path = join(await getDatabasesPath(), DatabaseService.dbFileName);
    await databaseFactory.deleteDatabase(path);
  });

  test('експорт починається з UTF-8 BOM (для коректного відкриття в Excel)', () async {
    final db = DatabaseService.instance;
    final divisionId = await db.insertDivision(const Division(name: 'Управління BOM'));
    await db.insertBuilding(Building(divisionId: divisionId, name: 'Будівля BOM'));

    final csvText = await CsvService.buildCsv(divisionId: divisionId);

    expect(csvText.startsWith('\uFEFF'), isTrue);
  });

  test('експорт містить заголовки та рядок вогнегасника', () async {
    final db = DatabaseService.instance;
    final divisionId = await db.insertDivision(const Division(name: 'Тестове управління'));
    final buildingId = await db.insertBuilding(Building(divisionId: divisionId, name: 'Тестова будівля'));
    final floorId = await db.insertFloor(Floor(buildingId: buildingId, name: 'Тестовий поверх', totalArea: 100));
    await db.insertExtinguisher(Extinguisher(
      serialNumber: 'SN-CSV-1',
      inventoryNumber: '1234001',
      type: ExtinguisherType.vp,
      capacityLiters: 5,
      floorId: floorId,
    ));

    final csvText = await CsvService.buildCsv();

    expect(csvText, contains('Тип рядка'));
    expect(csvText, contains(rowTypeExtinguisher));
    expect(csvText, contains('Тестове управління'));
    expect(csvText, contains('Тестова будівля'));
    expect(csvText, contains('Тестовий поверх'));
    expect(csvText, contains('SN-CSV-1'));
    expect(csvText, contains('1234001'));
  });

  test('експорт з divisionId обмежує звіт лише цим управлінням', () async {
    final db = DatabaseService.instance;
    final divisionAId = await db.insertDivision(const Division(name: 'Управління Скоуп А'));
    final buildingAId = await db.insertBuilding(Building(divisionId: divisionAId, name: 'Будівля Скоуп А'));
    final floorAId = await db.insertFloor(Floor(buildingId: buildingAId, name: 'Поверх Скоуп А', totalArea: 100));
    await db.insertExtinguisher(Extinguisher(
      serialNumber: 'SN-SCOPE-A',
      inventoryNumber: '1234004',
      type: ExtinguisherType.vp,
      capacityLiters: 5,
      floorId: floorAId,
    ));

    final divisionBId = await db.insertDivision(const Division(name: 'Управління Скоуп Б'));
    final buildingBId = await db.insertBuilding(Building(divisionId: divisionBId, name: 'Будівля Скоуп Б'));
    final floorBId = await db.insertFloor(Floor(buildingId: buildingBId, name: 'Поверх Скоуп Б', totalArea: 100));
    await db.insertExtinguisher(Extinguisher(
      serialNumber: 'SN-SCOPE-B',
      inventoryNumber: '1234005',
      type: ExtinguisherType.vp,
      capacityLiters: 5,
      floorId: floorBId,
    ));

    final csvText = await CsvService.buildCsv(divisionId: divisionAId);

    expect(csvText, contains('SN-SCOPE-A'));
    expect(csvText, isNot(contains('SN-SCOPE-B')));
  });

  test('експорт показує код кастомної моделі в колонці Модель', () async {
    final db = DatabaseService.instance;
    final divisionId = await db.insertDivision(const Division(name: 'Управління Кастом'));
    final buildingId = await db.insertBuilding(Building(divisionId: divisionId, name: 'Будівля Кастом'));
    final floorId = await db.insertFloor(Floor(buildingId: buildingId, name: 'Поверх Кастом', totalArea: 100));
    await db.insertCustomExtinguisherModel(const CustomExtinguisherModel(
      code: 'ВП-7-Кастом',
      type: ExtinguisherType.vp,
      capacity: 7,
      category: ExtinguisherCategory.portable,
    ));
    await db.insertExtinguisher(Extinguisher(
      serialNumber: 'SN-CUSTOM-1',
      inventoryNumber: '1234006',
      type: ExtinguisherType.vp,
      capacityLiters: 7,
      floorId: floorId,
    ));

    final csvText = await CsvService.buildCsv(divisionId: divisionId);

    expect(csvText, contains('ВП-7-Кастом'));
  });

  test('порожній поверх і кабінет без ПК передаються в CSV (заглушки, без вогнегасника)', () async {
    final db = DatabaseService.instance;
    final divisionId = await db.insertDivision(const Division(name: 'Управління Заглушки'));
    final buildingId = await db.insertBuilding(Building(divisionId: divisionId, name: 'Будівля Заглушки'));
    await db.insertFloor(Floor(buildingId: buildingId, name: 'Порожній поверх', totalArea: 77));
    final floorWithRoomId =
        await db.insertFloor(Floor(buildingId: buildingId, name: 'Поверх з кабінетом', totalArea: 88));
    await db.insertRoom(Room(floorId: floorWithRoomId, name: 'Каб. без ПК', area: 33, hasComputer: false));

    final csvText = await CsvService.buildCsv(divisionId: divisionId);

    expect(csvText, contains(rowTypeFloor));
    expect(csvText, contains('Порожній поверх'));
    expect(csvText, contains('77'));
    expect(csvText, contains(rowTypeRoom));
    expect(csvText, contains('Каб. без ПК'));
    expect(csvText, contains('33'));
  });

  test('імпорт CSV додає вогнегасник у наявний кабінет', () async {
    final db = DatabaseService.instance;
    final divisionId = await db.insertDivision(const Division(name: 'Управління Імпорт'));
    final buildingId = await db.insertBuilding(Building(divisionId: divisionId, name: 'Будівля Імпорт'));
    final floorId = await db.insertFloor(Floor(buildingId: buildingId, name: 'Поверх Імпорт', totalArea: 200));
    final roomId = await db.insertRoom(
      Room(floorId: floorId, name: 'Каб. Імпорт', area: 25, hasComputer: true),
    );

    final csvText = '${csvHeaders.join(',')}\n'
        '${_row({
      'Тип рядка': rowTypeExtinguisher,
      'Управління': 'Управління Імпорт',
      'Будівля': 'Будівля Імпорт',
      'Поверх': 'Поверх Імпорт',
      'Площа поверху': '200',
      'Кабінет': 'Каб. Імпорт',
      'Площа кабінету': '25',
      'Кабінет з ПК': 'так',
      'Тип': 'ВВК',
      'Модель': 'ВВК-5',
      'Ємність': '5',
      'Одиниця': 'кг',
      'Заводський номер': 'SN-IMPORT-1',
      'Інвентарний номер': '1234002',
    })}\n';

    final result = await CsvService.importCsv(csvText);

    expect(result.imported, 1);
    expect(result.skipped, isEmpty);

    final roomExtinguishers = await db.getExtinguishersForRoom(roomId);
    expect(roomExtinguishers.length, 1);
    expect(roomExtinguishers.first.serialNumber, 'SN-IMPORT-1');
    expect(roomExtinguishers.first.type, ExtinguisherType.vvk);
  });

  test('імпорт пропускає рядок, якщо не вистачає обовʼязкових полів', () async {
    final csvText = '${csvHeaders.join(',')}\n'
        '${_row({
      'Тип рядка': rowTypeExtinguisher,
      'Управління': 'Неіснуюче управління',
      'Будівля': 'Неіснуюча будівля',
      // Поверх і площа поверху навмисно відсутні — рядок має бути пропущений.
      'Тип': 'ВП',
      'Модель': 'ВП-5',
      'Одиниця': 'кг',
      'Заводський номер': 'SN-X',
      'Інвентарний номер': '1234003',
    })}\n';

    final result = await CsvService.importCsv(csvText);

    expect(result.imported, 0);
    expect(result.skipped.length, 1);
  });

  test('ПОВНИЙ ЦИКЛ: експорт → видалення управління → імпорт відновлює все дерево ідентично', () async {
    final db = DatabaseService.instance;

    final divisionId = await db.insertDivision(const Division(name: 'Кругообіг'));
    final buildingId = await db.insertBuilding(Building(divisionId: divisionId, name: 'Будівля Round'));
    final floorAId = await db.insertFloor(Floor(buildingId: buildingId, name: 'Поверх 1', totalArea: 300));
    await db.insertFloor(Floor(buildingId: buildingId, name: 'Поверх 2', totalArea: 150));

    await db.insertRoom(Room(floorId: floorAId, name: 'Каб 101', area: 15, hasComputer: false));
    final room102Id = await db.insertRoom(Room(floorId: floorAId, name: 'Каб 102', area: 22, hasComputer: true));
    await db.insertExtinguisher(Extinguisher(
      serialNumber: 'SN-ROUND-ROOM',
      inventoryNumber: '1234101',
      type: ExtinguisherType.vvk,
      capacityLiters: 5,
      roomId: room102Id,
    ));
    await db.insertExtinguisher(Extinguisher(
      serialNumber: 'SN-ROUND-FLOOR',
      inventoryNumber: '1234102',
      type: ExtinguisherType.vp,
      capacityLiters: 5,
      floorId: floorAId,
    ));
    // Поверх 2 навмисно лишається зовсім порожнім (без кабінетів і вогнегасників).
    await db.insertTerritory(Territory(divisionId: divisionId, name: 'Двір', area: 12000));

    final csvText = await CsvService.buildCsv(divisionId: divisionId);

    // Видаляємо управління — каскадно зникає геть усе (будівля/поверхи/кабінети/вогнегасники/територія).
    await db.deleteDivision(divisionId);
    expect((await db.getDivisions()).where((d) => d.name == 'Кругообіг'), isEmpty);

    final importResult = await CsvService.importCsv(csvText);
    expect(importResult.skipped, isEmpty);

    final restoredDivisionId = await db.findOrCreateDivision('Кругообіг');
    final restoredBuildings = await db.getBuildingsForDivision(restoredDivisionId);
    expect(restoredBuildings, hasLength(1));
    expect(restoredBuildings.first.name, 'Будівля Round');

    final restoredFloors = await db.getFloorsForBuilding(restoredBuildings.first.id!);
    expect(restoredFloors, hasLength(2));
    final floor1 = restoredFloors.firstWhere((f) => f.name == 'Поверх 1');
    final floor2 = restoredFloors.firstWhere((f) => f.name == 'Поверх 2');
    expect(floor1.totalArea, 300);
    expect(floor2.totalArea, 150); // площа порожнього поверху не загубилась

    final restoredRooms = await db.getRoomsForFloor(floor1.id!);
    expect(restoredRooms, hasLength(2));
    final room101 = restoredRooms.firstWhere((r) => r.name == 'Каб 101');
    final room102 = restoredRooms.firstWhere((r) => r.name == 'Каб 102');
    expect(room101.area, 15);
    expect(room101.hasComputer, isFalse);
    expect(room102.area, 22);
    expect(room102.hasComputer, isTrue);

    final room102Extinguishers = await db.getExtinguishersForRoom(room102.id!);
    expect(room102Extinguishers, hasLength(1));
    expect(room102Extinguishers.first.serialNumber, 'SN-ROUND-ROOM');

    final floor1Extinguishers = await db.getExtinguishersForFloor(floor1.id!);
    expect(floor1Extinguishers, hasLength(1));
    expect(floor1Extinguishers.first.serialNumber, 'SN-ROUND-FLOOR');

    final restoredTerritories = await db.getTerritoriesForDivision(restoredDivisionId);
    expect(restoredTerritories, hasLength(1));
    expect(restoredTerritories.first.name, 'Двір');
    expect(restoredTerritories.first.area, 12000);

    // Повторний імпорт того самого файлу — не повинен дублювати нічого.
    final secondImport = await CsvService.importCsv(csvText);
    expect(secondImport.skipped, isEmpty);
    expect(await db.getExtinguishersForRoom(room102.id!), hasLength(1));
    expect(await db.getExtinguishersForFloor(floor1.id!), hasLength(1));
    expect(await db.getBuildingsForDivision(restoredDivisionId), hasLength(1));
    expect(await db.getFloorsForBuilding(restoredBuildings.first.id!), hasLength(2));
    expect(await db.getTerritoriesForDivision(restoredDivisionId), hasLength(1));
  });
}
