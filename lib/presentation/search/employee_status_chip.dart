import 'package:flutter/material.dart';

import '../../domain/entities/employee.dart';

class EmployeeStatusChip extends StatelessWidget {
  const EmployeeStatusChip({super.key, required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = employee.isWorking
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = employee.isWorking
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          employee.statusLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
          ),
        ),
      ),
    );
  }
}
