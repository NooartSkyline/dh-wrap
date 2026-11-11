import 'dart:convert';

import 'package:flutter/services.dart';

class EmployeeCsvAsset {
  const EmployeeCsvAsset();

  static const path = 'assets/employees.csv';

  /// เปลี่ยนเมื่อแทนที่ไฟล์ CSV เพื่อให้เครื่องที่นำเข้าชุดเก่าแล้วโหลดใหม่
  static const version = '20261111';

  Future<String> load() async {
    final data = await rootBundle.load(path);
    return utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
}
