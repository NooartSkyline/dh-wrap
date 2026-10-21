import '../repositories/employee_repository.dart';

class IsEmployeeDataImported {
  const IsEmployeeDataImported(this._repository);

  final EmployeeRepository _repository;

  Future<bool> call() => _repository.isImported();
}
