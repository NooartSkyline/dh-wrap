import '../repositories/employee_repository.dart';

class ListEmployeeBranches {
  const ListEmployeeBranches(this._repository);

  final EmployeeRepository _repository;

  Future<List<String>> call() => _repository.listBranches();
}
