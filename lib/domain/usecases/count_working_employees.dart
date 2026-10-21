import '../repositories/employee_repository.dart';

class CountWorkingEmployees {
  const CountWorkingEmployees(this._repository);

  final EmployeeRepository _repository;

  Future<int> call() => _repository.countWorking();
}
