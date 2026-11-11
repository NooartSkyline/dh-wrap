import 'dart:io';

import 'package:dh_wrap/data/db/app_database.dart';
import 'package:dh_wrap/data/usage/usage_hint_store.dart';
import 'package:dh_wrap/domain/entities/employee.dart';
import 'package:dh_wrap/domain/entities/employee_page.dart';
import 'package:dh_wrap/domain/entities/employee_search_query.dart';
import 'package:dh_wrap/domain/repositories/employee_repository.dart';
import 'package:dh_wrap/domain/usecases/count_working_employees.dart';
import 'package:dh_wrap/domain/usecases/list_employee_branches.dart';
import 'package:dh_wrap/domain/usecases/read_data_updated_at.dart';
import 'package:dh_wrap/domain/usecases/search_employees.dart';
import 'package:dh_wrap/presentation/search/search_bloc.dart';
import 'package:dh_wrap/presentation/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('ยังไม่เคยเข้าแสดงวิธีใช้ และกดเข้าใจแล้วจะไม่ขึ้นอีก', () async {
    final tempDir = await Directory.systemTemp.createTemp('dh_wrap_hint');
    final database = AppDatabase(
      path: p.join(tempDir.path, 'employees.db'),
      factory: databaseFactoryFfi,
    );
    addTearDown(() async {
      await database.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    final hints = UsageHintStore(database);
    expect(await hints.seen(), isFalse);
    await hints.markSeen();
    expect(await hints.seen(), isTrue);
    expect(await UsageHintStore(database).seen(), isTrue);
  });

  testWidgets('เข้าครั้งแรกเห็นวิธีใช้งาน ปิดแล้วเปิดใหม่ไม่แสดง', (
    tester,
  ) async {
    final hints = _MemoryHints();

    await _pumpSearch(tester, hints);
    expect(find.byKey(const Key('employee-usage-hint')), findsOneWidget);
    expect(find.text('วิธีใช้งาน'), findsOneWidget);

    await tester.tap(find.byKey(const Key('employee-usage-hint-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('employee-usage-hint')), findsNothing);
    expect(hints.seenFlag, isTrue);

    await _pumpSearch(tester, hints);
    expect(find.byKey(const Key('employee-usage-hint')), findsNothing);
  });
}

Future<void> _pumpSearch(WidgetTester tester, UsageHints hints) async {
  final repository = _FakeEmployeeRepository();
  final bloc = SearchBloc(
    searchEmployees: SearchEmployees(repository),
    countWorkingEmployees: CountWorkingEmployees(repository),
    readDataUpdatedAt: ReadDataUpdatedAt(repository),
    listEmployeeBranches: ListEmployeeBranches(repository),
    debounce: Duration.zero,
  );
  addTearDown(bloc.close);
  await tester.pumpWidget(
    RepositoryProvider<EmployeeRepository>.value(
      value: repository,
      child: BlocProvider.value(
        value: bloc,
        child: MaterialApp(home: SearchScreen(usageHints: hints)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryHints implements UsageHints {
  var seenFlag = false;

  @override
  Future<bool> seen() async => seenFlag;

  @override
  Future<void> markSeen() async {
    seenFlag = true;
  }
}

class _FakeEmployeeRepository implements EmployeeRepository {
  @override
  Future<int> countWorking() async => 1;

  @override
  Future<DateTime?> dataUpdatedAt() async => null;

  @override
  Future<Employee?> findById(String personId) async => null;

  @override
  Future<int> importCsv(
    String csvText, {
    required void Function(int done, int total) onProgress,
  }) async => 0;

  @override
  Future<bool> isImported() async => true;

  @override
  Future<Set<String>> listPersonIds() async => {};

  @override
  Future<List<String>> listBranches() async => const [];

  @override
  Future<EmployeePage> search(EmployeeSearchQuery query) async {
    return const EmployeePage(items: [], hasMore: false);
  }
}
