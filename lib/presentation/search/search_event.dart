import 'package:equatable/equatable.dart';

import '../../domain/entities/employee_status_filter.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();
}

class SearchOpened extends SearchEvent {
  const SearchOpened();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class SearchSubmitted extends SearchEvent {
  const SearchSubmitted();

  @override
  List<Object?> get props => [];
}

class SearchFiltersConfirmed extends SearchEvent {
  const SearchFiltersConfirmed({
    required this.status,
    required this.branchLabel,
  });

  final EmployeeStatusFilter status;
  final String? branchLabel;

  @override
  List<Object?> get props => [status, branchLabel];
}

class SearchHistoryChosen extends SearchEvent {
  const SearchHistoryChosen({
    required this.query,
    required this.status,
    required this.branchLabel,
  });

  final String query;
  final EmployeeStatusFilter status;
  final String? branchLabel;

  @override
  List<Object?> get props => [query, status, branchLabel];
}

class SearchHistoryDeleted extends SearchEvent {
  const SearchHistoryDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

class SearchNextPageRequested extends SearchEvent {
  const SearchNextPageRequested();

  @override
  List<Object?> get props => [];
}

class SearchRetryRequested extends SearchEvent {
  const SearchRetryRequested();

  @override
  List<Object?> get props => [];
}
