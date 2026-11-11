import '../repositories/employee_repository.dart';

class ListEmployeeIds {
  const ListEmployeeIds(this._repository);

  final EmployeeRepository _repository;

  Future<Set<String>> call() => _repository.listPersonIds();
}
