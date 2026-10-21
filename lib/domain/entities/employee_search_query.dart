import 'package:equatable/equatable.dart';

import 'employee_status_filter.dart';

class EmployeeSearchQuery extends Equatable {
  const EmployeeSearchQuery({
    required this.text,
    required this.status,
    required this.branchLabel,
    required this.offset,
    required this.limit,
  });

  final String text;
  final EmployeeStatusFilter status;
  final String? branchLabel;
  final int offset;
  final int limit;

  @override
  List<Object?> get props => [text, status, branchLabel, offset, limit];
}
