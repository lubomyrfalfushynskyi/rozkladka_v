import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:rozkladka_v/models/custom_extinguisher_model.dart';
import 'package:rozkladka_v/models/extinguisher_model_catalog.dart';
import 'package:rozkladka_v/models/extinguisher_type.dart';
import 'package:rozkladka_v/services/database_service.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseService.dbFileName = 'vohnegasnyky_catalog_test.db';
    final path = join(await getDatabasesPath(), DatabaseService.dbFileName);
    await databaseFactory.deleteDatabase(path);
  });

  test('додана модель зберігається і потрапляє у список для свого типу', () async {
    final db = DatabaseService.instance;
    final id = await db.insertCustomExtinguisherModel(const CustomExtinguisherModel(
      code: 'ВП-77',
      type: ExtinguisherType.vp,
      capacity: 77,
      category: ExtinguisherCategory.mobile,
    ));

    final custom = await db.getCustomExtinguisherModels();
    expect(custom.any((m) => m.id == id && m.code == 'ВП-77'), isTrue);

    final merged = ExtinguisherModelCatalog.forTypeWithCustom(
      ExtinguisherType.vp,
      custom.map((c) => c.asModel).toList(),
    );
    expect(merged.any((m) => m.code == 'ВП-77'), isTrue);
    // Базові моделі типу ВП мають лишитись у списку поруч з доданою.
    expect(merged.any((m) => m.code == 'ВП-5'), isTrue);
  });

  test('видалена модель зникає зі списку', () async {
    final db = DatabaseService.instance;
    final id = await db.insertCustomExtinguisherModel(const CustomExtinguisherModel(
      code: 'ВВ-77',
      type: ExtinguisherType.vv,
      capacity: 77,
      category: ExtinguisherCategory.mobile,
    ));
    await db.deleteCustomExtinguisherModel(id);

    final custom = await db.getCustomExtinguisherModels();
    expect(custom.any((m) => m.code == 'ВВ-77'), isFalse);
  });

  test('findByTypeAndCapacityWithCustom знаходить кастомну модель, якщо базової немає', () async {
    const custom = [
      ExtinguisherModel(
        code: 'ВВП-77',
        type: ExtinguisherType.vvp,
        capacity: 77,
        category: ExtinguisherCategory.mobile,
      ),
    ];
    final found = ExtinguisherModelCatalog.findByTypeAndCapacityWithCustom(ExtinguisherType.vvp, 77, custom);
    expect(found?.code, 'ВВП-77');

    final notFound = ExtinguisherModelCatalog.findByTypeAndCapacityWithCustom(ExtinguisherType.vvp, 999, custom);
    expect(notFound, isNull);
  });
}
