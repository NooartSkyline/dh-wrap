import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/repositories/employee_repository_impl.dart';
import 'data/sync/sync_endpoint_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final repository = EmployeeRepositoryImpl(database);
  runApp(
    DhWrapApp(
      repository: repository,
      syncEndpoints: SqliteSyncEndpointStore(database),
    ),
  );
}
