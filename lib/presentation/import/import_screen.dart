import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/group_digits.dart';
import 'import_cubit.dart';
import 'import_state.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลพนักงาน')),
      body: SafeArea(
        child: BlocBuilder<ImportCubit, ImportState>(
          builder: (context, state) {
            return switch (state) {
              ImportInProgress() => _Progress(state: state),
              ImportSuccess() => const _Progress(
                state: ImportInProgress(done: 1, total: 1),
                title: 'นำเข้าข้อมูลแล้ว',
              ),
              ImportFailure(:final message) => _Failure(message: message),
            };
          },
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state, this.title = 'กำลังเตรียมข้อมูลพนักงาน'});

  final ImportInProgress state;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalText = state.total > 0
        ? '${groupDigits(state.done)} / ${groupDigits(state.total)}'
        : groupDigits(state.done);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'กำลังบันทึกลงเครื่อง ใช้ได้โดยไม่ต้องต่อเน็ต',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 12),
          Text('บันทึกแล้ว $totalText'),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('นำเข้าข้อมูลไม่สำเร็จ', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.read<ImportCubit>().start(),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}
