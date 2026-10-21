import 'package:equatable/equatable.dart';

import '../../domain/entities/employee.dart';

sealed class EmployeeDetailState extends Equatable {
  const EmployeeDetailState();
}

class EmployeeDetailLoading extends EmployeeDetailState {
  const EmployeeDetailLoading();

  @override
  List<Object?> get props => [];
}

class EmployeeDetailLoaded extends EmployeeDetailState {
  const EmployeeDetailLoaded(this.employee);

  final Employee employee;

  @override
  List<Object?> get props => [employee];
}

class EmployeeDetailMissing extends EmployeeDetailState {
  const EmployeeDetailMissing();

  @override
  List<Object?> get props => [];
}

class EmployeeDetailFailure extends EmployeeDetailState {
  const EmployeeDetailFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
