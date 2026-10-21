import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/employee.dart';

class EmployeeStatusChip extends StatelessWidget {
  const EmployeeStatusChip({super.key, required this.employee, this.onDark = false});

  final Employee employee;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final background = employee.isWorking ? AppColors.workingWash : AppColors.idleWash;
    final foreground = employee.isWorking ? AppColors.working : AppColors.idle;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.16) : background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: onDark ? Colors.white : foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              employee.statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: onDark ? Colors.white : foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
