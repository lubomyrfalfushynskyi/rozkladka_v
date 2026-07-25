import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/building.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/territory.dart';

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
      version: 1,
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
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
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
}
