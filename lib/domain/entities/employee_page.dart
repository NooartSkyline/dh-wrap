import 'package:equatable/equatable.dart';

import 'employee.dart';

class EmployeePage extends Equatable {
  const EmployeePage({required this.items, required this.hasMore});

  final List<Employee> items;
  final bool hasMore;

  @override
  List<Object?> get props => [items, hasMore];
}
