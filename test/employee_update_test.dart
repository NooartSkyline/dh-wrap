import 'dart:io';

import 'package:dh_wrap/data/datasources/csv_employee_parser.dart';
import 'package:dh_wrap/data/db/app_database.dart';
import 'package:dh_wrap/data/repositories/employee_repository_impl.dart';
import 'package:dh_wrap/data/sync/employee_database.dart';
import 'package:dh_wrap/data/sync/employee_snapshot_source.dart';
import 'package:dh_wrap/domain/entities/employee.dart';
import 'package:dh_wrap/domain/entities/employee_page.dart';
import 'package:dh_wrap/domain/entities/employee_search_query.dart';
import 'package:dh_wrap/domain/repositories/employee_repository.dart';
import 'package:dh_wrap/domain/usecases/count_working_employees.dart';
import 'package:dh_wrap/domain/usecases/import_employees.dart';
import 'package:dh_wrap/domain/usecases/list_employee_branches.dart';
import 'package:dh_wrap/domain/usecases/read_data_updated_at.dart';
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
    addTearDown(() async {
      await database.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    await repository.importCsv(_csv('100', 'คนเดิม'), onProgress: (_, _) {});
    final source = _ScriptedSnapshot();

    final updated = EmployeeUpdateCubit(source, ImportEmployees(repository));
    addTearDown(updated.close);
    source.next = _csv('200', 'คนใหม่');
    await updated.start();
    expect(source.calls, 1);
    expect(updated.state, isA<EmployeeUpdateSuccess>());
    expect((updated.state as EmployeeUpdateSuccess).count, 1);
    final found = await repository.findById('200');
    expect(found?.personId, '200');
    expect(found?.firstName, 'คนใหม่');
    expect(await repository.findById('100'), isNull);

    source.failure = const FormatException('เซิร์ฟเวอร์ตอบรหัส 500');
    final failed = EmployeeUpdateCubit(source, ImportEmployees(repository));
    addTearDown(failed.close);
    await failed.start();
    expect(failed.state, isA<EmployeeUpdateFailure>());
    final stillThere = await repository.findById('200');
    expect(stillThere?.firstName, 'คนใหม่');
  });

  testWidgets('กดอัปเดตแล้วดึงจากเครื่องนี้ทันที', (tester) async {
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

    expect(find.text('อัปเดตข้อมูลล่าสุด'), findsNothing);
    expect(find.text('กำลังดึงข้อมูลจากฐานข้อมูล'), findsNothing);
    expect(source.calls, 1);
    expect(find.text('อัปเดตแล้ว 0 คน'), findsOneWidget);
  });
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
