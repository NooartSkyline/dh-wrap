import 'dart:io';

import 'package:dh_wrap/data/datasources/csv_employee_parser.dart';
import 'package:dh_wrap/data/db/app_database.dart';
import 'package:dh_wrap/data/repositories/employee_repository_impl.dart';
import 'package:dh_wrap/domain/entities/employee_search_query.dart';
import 'package:dh_wrap/domain/entities/employee_status_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase database;
  late EmployeeRepositoryImpl repository;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dh_wrap_test');
    database = AppDatabase(
      path: p.join(tempDir.path, 'employees.db'),
      factory: databaseFactoryFfi,
    );
    repository = EmployeeRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('นำเข้าครั้งแรก ค้นชื่อเล่น รหัส และชื่อเต็ม แล้วเปิดซ้ำไม่ทับถ้าไม่เรียกใหม่', () async {
    final saved = await repository.importCsv(_sampleCsv(), onProgress: (_, _) {});

    expect(saved, 5);
    expect(await repository.isImported(), isTrue);
    expect(await repository.countWorking(), 3);

    final byNick = await repository.search(_query('เกมส์'));
    expect(byNick.items.single.personId, '1034254');
    expect(byNick.items.single.branchLabel, 'สาขาขอนแก่น');
    expect(byNick.items.single.displayName, 'พงศ์พิสิทธิ์ เหินชัย');

    final byId = await repository.search(_query('1034254'));
    expect(byId.items.single.nickName, 'เกมส์');

    final byFullName = await repository.search(_query('พงศ์พิสิทธิ์ เหินชัย'));
    expect(byFullName.items.single.personId, '1034254');

    final stored = await repository.findById('1034254');
    expect(stored?.mobilePhone, '0811111111');
    expect(await repository.findById('ไม่มี'), isNull);
  });

  test('ยังไม่ระบุคำค้นหรือสาขาจะไม่ดึงทั้งตาราง', () async {
    await repository.importCsv(_sampleCsv(), onProgress: (_, _) {});

    expect(
      () => repository.search(_query('')),
      throwsArgumentError,
    );
  });

  test('เลือกสาขาอย่างเดียวได้ และแบ่งหน้า', () async {
    await repository.importCsv(_sampleCsv(), onProgress: (_, _) {});

    final first = await repository.search(
      _query('', branchLabel: 'สาขาขอนแก่น', limit: 1),
    );
    expect(first.items, hasLength(1));
    expect(first.hasMore, isTrue);
    expect(first.items.single.branchLabel, 'สาขาขอนแก่น');

    final second = await repository.search(
      _query('', branchLabel: 'สาขาขอนแก่น', offset: 1, limit: 1),
    );
    expect(second.items, hasLength(1));
    expect(second.hasMore, isFalse);
    expect(second.items.single.personId, isNot(first.items.single.personId));
  });

  test('กรองไม่ปฏิบัติงานรวม InActive และ Inactive', () async {
    await repository.importCsv(_sampleCsv(), onProgress: (_, _) {});

    final page = await repository.search(
      _query(
        '',
        branchLabel: 'สาขาอุบลราชธานี',
        status: EmployeeStatusFilter.notWorking,
      ),
    );
    final statuses = page.items.map((employee) => employee.employeeStatus).toSet();
    expect(statuses, {'InActive', 'Inactive'});
    expect(page.items.every((employee) => !employee.isWorking), isTrue);
  });

  test('เครื่องหมายเปอร์เซ็นต์ในคำค้นไม่กลายเป็นค้นทุกคน', () async {
    await repository.importCsv(_sampleCsv(), onProgress: (_, _) {});

    final page = await repository.search(_query('%'));
    expect(page.items.map((employee) => employee.personId), ['9']);
  });

  test('นำเข้าซ้ำแทนของเก่า และไฟล์เสียไม่ทิ้งธงสำเร็จ', () async {
    await repository.importCsv(_sampleCsv(), onProgress: (_, _) {});
    final replaced = await repository.importCsv(
      _csv([
        {'person_id': '1', 'first_name': 'ใหม่', 'employee_status': 'Active'},
      ]),
      onProgress: (_, _) {},
    );
    expect(replaced, 1);
    expect(await repository.findById('1034254'), isNull);
    expect((await repository.findById('1'))?.firstName, 'ใหม่');

    expect(
      () => repository.importCsv('first_name\nสมชาย\n', onProgress: (_, _) {}),
      throwsFormatException,
    );
    expect(await repository.isImported(), isTrue);
    expect(await repository.findById('1'), isNotNull);
  });

  test('แถวไม่มีรหัสไม่ตั้งธงนำเข้า', () async {
    expect(
      () => repository.importCsv(
        _csv([
          {'person_id': '   ', 'first_name': 'ว่าง'},
        ]),
        onProgress: (_, _) {},
      ),
      throwsFormatException,
    );
    expect(await repository.isImported(), isFalse);
  });
}

EmployeeSearchQuery _query(
  String text, {
  EmployeeStatusFilter status = EmployeeStatusFilter.all,
  String? branchLabel,
  int offset = 0,
  int limit = 30,
}) {
  return EmployeeSearchQuery(
    text: text,
    status: status,
    branchLabel: branchLabel,
    offset: offset,
    limit: limit,
  );
}

String _sampleCsv() {
  return _csv([
    {
      'person_id': '1034254',
      'first_name': 'พงศ์พิสิทธิ์',
      'last_name': 'เหินชัย',
      'first_name_alt1': 'PONGPISIT',
      'last_name_alt1': 'HERNCHAI',
      'nick_name': 'เกมส์',
      'employee_status': 'Active',
      'position_desc': 'PC-ไอ วูด อินโนเวชั่น',
      'branch_name': 'สาขาขอนแก่น',
      'location_desc': 'ขอนแก่น',
      'mobile_phone': '0811111111',
      'password': 'secret-hash',
      'id_card': '1234567890123',
    },
    {
      'person_id': '200',
      'first_name': 'สมชาย',
      'last_name': 'ใจดี',
      'nick_name': 'ชาย',
      'employee_status': 'Active',
      'branch_name': 'สาขาขอนแก่น',
      'location_desc': 'ขอนแก่น',
    },
    {
      'person_id': '300',
      'first_name': 'ลาออก',
      'last_name': 'หนึ่ง',
      'employee_status': 'InActive',
      'branch_name': 'สาขาอุบลราชธานี',
      'last_working_date': '2020-01-02 00:00:00.000 +0700',
    },
    {
      'person_id': '301',
      'first_name': 'ลาออก',
      'last_name': 'สอง',
      'employee_status': 'Inactive',
      'branch_name': '',
      'location_desc': 'สาขาอุบลราชธานี',
    },
    {
      'person_id': '9',
      'first_name': 'เปอร์เซ็นต์',
      'last_name': 'ทดสอบ',
      'nick_name': '100%',
      'employee_status': 'Active',
      'branch_name': 'สาขาทดสอบ',
    },
  ]);
}

String _csv(List<Map<String, String>> rows) {
  final header = <String>{
    ...CsvEmployeeParser.requiredColumns,
    ...rows.expand((row) => row.keys),
  }.toList();
  final buffer = StringBuffer()..writeln(header.join(','));
  for (final row in rows) {
    buffer.writeln([
      for (final column in header) '"${(row[column] ?? '').replaceAll('"', '""')}"',
    ].join(','));
  }
  return buffer.toString();
}
