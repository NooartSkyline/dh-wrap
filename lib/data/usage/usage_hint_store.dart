import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

abstract interface class UsageHints {
  Future<bool> seen();

  Future<void> markSeen();
}

class UsageHintStore implements UsageHints {
  UsageHintStore(this._database);

  static const _key = 'usage_hint_seen';

  final AppDatabase _database;

  @override
  Future<bool> seen() async {
    final db = await _database.open();
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_key],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.first['value'] == '1';
  }

  @override
  Future<void> markSeen() async {
    final db = await _database.open();
    await db.insert('app_meta', {
      'key': _key,
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
