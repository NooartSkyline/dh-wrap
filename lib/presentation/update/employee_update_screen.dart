import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/update/update_history_store.dart';
import '../../domain/entities/employee_update_record.dart';
import '../common/data_updated_label.dart';
import '../common/group_digits.dart';
import '../theme/theme_color_dialog.dart';
import '../theme/theme_cubit.dart';
import 'employee_update_cubit.dart';
import 'employee_update_state.dart';

class EmployeeUpdateScreen extends StatefulWidget {
  const EmployeeUpdateScreen({super.key, this.history});

  final UpdateHistoryStore? history;

  @override
  State<EmployeeUpdateScreen> createState() => _EmployeeUpdateScreenState();
}

class _EmployeeUpdateScreenState extends State<EmployeeUpdateScreen> {
  EmployeeUpdateRecord? _selected;
  List<EmployeeUpdateRecord> _records = const [];
  String? _historyLoadError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = widget.history;
    if (history == null) return;
    try {
      final records = await history.list();
      if (!mounted) return;
      setState(() {
        _records = records;
        _historyLoadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyLoadError = errorText(error));
    }
  }

  void _openRecord(EmployeeUpdateRecord record) {
    setState(() => _selected = record);
  }

  void _back(EmployeeUpdateState state) {
    if (_selected != null) {
      setState(() => _selected = null);
      return;
    }
    _leave(state);
  }

  void _leave(EmployeeUpdateState state) {
    final count = state is EmployeeUpdateSuccess
        ? state.summary.currentCount
        : null;
    Navigator.pop(context, count);
  }

