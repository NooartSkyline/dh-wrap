import 'dart:io';

import 'package:dh_wrap/data/datasources/csv_employee_parser.dart';
import 'package:dh_wrap/data/db/app_database.dart';
import 'package:dh_wrap/data/repositories/employee_repository_impl.dart';
import 'package:dh_wrap/data/sync/employee_database.dart';
import 'package:dh_wrap/data/sync/employee_snapshot_source.dart';
import 'package:dh_wrap/data/update/update_history_store.dart';
import 'package:dh_wrap/domain/entities/employee.dart';
import 'package:dh_wrap/domain/entities/employee_page.dart';
import 'package:dh_wrap/domain/entities/employee_search_query.dart';
import 'package:dh_wrap/domain/repositories/employee_repository.dart';
import 'package:dh_wrap/domain/usecases/count_working_employees.dart';
import 'package:dh_wrap/domain/usecases/import_employees.dart';
import 'package:dh_wrap/domain/usecases/list_employee_ids.dart';
import 'package:dh_wrap/domain/usecases/list_employee_branches.dart';
import 'package:dh_wrap/domain/usecases/read_data_updated_at.dart';
import 'package:dh_wrap/domain/usecases/search_employees.dart';
import 'package:dh_wrap/domain/entities/employee_update_record.dart';
import 'package:dh_wrap/presentation/search/search_bloc.dart';
import 'package:dh_wrap/presentation/search/search_screen.dart';
import 'package:dh_wrap/presentation/update/employee_update_cubit.dart';
import 'package:dh_wrap/presentation/update/employee_update_screen.dart';
import 'package:dh_wrap/presentation/update/employee_update_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('ค่าเชื่อมต่อใช้โฮสต์อ่าน และไม่รับค่าที่หาย', () {
    final settings = EmployeeDatabaseSettings.fromMap({
      'PG_HOST': 'writer.example',
      'PG_READ': 'reader.example',
      'PG_PORT': '5432',
      'PG_USER': 'postgres',
      'PG_PASS': 'secret',
    });
    expect(settings.host, 'reader.example');
    expect(settings.port, 5432);
    expect(settings.database, 'dh_company');
    expect(settings.schema, 'public');
    expect(settings.table, 'employees');
    expect(settings.password, isNotEmpty);

    expect(
      () => EmployeeDatabaseSettings.fromMap({
        'PG_HOST': 'writer.example',
        'PG_PORT': '5432',
        'PG_USER': 'postgres',
      }),
      throwsFormatException,
    );
  });

  test('อัปเดตสำเร็จแทนที่ข้อมูลเดิม และล้มเหลวแล้วของเดิมยังอยู่', () async {
    final tempDir = await Directory.systemTemp.createTemp('dh_wrap_update');
    final database = AppDatabase(
      path: p.join(tempDir.path, 'employees.db'),
      factory: databaseFactoryFfi,
    );
    final repository = EmployeeRepositoryImpl(database);
    final history = UpdateHistoryStore(
      database,
      now: () => DateTime(2026, 11, 12, 0, 40),
    );
    addTearDown(() async {
      await database.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    await repository.importCsv(_csv('100', 'คนเดิม'), onProgress: (_, _) {});
    final source = _ScriptedSnapshot();

    final updated = EmployeeUpdateCubit(
      source,
      ImportEmployees(repository),
      ListEmployeeIds(repository),
      history: history,
    );
    addTearDown(updated.close);
    source.next = _csv('200', 'คนใหม่');
    await updated.start();
    expect(source.calls, 1);
    expect(updated.state, isA<EmployeeUpdateSuccess>());
    final summary = (updated.state as EmployeeUpdateSuccess).summary;
    expect(summary.previousCount, 1);
    expect(summary.addedCount, 1);
    expect(summary.removedCount, 1);
    expect(summary.currentCount, 1);
    final found = await repository.findById('200');
    expect(found?.personId, '200');
    expect(found?.firstName, 'คนใหม่');
    expect(await repository.findById('100'), isNull);
    final saved = await history.list();
    expect(saved, hasLength(1));
    expect(saved.single.previousCount, 1);
    expect(saved.single.addedCount, 1);
    expect(saved.single.removedCount, 1);
    expect(saved.single.currentCount, 1);
    expect(saved.single.updatedAt, DateTime(2026, 11, 12, 0, 40));

    source.failure = const FormatException('เซิร์ฟเวอร์ตอบรหัส 500');
    final failed = EmployeeUpdateCubit(
      source,
      ImportEmployees(repository),
      ListEmployeeIds(repository),
      history: history,
    );
    addTearDown(failed.close);
    await failed.start();
    expect(failed.state, isA<EmployeeUpdateFailure>());
    final stillThere = await repository.findById('200');
    expect(stillThere?.firstName, 'คนใหม่');
    expect(await history.list(), hasLength(1));
  });

  testWidgets('เข้าหน้าอัปเดตก่อน แล้วกดอัปเดตจึงเห็นสรุป', (tester) async {
    final repository = _FakeEmployeeRepository();
    final source = _ScriptedSnapshot()..next = _csv('200', 'คนใหม่');
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
          child: MaterialApp(home: SearchScreen(snapshotSource: source)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('employee-update-button')));
    await tester.pumpAndSettle();
    expect(find.text('ดึงข้อมูลล่าสุด'), findsOneWidget);
    expect(source.calls, 0);

    await tester.tap(find.byKey(const Key('employee-update-theme-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('employee-theme-hue')), findsOneWidget);
    await tester.tap(find.byKey(const Key('employee-theme-cancel')));
    await tester.pumpAndSettle();
    expect(source.calls, 0);

    await tester.tap(find.byKey(const Key('employee-update-start')));
    await tester.pumpAndSettle();

    expect(find.text('เดิมมีในเครื่อง'), findsOneWidget);
    expect(find.text('เพิ่มเข้ามา'), findsOneWidget);
    expect(find.text('0 คน'), findsNWidgets(4));
    expect(source.calls, 1);
  });

  test('ฐานข้อมูลเดิมได้ตารางประวัติเมื่อเปิดเวอร์ชันใหม่', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'dh_wrap_history_upgrade',
    );
    final path = p.join(tempDir.path, 'employees.db');
    final opened = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
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

    final history = UpdateHistoryStore(
      database,
      now: () => DateTime(2026, 11, 12, 0, 48),
    );
    expect(await history.list(), isEmpty);
    await history.add(
      previousCount: 105309,
      addedCount: 0,
      removedCount: 0,
      currentCount: 105309,
    );
    final saved = await history.list();
    expect(saved.single.previousCount, 105309);
    expect(saved.single.addedCount, 0);
    expect(saved.single.currentCount, 105309);
    expect(saved.single.updatedAt, DateTime(2026, 11, 12, 0, 48));
  });

  testWidgets('ดูสรุปย้อนหลังได้หลังอัปเดตสำเร็จ', (tester) async {
    final history = _MemoryHistory();
    final source = _ScriptedSnapshot()..next = _csv('200', 'คนใหม่');
    final repository = _FakeEmployeeRepository();
    final cubit = EmployeeUpdateCubit(
      source,
      ImportEmployees(repository),
      ListEmployeeIds(repository),
      history: history,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(home: EmployeeUpdateScreen(history: history)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ย้อนหลัง'), findsOneWidget);
    expect(
      find.text('ยังไม่มีประวัติ รายการจะถูกเก็บหลังอัปเดตสำเร็จ'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('employee-update-start')));
    await tester.pumpAndSettle();

    expect(find.text('12/11/2026 00:40'), findsOneWidget);
    await tester.tap(find.byKey(const Key('employee-update-history-1')));
    await tester.pumpAndSettle();
    expect(find.text('เดิมมีในเครื่อง'), findsOneWidget);
    expect(find.textContaining('บันทึกเมื่อ 12/11/2026 00:40'), findsOneWidget);
    expect(find.text('กลับ'), findsOneWidget);
  });
}

class _MemoryHistory extends UpdateHistoryStore {
  _MemoryHistory() : super(AppDatabase());

  final records = <EmployeeUpdateRecord>[];

  @override
  Future<void> add({
    required int previousCount,
    required int addedCount,
    required int removedCount,
    required int currentCount,
  }) async {
    records.insert(
      0,
      EmployeeUpdateRecord(
        id: records.length + 1,
        updatedAt: DateTime(2026, 11, 12, 0, 40),
        previousCount: previousCount,
        addedCount: addedCount,
        removedCount: removedCount,
        currentCount: currentCount,
      ),
    );
  }

  @override
  Future<List<EmployeeUpdateRecord>> list() async => records;
}

class _ScriptedSnapshot implements EmployeeSnapshotSource {
  String? next;
  FormatException? failure;
  var calls = 0;

  @override
  Future<String> download({
    required void Function(int received, int? total) onProgress,
  }) async {
    calls++;
    final error = failure;
    if (error != null) throw error;
    final csv = next ?? '';
    onProgress(csv.length, csv.length);
    return csv;
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

String _csv(String personId, String firstName) {
  final header = CsvEmployeeParser.requiredColumns;
  final values = {
    'person_id': personId,
    'first_name': firstName,
    'employee_status': 'Active',
  };
  final buffer = StringBuffer()..writeln(header.join(','));
  buffer.writeln(
    [for (final column in header) '"${values[column] ?? ''}"'].join(','),
  );
  return buffer.toString();
}
