import '../entities/employee_page.dart';
import '../entities/employee_search_query.dart';
import '../repositories/employee_repository.dart';

class SearchEmployees {
  const SearchEmployees(this._repository);

  static const pageSize = 30;

  final EmployeeRepository _repository;

  Future<EmployeePage> call(EmployeeSearchQuery query) {
    return _repository.search(query);
  }
}
