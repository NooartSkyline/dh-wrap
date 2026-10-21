import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/repositories/employee_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = EmployeeRepositoryImpl(AppDatabase());
  runApp(DhWrapApp(repository: repository));
}
