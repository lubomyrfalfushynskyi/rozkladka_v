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
import 'package:rozkladka_v/services/csv_service.dart';
import 'package:rozkladka_v/services/database_service.dart';

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

  test('експорт CSV містить заголовки та рядок вогнегасника', () async {
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

    expect(csvText, contains('Ідентифікатор'));
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

  test('імпорт CSV додає вогнегасник у наявний кабінет', () async {
    final db = DatabaseService.instance;
    final divisionId = await db.insertDivision(const Division(name: 'Управління Імпорт'));
    final buildingId = await db.insertBuilding(Building(divisionId: divisionId, name: 'Будівля Імпорт'));
    final floorId = await db.insertFloor(Floor(buildingId: buildingId, name: 'Поверх Імпорт', totalArea: 200));
    final roomId = await db.insertRoom(
      Room(floorId: floorId, name: 'Каб. Імпорт', area: 25, hasComputer: true),
    );

    final csvText = 'Ідентифікатор,Управління,Будівля,Поверх,Кабінет,Тип,Модель,Ємність,Одиниця,Заводський номер,Інвентарний номер\n'
        ',Управління Імпорт,Будівля Імпорт,Поверх Імпорт,Каб. Імпорт,ВВК,ВВК-5,5,кг,SN-IMPORT-1,1234002\n';

    final result = await CsvService.importCsv(csvText);

    expect(result.imported, 1);
    expect(result.skipped, isEmpty);

    final roomExtinguishers = await db.getExtinguishersForRoom(roomId);
    expect(roomExtinguishers.length, 1);
    expect(roomExtinguishers.first.serialNumber, 'SN-IMPORT-1');
    expect(roomExtinguishers.first.type, ExtinguisherType.vvk);
  });

  test('імпорт пропускає рядок, якщо поверх не існує', () async {
    final csvText = 'Ідентифікатор,Управління,Будівля,Поверх,Кабінет,Тип,Модель,Ємність,Одиниця,Заводський номер,Інвентарний номер\n'
        ',Неіснуюче управління,Неіснуюча будівля,Неіснуючий поверх,Загальна площа,ВП,ВП-5,5,кг,SN-X,1234003\n';

    final result = await CsvService.importCsv(csvText);

    expect(result.imported, 0);
    expect(result.skipped.length, 1);
  });
}
