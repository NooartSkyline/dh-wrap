import 'package:dh_wrap/domain/entities/employee.dart';
import 'package:dh_wrap/domain/entities/employee_page.dart';
import 'package:dh_wrap/domain/entities/employee_search_query.dart';
import 'package:dh_wrap/domain/repositories/employee_repository.dart';
import 'package:dh_wrap/domain/usecases/get_employee.dart';
import 'package:dh_wrap/presentation/detail/employee_detail_cubit.dart';
import 'package:dh_wrap/presentation/detail/employee_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/employee_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('คัดลอกรหัส ชื่อไทย ชื่ออังกฤษ ชื่อเล่น และเบอร์โทร', (tester) async {
    final copied = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments;
        copied.add(arguments is Map ? arguments['text'] as String? : null);
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final employee = sampleEmployee();
    final cubit = EmployeeDetailCubit(GetEmployee(_FakeRepository(employee)));
    addTearDown(cubit.close);
    await cubit.load(employee.personId);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const EmployeeDetailScreen()),
      ),
    );
    await tester.pump();

    await _expectCopy(tester, copied, 'คัดลอกชื่อไทย', 'พงศ์พิสิทธิ์ เหินชัย');
    await _expectCopy(tester, copied, 'คัดลอกชื่อเล่น', 'เกมส์');
    await _expectCopy(tester, copied, 'คัดลอกชื่ออังกฤษ', 'PONGPISIT HERNCHAI');
    await _expectCopy(tester, copied, 'คัดลอกรหัสพนักงาน', '1034254');
    await _expectCopy(tester, copied, 'คัดลอกเบอร์โทร', '0812345678');
  });
}

Future<void> _expectCopy(
  WidgetTester tester,
  List<String?> copied,
  String tooltip,
  String value,
) async {
  final finder = find.byTooltip(tooltip);
  await tester.tap(finder);
  await tester.pump();
  expect(copied.last, value);
}

class _FakeRepository implements EmployeeRepository {
  _FakeRepository(this.employee);

  final Employee employee;

  @override
  Future<int> countWorking() async => 0;

  @override
  Future<Employee?> findById(String personId) async => employee;

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
