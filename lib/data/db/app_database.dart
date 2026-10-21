import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({String? path, DatabaseFactory? factory})
    : _path = path,
      _factory = factory;

  final String? _path;
  final DatabaseFactory? _factory;
  Database? _database;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null) return existing;
    final path = _path ?? p.join(await getDatabasesPath(), 'employees.db');
    final factory = _factory ?? databaseFactory;
    final opened = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
    _database = opened;
    return opened;
  }

  Future<void> close() async {
    final existing = _database;
    _database = null;
    await existing?.close();
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employees (
        person_id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL DEFAULT '',
        last_name TEXT NOT NULL DEFAULT '',
        first_name_alt1 TEXT NOT NULL DEFAULT '',
        last_name_alt1 TEXT NOT NULL DEFAULT '',
        nick_name TEXT NOT NULL DEFAULT '',
        employee_status TEXT NOT NULL DEFAULT '',
        position_desc TEXT NOT NULL DEFAULT '',
        employee_type TEXT NOT NULL DEFAULT '',
        company TEXT NOT NULL DEFAULT '',
        business_name TEXT NOT NULL DEFAULT '',
        division_hq_name TEXT NOT NULL DEFAULT '',
        division_branch_name TEXT NOT NULL DEFAULT '',
        section_name TEXT NOT NULL DEFAULT '',
        unit_name TEXT NOT NULL DEFAULT '',
        supervisor TEXT NOT NULL DEFAULT '',
        branch_name TEXT NOT NULL DEFAULT '',
        location_desc TEXT NOT NULL DEFAULT '',
        branch_label TEXT NOT NULL DEFAULT '',
        mobile_phone TEXT NOT NULL DEFAULT '',
        business_phone TEXT NOT NULL DEFAULT '',
        email_company TEXT NOT NULL DEFAULT '',
        hire_date TEXT NOT NULL DEFAULT '',
        end_date TEXT NOT NULL DEFAULT '',
        search_text TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_employees_status ON employees(employee_status)',
    );
    await db.execute(
      'CREATE INDEX idx_employees_branch_status ON employees(branch_label, employee_status)',
    );
    await db.execute(
      'CREATE INDEX idx_employees_sort ON employees(first_name, last_name, person_id)',
    );
    await db.execute('''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
