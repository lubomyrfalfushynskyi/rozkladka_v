import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/building.dart';
import '../models/custom_extinguisher_model.dart';
import '../models/division.dart';
import '../models/extinguisher.dart';
import '../models/extinguisher_type.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/territory.dart';

const String _settingsKeyGeneralAllowedTypes = 'general_allowed_types';
const String _defaultDivisionName = 'Без управління';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  /// Ім'я файлу БД. Перевизначається в тестах, щоб різні тестові файли
  /// (які запускаються паралельно в окремих ізолятах) не ділили один і
  /// той самий файл на диску через `databaseFactoryFfiNoIsolate` — інакше
  /// паралельний запуск падає з "database is locked".
  static String dbFileName = 'vohnegasnyky.db';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbFileName);
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE divisions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE buildings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            divisionId INTEGER NOT NULL,
            name TEXT NOT NULL,
            FOREIGN KEY (divisionId) REFERENCES divisions (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE floors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            buildingId INTEGER NOT NULL,
            name TEXT NOT NULL,
            totalArea REAL NOT NULL,
            FOREIGN KEY (buildingId) REFERENCES buildings (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE rooms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            floorId INTEGER NOT NULL,
            name TEXT NOT NULL,
            area REAL NOT NULL,
            hasComputer INTEGER NOT NULL,
            FOREIGN KEY (floorId) REFERENCES floors (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE territories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            divisionId INTEGER NOT NULL,
            name TEXT NOT NULL,
            area REAL NOT NULL,
            assignedShields INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (divisionId) REFERENCES divisions (id) ON DELETE CASCADE
          )
        ''');
        await _createExtinguisherTables(db);
        await _createCustomExtinguisherModelsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createExtinguisherTables(db);
        }
        if (oldVersion < 3) {
          await _migrateToDivisions(db);
        }
        if (oldVersion < 4) {
          await _createCustomExtinguisherModelsTable(db);
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE territories ADD COLUMN assignedShields INTEGER NOT NULL DEFAULT 0');
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createExtinguisherTables(Database db) async {
    await db.execute('''
      CREATE TABLE extinguishers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serialNumber TEXT NOT NULL,
        inventoryNumber TEXT NOT NULL,
        type TEXT NOT NULL,
        capacityLiters REAL NOT NULL,
        roomId INTEGER,
        floorId INTEGER,
        FOREIGN KEY (roomId) REFERENCES rooms (id) ON DELETE CASCADE,
        FOREIGN KEY (floorId) REFERENCES floors (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert(
      'settings',
      {'key': _settingsKeyGeneralAllowedTypes, 'value': ExtinguisherType.vp.code},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _createCustomExtinguisherModelsTable(Database db) async {
    await db.execute('''
      CREATE TABLE custom_extinguisher_models (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        type TEXT NOT NULL,
        capacity REAL NOT NULL,
        category TEXT NOT NULL
      )
    ''');
  }

  /// Додає новий рівень ієрархії "Управління" над будівлями й територіями.
  /// Наявні будівлі/території (без управління) переносяться в
  /// автоматично створене управління-заглушку, щоб дані не загубились.
  Future<void> _migrateToDivisions(Database db) async {
    await db.execute('''
      CREATE TABLE divisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('ALTER TABLE buildings ADD COLUMN divisionId INTEGER');
    await db.execute('ALTER TABLE territories ADD COLUMN divisionId INTEGER');

    final existingBuildings = await db.query('buildings');
    final existingTerritories = await db.query('territories');
    if (existingBuildings.isNotEmpty || existingTerritories.isNotEmpty) {
      final defaultDivisionId = await db.insert('divisions', {'name': _defaultDivisionName});
      await db.update('buildings', {'divisionId': defaultDivisionId}, where: 'divisionId IS NULL');
      await db.update('territories', {'divisionId': defaultDivisionId}, where: 'divisionId IS NULL');
    }
  }

  // Divisions
  Future<int> insertDivision(Division division) async {
    final db = await database;
    return db.insert('divisions', division.toMap()..remove('id'));
  }

  Future<int> updateDivision(Division division) async {
    final db = await database;
    return db.update('divisions', division.toMap(), where: 'id = ?', whereArgs: [division.id]);
  }

  Future<int> deleteDivision(int id) async {
    final db = await database;
    return db.delete('divisions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Division>> getDivisions() async {
    final db = await database;
    final rows = await db.query('divisions', orderBy: 'name');
    return rows.map(Division.fromMap).toList();
  }

  /// Знаходить управління за назвою (регістронезалежно, порівняння в Dart —
  /// SQLite LOWER() не працює для кирилиці) або створює нове.
  Future<int> findOrCreateDivision(String name) async {
    final db = await database;
    final rows = await db.query('divisions');
    final target = name.toLowerCase();
    for (final row in rows) {
      if ((row['name'] as String).toLowerCase() == target) return row['id'] as int;
    }
    return db.insert('divisions', {'name': name});
  }

  // Buildings
  Future<int> insertBuilding(Building building) async {
    final db = await database;
    return db.insert('buildings', building.toMap()..remove('id'));
  }

  Future<int> updateBuilding(Building building) async {
    final db = await database;
    return db.update('buildings', building.toMap(), where: 'id = ?', whereArgs: [building.id]);
  }

  Future<int> deleteBuilding(int id) async {
    final db = await database;
    return db.delete('buildings', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Building>> getBuildingsForDivision(int divisionId) async {
    final db = await database;
    final rows = await db.query('buildings', where: 'divisionId = ?', whereArgs: [divisionId], orderBy: 'name');
    return rows.map(Building.fromMap).toList();
  }

  Future<List<Building>> getBuildings() async {
    final db = await database;
    final rows = await db.query('buildings', orderBy: 'name');
    return rows.map(Building.fromMap).toList();
  }

  /// Знаходить будівлю за назвою в межах управління або створює нову.
  Future<int> findOrCreateBuilding(int divisionId, String name) async {
    final db = await database;
    final rows = await db.query('buildings', where: 'divisionId = ?', whereArgs: [divisionId]);
    final target = name.toLowerCase();
    for (final row in rows) {
      if ((row['name'] as String).toLowerCase() == target) return row['id'] as int;
    }
    return db.insert('buildings', {'divisionId': divisionId, 'name': name});
  }

  // Floors
  Future<int> insertFloor(Floor floor) async {
    final db = await database;
    return db.insert('floors', floor.toMap()..remove('id'));
  }

  Future<int> updateFloor(Floor floor) async {
    final db = await database;
    return db.update('floors', floor.toMap(), where: 'id = ?', whereArgs: [floor.id]);
  }

  Future<int> deleteFloor(int id) async {
    final db = await database;
    return db.delete('floors', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Floor>> getFloorsForBuilding(int buildingId) async {
    final db = await database;
    final rows = await db.query('floors', where: 'buildingId = ?', whereArgs: [buildingId], orderBy: 'name');
    return rows.map(Floor.fromMap).toList();
  }

  Future<List<Floor>> getAllFloors() async {
    final db = await database;
    final rows = await db.query('floors');
    return rows.map(Floor.fromMap).toList();
  }

  /// Знаходить поверх за назвою в межах будівлі. НЕ створює новий.
  Future<Floor?> findFloorByName(int buildingId, String name) async {
    final db = await database;
    final rows = await db.query('floors', where: 'buildingId = ?', whereArgs: [buildingId]);
    final target = name.toLowerCase();
    for (final row in rows) {
      if ((row['name'] as String).toLowerCase() == target) return Floor.fromMap(row);
    }
    return null;
  }

  /// Знаходить поверх за назвою в межах будівлі або створює новий з
  /// вказаною площею. Якщо вже існує — оновлює його площу значенням з CSV
  /// (джерело правди — файл, що імпортується, для синхронізації між
  /// пристроями).
  Future<Floor> findOrCreateFloor(int buildingId, String name, double totalArea) async {
    final existing = await findFloorByName(buildingId, name);
    if (existing == null) {
      final id = await insertFloor(Floor(buildingId: buildingId, name: name, totalArea: totalArea));
      return Floor(id: id, buildingId: buildingId, name: name, totalArea: totalArea);
    }
    final updated = existing.copyWith(totalArea: totalArea);
    await updateFloor(updated);
    return updated;
  }

  // Rooms
  Future<int> insertRoom(Room room) async {
    final db = await database;
    return db.insert('rooms', room.toMap()..remove('id'));
  }

  Future<int> updateRoom(Room room) async {
    final db = await database;
    return db.update('rooms', room.toMap(), where: 'id = ?', whereArgs: [room.id]);
  }

  Future<int> deleteRoom(int id) async {
    final db = await database;
    return db.delete('rooms', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Room>> getRoomsForFloor(int floorId) async {
    final db = await database;
    final rows = await db.query('rooms', where: 'floorId = ?', whereArgs: [floorId], orderBy: 'name');
    return rows.map(Room.fromMap).toList();
  }

  Future<List<Room>> getAllRooms() async {
    final db = await database;
    final rows = await db.query('rooms');
    return rows.map(Room.fromMap).toList();
  }

  /// Знаходить кабінет за назвою в межах поверху. НЕ створює новий.
  Future<Room?> findRoomByName(int floorId, String name) async {
    final db = await database;
    final rows = await db.query('rooms', where: 'floorId = ?', whereArgs: [floorId]);
    final target = name.toLowerCase();
    for (final row in rows) {
      if ((row['name'] as String).toLowerCase() == target) return Room.fromMap(row);
    }
    return null;
  }

  /// Знаходить кабінет за назвою в межах поверху або створює новий з
  /// вказаною площею й ознакою ПК. Якщо вже існує — оновлює площу й ознаку
  /// ПК значеннями з CSV.
  Future<Room> findOrCreateRoom(int floorId, String name, double area, bool hasComputer) async {
    final existing = await findRoomByName(floorId, name);
    if (existing == null) {
      final id = await insertRoom(Room(floorId: floorId, name: name, area: area, hasComputer: hasComputer));
      return Room(id: id, floorId: floorId, name: name, area: area, hasComputer: hasComputer);
    }
    final updated = existing.copyWith(area: area, hasComputer: hasComputer);
    await updateRoom(updated);
    return updated;
  }

  // Territories
  Future<int> insertTerritory(Territory territory) async {
    final db = await database;
    return db.insert('territories', territory.toMap()..remove('id'));
  }

  Future<int> updateTerritory(Territory territory) async {
    final db = await database;
    return db.update('territories', territory.toMap(), where: 'id = ?', whereArgs: [territory.id]);
  }

  Future<int> deleteTerritory(int id) async {
    final db = await database;
    return db.delete('territories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Territory>> getTerritoriesForDivision(int divisionId) async {
    final db = await database;
    final rows = await db.query('territories', where: 'divisionId = ?', whereArgs: [divisionId], orderBy: 'name');
    return rows.map(Territory.fromMap).toList();
  }

  Future<List<Territory>> getTerritories() async {
    final db = await database;
    final rows = await db.query('territories', orderBy: 'name');
    return rows.map(Territory.fromMap).toList();
  }

  /// Знаходить територію за назвою в межах управління або створює нову з
  /// вказаною площею. Якщо вже існує — оновлює площу значенням з CSV.
  Future<Territory> findOrCreateTerritory(
    int divisionId,
    String name,
    double area, {
    int? assignedShields,
  }) async {
    final db = await database;
    final rows = await db.query('territories', where: 'divisionId = ?', whereArgs: [divisionId]);
    final target = name.toLowerCase();
    for (final row in rows) {
      if ((row['name'] as String).toLowerCase() == target) {
        final updated = Territory.fromMap(row).copyWith(area: area, assignedShields: assignedShields);
        await updateTerritory(updated);
        return updated;
      }
    }
    final territory = Territory(
      divisionId: divisionId,
      name: name,
      area: area,
      assignedShields: assignedShields ?? 0,
    );
    final id = await insertTerritory(territory);
    return territory.copyWith(id: id);
  }

  // Extinguishers
  Future<int> insertExtinguisher(Extinguisher extinguisher) async {
    final db = await database;
    return db.insert('extinguishers', extinguisher.toMap()..remove('id'));
  }

  Future<int> updateExtinguisher(Extinguisher extinguisher) async {
    final db = await database;
    return db.update('extinguishers', extinguisher.toMap(), where: 'id = ?', whereArgs: [extinguisher.id]);
  }

  Future<int> deleteExtinguisher(int id) async {
    final db = await database;
    return db.delete('extinguishers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Extinguisher>> getExtinguishersForRoom(int roomId) async {
    final db = await database;
    final rows = await db.query('extinguishers', where: 'roomId = ?', whereArgs: [roomId], orderBy: 'id');
    return rows.map(Extinguisher.fromMap).toList();
  }

  Future<List<Extinguisher>> getExtinguishersForFloor(int floorId) async {
    final db = await database;
    final rows = await db.query('extinguishers', where: 'floorId = ?', whereArgs: [floorId], orderBy: 'id');
    return rows.map(Extinguisher.fromMap).toList();
  }

  Future<List<Extinguisher>> getAllExtinguishers() async {
    final db = await database;
    final rows = await db.query('extinguishers', orderBy: 'id');
    return rows.map(Extinguisher.fromMap).toList();
  }

  // Custom extinguisher models (номенклатура понад базові 30 моделей)
  Future<List<CustomExtinguisherModel>> getCustomExtinguisherModels() async {
    final db = await database;
    final rows = await db.query('custom_extinguisher_models', orderBy: 'type, capacity');
    return rows.map(CustomExtinguisherModel.fromMap).toList();
  }

  Future<int> insertCustomExtinguisherModel(CustomExtinguisherModel model) async {
    final db = await database;
    return db.insert('custom_extinguisher_models', model.toMap()..remove('id'));
  }

  Future<int> deleteCustomExtinguisherModel(int id) async {
    final db = await database;
    return db.delete('custom_extinguisher_models', where: 'id = ?', whereArgs: [id]);
  }

  // Settings
  Future<List<ExtinguisherType>> getAllowedGeneralTypes() async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [_settingsKeyGeneralAllowedTypes]);
    if (rows.isEmpty) return [ExtinguisherType.vp];
    final codes = (rows.first['value'] as String).split(',').where((c) => c.isNotEmpty);
    final types = codes.map(ExtinguisherType.fromCode).toList();
    return types.isEmpty ? [ExtinguisherType.vp] : types;
  }

  Future<void> setAllowedGeneralTypes(List<ExtinguisherType> types) async {
    final db = await database;
    final value = (types.isEmpty ? [ExtinguisherType.vp] : types).map((t) => t.code).join(',');
    await db.insert(
      'settings',
      {'key': _settingsKeyGeneralAllowedTypes, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
