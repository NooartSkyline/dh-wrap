import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error_text.dart';
import '../../domain/entities/employee_search_query.dart';
import '../../domain/usecases/count_working_employees.dart';
import '../../domain/usecases/list_employee_branches.dart';
import '../../domain/usecases/search_employees.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required SearchEmployees searchEmployees,
    required CountWorkingEmployees countWorkingEmployees,
    required ListEmployeeBranches listEmployeeBranches,
    this.debounce = const Duration(milliseconds: 300),
  }) : _searchEmployees = searchEmployees,
       _countWorkingEmployees = countWorkingEmployees,
       _listEmployeeBranches = listEmployeeBranches,
       super(const SearchState()) {
    on<SearchOpened>(_onOpened);
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchSubmitted>(_onSubmitted);
    on<SearchFiltersConfirmed>(_onFiltersConfirmed);
    on<SearchNextPageRequested>(_onNextPage);
    on<SearchRetryRequested>(_onRetry);
  }

  final SearchEmployees _searchEmployees;
  final CountWorkingEmployees _countWorkingEmployees;
  final ListEmployeeBranches _listEmployeeBranches;
  final Duration debounce;

  Timer? _debounce;
  int _requestId = 0;
  int _countRequestId = 0;

  Future<List<String>> loadBranches() => _listEmployeeBranches();

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> _onOpened(SearchOpened event, Emitter<SearchState> emit) async {
    final requestId = ++_countRequestId;
    try {
      final count = await _countWorkingEmployees();
      if (isClosed || requestId != _countRequestId) return;
      emit(state.copyWith(activeCount: count, activeCountReady: true));
    } catch (error) {
      if (isClosed || requestId != _countRequestId) return;
      if (state.view == SearchViewStatus.idle &&
          state.items.isEmpty &&
          state.query.trim().isEmpty) {
        emit(
          state.copyWith(
            view: SearchViewStatus.failure,
            errorMessage: errorText(error),
          ),
        );
      }
    }
  }

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    _debounce?.cancel();
    _requestId++;
    final next = state.copyWith(
      query: event.query,
      loadingMore: false,
      clearLoadMoreError: true,
    );
    if (!next.canSearch) {
      emit(
        next.copyWith(
          view: SearchViewStatus.idle,
          items: const [],
          hasMore: false,
          clearError: true,
        ),
      );
      return;
    }
    emit(next);
    _debounce = Timer(debounce, () {
      if (!isClosed) add(const SearchSubmitted());
    });
  }

  Future<void> _onSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    await _runSearch(emit, reset: true);
  }

  Future<void> _onFiltersConfirmed(
    SearchFiltersConfirmed event,
    Emitter<SearchState> emit,
  ) async {
    _debounce?.cancel();
    _requestId++;
    final branch = event.branchLabel?.trim();
    final clearBranch = branch == null || branch.isEmpty;
    emit(
      state.copyWith(
        statusFilter: event.status,
        branchLabel: clearBranch ? null : branch,
        clearBranch: clearBranch,
        loadingMore: false,
        clearLoadMoreError: true,
      ),
    );
    await _runSearch(emit, reset: true);
  }

  Future<void> _onNextPage(
    SearchNextPageRequested event,
    Emitter<SearchState> emit,
  ) async {
    if (state.loadingMore ||
        state.view != SearchViewStatus.loaded ||
        !state.hasMore) {
      return;
    }
    await _runSearch(emit, reset: false);
  }

  Future<void> _onRetry(
    SearchRetryRequested event,
    Emitter<SearchState> emit,
  ) async {
    if (state.canSearch) {
      await _runSearch(emit, reset: true);
      return;
    }
    emit(
      state.copyWith(
        view: SearchViewStatus.idle,
        clearError: true,
        items: const [],
        hasMore: false,
      ),
    );
    await _onOpened(const SearchOpened(), emit);
  }

  Future<void> _runSearch(
    Emitter<SearchState> emit, {
    required bool reset,
  }) async {
    if (!state.canSearch) {
      emit(
        state.copyWith(
          view: SearchViewStatus.idle,
          items: const [],
          hasMore: false,
          loadingMore: false,
          clearError: true,
          clearLoadMoreError: true,
        ),
      );
      return;
    }

    final requestId = ++_requestId;
    final offset = reset ? 0 : state.items.length;
    final query = EmployeeSearchQuery(
      text: state.query,
      status: state.statusFilter,
      branchLabel: state.branchLabel,
      offset: offset,
      limit: SearchEmployees.pageSize,
    );

    if (reset) {
      emit(
        state.copyWith(
          view: SearchViewStatus.loading,
          items: const [],
          hasMore: false,
          loadingMore: false,
          clearError: true,
          clearLoadMoreError: true,
        ),
      );
    } else {
      emit(state.copyWith(loadingMore: true, clearLoadMoreError: true));
    }

    try {
      final page = await _searchEmployees(query);
      if (isClosed || requestId != _requestId) return;
      final items = reset ? page.items : [...state.items, ...page.items];
      emit(
        state.copyWith(
          items: items,
          hasMore: page.hasMore,
          loadingMore: false,
          view: items.isEmpty ? SearchViewStatus.empty : SearchViewStatus.loaded,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed || requestId != _requestId) return;
      if (reset) {
        emit(
          state.copyWith(
            view: SearchViewStatus.failure,
            errorMessage: errorText(error),
            loadingMore: false,
            items: const [],
            hasMore: false,
          ),
        );
        return;
      }
      emit(
        state.copyWith(loadingMore: false, loadMoreError: errorText(error)),
      );
    }
  }
}
