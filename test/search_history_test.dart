import 'dart:io';

import 'package:dh_wrap/data/db/app_database.dart';
import 'package:dh_wrap/data/search/search_history_store.dart';
import 'package:dh_wrap/domain/entities/employee_status_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('ค้นคำเดิมซ้ำแล้วยกขึ้นบนสุด และฐานข้อมูลเดิมได้ตารางนี้', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'dh_wrap_search_history',
    );
    final path = p.join(tempDir.path, 'employees.db');
    final opened = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    await opened.close();

    final database = AppDatabase(path: path, factory: databaseFactoryFfi);
    addTearDown(() async {
      await database.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    var clock = DateTime(2026, 11, 12, 9, 1);
    final history = SearchHistoryStore(database, now: () => clock);
    await history.add(
      query: ' เกมส์ ',
      status: EmployeeStatusFilter.working,
      branchLabel: null,
    );
    clock = DateTime(2026, 11, 12, 9, 2);
    await history.add(
      query: 'สมชาย',
      status: EmployeeStatusFilter.all,
      branchLabel: ' สาขาขอนแก่น ',
    );
    clock = DateTime(2026, 11, 12, 9, 3);
    await history.add(
      query: 'เกมส์',
      status: EmployeeStatusFilter.working,
      branchLabel: '',
    );

    final saved = await history.list();
    expect(saved, hasLength(2));
    expect(saved.first.query, 'เกมส์');
    expect(saved.first.status, EmployeeStatusFilter.working);
    expect(saved.first.branchLabel, isNull);
    expect(saved.first.searchedAt, DateTime(2026, 11, 12, 9, 3));
    expect(saved.last.query, 'สมชาย');
    expect(saved.last.branchLabel, 'สาขาขอนแก่น');
    expect(saved.last.status, EmployeeStatusFilter.all);

    await history.delete(saved.first.id);
    final remaining = await history.list();
    expect(remaining, hasLength(1));
    expect(remaining.single.query, 'สมชาย');
  });
}
