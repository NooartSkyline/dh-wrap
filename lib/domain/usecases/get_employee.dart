import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class GetEmployee {
  const GetEmployee(this._repository);

  final EmployeeRepository _repository;

  Future<Employee?> call(String personId) {
    return _repository.findById(personId);
  }
}
