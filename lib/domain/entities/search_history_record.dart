import 'employee_status_filter.dart';

class SearchHistoryRecord {
  const SearchHistoryRecord({
    required this.id,
    required this.query,
    required this.status,
    required this.branchLabel,
    required this.searchedAt,
  });

  final int id;
  final String query;
  final EmployeeStatusFilter status;
  final String? branchLabel;
  final DateTime searchedAt;
}
