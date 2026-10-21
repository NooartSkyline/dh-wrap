import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/employee.dart';
import '../common/group_digits.dart';
import '../detail/employee_detail_screen.dart';
import 'employee_card.dart';
import 'employee_filter_sheet.dart';
import 'search_bloc.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    context.read<SearchBloc>().add(const SearchOpened());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!mounted || !_scrollController.hasClients) return;
    final bloc = context.read<SearchBloc>();
    final state = bloc.state;
    if (!state.hasMore || state.loadingMore || state.view != SearchViewStatus.loaded) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      bloc.add(const SearchNextPageRequested());
    }
  }

  Future<void> _openFilters() async {
    final bloc = context.read<SearchBloc>();
    final current = bloc.state;
    final result = await showEmployeeFilterSheet(
      context: context,
      status: current.statusFilter,
      branchLabel: current.branchLabel,
      loadBranches: bloc.loadBranches,
    );
    if (!mounted || result == null) return;
    bloc.add(
      SearchFiltersConfirmed(status: result.status, branchLabel: result.branchLabel),
    );
  }

  void _openEmployee(Employee employee) {
    Navigator.pushNamed(
      context,
      EmployeeDetailScreen.routeName,
      arguments: employee.personId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาพนักงาน'),
        actions: [
          IconButton(
            tooltip: 'ตัวกรอง',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const Key('employee-search-field'),
                controller: _queryController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'พิมพ์ชื่อ ชื่อเล่น หรือรหัสพนักงาน',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ListenableBuilder(
                    listenable: _queryController,
                    builder: (context, _) {
                      if (_queryController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        tooltip: 'ล้างคำค้น',
                        onPressed: () {
                          _queryController.clear();
                          context.read<SearchBloc>().add(const SearchQueryChanged(''));
                        },
                        icon: const Icon(Icons.close),
                      );
                    },
                  ),
                ),
                onChanged: (value) {
                  context.read<SearchBloc>().add(SearchQueryChanged(value));
                },
              ),
            ),
            BlocBuilder<SearchBloc, SearchState>(
              buildWhen: (previous, current) =>
                  previous.statusFilter != current.statusFilter ||
                  previous.branchLabel != current.branchLabel,
              builder: (context, state) {
                return _FilterChips(state: state, onPressed: _openFilters);
              },
            ),
            Expanded(
              child: BlocConsumer<SearchBloc, SearchState>(
                listener: (context, state) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _maybeLoadMore();
                  });
                },
                builder: (context, state) {
                  return switch (state.view) {
                    SearchViewStatus.idle => _Idle(state: state),
                    SearchViewStatus.loading => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    SearchViewStatus.empty => const _Message(
                      text: 'ไม่พบพนักงานตามเงื่อนไข',
                    ),
                    SearchViewStatus.failure => _Failure(
                      message: state.errorMessage ?? 'ค้นหาไม่สำเร็จ',
                    ),
                    SearchViewStatus.loaded => _Results(
                      state: state,
                      controller: _scrollController,
                      onTap: _openEmployee,
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state, required this.onPressed});

  final SearchState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final branch = state.branchLabel;
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            ActionChip(
              label: Text(state.statusFilter.label),
              onPressed: onPressed,
            ),
            if (branch != null && branch.isNotEmpty) ...[
              const SizedBox(width: 8),
              ActionChip(
                onPressed: onPressed,
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    branch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (state.activeCountReady)
          Text(
            'พนักงานที่ปฏิบัติงาน ${groupDigits(state.activeCount)} คน',
            style: theme.textTheme.titleMedium,
          ),
        const SizedBox(height: 8),
        Text(
          'พิมพ์ชื่อ ชื่อเล่น หรือรหัสพนักงาน หรือเลือกสาขา',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('employee-search-retry'),
              onPressed: () {
                context.read<SearchBloc>().add(const SearchRetryRequested());
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.state,
    required this.controller,
    required this.onTap,
  });

  final SearchState state;
  final ScrollController controller;
  final ValueChanged<Employee> onTap;

  @override
  Widget build(BuildContext context) {
    final showFooter =
        state.hasMore || state.loadingMore || state.loadMoreError != null;
    return ListView.builder(
      controller: controller,
      itemCount: state.items.length + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return _LoadMoreFooter(state: state);
        }
        final employee = state.items[index];
        return EmployeeCard(
          key: ValueKey(employee.personId),
          employee: employee,
          onTap: () => onTap(employee),
        );
      },
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final error = state.loadMoreError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                context.read<SearchBloc>().add(const SearchNextPageRequested());
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox(height: 24);
  }
}
