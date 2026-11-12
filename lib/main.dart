import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/repositories/employee_repository_impl.dart';
import 'data/search/search_history_store.dart';
import 'data/theme/theme_seed_store.dart';
import 'data/update/update_history_store.dart';
import 'data/usage/usage_hint_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final repository = EmployeeRepositoryImpl(database);
  final themeSeeds = ThemeSeedStore(database);
  final usageHints = UsageHintStore(database);
  final updateHistory = UpdateHistoryStore(database);
  final searchHistory = SearchHistoryStore(database);
  final seed = await themeSeeds.read();
  runApp(
    DhWrapApp(
      repository: repository,
      themeSeeds: themeSeeds,
      usageHints: usageHints,
      updateHistory: updateHistory,
      searchHistory: searchHistory,
      initialSeed: seed,
    ),
  );
}