  Future<void> _openTheme() async {
    final picked = await showThemeColorDialog(
      context: context,
      seed: AppColors.of(context).seed,
    );
    if (!mounted || picked == null) return;
    await context.read<ThemeCubit>().select(picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EmployeeUpdateCubit, EmployeeUpdateState>(
      listenWhen: (previous, next) =>
          next is EmployeeUpdateSuccess && previous is! EmployeeUpdateSuccess,
      listener: (_, _) {
        _loadHistory();
      },
      child: BlocBuilder<EmployeeUpdateCubit, EmployeeUpdateState>(
        builder: (context, state) {
          final selected = _selected;
          final title = selected == null ? 'อัปเดตข้อมูล' : 'สรุปย้อนหลัง';
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop || state is EmployeeUpdateInProgress) return;
              _back(state);
            },
            child: Scaffold(
              backgroundColor: AppColors.of(context).canvas,
              appBar: AppBar(
                title: Text(title),
                leading: IconButton(
                  tooltip: 'กลับ',
                  onPressed: state is EmployeeUpdateInProgress
                      ? null
                      : () => _back(state),
                  icon: const Icon(Icons.arrow_back),
                ),
                actions: [
                  IconButton(
                    key: const Key('employee-update-theme-button'),
                    tooltip: 'สีธีม',
                    onPressed: _openTheme,
                    icon: const Icon(Icons.palette_outlined),
                  ),
                ],
              ),
              body: SafeArea(
                child: selected != null
                    ? _pastSummary(selected, state)
                    : switch (state) {
                        EmployeeUpdateReady() => _Ready(
                          records: widget.history == null ? null : _records,
                          error: _historyLoadError,
                          onOpen: _openRecord,
                        ),
                        EmployeeUpdateInProgress() => _Progress(state: state),
                        EmployeeUpdateSuccess(
                          :final summary,
                          :final historyError,
                        ) =>
                          _Summary(
                            summary: summary,
                            historyError: historyError,
                            records: widget.history == null ? null : _records,
                            error: _historyLoadError,
                            onOpen: _openRecord,
                            onDone: () => _leave(state),
                          ),
                        EmployeeUpdateFailure(:final message) => _Failure(
                          message: message,
                        ),
                      },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pastSummary(
    EmployeeUpdateRecord selected,
    EmployeeUpdateState state,
  ) {
    return _Summary(
      summary: EmployeeUpdateSummary(
        previousCount: selected.previousCount,
        addedCount: selected.addedCount,
        removedCount: selected.removedCount,
        currentCount: selected.currentCount,
      ),
      when: selected.updatedAt,
      onDone: () => _back(state),
      doneLabel: 'กลับ',
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({this.records, this.error, this.onOpen});

  final List<EmployeeUpdateRecord>? records;
  final String? error;
  final ValueChanged<EmployeeUpdateRecord>? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final history = records;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ดึงข้อมูลล่าสุด',
            style: TextStyle(
              color: colors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ดึงชุดล่าสุดจากฐานข้อมูลมาแทนที่ข้อมูลในเครื่อง ใช้เวลาสักครู่ ถ้าดึงไม่สำเร็จ ข้อมูลเดิมยังอยู่',
            style: TextStyle(color: colors.muted, fontSize: 16, height: 1.4),
          ),
          if (history != null && onOpen != null) ...[
            const SizedBox(height: 24),
            Text(
              'ย้อนหลัง',
              style: TextStyle(
                color: colors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _HistoryList(
                records: history,
                error: error,
                onOpen: onOpen!,
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('employee-update-start'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.read<EmployeeUpdateCubit>().start(),
            child: const Text('อัปเดต'),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.summary,
    this.when,
    this.onDone,
    this.doneLabel = 'กลับไปค้นหา',
    this.records,
    this.error,
    this.onOpen,
    this.historyError,
  });

  final EmployeeUpdateSummary summary;
  final DateTime? when;
  final VoidCallback? onDone;
  final String doneLabel;
  final List<EmployeeUpdateRecord>? records;
  final String? error;
  final ValueChanged<EmployeeUpdateRecord>? onOpen;
  final String? historyError;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recordedAt = when;
    final history = records;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                Text(
                  'เทียบข้อมูลที่อัปเดต',
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  recordedAt == null
                      ? 'นับจากรหัสพนักงาน คนเดิมที่ยังอยู่ในชุดไม่นับเป็นคนใหม่'
                      : 'บันทึกเมื่อ ${updateHistoryWhen(recordedAt)} นับจากรหัสพนักงาน คนเดิมที่ยังอยู่ในชุดไม่นับเป็นคนใหม่',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                _CompareRow(
                  label: 'เดิมมีในเครื่อง',
                  value: summary.previousCount,
                  colors: colors,
                ),
                _CompareRow(
                  label: 'เพิ่มเข้ามา',
                  value: summary.addedCount,
                  colors: colors,
                  emphasize: true,
                ),
                _CompareRow(
                  label: 'ไม่อยู่ในชุดใหม่',
                  value: summary.removedCount,
                  colors: colors,
                ),
                _CompareRow(
                  label: 'ตอนนี้มีในเครื่อง',
                  value: summary.currentCount,
                  colors: colors,
                ),
                if (historyError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'บันทึกประวัติไม่สำเร็จ $historyError',
                    style: TextStyle(color: colors.idle, height: 1.4),
                  ),
                ],
                if (history != null && onOpen != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'ย้อนหลัง',
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _HistoryList(
                    records: history,
                    error: error,
                    onOpen: onOpen!,
                    scrollable: false,
                  ),
                ],
              ],
            ),
          ),
          if (onDone != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('employee-update-done'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onDone,
              child: Text(doneLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.records,
    required this.error,
    required this.onOpen,
    this.scrollable = true,
  });

  final List<EmployeeUpdateRecord> records;
  final String? error;
  final ValueChanged<EmployeeUpdateRecord> onOpen;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final message = error;
    if (message != null) {
      return Text(
        message,
        style: TextStyle(color: colors.ink, fontSize: 16, height: 1.4),
      );
    }
    if (records.isEmpty) {
      return Text(
        'ยังไม่มีประวัติ รายการจะถูกเก็บหลังอัปเดตสำเร็จ',
        style: TextStyle(color: colors.muted, fontSize: 16, height: 1.4),
      );
    }
    final tiles = [
      for (final record in records)
        ListTile(
          key: Key('employee-update-history-${record.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            updateHistoryWhen(record.updatedAt),
            style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'เพิ่ม ${groupDigits(record.addedCount)} · ออก ${groupDigits(record.removedCount)} · ตอนนี้ ${groupDigits(record.currentCount)}',
            style: TextStyle(color: colors.muted),
          ),
          trailing: Icon(Icons.chevron_right, color: colors.muted),
          onTap: () => onOpen(record),
        ),
    ];
    if (!scrollable) return Column(children: tiles);
    return ListView(children: tiles);
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.value,
    required this.colors,
    this.emphasize = false,
  });

  final String label;
  final int value;
  final AppColors colors;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.ink,
                fontSize: emphasize ? 18 : 16,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${groupDigits(value)} คน',
            style: TextStyle(
              color: emphasize ? colors.leaf : colors.ink,
              fontSize: emphasize ? 22 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
            decoration: BoxDecoration(
              color: AppColors.of(context).mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              downloading ? Icons.storage_outlined : Icons.inventory_2_outlined,
              color: AppColors.of(context).ink,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: AppColors.of(context).ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: TextStyle(
              color: AppColors.of(context).muted,
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
              backgroundColor: AppColors.of(context).line,
              color: AppColors.of(context).leaf,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            statusLine,
            style: TextStyle(
              color: AppColors.of(context).ink,
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
          Icon(
            Icons.error_outline,
            color: AppColors.of(context).idle,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'อัปเดตไม่สำเร็จ',
            style: TextStyle(
              color: AppColors.of(context).ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: AppColors.of(context).ink, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'ข้อมูลเดิมในเครื่องยังอยู่',
            style: TextStyle(color: AppColors.of(context).muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.of(context).ink,
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
