import 'package:equatable/equatable.dart';

enum EmployeeUpdatePhase { download, save }

sealed class EmployeeUpdateState extends Equatable {
  const EmployeeUpdateState();
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
  const EmployeeUpdateSuccess(this.count);

  final int count;

  @override
  List<Object?> get props => [count];
}

class EmployeeUpdateFailure extends EmployeeUpdateState {
  const EmployeeUpdateFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
