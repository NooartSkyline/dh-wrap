import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../common/group_digits.dart';
import 'import_cubit.dart';
import 'import_state.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
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
    final totalText = state.total > 0
        ? '${groupDigits(state.done)} / ${groupDigits(state.total)}'
        : groupDigits(state.done);
    final value = state.progress;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.ink, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'กำลังบันทึกลงเครื่อง ใช้ได้โดยไม่ต้องต่อเน็ต',
            style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 28),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: AppColors.line,
              color: AppColors.leaf,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'บันทึกแล้ว $totalText',
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
          ),
          const Spacer(flex: 2),
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
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Icon(Icons.error_outline, color: AppColors.idle, size: 40),
          const SizedBox(height: 16),
          const Text(
            'นำเข้าข้อมูลไม่สำเร็จ',
            style: TextStyle(color: AppColors.ink, fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.ink, height: 1.4)),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => context.read<ImportCubit>().start(),
            child: const Text('ลองใหม่'),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
