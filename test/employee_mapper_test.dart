import 'package:csv/csv.dart';
import 'package:dh_wrap/data/datasources/csv_employee_parser.dart';
import 'package:dh_wrap/data/mappers/employee_mapper.dart';
import 'package:dh_wrap/domain/entities/employee.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = CsvEmployeeParser();

  test('สาขาใช้ branch_name และถ้าว่างใช้ location_desc', () {
    final withBranch = _employee({
      'branch_name': 'สาขาขอนแก่น',
      'location_desc': 'ขอนแก่น',
    });
    final fallback = _employee({'branch_name': '', 'location_desc': 'ขอนแก่น'});
    final empty = _employee({'branch_name': '  ', 'location_desc': '  '});

    expect(withBranch.branchLabel, 'สาขาขอนแก่น');
    expect(fallback.branchLabel, 'ขอนแก่น');
    expect(empty.branchLabel, isEmpty);
  });

  test('สถานะและชื่อใช้สูตรเดียว', () {
    final active = _employee({
      'employee_status': 'Active',
      'nick_name': 'เกมส์',
    });
    final inactive = _employee({'employee_status': 'InActive'});
    final legacy = _employee({'employee_status': 'Inactive'});

    expect(active.displayName, 'พงศ์พิสิทธิ์ เหินชัย');
    expect(active.displayNameEn, 'PONGPISIT HERNCHAI');
    expect(active.statusLabel, 'ปฏิบัติงาน');
    expect(active.isWorking, isTrue);
    expect(inactive.statusLabel, 'ไม่ปฏิบัติงาน');
    expect(legacy.statusLabel, 'ไม่ปฏิบัติงาน');
    expect(inactive.isWorking, isFalse);
  });

  test('อายุงานนับจากวันเริ่มถึงวันนี้ หรือถึงวันสิ้นสุดถ้าออกแล้ว', () {
    final working = sampleForService(
      status: 'Active',
      hireDate: '2015-11-10',
      endDate: '',
    );
    expect(
      working.serviceLengthLabel(asOf: DateTime(2026, 11, 11)),
      '11 ปี 1 วัน',
    );
    expect(working.serviceLengthLabel(asOf: DateTime(2026, 11, 10)), '11 ปี');

    final left = sampleForService(
      status: 'InActive',
      hireDate: '2015-11-10',
      endDate: '2025-03-01',
    );
    expect(
      left.serviceLengthLabel(asOf: DateTime(2026, 11, 11)),
      '9 ปี 3 เดือน 19 วัน',
    );
    expect(
      sampleForService(
        status: 'Active',
        hireDate: '2026-01-31',
        endDate: '',
      ).serviceLengthLabel(asOf: DateTime(2026, 3, 1)),
      '1 เดือน 1 วัน',
    );
    expect(
      sampleForService(
        status: 'Active',
        hireDate: '2026-11-11',
        endDate: '',
      ).serviceLengthLabel(asOf: DateTime(2026, 11, 11)),
      '0 วัน',
    );
    expect(
      sampleForService(
        status: 'InActive',
        hireDate: '2015-11-10',
        endDate: '',
      ).serviceLengthLabel(),
      isNull,
    );
    expect(
      sampleForService(
        status: 'InActive',
        hireDate: '2026-05-01',
        endDate: '2026-04-01',
      ).serviceLengthLabel(),
      isNull,
    );
    expect(
      sampleForService(
        status: 'Active',
        hireDate: '',
        endDate: '',
      ).serviceLengthLabel(),
      isNull,
    );
  });

  test('วันสิ้นสุดเลือกวันทำงานสุดท้ายก่อนวันลาออก', () {
    final employee = _employee({
      'last_working_date': '2025-03-01 23:59:59.000 +0700',
      'resign_date': '2025-03-06 10:45:05.113 +0700',
      'termination_date': '2025-03-02 00:00:00.000 +0700',
      'hire_date': '2015-11-10 00:00:00.000 +0700',
    });

    expect(employee.hireDate, '2015-11-10');
    expect(employee.hireDateLabel, '10/11/2015');
    expect(employee.endDate, '2025-03-01');
    expect(employee.endDateLabel, '01/03/2025');
  });

  test('ไม่มีวันทำงานสุดท้ายจึงใช้วันลาออก', () {
    final employee = _employee({
      'last_working_date': '',
      'resign_date': '2013-07-20 00:00:00.000 +0700',
      'termination_date': '2013-07-19 23:59:59.000 +0700',
    });
    expect(employee.endDate, '2013-07-20');
  });

  test('ไม่เขียนคอลัมน์ลับลงฐานข้อมูล', () {
    final employee = _employee({
      'password': r'$2a$10$secret',
      'id_card': '1411900250033',
      'black_list': 'True',
      'black_list_reason': 'เหตุผล',
    });
    final row = EmployeeMapper.toDb(employee);

    expect(row.keys, isNot(containsAll(EmployeeMapper.droppedColumns)));
    expect(row.values, isNot(contains(r'$2a$10$secret')));
    expect(row.values, isNot(contains('1411900250033')));
    expect(employee.personId, '1034254');
    expect(row['search_text'], contains('เกมส์'));
    expect(row['search_text'], contains('1034254'));
    expect(row['search_text'], contains('pongpisit hernchai'));
  });

  test('parser อ่านแถวที่มีจุลภาคในเครื่องหมายคำพูด และข้ามรหัสว่าง', () async {
    final csv = _csv([
      {'person_id': '', 'first_name': 'ว่าง'},
      {'person_id': '1', 'position_desc': 'PC-เอ, บี', 'password': 'secret'},
    ]);
    final employees = await parser.parse(csv).toList();

    expect(employees, hasLength(1));
    expect(employees.single.positionDesc, 'PC-เอ, บี');
    expect(
      EmployeeMapper.toDb(employees.single).values,
      isNot(contains('secret')),
    );
  });

  test('parser บอกคอลัมน์ที่หายและนับแถว', () {
    expect(
      () => parser.validate('first_name\nสมชาย'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('person_id'),
        ),
      ),
    );
    expect(parser.dataRowCount('h\na\nb\n'), 2);
    expect(parser.dataRowCount('h\na\nb'), 2);
    expect(parser.dataRowCount(''), 0);
  });
}

