import 'dart:io';

import 'package:dh_wrap/data/datasources/csv_employee_parser.dart';
import 'package:dh_wrap/data/db/app_database.dart';
import 'package:dh_wrap/data/repositories/employee_repository_impl.dart';
import 'package:dh_wrap/data/sync/employee_snapshot_client.dart';
import 'package:dh_wrap/data/sync/sync_endpoint_store.dart';
import 'package:dh_wrap/domain/entities/employee.dart';
import 'package:dh_wrap/domain/entities/employee_page.dart';
import 'package:dh_wrap/domain/entities/employee_search_query.dart';
import 'package:dh_wrap/domain/repositories/employee_repository.dart';
import 'package:dh_wrap/domain/usecases/count_working_employees.dart';
import 'package:dh_wrap/domain/usecases/import_employees.dart';
import 'package:dh_wrap/domain/usecases/list_employee_branches.dart';
import 'package:dh_wrap/domain/usecases/search_employees.dart';
import 'package:dh_wrap/presentation/search/search_bloc.dart';
import 'package:dh_wrap/presentation/search/search_screen.dart';
import 'package:dh_wrap/presentation/update/employee_update_cubit.dart';
import 'package:dh_wrap/presentation/update/employee_update_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('ที่อยู่ฐานชี้ไปที่ employees.csv', () {
    expect(
      csvUriFromBase('http://10.0.0.8:8787/').toString(),
      'http://10.0.0.8:8787/employees.csv',
    );
    expect(
      csvUriFromBase('10.0.0.8:8787').toString(),
      'http://10.0.0.8:8787/employees.csv',
    );
    expect(() => csvUriFromBase(''), throwsFormatException);
    expect(() => csvUriFromBase('ftp://10.0.0.8'), throwsFormatException);
  });

  test('อัปเดตสำเร็จแทนที่ข้อมูลเดิม และล้มเหลวแล้วของเดิมยังอยู่', () async {
    final tempDir = await Directory.systemTemp.createTemp('dh_wrap_update');
    final database = AppDatabase(
      path: p.join(tempDir.path, 'employees.db'),
      factory: databaseFactoryFfi,
    );
    final repository = EmployeeRepositoryImpl(database);
    addTearDown(() async {
      await database.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    await repository.importCsv(_csv('100', 'คนเดิม'), onProgress: (_, _) {});
    final source = _ScriptedSnapshot();

    final updated = EmployeeUpdateCubit(
      source,
      ImportEmployees(repository),
      'http://10.0.0.8:8787',
    );
    addTearDown(updated.close);
    source.next = _csv('200', 'คนใหม่');
    await updated.start();
    expect(source.lastUri?.path, '/employees.csv');
    expect(updated.state, isA<EmployeeUpdateSuccess>());
    expect((updated.state as EmployeeUpdateSuccess).count, 1);
    final found = await repository.findById('200');
    expect(found?.personId, '200');
    expect(found?.firstName, 'คนใหม่');
    expect(await repository.findById('100'), isNull);

    source.failure = const FormatException('เซิร์ฟเวอร์ตอบรหัส 500');
    final failed = EmployeeUpdateCubit(
      source,
      ImportEmployees(repository),
      'http://10.0.0.8:8787',
    );
    addTearDown(failed.close);
    await failed.start();
    expect(failed.state, isA<EmployeeUpdateFailure>());
    final stillThere = await repository.findById('200');
    expect(stillThere?.firstName, 'คนใหม่');
  });

  testWidgets('ยกเลิกอัปเดตไม่จำที่อยู่ และที่อยู่ผิดไม่เริ่ม', (tester) async {
    final store = _MemorySyncStore();
    final repository = _FakeEmployeeRepository();
    final bloc = SearchBloc(
      searchEmployees: SearchEmployees(repository),
      countWorkingEmployees: CountWorkingEmployees(repository),
      listEmployeeBranches: ListEmployeeBranches(repository),
      debounce: Duration.zero,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      RepositoryProvider<SyncEndpointStore>.value(
        value: store,
        child: BlocProvider.value(
          value: bloc,
          child: const MaterialApp(home: SearchScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('employee-update-button')));
    await tester.pumpAndSettle();
    expect(find.text('อัปเดตข้อมูลล่าสุด'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('employee-sync-url')),
      'ftp://10.0.0.8',
    );
    await tester.tap(find.byKey(const Key('employee-sync-start')));
    await tester.pump();
    expect(find.text('ที่อยู่ต้องขึ้นต้นด้วย http หรือ https'), findsOneWidget);
    expect(store.saves, 0);

    await tester.tap(find.byKey(const Key('employee-sync-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('อัปเดตข้อมูลล่าสุด'), findsNothing);
    expect(store.value, isNull);
  });
}

class _ScriptedSnapshot implements EmployeeSnapshotSource {
  String? next;
  FormatException? failure;
  Uri? lastUri;

  @override
  Future<String> download(
    Uri uri, {
    required void Function(int received, int? total) onProgress,
  }) async {
    lastUri = uri;
    final error = failure;
    if (error != null) throw error;
    final csv = next ?? '';
    onProgress(csv.length, csv.length);
    return csv;
  }
}

class _MemorySyncStore implements SyncEndpointStore {
  String? value;
  var saves = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String url) async {
    saves++;
    value = url;
  }
}

class _FakeEmployeeRepository implements EmployeeRepository {
  @override
  Future<int> countWorking() async => 1;

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
