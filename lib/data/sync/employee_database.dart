import 'dart:io';

import 'package:csv/csv.dart';
import 'package:postgres/postgres.dart';

import '../datasources/csv_employee_parser.dart';
import 'employee_snapshot_source.dart';

class EmployeeDatabaseSettings {
  const EmployeeDatabaseSettings({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.database,
    this.schema,
    this.table,
  });

  /// ค่าจาก `--dart-define-from-file=.env` ตอนบิลด์แอป
  factory EmployeeDatabaseSettings.fromEnvironment() {
    return EmployeeDatabaseSettings.fromMap(const {
      'PG_HOST': String.fromEnvironment('PG_HOST'),
      'PG_READ': String.fromEnvironment('PG_READ'),
      'PG_PORT': String.fromEnvironment('PG_PORT'),
      'PG_USER': String.fromEnvironment('PG_USER'),
      'PG_PASS': String.fromEnvironment('PG_PASS'),
      'PG_DATABASE': String.fromEnvironment('PG_DATABASE'),
      'PG_SCHEMA': String.fromEnvironment('PG_SCHEMA'),
      'PG_TABLE': String.fromEnvironment('PG_TABLE'),
    }, missing: 'บิลด์นี้ไม่มีค่า');
  }

  factory EmployeeDatabaseSettings.fromMap(
    Map<String, String> env, {
    String missing = 'ไฟล์ .env ไม่มี',
  }) {
    final reader = env['PG_READ']?.trim() ?? '';
    final host = reader.isNotEmpty
        ? reader
        : _required(env, 'PG_HOST', missing);
    final port = int.tryParse(_required(env, 'PG_PORT', missing));
    if (port == null) {
      throw const FormatException('PG_PORT ต้องเป็นตัวเลข');
    }
    return EmployeeDatabaseSettings(
      host: host,
      port: port,
      username: _required(env, 'PG_USER', missing),
      password: _required(env, 'PG_PASS', missing),
      database: _optional(env, 'PG_DATABASE') ?? 'dh_company',
      schema: _optional(env, 'PG_SCHEMA') ?? 'public',
      table: _optional(env, 'PG_TABLE') ?? 'employees',
    );
  }

  final String host;
  final int port;
  final String username;
  final String password;
  final String? database;
  final String? schema;
  final String? table;
}

class EmployeeSourceTable {
  const EmployeeSourceTable({
    required this.database,
    required this.schema,
    required this.table,
  });

  final String database;
  final String schema;
  final String table;
}

class EmployeeDatabase {
  const EmployeeDatabase(this.settings);

  final EmployeeDatabaseSettings settings;

  Future<EmployeeSourceTable> discover() {
    return _guard(_discover);
  }

  Future<int> countRows(EmployeeSourceTable source) {
    return _guard(() => _countRows(source));
  }

  Future<String> exportCsv(EmployeeSourceTable source) {
    return _guard(() => _exportCsv(source));
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException catch (error) {
      throw FormatException(_redact(error.message));
    } on SocketException {
      throw const FormatException(
        'เชื่อมต่อฐานข้อมูลไม่สำเร็จ ตรวจว่าเครื่องนี้อยู่ในเครือข่ายที่เข้าถึงฐานข้อมูลได้',
      );
    } catch (error) {
      final text = _redact('$error');
      final lower = text.toLowerCase();
      if (lower.contains('timed out') || lower.contains('timeout')) {
        throw const FormatException(
          'เชื่อมต่อฐานข้อมูลไม่สำเร็จ ตรวจว่าเครื่องนี้อยู่ในเครือข่ายที่เข้าถึงฐานข้อมูลได้',
        );
      }
      throw FormatException(text);
    }
  }

  String _redact(String text) {
    final secret = settings.password;
    if (secret.isEmpty) return text;
    return text.replaceAll(secret, '***');
  }

