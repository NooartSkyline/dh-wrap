import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/employee_status_filter.dart';

class EmployeeFilterResult extends Equatable {
  const EmployeeFilterResult({required this.status, required this.branchLabel});

  final EmployeeStatusFilter status;
  final String? branchLabel;

  @override
  List<Object?> get props => [status, branchLabel];
}

Future<EmployeeFilterResult?> showEmployeeFilterSheet({
  required BuildContext context,
  required EmployeeStatusFilter status,
  required String? branchLabel,
  required Future<List<String>> Function() loadBranches,
}) {
  return showModalBottomSheet<EmployeeFilterResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return EmployeeFilterSheet(
        initialStatus: status,
        initialBranch: branchLabel,
        loadBranches: loadBranches,
      );
    },
  );
}

class EmployeeFilterSheet extends StatefulWidget {
  const EmployeeFilterSheet({
    super.key,
    required this.initialStatus,
    required this.initialBranch,
    required this.loadBranches,
  });

  final EmployeeStatusFilter initialStatus;
  final String? initialBranch;
  final Future<List<String>> Function() loadBranches;

  @override
  State<EmployeeFilterSheet> createState() => _EmployeeFilterSheetState();
}

class _EmployeeFilterSheetState extends State<EmployeeFilterSheet> {
  late EmployeeStatusFilter _status;
  String? _branch;
  late final TextEditingController _branchQuery;
  late final Future<List<String>> _branches;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    final branch = widget.initialBranch?.trim();
    _branch = (branch == null || branch.isEmpty) ? null : branch;
    _branchQuery = TextEditingController();
    _branches = widget.loadBranches();
  }

  @override
  void dispose() {
    _branchQuery.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.pop(
      context,
      EmployeeFilterResult(status: _status, branchLabel: _branch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.86;
    final selectedBranch = _branch ?? 'ทุกสาขา';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'ตัวกรอง',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('employee-filter-close'),
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('สถานะ', style: theme.textTheme.titleSmall),
            ),
            RadioGroup<EmployeeStatusFilter>(
              groupValue: _status,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _status = value);
              },
              child: Column(
                children: [
                  for (final status in EmployeeStatusFilter.values)
                    RadioListTile<EmployeeStatusFilter>(
                      value: status,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(status.label),
                      selected: status == _status,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('สาขา', style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _branchQuery,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาสาขา',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'สาขาที่เลือก: $selectedBranch',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _branches,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(snapshot.error.toString()),
                    );
                  }
                  final branches = snapshot.data;
                  if (branches == null) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('โหลดรายชื่อสาขาไม่สำเร็จ'),
                    );
                  }
                  return _BranchList(
                    branches: branches,
                    query: _branchQuery.text,
                    selected: _branch,
                    onSelected: (value) => setState(() => _branch = value),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                key: const Key('employee-filter-confirm'),
                onPressed: _confirm,
                child: const Text('ยืนยัน'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchList extends StatelessWidget {
  const _BranchList({
    required this.branches,
    required this.query,
    required this.selected,
    required this.onSelected,
  });

  final List<String> branches;
  final String query;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim().toLowerCase();
    final visible = [
      for (final branch in branches)
        if (needle.isEmpty || branch.toLowerCase().contains(needle)) branch,
    ];
    return RadioGroup<String>(
      groupValue: selected ?? '',
      onChanged: (value) {
        if (value == null) return;
        onSelected(value.isEmpty ? null : value);
      },
      child: ListView.builder(
        itemCount: visible.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return RadioListTile<String>(
              value: '',
              dense: true,
              visualDensity: VisualDensity.compact,
              selected: selected == null,
              title: const Text('ทุกสาขา'),
            );
          }
          final branch = visible[index - 1];
          return RadioListTile<String>(
            value: branch,
            dense: true,
            visualDensity: VisualDensity.compact,
            selected: selected == branch,
            title: Text(branch, maxLines: 2, overflow: TextOverflow.ellipsis),
          );
        },
      ),
    );
  }
}
