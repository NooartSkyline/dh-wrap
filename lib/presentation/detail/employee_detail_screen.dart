import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/employee.dart';
import '../search/employee_status_chip.dart';
import 'employee_detail_cubit.dart';
import 'employee_detail_state.dart';

class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key});

  static const routeName = '/employee';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeeDetailCubit, EmployeeDetailState>(
      builder: (context, state) {
        return switch (state) {
          EmployeeDetailLoading() => const _PlainScaffold(
            child: Center(child: CircularProgressIndicator(color: AppColors.leaf)),
          ),
          EmployeeDetailMissing() => const _PlainScaffold(
            child: _DetailMessage(message: 'ไม่พบพนักงาน'),
          ),
          EmployeeDetailFailure(:final message) => _PlainScaffold(
            child: _DetailMessage(
              message: message,
              onRetry: () => context.read<EmployeeDetailCubit>().retry(),
            ),
          ),
          EmployeeDetailLoaded(:final employee) => _EmployeeBody(employee: employee),
        };
      },
    );
  }
}

class _PlainScaffold extends StatelessWidget {
  const _PlainScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('ข้อมูลพนักงาน')),
      body: SafeArea(child: child),
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('ข้อมูลพนักงาน')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ProfileCard(employee: employee, english: showEnglish ? english : ''),
          if (workRows.isNotEmpty)
            _SectionCard(
              title: 'งาน',
              icon: Icons.work_outline,
              children: [for (final fact in workRows) _FactTile(fact: fact)],
            ),
          if (contactRows.isNotEmpty)
            _SectionCard(
              title: 'ติดต่อ',
              icon: Icons.forum_outlined,
              children: [for (final contact in contactRows) _ContactTile(contact: contact)],
            ),
          if (dateRows.isNotEmpty)
            _SectionCard(
              title: 'วันที่',
              icon: Icons.event_outlined,
              children: [for (final fact in dateRows) _FactTile(fact: fact)],
            ),
        ],
      ),
    );
  }
}

String _thaiName(Employee employee) {
  return Employee.joinName(employee.firstName, employee.lastName);
}

class _CopyLine extends StatelessWidget {
  const _CopyLine({
    required this.text,
    required this.tooltip,
    required this.style,
    required this.onDark,
  });

  final String text;
  final String tooltip;
  final TextStyle style;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(text, style: style)),
        _CopyButton(value: text, tooltip: tooltip, onDark: onDark),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value, required this.tooltip, this.onDark = false});

  final String value;
  final String tooltip;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : AppColors.leaf;
    return IconButton(
      tooltip: 'คัดลอก$tooltip',
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: color,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('คัดลอก$tooltipแล้ว')));
      },
      icon: const Icon(Icons.copy, size: 18),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.employee, required this.english});

  final Employee employee;
  final String english;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              employee.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_thaiName(employee).isEmpty &&
              english.isEmpty &&
              employee.displayName == employee.personId)
            Text(
              employee.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            )
          else
            _CopyLine(
              text: employee.displayName,
              tooltip: _thaiName(employee).isNotEmpty ? 'ชื่อไทย' : 'ชื่ออังกฤษ',
              onDark: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          if (employee.nickName.isNotEmpty)
            _CopyLine(
              text: employee.nickName,
              tooltip: 'ชื่อเล่น',
              onDark: true,
              style: const TextStyle(
                color: Color(0xFFB7E4C7),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (english.isNotEmpty)
            _CopyLine(
              text: english,
              tooltip: 'ชื่ออังกฤษ',
              onDark: true,
              style: const TextStyle(color: Color(0xFFD5E7DE), fontSize: 14),
            ),
          _CopyLine(
            text: employee.personId,
            tooltip: 'รหัสพนักงาน',
            onDark: true,
            style: const TextStyle(color: Color(0xFFD5E7DE)),
          ),
          const SizedBox(height: 12),
          EmployeeStatusChip(employee: employee, onDark: true),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.leaf),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
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
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              fact.value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
    final icon = switch (contact.kind) {
      _ContactKind.phone => Icons.call_outlined,
      _ContactKind.email => Icons.mail_outline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _open(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 18, color: AppColors.leaf),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _FactTile(fact: _Fact(contact.label, contact.value))),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
          if (contact.kind == _ContactKind.phone)
            _CopyButton(value: contact.value, tooltip: 'เบอร์โทร'),
        ],
      ),
    );
  }
}
