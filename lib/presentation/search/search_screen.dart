import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
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
    if (!state.hasMore ||
        state.loadingMore ||
        state.view != SearchViewStatus.loaded) {
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
      SearchFiltersConfirmed(
        status: result.status,
        branchLabel: result.branchLabel,
      ),
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
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _SearchHeader(
            controller: _queryController,
            onFilter: _openFilters,
            onChanged: (value) {
              context.read<SearchBloc>().add(SearchQueryChanged(value));
            },
            onClear: () {
              _queryController.clear();
              context.read<SearchBloc>().add(const SearchQueryChanged(''));
            },
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
                    child: CircularProgressIndicator(color: AppColors.leaf),
                  ),
                  SearchViewStatus.empty => const _Message(
                    icon: Icons.search_off,
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
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.onFilter,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onFilter;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ค้นหาชื่อเจ้าเหมียว',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'สมุดรายชื่อเจ้าเหมียวในเครื่อง',
                          style: TextStyle(
                            color: Color(0xFFD5E7DE),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'ตัวกรอง',
                    onPressed: onFilter,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('employee-search-field'),
                controller: controller,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: AppColors.ink),
                cursorColor: AppColors.leaf,
                decoration: InputDecoration(
                  hintText: 'พิมพ์ชื่อ ชื่อเล่น หรือรหัสเจ้าเหมียว',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search, color: AppColors.leaf),
                  suffixIcon: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      if (controller.text.isEmpty)
                        return const SizedBox.shrink();
                      return IconButton(
                        tooltip: 'ล้างคำค้น',
                        onPressed: onClear,
                        icon: const Icon(Icons.close, color: AppColors.muted),
                      );
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: onChanged,
              ),
            ],
          ),
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
              avatar: const Icon(
                Icons.badge_outlined,
                size: 18,
                color: AppColors.leaf,
              ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 36,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            if (state.activeCountReady)
              Text(
                'เจ้าเหมียวที่ปฏิบัติงาน ${groupDigits(state.activeCount)} คน',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            const SizedBox(height: 8),
            Text(
              'พิมพ์ชื่อ ชื่อเล่น หรือรหัสเจ้าเหมียว หรือเลือกสาขา',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink),
            ),
          ],
        ),
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
            const Icon(Icons.error_outline, size: 40, color: AppColors.idle),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink),
            ),
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
      padding: const EdgeInsets.only(top: 4, bottom: 24),
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
