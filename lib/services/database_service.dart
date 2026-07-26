import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/building.dart';
import '../models/extinguisher.dart';
import '../models/extinguisher_type.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/territory.dart';

const String _settingsKeyGeneralAllowedTypes = 'general_allowed_types';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vohnegasnyky.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE buildings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
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
            name TEXT NOT NULL,
            area REAL NOT NULL
          )
        ''');
        await _createExtinguisherTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createExtinguisherTables(db);
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

  Future<List<Building>> getBuildings() async {
    final db = await database;
    final rows = await db.query('buildings', orderBy: 'name');
    return rows.map(Building.fromMap).toList();
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

  Future<List<Territory>> getTerritories() async {
    final db = await database;
    final rows = await db.query('territories', orderBy: 'name');
    return rows.map(Territory.fromMap).toList();
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
