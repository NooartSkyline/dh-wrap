import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/employee_repository.dart';
import 'domain/usecases/count_working_employees.dart';
import 'domain/usecases/list_employee_branches.dart';
import 'domain/usecases/search_employees.dart';
import 'presentation/bootstrap/app_gate.dart';
import 'presentation/search/search_bloc.dart';

class DhWrapApp extends StatelessWidget {
  const DhWrapApp({super.key, required this.repository});

  final EmployeeRepository repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<EmployeeRepository>.value(
      value: repository,
      child: BlocProvider(
        create: (_) => SearchBloc(
          searchEmployees: SearchEmployees(repository),
          countWorkingEmployees: CountWorkingEmployees(repository),
          listEmployeeBranches: ListEmployeeBranches(repository),
        ),
        child: MaterialApp(
          title: 'ค้นหาพนักงาน',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const AppGate(),
        ),
      ),
    );
  }
}
