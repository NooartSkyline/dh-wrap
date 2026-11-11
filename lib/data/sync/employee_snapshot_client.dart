import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// ที่อยู่ฐาน เช่น http://192.168.1.10:8787 กลายเป็นไฟล์ CSV ของชุดข้อมูล
Uri csvUriFromBase(String raw) {
  var text = raw.trim();
  if (text.isEmpty) {
    throw const FormatException('ยังไม่ได้ใส่ที่อยู่เซิร์ฟเวอร์');
  }
  if (!text.contains('://')) text = 'http://$text';
  final base = Uri.tryParse(text);
  if (base == null || !base.hasScheme || base.host.isEmpty) {
    throw const FormatException('ที่อยู่เซิร์ฟเวอร์ไม่ถูกต้อง');
  }
  if (base.scheme != 'http' && base.scheme != 'https') {
    throw const FormatException('ที่อยู่ต้องขึ้นต้นด้วย http หรือ https');
  }
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/employees.csv',
  );
}

abstract class EmployeeSnapshotSource {
  Future<String> download(
    Uri uri, {
    required void Function(int received, int? total) onProgress,
  });
}

class EmployeeSnapshotClient implements EmployeeSnapshotSource {
  const EmployeeSnapshotClient();

  @override
  Future<String> download(
    Uri uri, {
    required void Function(int received, int? total) onProgress,
  }) {
    return _download(uri, onProgress).timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw const FormatException('ดาวน์โหลดนานเกินไป'),
    );
  }

  Future<String> _download(
    Uri uri,
    void Function(int received, int? total) onProgress,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw FormatException('เซิร์ฟเวอร์ตอบรหัส ${response.statusCode}');
      }
      final total = response.contentLength;
      final bytes = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response) {
        bytes.add(chunk);
        received += chunk.length;
        onProgress(received, total < 0 ? null : total);
      }
      final text = utf8.decode(bytes.takeBytes());
      if (text.trim().isEmpty) {
        throw const FormatException('เซิร์ฟเวอร์ไม่ได้ส่งข้อมูล');
      }
      return text;
    } on FormatException {
      rethrow;
    } on SocketException {
      throw const FormatException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ ตรวจที่อยู่และว่าเปิดตัวดึงไว้แล้ว',
      );
    } finally {
      client.close();
    }
  }
}
