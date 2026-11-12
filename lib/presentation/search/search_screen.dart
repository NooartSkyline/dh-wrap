import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/sync/employee_database.dart';
import '../../data/sync/employee_snapshot_source.dart';
import '../../data/update/update_history_store.dart';
import '../../data/usage/usage_hint_store.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/search_history_record.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/usecases/import_employees.dart';
import '../../domain/usecases/list_employee_ids.dart';
import '../common/data_updated_label.dart';
import '../common/group_digits.dart';
import '../detail/employee_detail_screen.dart';
import '../update/employee_update_cubit.dart';
import '../update/employee_update_screen.dart';
import 'employee_card.dart';
import 'employee_filter_sheet.dart';
import 'search_bloc.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.snapshotSource,
    this.usageHints,
    this.updateHistory,
  });

  final EmployeeSnapshotSource? snapshotSource;
  final UsageHints? usageHints;
  final UpdateHistoryStore? updateHistory;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  var _showUsageHint = false;
  var _applyingQuery = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    context.read<SearchBloc>().add(const SearchOpened());
    _loadUsageHint();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadUsageHint() async {
    final hints = widget.usageHints;
    if (hints == null) return;
    final seen = await hints.seen();
    if (!mounted || seen) return;
    setState(() => _showUsageHint = true);
  }

  Future<void> _dismissUsageHint() async {
    final hints = widget.usageHints;
    if (hints == null) return;
    try {
      await hints.markSeen();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText(error))));
      return;
    }
    if (!mounted) return;
    setState(() => _showUsageHint = false);
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

  Future<void> _openUpdate() async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (routeContext) => BlocProvider(
          create: (_) => EmployeeUpdateCubit(
            widget.snapshotSource ?? const EmployeeDatabaseSnapshot(),
            ImportEmployees(routeContext.read<EmployeeRepository>()),
            ListEmployeeIds(routeContext.read<EmployeeRepository>()),
            history: widget.updateHistory,
          ),
          child: EmployeeUpdateScreen(history: widget.updateHistory),
        ),
      ),
    );
    if (!mounted || count == null) return;
    final bloc = context.read<SearchBloc>();
    bloc.add(const SearchOpened());
    if (bloc.state.canSearch) {
      bloc.add(const SearchSubmitted());
    }
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
      backgroundColor: AppColors.of(context).canvas,
      body: Column(
        children: [
          _SearchHeader(
            controller: _queryController,
            onFilter: _openFilters,
            onUpdate: _openUpdate,
            onChanged: (value) {
              if (_applyingQuery) return;
              context.read<SearchBloc>().add(SearchQueryChanged(value));
            },
            onClear: () {
              _queryController.clear();
              context.read<SearchBloc>().add(const SearchQueryChanged(''));
            },
          ),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    BlocBuilder<SearchBloc, SearchState>(
                      buildWhen: (previous, current) =>
                          previous.statusFilter != current.statusFilter ||
                          previous.branchLabel != current.branchLabel,
                      builder: (context, state) {
                        return _FilterChips(
                          state: state,
                          onPressed: _openFilters,
                        );
                      },
                    ),
                    Expanded(
                      child: BlocConsumer<SearchBloc, SearchState>(
                        listener: (context, state) {
                          if (_queryController.text != state.query) {
                            _applyingQuery = true;
                            _queryController.value = TextEditingValue(
                              text: state.query,
                              selection: TextSelection.collapsed(
                                offset: state.query.length,
                              ),
                            );
                            _applyingQuery = false;
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _maybeLoadMore();
                          });
                        },
                        builder: (context, state) {
                          return switch (state.view) {
                            SearchViewStatus.idle => _Idle(
                              state: state,
                              onSelect: (record) {
                                context.read<SearchBloc>().add(
                                  SearchHistoryChosen(
                                    query: record.query,
                                    status: record.status,
                                    branchLabel: record.branchLabel,
                                  ),
                                );
                              },
                              onDelete: (record) {
                                context.read<SearchBloc>().add(
                                  SearchHistoryDeleted(record.id),
                                );
                              },
                            ),
                            SearchViewStatus.loading => Center(
                              child: CircularProgressIndicator(
                                color: AppColors.of(context).leaf,
                              ),
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
                if (_showUsageHint)
                  Positioned.fill(
                    child: _UsageHint(onDismiss: _dismissUsageHint),
                  ),
              ],
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
    required this.onUpdate,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onFilter;
  final VoidCallback onUpdate;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.of(context).ink,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ค้นหา',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'สมุดรายชื่อ',
                          style: TextStyle(
                            color: AppColors.of(context).onInkMuted,
                            fontSize: 14,
                          ),
                        ),
                        BlocBuilder<SearchBloc, SearchState>(
                          buildWhen: (previous, current) =>
                              previous.dataUpdatedAt != current.dataUpdatedAt,
                          builder: (context, state) {
                            final label = dataUpdatedLabel(state.dataUpdatedAt);
                            if (label == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                label,
                                key: const Key('employee-data-updated-at'),
                                style: TextStyle(
                                  color: AppColors.of(context).onInkMuted,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('employee-update-button'),
                    onPressed: onUpdate,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 40),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'อัปเดต',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('employee-search-field'),
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: AppColors.of(context).ink),
                      cursorColor: AppColors.of(context).leaf,
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ชื่อ ชื่อเล่น หรือรหัส',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.of(context).leaf,
                        ),
                        suffixIcon: ListenableBuilder(
                          listenable: controller,
                          builder: (context, _) {
                            if (controller.text.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              tooltip: 'ล้างคำค้น',
                              onPressed: onClear,
                              icon: Icon(
                                Icons.close,
                                color: AppColors.of(context).muted,
                              ),
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
                  ),
                  const SizedBox(width: 8),
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
              avatar: Icon(
                Icons.badge_outlined,
                size: 18,
                color: AppColors.of(context).leaf,
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
  const _Idle({
    required this.state,
    required this.onSelect,
    required this.onDelete,
  });

  final SearchState state;
  final ValueChanged<SearchHistoryRecord> onSelect;
  final ValueChanged<SearchHistoryRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final history = state.searchHistory;
    final historyError = state.searchHistoryError;
    if (history.isEmpty && historyError == null) {
      return Center(child: _IdleHint(state: state));
    }
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      children: [
        _IdleHint(state: state),
        if (historyError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              historyError,
              style: TextStyle(color: colors.idle, height: 1.4),
            ),
          ),
        if (history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'ค้นหาล่าสุด',
              style: TextStyle(
                color: colors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final record in history)
            ListTile(
              key: Key('search-history-${record.id}'),
              leading: Icon(Icons.history, color: colors.muted),
              title: Text(
                _historyTitle(record),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                _historySubtitle(record),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.muted),
              ),
              trailing: IconButton(
                key: Key('search-history-delete-${record.id}'),
                tooltip: 'ลบ',
                onPressed: () => onDelete(record),
                icon: Icon(Icons.delete_outline, color: colors.muted),
              ),
              onTap: () => onSelect(record),
            ),
        ],
      ],
    );
  }

  String _historyTitle(SearchHistoryRecord record) {
    final query = record.query.trim();
    if (query.isNotEmpty) return query;
    return record.branchLabel ?? '';
  }

  String _historySubtitle(SearchHistoryRecord record) {
    final parts = <String>[record.status.label];
    final branch = record.branchLabel?.trim();
    if (record.query.trim().isNotEmpty && branch != null && branch.isNotEmpty) {
      parts.add(branch);
    }
    parts.add(updateHistoryWhen(record.searchedAt));
    return parts.join(' · ');
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.of(context).mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_outlined,
              size: 36,
              color: AppColors.of(context).ink,
            ),
          ),
          const SizedBox(height: 20),
          if (state.activeCountReady)
            Text(
              'ที่ปฏิบัติงาน ${groupDigits(state.activeCount)} คน',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          const SizedBox(height: 8),
          Text(
            'พิมพ์ชื่อ ชื่อเล่น หรือรหัส หรือเลือกสาขา',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.of(context).muted,
              height: 1.4,
            ),
          ),
        ],
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
            Icon(icon, size: 40, color: AppColors.of(context).muted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).ink),
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
            Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.of(context).idle,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).ink),
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

class _UsageHint extends StatelessWidget {
  const _UsageHint({required this.onDismiss});

  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.38),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(18, 10),
                  painter: _HintCaretPainter(colors.ink),
                ),
                Material(
                  color: colors.ink,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'วิธีใช้งาน',
                          key: Key('employee-usage-hint'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'พิมพ์ชื่อ ชื่อเล่น หรือรหัสในช่องค้นหา\n'
                          'กดอัปเดตมุมบนขวา เพื่อดึงข้อมูลล่าสุดและดูสรุปในหน้าเดียวกัน เปลี่ยนสีธีมได้ที่มุมบนขวาของหน้านั้น\n'
                          'แตะชื่อเพื่อดูรายละเอียด\n'
                          'กดตัวกรองขวาสุดของช่องค้นหา เพื่อเลือกสถานะหรือสาขา',
                          style: TextStyle(
                            color: colors.onInkMuted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const Key('employee-usage-hint-dismiss'),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.ink,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              minimumSize: const Size(0, 36),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: onDismiss,
                            child: const Text(
                              'เข้าใจแล้ว',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintCaretPainter extends CustomPainter {
  const _HintCaretPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HintCaretPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
