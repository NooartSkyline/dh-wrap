import 'dart:convert';

import 'package:dh_wrap/data/db/app_database.dart';
import 'package:dh_wrap/data/repositories/employee_repository_impl.dart';
import 'package:dh_wrap/domain/entities/employee_search_query.dart';
import 'package:dh_wrap/domain/entities/employee_status_filter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  test(
    'นำเข้าไฟล์จริงแล้วค้นเกมส์กับรหัส 1034254',
    () async {
      final data = await rootBundle.load('assets/employees.csv');
      final csvText = utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final database = AppDatabase(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      final repository = EmployeeRepositoryImpl(database);
      addTearDown(database.close);

      final saved = await repository.importCsv(csvText, onProgress: (_, _) {});
      expect(saved, greaterThan(100000));
      expect(await repository.isImported(), isTrue);

      final byName = await repository.search(
        const EmployeeSearchQuery(
          text: 'พงศ์พิสิทธิ์ เหินชัย',
          status: EmployeeStatusFilter.all,
          branchLabel: null,
          offset: 0,
          limit: 30,
        ),
      );
      expect(
        byName.items.map((employee) => employee.personId),
        contains('1034254'),
      );

      final stored = await repository.findById('1034254');
      expect(stored?.displayName, 'พงศ์พิสิทธิ์ เหินชัย');
      expect(stored?.nickName, 'เกมส์');
      expect(stored?.branchLabel, 'สาขาขอนแก่น');

      final byNick = await repository.search(
        const EmployeeSearchQuery(
          text: 'เกมส์',
          status: EmployeeStatusFilter.working,
          branchLabel: null,
          offset: 0,
          limit: 30,
        ),
      );
      expect(byNick.items, isNotEmpty);

      final byId = await repository.search(
        const EmployeeSearchQuery(
          text: '1034254',
          status: EmployeeStatusFilter.all,
          branchLabel: null,
          offset: 0,
          limit: 10,
        ),
      );
      expect(
        byId.items.any(
          (employee) => employee.personId == '1034254' && employee.nickName == 'เกมส์',
        ),
        isTrue,
      );

      final columns = await (await database.open()).rawQuery(
        'PRAGMA table_info(employees)',
      );
      final names = columns.map((row) => row['name']).toSet();
      expect(names, isNot(contains('password')));
      expect(names, isNot(contains('id_card')));
      expect(names, isNot(contains('black_list')));
      expect(names, isNot(contains('black_list_reason')));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
