import '../entities/employee.dart';
import '../entities/employee_page.dart';
import '../entities/employee_search_query.dart';

abstract class EmployeeRepository {
  Future<bool> isImported();

  Future<DateTime?> dataUpdatedAt();

  Future<int> importCsv(
    String csvText, {
    required void Function(int done, int total) onProgress,
  });

  Future<EmployeePage> search(EmployeeSearchQuery query);

  Future<Employee?> findById(String personId);

  Future<int> countWorking();

  Future<Set<String>> listPersonIds();

  Future<List<String>> listBranches();
}
