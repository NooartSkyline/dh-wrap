import '../repositories/employee_repository.dart';

class ReadDataUpdatedAt {
  const ReadDataUpdatedAt(this._repository);

  final EmployeeRepository _repository;

  Future<DateTime?> call() => _repository.dataUpdatedAt();
}
