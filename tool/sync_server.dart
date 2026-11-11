import 'dart:convert';
import 'dart:io';

import 'package:dh_wrap/data/sync/employee_database.dart';

/// เปิดจากโฟลเดอร์โปรเจกต์:
/// dart run tool/sync_server.dart
/// dart run tool/sync_server.dart --check
///
/// อ่าน .env ที่เครื่องนี้ แล้วส่งเฉพาะ 25 คอลัมน์ที่แอปใช้
/// แอปกดอัปเดตต่อฐานข้อมูลเองจากค่าชุดเดียวกันที่ใส่ตอนบิลด์
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
    final database = EmployeeDatabase(EmployeeDatabaseSettings.fromMap(env));
    final source = await database.discover();
    stdout.writeln(
      'ใช้ตาราง ${source.database}.${source.schema}.${source.table}',
    );
    if (args.contains('--check')) {
      final count = await database.countRows(source);
      stdout.writeln('จำนวนแถว $count');
      return;
    }
    final port = _portArg(args) ?? 8787;
    await _serve(database, source, port, password);
  } catch (error) {
    stderr.writeln(_redact('$error', password));
    exitCode = 1;
  }
}

Future<void> _serve(
  EmployeeDatabase database,
  EmployeeSourceTable source,
  int port,
  String password,
) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  var busy = false;
  stdout.writeln('ตัวดึงข้อมูลพร้อมแล้ว');
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
      final csv = await database.exportCsv(source);
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
      stderr.writeln(_redact('$error', password));
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
