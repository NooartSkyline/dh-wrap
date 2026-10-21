import 'package:csv/csv.dart';

import '../../domain/entities/employee.dart';
import '../mappers/employee_mapper.dart';

class CsvEmployeeParser {
  const CsvEmployeeParser();

  static const requiredColumns = <String>[
    'person_id',
    'first_name',
    'last_name',
    'first_name_alt1',
    'last_name_alt1',
    'nick_name',
    'employee_status',
    'position_desc',
    'employee_type',
    'company',
    'business_name',
    'division_hq_name',
    'division_branch_name',
    'section_name',
    'unit_name',
    'supervisor',
    'branch_name',
    'location_desc',
    'mobile_phone',
    'business_phone',
    'email_company',
    'hire_date',
    'resign_date',
    'termination_date',
    'last_working_date',
  ];

  static const droppedColumns = <String>[
    'password',
    'id_card',
    'black_list',
    'black_list_reason',
  ];

  void validate(String csvText) {
    final header = readHeader(csvText).toSet();
    final missing = requiredColumns.where((column) => !header.contains(column));
    if (missing.isNotEmpty) {
      throw FormatException('ไฟล์ CSV ไม่มีคอลัมน์ ${missing.join(', ')}');
    }
  }

  int dataRowCount(String csvText) {
    if (csvText.isEmpty) return 0;
    var lines = 0;
    var endsWithBreak = false;
    for (var index = 0; index < csvText.length; index++) {
      final unit = csvText.codeUnitAt(index);
      if (unit == 10) {
        lines++;
        endsWithBreak = true;
      } else if (unit != 13) {
        endsWithBreak = false;
      }
    }
    if (!endsWithBreak) lines++;
    if (lines == 0) return 0;
    return lines - 1;
  }

  Stream<Employee> parse(String csvText) async* {
    validate(csvText);
    final headerLine = _headerLine(csvText);
    final chunk = StringBuffer()..writeln(headerLine);
    var linesInChunk = 0;

    for (final line in _bodyLines(csvText)) {
      if (line.trim().isEmpty) continue;
      chunk.writeln(line);
      linesInChunk++;
      if (linesInChunk == 500) {
        yield* _employeesIn(chunk.toString());
        chunk
          ..clear()
          ..writeln(headerLine);
        linesInChunk = 0;
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (linesInChunk > 0) {
      yield* _employeesIn(chunk.toString());
    }
  }

  List<String> readHeader(String csvText) {
    if (csvText.trim().isEmpty) {
      throw const FormatException('ไฟล์ CSV ว่าง');
    }
    final rows = const CsvDecoder(
      dynamicTyping: false,
    ).convert(_headerLine(csvText));
    if (rows.isEmpty || rows.first.isEmpty) {
      throw const FormatException('ไฟล์ CSV ไม่มีหัวคอลัมน์');
    }
    return rows.first.map((cell) => cell.toString().trim()).toList();
  }

  String _headerLine(String csvText) {
    final breakAt = csvText.indexOf(RegExp(r'\r\n|\n|\r'));
    final line = breakAt == -1 ? csvText : csvText.substring(0, breakAt);
    return line.replaceFirst('\ufeff', '');
  }

  Iterable<String> _bodyLines(String csvText) sync* {
    final breakAt = csvText.indexOf(RegExp(r'\r\n|\n|\r'));
    if (breakAt == -1) return;
    var start = breakAt + (csvText.startsWith('\r\n', breakAt) ? 2 : 1);
    while (start < csvText.length) {
      var index = start;
      while (index < csvText.length) {
        final unit = csvText.codeUnitAt(index);
        if (unit == 10 || unit == 13) break;
        index++;
      }
      yield csvText.substring(start, index);
      if (index >= csvText.length) break;
      final isCrLf =
          csvText.codeUnitAt(index) == 13 &&
          index + 1 < csvText.length &&
          csvText.codeUnitAt(index + 1) == 10;
      start = index + (isCrLf ? 2 : 1);
    }
  }

  Stream<Employee> _employeesIn(String csvChunk) async* {
    final rows = const CsvDecoder(
      parseHeaders: true,
      dynamicTyping: false,
    ).convert(csvChunk);
    for (final row in rows) {
      if (row is! CsvRow) {
        throw const FormatException('ไฟล์ CSV อ่านแถวไม่สำเร็จ');
      }
      final employee = EmployeeMapper.fromCsvRow(row);
      if (employee != null) yield employee;
    }
  }
}
