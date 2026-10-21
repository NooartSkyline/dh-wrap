import 'package:equatable/equatable.dart';

import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_status_filter.dart';

enum SearchViewStatus { idle, loading, loaded, empty, failure }

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.statusFilter = EmployeeStatusFilter.working,
    this.branchLabel,
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.view = SearchViewStatus.idle,
    this.errorMessage,
    this.loadMoreError,
    this.activeCount = 0,
    this.activeCountReady = false,
  });

  final String query;
  final EmployeeStatusFilter statusFilter;
  final String? branchLabel;
  final List<Employee> items;
  final bool hasMore;
  final bool loadingMore;
  final SearchViewStatus view;
  final String? errorMessage;
  final String? loadMoreError;
  final int activeCount;
  final bool activeCountReady;

  bool get canSearch {
    if (query.trim().isNotEmpty) return true;
    final branch = branchLabel?.trim();
    return branch != null && branch.isNotEmpty;
  }

  SearchState copyWith({
    String? query,
    EmployeeStatusFilter? statusFilter,
    String? branchLabel,
    bool clearBranch = false,
    List<Employee>? items,
    bool? hasMore,
    bool? loadingMore,
    SearchViewStatus? view,
    String? errorMessage,
    bool clearError = false,
    String? loadMoreError,
    bool clearLoadMoreError = false,
    int? activeCount,
    bool? activeCountReady,
  }) {
    return SearchState(
      query: query ?? this.query,
      statusFilter: statusFilter ?? this.statusFilter,
      branchLabel: clearBranch ? null : (branchLabel ?? this.branchLabel),
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      view: view ?? this.view,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
      activeCount: activeCount ?? this.activeCount,
      activeCountReady: activeCountReady ?? this.activeCountReady,
    );
  }

  @override
  List<Object?> get props => [
    query,
    statusFilter,
    branchLabel,
    items,
    hasMore,
    loadingMore,
    view,
    errorMessage,
    loadMoreError,
    activeCount,
    activeCountReady,
  ];
}
