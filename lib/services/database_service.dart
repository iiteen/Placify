import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/role.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'roles.db');

    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyName TEXT NOT NULL,
        roleName TEXT NOT NULL,
        pptDate TEXT,
        testDate TEXT,
        interviewDate TEXT,
        isInterested INTEGER NOT NULL,
        isRejected INTEGER NOT NULL,
        pptEventId TEXT,
        testEventId TEXT,
        interviewEventId TEXT
      )
    ''');
  }

  Future<int> insertRole(Role role) async {
    final db = await database;
    final id = await db.insert(
      'roles',
      role.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    role.id = id;
    return id;
  }

  Future<List<Role>> getAllRoles() async {
    final db = await database;
    final rows = await db.query('roles', orderBy: 'id DESC');
    return rows.map((e) => Role.fromMap(e)).toList();
  }

  Future<int> updateRole(Role role) async {
    final db = await database;
    return await db.update(
      'roles',
      role.toMap(),
      where: 'id = ?',
      whereArgs: [role.id],
    );
  }

  Future<int> deleteRole(int id) async {
    final db = await database;
    return await db.delete('roles', where: 'id = ?', whereArgs: [id]);
  }
}
