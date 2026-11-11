import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dh_wrap/data/datasources/csv_employee_parser.dart';
import 'package:postgres/postgres.dart';

/// เปิดจากโฟลเดอร์โปรเจกต์:
/// dart run tool/sync_server.dart
/// dart run tool/sync_server.dart --check
///
/// อ่าน .env ที่เครื่องนี้ แล้วส่งเฉพาะ 25 คอลัมน์ที่แอปใช้
/// รหัสฐานข้อมูลไม่ถูกใส่ในแอป
Future<void> main(List<String> args) async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    stderr.writeln(
      'ไม่พบไฟล์ .env ในโฟลเดอร์นี้ เปิดเทอร์มินัลที่โฟลเดอร์โปรเจกต์แล้วรันใหม่',
    );
    exitCode = 1;
    return;
  }
  final env = _loadEnv(envFile);
  final password = env['PG_PASS'] ?? '';
  try {
    final config = _configFrom(env);
    final source = await _discover(config);
    stdout.writeln(
      'ใช้ตาราง ${source.database}.${source.schema}.${source.table}',
    );
    if (args.contains('--check')) {
      final count = await _countRows(config, source);
      stdout.writeln('จำนวนแถว $count');
      return;
    }
    final port = _portArg(args) ?? 8787;
    await _serve(config, source, port);
  } catch (error) {
    stderr.writeln(_redact('$error', password));
    exitCode = 1;
  }
}

class _DbConfig {
  const _DbConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.database,
    required this.schema,
    required this.table,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String? database;
  final String? schema;
  final String? table;
}

class _EmployeeSource {
  const _EmployeeSource({
    required this.database,
    required this.schema,
    required this.table,
  });

  final String database;
  final String schema;
  final String table;
}

_DbConfig _configFrom(Map<String, String> env) {
  final reader = env['PG_READ']?.trim() ?? '';
  final host = reader.isNotEmpty ? reader : _required(env, 'PG_HOST');
  final port = int.tryParse(_required(env, 'PG_PORT'));
  if (port == null) {
    throw const FormatException('PG_PORT ต้องเป็นตัวเลข');
  }
  final database = env['PG_DATABASE']?.trim();
  final schema = env['PG_SCHEMA']?.trim();
  final table = env['PG_TABLE']?.trim();
  return _DbConfig(
    host: host,
    port: port,
    username: _required(env, 'PG_USER'),
    password: _required(env, 'PG_PASS'),
    database: database == null || database.isEmpty ? null : database,
    schema: schema == null || schema.isEmpty ? null : schema,
    table: table == null || table.isEmpty ? null : table,
  );
}

String _required(Map<String, String> env, String key) {
  final value = env[key]?.trim() ?? '';
  if (value.isEmpty) {
    throw FormatException('ไฟล์ .env ไม่มี $key');
  }
  return value;
}

Future<_EmployeeSource> _discover(_DbConfig config) async {
  final pinnedSchema = config.schema;
  final pinnedTable = config.table;
  if (pinnedSchema != null && pinnedTable != null) {
    final database = config.database;
    if (database == null) {
      throw const FormatException('ถ้าระบุ PG_SCHEMA กับ PG_TABLE ต้องมี PG_DATABASE');
    }
    return _EmployeeSource(
      database: database,
      schema: pinnedSchema,
      table: pinnedTable,
    );
  }
  final names = config.database == null
      ? await _databaseNames(config)
      : [config.database!];
  final matches = <_RankedSource>[];
  Object? lastError;
  for (final name in names) {
    try {
      final found = await _withConnection(config, name, (connection) async {
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
  return _EmployeeSource(
    database: chosen.database,
    schema: chosen.schema,
    table: chosen.table,
  );
}

Future<List<String>> _databaseNames(_DbConfig config) {
  return _withConnection(config, 'postgres', (connection) async {
    final result = await connection.execute(
      "SELECT datname FROM pg_database "
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
  for (final column in columns) {
    if (!RegExp(r'^[a-z_]+$').hasMatch(column)) {
      throw StateError('คอลัมน์ $column ใช้ในคำสั่ง SQL ไม่ได้');
    }
  }
  if (columns
      .toSet()
      .intersection(CsvEmployeeParser.droppedColumns.toSet())
      .isNotEmpty) {
    throw StateError('คำสั่งดึงข้อมูลมีคอลัมน์ที่ห้ามเก็บ');
  }
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

Future<int> _countRows(_DbConfig config, _EmployeeSource source) {
  return _withConnection(config, source.database, (connection) async {
    final result = await connection.execute(
      'SELECT COUNT(*) FROM ${_from(source)}',
    );
    final raw = result.first[0];
    if (raw is int) return raw;
    if (raw is BigInt) return raw.toInt();
    return int.parse('$raw');
  });
}

Future<String> _exportCsv(_DbConfig config, _EmployeeSource source) {
  return _withConnection(config, source.database, (connection) async {
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

String _from(_EmployeeSource source) {
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

Future<T> _withConnection<T>(
  _DbConfig config,
  String database,
  Future<T> Function(Connection connection) action,
) async {
  final endpoint = Endpoint(
    host: config.host,
    port: config.port,
    database: database,
    username: config.username,
    password: config.password,
  );
  try {
    return await _run(endpoint, SslMode.require, action);
  } catch (error) {
    final text = _redact('$error', config.password).toLowerCase();
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

Future<void> _serve(_DbConfig config, _EmployeeSource source, int port) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  var busy = false;
  stdout.writeln('ตัวดึงข้อมูลพร้อมแล้ว พิมพ์ที่อยู่นี้ในแอป');
  stdout.writeln('http://127.0.0.1:$port');
  final interfaces = await NetworkInterface.list();
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (address.type != InternetAddressType.IPv4 || address.isLoopback) {
        continue;
      }
      stdout.writeln('http://${address.address}:$port');
    }
  }
  await for (final request in server) {
    if (request.method != 'GET' || request.uri.path != '/employees.csv') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    if (busy) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.write('กำลังดึงข้อมูลอยู่แล้ว');
      await request.response.close();
      continue;
    }
    busy = true;
    try {
      final csv = await _exportCsv(config, source);
      final bytes = utf8.encode(csv);
      request.response.headers.contentType = ContentType(
        'text',
        'csv',
        charset: 'utf-8',
      );
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    } catch (error) {
      stderr.writeln(_redact('$error', config.password));
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('อ่านข้อมูลไม่สำเร็จ');
      await request.response.close();
    } finally {
      busy = false;
    }
  }
}

int? _portArg(List<String> args) {
  final index = args.indexOf('--port');
  if (index == -1 || index + 1 >= args.length) return null;
  final port = int.tryParse(args[index + 1]);
  if (port == null || port <= 0 || port > 65535) {
    throw const FormatException('--port ต้องเป็นเลขพอร์ต');
  }
  return port;
}

Map<String, String> _loadEnv(File file) {
  final env = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final split = line.indexOf('=');
    if (split <= 0) continue;
    env[line.substring(0, split).trim()] = line.substring(split + 1).trim();
  }
  return env;
}

String _redact(String text, String secret) {
  if (secret.isEmpty) return text;
  return text.replaceAll(secret, '***');
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
