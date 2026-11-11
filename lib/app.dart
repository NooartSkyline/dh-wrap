import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/theme/theme_seed_store.dart';
import 'data/update/update_history_store.dart';
import 'data/usage/usage_hint_store.dart';
import 'domain/repositories/employee_repository.dart';
import 'domain/usecases/count_working_employees.dart';
import 'domain/usecases/list_employee_branches.dart';
import 'domain/usecases/read_data_updated_at.dart';
import 'domain/usecases/search_employees.dart';
import 'presentation/bootstrap/app_gate.dart';
import 'presentation/search/search_bloc.dart';
import 'presentation/theme/theme_cubit.dart';

class DhWrapApp extends StatelessWidget {
  const DhWrapApp({
    super.key,
    required this.repository,
    required this.themeSeeds,
    required this.usageHints,
    required this.updateHistory,
    required this.initialSeed,
  });

  final EmployeeRepository repository;
  final ThemeSeedStore themeSeeds;
  final UsageHintStore usageHints;
  final UpdateHistoryStore updateHistory;
  final Color initialSeed;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<EmployeeRepository>.value(
      value: repository,
      child: RepositoryProvider<UsageHintStore>.value(
        value: usageHints,
        child: RepositoryProvider<UpdateHistoryStore>.value(
          value: updateHistory,
          child: BlocProvider(
            create: (_) => ThemeCubit(themeSeeds.save, initialSeed),
            child: BlocProvider(
              create: (_) => SearchBloc(
                searchEmployees: SearchEmployees(repository),
                countWorkingEmployees: CountWorkingEmployees(repository),
                readDataUpdatedAt: ReadDataUpdatedAt(repository),
                listEmployeeBranches: ListEmployeeBranches(repository),
              ),
              child: BlocBuilder<ThemeCubit, Color>(
                builder: (context, seed) {
                  return MaterialApp(
                    key: const ValueKey('dh-wrap-app'),
                    title: 'เจ้าเหมียว',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light(seed),
                    onGenerateRoute: AppRouter.onGenerateRoute,
                    home: const AppGate(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
