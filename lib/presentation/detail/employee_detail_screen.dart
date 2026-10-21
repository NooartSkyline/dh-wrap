import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/employee.dart';
import '../search/employee_status_chip.dart';
import 'employee_detail_cubit.dart';
import 'employee_detail_state.dart';

class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key});

  static const routeName = '/employee';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลพนักงาน')),
      body: SafeArea(
        child: BlocBuilder<EmployeeDetailCubit, EmployeeDetailState>(
          builder: (context, state) {
            return switch (state) {
              EmployeeDetailLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              EmployeeDetailMissing() => const _DetailMessage(
                message: 'ไม่พบพนักงาน',
              ),
              EmployeeDetailFailure(:final message) => _DetailMessage(
                message: message,
                onRetry: () => context.read<EmployeeDetailCubit>().retry(),
              ),
              EmployeeDetailLoaded(:final employee) => _EmployeeBody(
                employee: employee,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmployeeBody extends StatelessWidget {
  const _EmployeeBody({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final english = employee.displayNameEn;
    final showEnglish =
        english.isNotEmpty &&
        english.toLowerCase() != employee.displayName.toLowerCase();
    final workRows = <_Fact>[
      _Fact('ตำแหน่ง', employee.positionDesc),
      _Fact('ประเภท', employee.employeeType),
      _Fact('บริษัท', employee.company),
      _Fact('สาขา', employee.branchLabel),
      _Fact('ธุรกิจ', employee.businessName),
      _Fact('ฝ่าย', employee.divisionHqName),
      _Fact('ฝ่ายสาขา', employee.divisionBranchName),
      _Fact('แผนก', employee.sectionName),
      _Fact('หน่วยงาน', employee.unitName),
      _Fact('หัวหน้า', employee.supervisor),
    ].where((fact) => fact.value.isNotEmpty).toList();
    final contactRows = <_Contact>[
      if (employee.mobilePhone.isNotEmpty)
        _Contact('มือถือ', employee.mobilePhone, _ContactKind.phone),
      if (employee.businessPhone.isNotEmpty)
        _Contact('โทรที่ทำงาน', employee.businessPhone, _ContactKind.phone),
      if (employee.emailCompany.isNotEmpty)
        _Contact('อีเมล', employee.emailCompany, _ContactKind.email),
    ];
    final dateRows = <_Fact>[
      if (employee.hireDate.isNotEmpty)
        _Fact('วันเริ่มงาน', employee.hireDateLabel),
      if (!employee.isWorking && employee.endDate.isNotEmpty)
        _Fact('วันสิ้นสุด', employee.endDateLabel),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(employee.initials),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.displayName, style: theme.textTheme.headlineSmall),
                  if (employee.nickName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(employee.nickName, style: theme.textTheme.titleMedium),
                  ],
                  if (showEnglish) ...[
                    const SizedBox(height: 4),
                    Text(
                      english,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(employee.personId, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EmployeeStatusChip(employee: employee),
          ],
        ),
        if (workRows.isNotEmpty) ...[
          const _SectionTitle('งาน'),
          for (final fact in workRows) _FactTile(fact: fact),
        ],
        if (contactRows.isNotEmpty) ...[
          const _SectionTitle('ติดต่อ'),
          for (final contact in contactRows) _ContactTile(contact: contact),
        ],
        if (dateRows.isNotEmpty) ...[
          const _SectionTitle('วันที่'),
          for (final fact in dateRows) _FactTile(fact: fact),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Fact {
  const _Fact(this.label, this.value);

  final String label;
  final String value;
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});

  final _Fact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              fact.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(fact.value)),
        ],
      ),
    );
  }
}

enum _ContactKind { phone, email }

class _Contact {
  const _Contact(this.label, this.value, this.kind);

  final String label;
  final String value;
  final _ContactKind kind;
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final _Contact contact;

  Future<void> _open(BuildContext context) async {
    final uri = switch (contact.kind) {
      _ContactKind.phone => Uri(
        scheme: 'tel',
        path: contact.value.replaceAll(RegExp(r'[\s-]'), ''),
      ),
      _ContactKind.email => Uri(scheme: 'mailto', path: contact.value.trim()),
    };
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!opened) {
        _showMessage(context, 'เปิดลิงก์ไม่สำเร็จ');
      }
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, error.toString());
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: _FactTile(fact: _Fact(contact.label, contact.value))),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
