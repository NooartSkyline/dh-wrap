import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/theme/app_theme.dart';
import '../db/app_database.dart';

class ThemeSeedStore {
  ThemeSeedStore(this._database);

  static const _key = 'theme_seed';

  final AppDatabase _database;

  Future<Color> read() async {
    final db = await _database.open();
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_key],
      limit: 1,
    );
    if (rows.isEmpty) return AppColors.standardSeed;
    final parsed = int.tryParse('${rows.first['value']}');
    if (parsed == null) return AppColors.standardSeed;
    return colorFromArgb(parsed);
  }

  Future<void> save(Color color) async {
    final db = await _database.open();
    await db.insert('app_meta', {
      'key': _key,
      'value': '${color.toARGB32()}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

Color colorFromArgb(int value) {
  return Color.fromARGB(
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  );
}
