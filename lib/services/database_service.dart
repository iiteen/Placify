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
        companyName TEXT NOT NULL COLLATE NOCASE,
        roleName TEXT NOT NULL COLLATE NOCASE,
        pptDate TEXT,
        testDate TEXT,
        applicationDeadline TEXT,
        isInterested INTEGER NOT NULL,
        isRejected INTEGER NOT NULL,
        pptEventId TEXT,
        testEventId TEXT,
        applicationDeadlineEventId TEXT
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

  /// Finds a role by company name and role name.
  /// Returns null if no matching role is found.
  Future<Role?> findRole(String companyName, String roleName) async {
    final db = await database;
    final rows = await db.query(
      'roles',
      where: 'companyName = ? AND roleName = ?',
      whereArgs: [companyName, roleName],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return Role.fromMap(rows.first);
    } else {
      return null;
    }
  }

  Future<List<Role>> findRolesByCompany(String companyName) async {
    final db = await database;
    final rows = await db.query(
      'roles',
      where: 'companyName = ?',
      whereArgs: [companyName],
    );

    // Map each row to a Role object
    return rows.map((row) => Role.fromMap(row)).toList();
  }


  // Fetch only active roles (not rejected)
  Future<List<Role>> getActiveRoles() async {
    final dbClient = await database;
    final rows = await dbClient.query(
      'roles',
      where: 'isRejected = ?',
      whereArgs: [0], // 0 = false
      orderBy: 'id DESC',
    );
    return rows.map((e) => Role.fromMap(e)).toList();
  }

  // Fetch only rejected roles
  Future<List<Role>> getRejectedRoles() async {
    final dbClient = await database;
    final rows = await dbClient.query(
      'roles',
      where: 'isRejected = ?',
      whereArgs: [1], // 1 = true
      orderBy: 'id DESC',
    );
    return rows.map((e) => Role.fromMap(e)).toList();
  }
}