Map<String, String> _baseRow() {
  return {
    for (final column in CsvEmployeeParser.requiredColumns) column: '',
    'person_id': '1034254',
    'first_name': 'พงศ์พิสิทธิ์',
    'last_name': 'เหินชัย',
    'first_name_alt1': 'PONGPISIT',
    'last_name_alt1': 'HERNCHAI',
    'nick_name': 'เกมส์',
    'employee_status': 'Active',
    'branch_name': 'สาขาขอนแก่น',
    'location_desc': 'ขอนแก่น',
  };
}

Employee sampleForService({
  required String status,
  required String hireDate,
  required String endDate,
}) {
  return _employee({
    'employee_status': status,
    'hire_date': hireDate,
    'last_working_date': endDate,
    'resign_date': '',
    'termination_date': '',
  });
}

Employee _employee(Map<String, String> overrides) {
  final row = _baseRow()..addAll(overrides);
  final csv = _csv([row]);
  final parsed = const CsvDecoder(
    parseHeaders: true,
    dynamicTyping: false,
  ).convert(csv);
  final first = parsed.first;
  if (first is! CsvRow) {
    throw StateError('อ่านแถวทดสอบไม่สำเร็จ');
  }
  final employee = EmployeeMapper.fromCsvRow(first);
  if (employee == null) {
    throw StateError('แปลงแถวทดสอบไม่สำเร็จ');
  }
  return employee;
}

String _csv(List<Map<String, String>> rows) {
  final header = <String>{
    ...CsvEmployeeParser.requiredColumns,
    ...rows.expand((row) => row.keys),
  }.toList();
  final buffer = StringBuffer()..writeln(header.join(','));
  for (final row in rows) {
    final cells = [for (final column in header) _quote(row[column] ?? '')];
    buffer.writeln(cells.join(','));
  }
  return buffer.toString();
}

String _quote(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
