import 'package:equatable/equatable.dart';

enum EmployeeUpdatePhase { download, save }

sealed class EmployeeUpdateState extends Equatable {
  const EmployeeUpdateState();
}

class EmployeeUpdateReady extends EmployeeUpdateState {
  const EmployeeUpdateReady();

  @override
  List<Object?> get props => [];
}

class EmployeeUpdateInProgress extends EmployeeUpdateState {
  const EmployeeUpdateInProgress({
    required this.phase,
    required this.done,
    required this.total,
  });

  final EmployeeUpdatePhase phase;
  final int done;
  final int total;

  double? get progress {
    if (total <= 0) return null;
    final value = done / total;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  @override
  List<Object?> get props => [phase, done, total];
}

class EmployeeUpdateSuccess extends EmployeeUpdateState {
  const EmployeeUpdateSuccess(this.summary, {this.historyError});

  final EmployeeUpdateSummary summary;
  final String? historyError;

  @override
  List<Object?> get props => [summary, historyError];
}

class EmployeeUpdateSummary extends Equatable {
  const EmployeeUpdateSummary({
    required this.previousCount,
    required this.addedCount,
    required this.removedCount,
    required this.currentCount,
  });

  final int previousCount;
  final int addedCount;
  final int removedCount;
  final int currentCount;

  @override
  List<Object?> get props => [
    previousCount,
    addedCount,
    removedCount,
    currentCount,
  ];
}

EmployeeUpdateSummary compareEmployeeIds(
  Set<String> before,
  Set<String> after,
) {
  return EmployeeUpdateSummary(
    previousCount: before.length,
    addedCount: after.difference(before).length,
    removedCount: before.difference(after).length,
    currentCount: after.length,
  );
}

class EmployeeUpdateFailure extends EmployeeUpdateState {
  const EmployeeUpdateFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
