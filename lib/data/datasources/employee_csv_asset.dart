import 'dart:convert';

import 'package:flutter/services.dart';

class EmployeeCsvAsset {
  const EmployeeCsvAsset();

  static const path = 'assets/employees.csv';

  Future<String> load() async {
    final data = await rootBundle.load(path);
    return utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
}
