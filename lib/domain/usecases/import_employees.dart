import '../repositories/employee_repository.dart';

class ImportEmployees {
  const ImportEmployees(this._repository);

  final EmployeeRepository _repository;

  Future<int> call(
    String csvText, {
    required void Function(int done, int total) onProgress,
  }) {
    return _repository.importCsv(csvText, onProgress: onProgress);
  }
}
