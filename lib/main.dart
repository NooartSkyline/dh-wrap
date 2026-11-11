import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/repositories/employee_repository_impl.dart';
import 'data/theme/theme_seed_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final repository = EmployeeRepositoryImpl(database);
  final themeSeeds = ThemeSeedStore(database);
  final seed = await themeSeeds.read();
  runApp(
    DhWrapApp(
      repository: repository,
      themeSeeds: themeSeeds,
      initialSeed: seed,
    ),
  );
}
