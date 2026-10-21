import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/employee_repository.dart';
import '../../domain/usecases/get_employee.dart';
import '../../presentation/detail/employee_detail_cubit.dart';
import '../../presentation/detail/employee_detail_screen.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case EmployeeDetailScreen.routeName:
        final personId = settings.arguments;
        if (personId is! String || personId.trim().isEmpty) {
          return _messageRoute('ไม่พบรหัสพนักงาน');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) {
            return BlocProvider(
              create: (_) => EmployeeDetailCubit(
                GetEmployee(context.read<EmployeeRepository>()),
              )..load(personId),
              child: const EmployeeDetailScreen(),
            );
          },
        );
      default:
        return _messageRoute('ไม่พบหน้า ${settings.name ?? ''}');
    }
  }

  static MaterialPageRoute<void> _messageRoute(String message) {
    return MaterialPageRoute<void>(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(title: const Text('ค้นหาพนักงาน')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        );
      },
    );
  }
}
