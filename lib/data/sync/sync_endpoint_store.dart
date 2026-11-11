import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

abstract class SyncEndpointStore {
  Future<String?> read();

  Future<void> save(String url);
}

class SqliteSyncEndpointStore implements SyncEndpointStore {
  SqliteSyncEndpointStore(this._database);

  static const _key = 'sync_base_url';

  final AppDatabase _database;

  @override
  Future<String?> read() async {
    final db = await _database.open();
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'];
    if (value is! String) return null;
    final url = value.trim();
    if (url.isEmpty) return null;
    return url;
  }

  @override
  Future<void> save(String url) async {
    final db = await _database.open();
    await db.insert('app_meta', {
      'key': _key,
      'value': url.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
