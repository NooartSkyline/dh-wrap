import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../common/group_digits.dart';
import 'employee_update_cubit.dart';
import 'employee_update_state.dart';

class EmployeeUpdateScreen extends StatelessWidget {
  const EmployeeUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmployeeUpdateCubit, EmployeeUpdateState>(
      listener: (context, state) {
        if (state is EmployeeUpdateSuccess) {
          Navigator.pop(context, state.count);
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: state is EmployeeUpdateFailure,
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            body: SafeArea(
              child: switch (state) {
                EmployeeUpdateInProgress() => _Progress(state: state),
                EmployeeUpdateSuccess() => const _Progress(
                  state: EmployeeUpdateInProgress(
                    phase: EmployeeUpdatePhase.save,
                    done: 1,
                    total: 1,
                  ),
                ),
                EmployeeUpdateFailure(:final message) => _Failure(
                  message: message,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final EmployeeUpdateInProgress state;

  @override
  Widget build(BuildContext context) {
    final downloading = state.phase == EmployeeUpdatePhase.download;
    final title = downloading
        ? 'กำลังดึงข้อมูลจากฐานข้อมูล'
        : 'กำลังบันทึกลงเครื่อง';
    final detail = downloading
        ? 'ยังไม่ลบข้อมูลเดิม'
        : 'กำลังแทนที่ข้อมูลในเครื่อง';
    final progressText = state.total > 0
        ? '${groupDigits(state.done)} / ${groupDigits(state.total)}'
        : groupDigits(state.done);
    final statusLine = !downloading
        ? 'บันทึกแล้ว $progressText'
        : state.total > 0
        ? 'อ่านแล้ว $progressText'
        : 'กำลังเชื่อมต่อและอ่านข้อมูล';
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              downloading ? Icons.storage_outlined : Icons.inventory_2_outlined,
              color: AppColors.ink,
              size: 32,
            ),
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
          Text(
            detail,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 8,
              backgroundColor: AppColors.line,
              color: AppColors.leaf,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            statusLine,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
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
            'อัปเดตไม่สำเร็จ',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: AppColors.ink, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'ข้อมูลเดิมในเครื่องยังอยู่',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.read<EmployeeUpdateCubit>().start(),
            child: const Text('ลองใหม่'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
