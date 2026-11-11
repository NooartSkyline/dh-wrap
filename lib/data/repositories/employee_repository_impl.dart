import 'package:sqflite/sqflite.dart';

import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_page.dart';
import '../../domain/entities/employee_search_query.dart';
import '../../domain/entities/employee_status_filter.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/csv_employee_parser.dart';
import '../db/app_database.dart';
import '../mappers/employee_mapper.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl(this._database, {CsvEmployeeParser? parser})
    : _parser = parser ?? const CsvEmployeeParser();

  static const _importKey = 'import_complete';
  static const _batchSize = 30;

  final AppDatabase _database;
  final CsvEmployeeParser _parser;

  @override
  Future<bool> isImported() async {
    final db = await _database.open();
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_importKey],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.first['value'] == '1';
  }

  @override
  Future<int> importCsv(
    String csvText, {
    required void Function(int done, int total) onProgress,
  }) async {
    _parser.validate(csvText);
    final total = _parser.dataRowCount(csvText);
    if (total <= 0) {
      throw const FormatException('ไฟล์ CSV ไม่มีข้อมูลพนักงาน');
    }

    final db = await _database.open();
    var saved = 0;
    var pending = <Employee>[];

    await db.transaction((txn) async {
      await txn.delete('employees');
      await txn.delete('app_meta', where: 'key = ?', whereArgs: [_importKey]);

      await for (final employee in _parser.parse(csvText)) {
        pending.add(employee);
        if (pending.length >= _batchSize) {
          saved += await _insertBatch(txn, pending);
          pending = [];
          if (saved % 300 == 0) onProgress(saved, total);
        }
      }

      if (pending.isNotEmpty) {
        saved += await _insertBatch(txn, pending);
      }
      if (saved == 0) {
        throw const FormatException('ไฟล์ CSV ไม่มีข้อมูลพนักงาน');
      }
      await txn.insert('app_meta', {
        'key': _importKey,
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    onProgress(saved, total);
    return saved;
  }

  Future<int> _insertBatch(Transaction txn, List<Employee> employees) async {
    final batch = txn.batch();
    for (final employee in employees) {
      batch.insert(
        'employees',
        EmployeeMapper.toDb(employee),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    return employees.length;
  }

  @override
  Future<EmployeePage> search(EmployeeSearchQuery query) async {
    final text = query.text.trim().toLowerCase();
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final branch = query.branchLabel?.trim();
    final hasBranch = branch != null && branch.isNotEmpty;
    if (tokens.isEmpty && !hasBranch) {
      throw ArgumentError('ต้องระบุคำค้นหรือสาขา');
    }

    final where = <String>[];
    final args = <Object?>[];
    switch (query.status) {
      case EmployeeStatusFilter.working:
        where.add("employee_status = 'Active'");
      case EmployeeStatusFilter.notWorking:
        where.add("employee_status IN ('InActive', 'Inactive')");
      case EmployeeStatusFilter.all:
        break;
    }
    if (hasBranch) {
      where.add('branch_label = ?');
      args.add(branch);
    }
    for (final token in tokens) {
      where.add("search_text LIKE ? ESCAPE '\\'");
      args.add('%${_escapeLike(token)}%');
    }

    final limit = query.limit < 1 ? 1 : query.limit;
    final offset = query.offset < 0 ? 0 : query.offset;
    args
      ..add(limit + 1)
      ..add(offset);

    final db = await _database.open();
    final rows = await db.rawQuery('''
      SELECT *
      FROM employees
      WHERE ${where.join(' AND ')}
      ORDER BY first_name, last_name, person_id
      LIMIT ? OFFSET ?
    ''', args);

    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.sublist(0, limit) : rows;
    return EmployeePage(
      items: pageRows.map(EmployeeMapper.fromDb).toList(),
      hasMore: hasMore,
    );
  }

  @override
  Future<Employee?> findById(String personId) async {
    final db = await _database.open();
    final rows = await db.query(
      'employees',
      where: 'person_id = ?',
      whereArgs: [personId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EmployeeMapper.fromDb(rows.first);
  }

  @override
  Future<int> countWorking() async {
    final db = await _database.open();
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM employees WHERE employee_status = 'Active'",
      ),
    );
    if (count == null) {
      throw StateError('นับจำนวนพนักงานไม่สำเร็จ');
    }
    return count;
  }

  @override
  Future<List<String>> listBranches() async {
    final db = await _database.open();
    final rows = await db.rawQuery('''
      SELECT DISTINCT branch_label
      FROM employees
      WHERE branch_label != ''
      ORDER BY branch_label
    ''');
    return rows
        .map((row) => (row['branch_label'] ?? '').toString())
        .where((label) => label.isNotEmpty)
        .toList();
  }

  String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