  Future<EmployeeSourceTable> _discover() async {
    _assertColumnsAreSafe();
    final pinnedSchema = settings.schema;
    final pinnedTable = settings.table;
    if (pinnedSchema != null && pinnedTable != null) {
      final database = settings.database;
      if (database == null) {
        throw const FormatException(
          'ถ้าระบุ PG_SCHEMA กับ PG_TABLE ต้องมี PG_DATABASE',
        );
      }
      return EmployeeSourceTable(
        database: database,
        schema: pinnedSchema,
        table: pinnedTable,
      );
    }
    final names = settings.database == null
        ? await _databaseNames()
        : [settings.database!];
    final matches = <_RankedSource>[];
    Object? lastError;
    for (final name in names) {
      try {
        final found = await _withConnection(name, (connection) {
          return _tablesWithColumns(connection, name);
        });
        matches.addAll(found);
      } catch (error) {
        lastError = error;
      }
    }
    if (matches.isEmpty) {
      if (lastError != null) throw lastError;
      throw const FormatException('ไม่พบตารางที่มีคอลัมน์พนักงานครบ');
    }
    matches.sort((a, b) {
      final employeeBias =
          (b.table.contains('employee') ? 1 : 0) -
          (a.table.contains('employee') ? 1 : 0);
      if (employeeBias != 0 && (a.estimate - b.estimate).abs() < 1000) {
        return employeeBias;
      }
      return b.estimate.compareTo(a.estimate);
    });
    final chosen = matches.first;
    return EmployeeSourceTable(
      database: chosen.database,
      schema: chosen.schema,
      table: chosen.table,
    );
  }

  Future<List<String>> _databaseNames() {
    return _withConnection('postgres', (connection) async {
      final result = await connection.execute(
        'SELECT datname FROM pg_database '
        "WHERE datallowconn AND NOT datistemplate AND datname <> 'rdsadmin' "
        'ORDER BY datname',
      );
      return [
        for (final row in result)
          if (row[0] != null) '${row[0]}',
      ];
    });
  }

  Future<List<_RankedSource>> _tablesWithColumns(
    Connection connection,
    String database,
  ) async {
    final columns = CsvEmployeeParser.requiredColumns;
    final inList = columns.map((column) => "'$column'").join(', ');
    final result = await connection.execute(
      'SELECT table_schema, table_name '
      'FROM information_schema.columns '
      "WHERE column_name IN ($inList) "
      "AND table_schema NOT IN ('pg_catalog', 'information_schema') "
      'GROUP BY table_schema, table_name '
      'HAVING COUNT(DISTINCT column_name) = ${columns.length}',
    );
    final ranked = <_RankedSource>[];
    for (final row in result) {
      final schema = '${row[0]}';
      final table = '${row[1]}';
      final estimate = await connection.execute(
        Sql.named(
          'SELECT COALESCE(c.reltuples, 0) '
          'FROM pg_class c '
          'JOIN pg_namespace n ON n.oid = c.relnamespace '
          'WHERE n.nspname = @schema AND c.relname = @table',
        ),
        parameters: {'schema': schema, 'table': table},
      );
      final raw = estimate.isEmpty ? 0 : estimate.first[0];
      final value = raw is num ? raw.toDouble() : 0.0;
      ranked.add(
        _RankedSource(
          database: database,
          schema: schema,
          table: table,
          estimate: value,
        ),
      );
    }
    return ranked;
  }

  Future<int> _countRows(EmployeeSourceTable source) {
    return _withConnection(source.database, (connection) async {
      final result = await connection.execute(
        'SELECT COUNT(*) FROM ${_from(source)}',
      );
      final raw = result.first[0];
      if (raw is int) return raw;
      if (raw is BigInt) return raw.toInt();
      return int.parse('$raw');
    });
  }

  Future<String> _exportCsv(EmployeeSourceTable source) {
    return _withConnection(source.database, (connection) async {
      final columns = CsvEmployeeParser.requiredColumns;
      final select = columns.map(_quoteIdent).join(', ');
      final result = await connection.execute(
        'SELECT $select FROM ${_from(source)}',
        timeout: const Duration(minutes: 3),
      );
      final rows = <List<String>>[
        columns,
        for (final row in result)
          [
            for (var index = 0; index < columns.length; index++)
              _cell(row[index]),
          ],
      ];
      final csv = const CsvEncoder(lineDelimiter: '\n').convert(rows);
      return csv.endsWith('\n') ? csv : '$csv\n';
    });
  }

