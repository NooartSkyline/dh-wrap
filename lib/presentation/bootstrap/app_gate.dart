import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/employee_csv_asset.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/usecases/import_employees.dart';
import '../../domain/usecases/is_employee_data_imported.dart';
import '../import/import_cubit.dart';
import '../import/import_screen.dart';
import '../import/import_state.dart';
import '../search/search_screen.dart';
import 'app_gate_cubit.dart';
import 'app_gate_state.dart';

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<EmployeeRepository>();
    return BlocProvider(
      create: (_) => AppGateCubit(IsEmployeeDataImported(repository))..check(),
      child: BlocBuilder<AppGateCubit, AppGateState>(
        builder: (context, state) {
          return switch (state) {
            AppGateChecking() => const _GateMessage(
              title: 'กำลังตรวจสอบข้อมูล',
              showProgress: true,
            ),
            AppGateNeedsImport() => BlocProvider(
              create: (_) => ImportCubit(
                ImportEmployees(repository),
                const EmployeeCsvAsset(),
              )..start(),
              child: BlocListener<ImportCubit, ImportState>(
                listener: (context, importState) {
                  if (importState is ImportSuccess) {
                    context.read<AppGateCubit>().markReady();
                  }
                },
                child: const ImportScreen(),
              ),
            ),
            AppGateReady() => const SearchScreen(),
            AppGateFailure(:final message) => _GateMessage(
              title: 'เปิดข้อมูลไม่สำเร็จ',
              message: message,
              onRetry: () => context.read<AppGateCubit>().check(),
            ),
          };
        },
      ),
    );
  }
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({
    required this.title,
    this.message,
    this.showProgress = false,
    this.onRetry,
  });

  final String title;
  final String? message;
  final bool showProgress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showProgress) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 24),
              ],
              Text(title, style: theme.textTheme.titleLarge),
              if (message case final detail?) ...[
                const SizedBox(height: 12),
                Text(detail),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
