import 'package:dh_wrap/data/db/app_database.dart';
import 'package:dh_wrap/data/search/search_history_store.dart';
import 'package:dh_wrap/domain/entities/employee.dart';
import 'package:dh_wrap/domain/entities/employee_page.dart';
import 'package:dh_wrap/domain/entities/employee_search_query.dart';
import 'package:dh_wrap/domain/entities/search_history_record.dart';
import 'package:dh_wrap/domain/entities/employee_status_filter.dart';
import 'package:dh_wrap/domain/repositories/employee_repository.dart';
import 'package:dh_wrap/domain/usecases/count_working_employees.dart';
import 'package:dh_wrap/domain/usecases/list_employee_branches.dart';
import 'package:dh_wrap/domain/usecases/read_data_updated_at.dart';
import 'package:dh_wrap/domain/usecases/search_employees.dart';
import 'package:dh_wrap/presentation/search/employee_card.dart';
import 'package:dh_wrap/presentation/search/employee_filter_sheet.dart';
import 'package:dh_wrap/presentation/search/search_bloc.dart';
import 'package:dh_wrap/presentation/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/employee_fixtures.dart';

void main() {
  testWidgets('การ์ดชื่อยาวไม่ล้นจอแคบ', (tester) async {
    final employee = sampleEmployee(
      positionDesc: 'ตำแหน่ง${'ยาวมาก' * 40}',
      branchName: 'สาขา${'ชื่อยาว' * 20}',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: EmployeeCard(employee: employee, onTap: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('พงศ์พิสิทธิ์ เหินชัย'), findsOneWidget);
    expect(find.text('สาขา${'ชื่อยาว' * 20}'), findsOneWidget);
    expect(find.text('ขอนแก่น'), findsNothing);
  });

  testWidgets('ปิดชีตโดยไม่ยืนยันไม่ส่งตัวกรอง', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    EmployeeFilterResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showEmployeeFilterSheet(
                  context: context,
                  status: EmployeeStatusFilter.working,
                  branchLabel: 'สาขาขอนแก่น',
                  loadBranches: () async => ['สาขาขอนแก่น', 'สาขาอุดรธานี'],
                );
              },
              child: const Text('เปิด'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไม่ปฏิบัติงาน'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('employee-filter-close')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('ยืนยันชีตส่งสถานะและสาขาที่เลือกตอนกด', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    EmployeeFilterResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showEmployeeFilterSheet(
                  context: context,
                  status: EmployeeStatusFilter.working,
                  branchLabel: null,
                  loadBranches: () async => ['สาขาขอนแก่น'],
                );
              },
              child: const Text('เปิด'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไม่ปฏิบัติงาน'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('สาขาขอนแก่น'));
    await tester.tap(find.text('สาขาขอนแก่น'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('employee-filter-confirm')));
    await tester.pumpAndSettle();

    expect(result?.status, EmployeeStatusFilter.notWorking);
    expect(result?.branchLabel, 'สาขาขอนแก่น');
  });

  testWidgets('จอค้นหาแสดงคำใบ้ ผลลัพธ์ ว่าง และข้อผิดพลาดจริง', (
    tester,
  ) async {
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
      MaterialApp(
        home: BlocProvider.value(value: bloc, child: const SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ที่ปฏิบัติงาน 12,637 คน'), findsOneWidget);
    expect(find.text('อัปเดตล่าสุด 12/11/2026 00:06'), findsOneWidget);
    expect(
      find.text('พิมพ์ชื่อ ชื่อเล่น หรือรหัส หรือเลือกสาขา'),
      findsOneWidget,
    );
    expect(repository.searchCalls, 0);

    repository.page = EmployeePage(items: [sampleEmployee()], hasMore: false);
    await tester.enterText(
      find.byKey(const Key('employee-search-field')),
      'เกมส์',
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 1);
    expect(repository.lastQuery?.text, 'เกมส์');
    expect(repository.lastQuery?.status, EmployeeStatusFilter.working);
    expect(find.text('พงศ์พิสิทธิ์ เหินชัย'), findsOneWidget);

    repository.page = const EmployeePage(items: [], hasMore: false);
    await tester.enterText(
      find.byKey(const Key('employee-search-field')),
      'ไม่มีคนนี้',
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('ไม่พบพนักงานตามเงื่อนไข'), findsOneWidget);

    repository.searchError = StateError('อ่านฐานข้อมูลไม่สำเร็จ');
    await tester.enterText(
      find.byKey(const Key('employee-search-field')),
      'พัง',
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('อ่านฐานข้อมูลไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);
  });

  testWidgets('ค้นสำเร็จแล้วล้างคำค้นจะเห็นประวัติ และกดแล้วค้นซ้ำ', (
    tester,
  ) async {
    final repository = _FakeEmployeeRepository();
    final history = _MemorySearchHistory();
    final bloc = SearchBloc(
      searchEmployees: SearchEmployees(repository),
      countWorkingEmployees: CountWorkingEmployees(repository),
      readDataUpdatedAt: ReadDataUpdatedAt(repository),
      listEmployeeBranches: ListEmployeeBranches(repository),
      searchHistory: history,
      debounce: Duration.zero,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: bloc, child: const SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    repository.page = EmployeePage(items: [sampleEmployee()], hasMore: false);
    await tester.enterText(
      find.byKey(const Key('employee-search-field')),
      'เกมส์',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(repository.searchCalls, 1);

    await tester.tap(find.byTooltip('ล้างคำค้น'));
    await tester.pumpAndSettle();
    expect(find.text('ค้นหาล่าสุด'), findsOneWidget);
    expect(find.text('เกมส์'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-history-1')));
    await tester.pumpAndSettle();
    expect(repository.searchCalls, 2);
    expect(repository.lastQuery?.text, 'เกมส์');
    expect(repository.lastQuery?.status, EmployeeStatusFilter.working);
    expect(find.text('พงศ์พิสิทธิ์ เหินชัย'), findsOneWidget);

    await tester.tap(find.byTooltip('ล้างคำค้น'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-history-delete-1')));
    await tester.pumpAndSettle();
    expect(find.text('ค้นหาล่าสุด'), findsNothing);
    expect(find.text('เกมส์'), findsNothing);
    expect(repository.searchCalls, 2);
  });
}

class _MemorySearchHistory extends SearchHistoryStore {
  _MemorySearchHistory() : super(AppDatabase());

  final records = <SearchHistoryRecord>[];

  @override
  Future<void> add({
    required String query,
    required EmployeeStatusFilter status,
    required String? branchLabel,
  }) async {
    final text = query.trim();
    final branch = branchLabel?.trim();
    final label = branch == null || branch.isEmpty ? null : branch;
    records.removeWhere(
      (item) =>
          item.query == text &&
          item.status == status &&
          item.branchLabel == label,
    );
    records.insert(
      0,
      SearchHistoryRecord(
        id: records.length + 1,
        query: text,
        status: status,
        branchLabel: label,
        searchedAt: DateTime(2026, 11, 12, 9, 31),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    records.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<SearchHistoryRecord>> list() async => List.of(records);
}

class _FakeEmployeeRepository implements EmployeeRepository {
  int searchCalls = 0;
  EmployeeSearchQuery? lastQuery;
  EmployeePage page = const EmployeePage(items: [], hasMore: false);
  Object? searchError;
  DateTime? updatedAt = DateTime(2026, 11, 12, 0, 6);

  @override
  Future<int> countWorking() async => 12637;

  @override
  Future<DateTime?> dataUpdatedAt() async => updatedAt;

  @override
  Future<Employee?> findById(String personId) async => null;

  @override
  Future<int> importCsv(
    String csvText, {
    required void Function(int done, int total) onProgress,
  }) async {
    return 0;
  }

  @override
  Future<bool> isImported() async => true;

  @override
  Future<Set<String>> listPersonIds() async => {};

  @override
  Future<List<String>> listBranches() async => const ['สาขาขอนแก่น'];

  @override
  Future<EmployeePage> search(EmployeeSearchQuery query) async {
    searchCalls++;
    lastQuery = query;
    final error = searchError;
    if (error != null) throw error;
    return page;
  }
}