  Future<T> _withConnection<T>(
    String database,
    Future<T> Function(Connection connection) action,
  ) async {
    final endpoint = Endpoint(
      host: settings.host,
      port: settings.port,
      database: database,
      username: settings.username,
      password: settings.password,
    );
    try {
      return await _run(endpoint, SslMode.require, action);
    } catch (error) {
      final text = _redact('$error').toLowerCase();
      if (!text.contains('ssl') && !text.contains('handshake')) rethrow;
      return _run(endpoint, SslMode.disable, action);
    }
  }

  Future<T> _run<T>(
    Endpoint endpoint,
    SslMode sslMode,
    Future<T> Function(Connection connection) action,
  ) async {
    final connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(
        applicationName: 'dh_wrap_sync',
        sslMode: sslMode,
        connectTimeout: const Duration(seconds: 20),
        queryTimeout: const Duration(minutes: 3),
        onOpen: (connection) async {
          await connection.execute("SET statement_timeout = '180s'");
          await connection.execute('SET default_transaction_read_only = on');
        },
      ),
    );
    try {
      return await action(connection);
    } finally {
      await connection.close();
    }
  }
}

class EmployeeDatabaseSnapshot implements EmployeeSnapshotSource {
  const EmployeeDatabaseSnapshot({this.settings});

  final EmployeeDatabaseSettings? settings;

  @override
  Future<String> download({
    required void Function(int received, int? total) onProgress,
  }) async {
    final database = EmployeeDatabase(
      settings ?? EmployeeDatabaseSettings.fromEnvironment(),
    );
    final table = await database.discover();
    final csv = await database.exportCsv(table);
    onProgress(csv.length, csv.length);
    return csv;
  }
}

void _assertColumnsAreSafe() {
  final columns = CsvEmployeeParser.requiredColumns;
  for (final column in columns) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(column)) {
      throw StateError('คอลัมน์ $column ใช้ในคำสั่ง SQL ไม่ได้');
    }
  }
  if (columns
      .toSet()
      .intersection(CsvEmployeeParser.droppedColumns.toSet())
      .isNotEmpty) {
    throw StateError('คำสั่งดึงข้อมูลมีคอลัมน์ที่ห้ามเก็บ');
  }
}

String _required(Map<String, String> env, String key, String missing) {
  final value = env[key]?.trim() ?? '';
  if (value.isEmpty) {
    throw FormatException('$missing $key');
  }
  return value;
}

String? _optional(Map<String, String> env, String key) {
  final value = env[key]?.trim() ?? '';
  if (value.isEmpty) return null;
  return value;
}

String _from(EmployeeSourceTable source) {
  return '${_quoteIdent(source.schema)}.${_quoteIdent(source.table)}';
}

String _quoteIdent(String name) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
    throw FormatException('ชื่อ $name ใช้ในคำสั่ง SQL ไม่ได้');
  }
  return '"$name"';
}

String _cell(Object? value) {
  if (value == null) return '';
  if (value is DateTime) {
    final utc = value.toUtc();
    final midnight =
        utc.hour == 0 &&
        utc.minute == 0 &&
        utc.second == 0 &&
        utc.millisecond == 0 &&
        utc.microsecond == 0;
    final clock = midnight ? utc : utc.add(const Duration(hours: 7));
    final year = clock.year.toString().padLeft(4, '0');
    final month = clock.month.toString().padLeft(2, '0');
    final day = clock.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
  return value.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
}

class _RankedSource {
  const _RankedSource({
    required this.database,
    required this.schema,
    required this.table,
    required this.estimate,
  });

  final String database;
  final String schema;
  final String table;
  final double estimate;
}
