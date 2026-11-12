import '../../domain/entities/employee_status_filter.dart';
import '../../domain/entities/search_history_record.dart';
import '../db/app_database.dart';

class SearchHistoryStore {
  SearchHistoryStore(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const kept = 20;

  final AppDatabase _database;
  final DateTime Function() _now;

  Future<void> add({
    required String query,
    required EmployeeStatusFilter status,
    required String? branchLabel,
  }) async {
    final text = query.trim();
    final branch = branchLabel?.trim() ?? '';
    if (text.isEmpty && branch.isEmpty) return;
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.delete(
        'search_history',
        where: 'query_text = ? AND status = ? AND branch_label = ?',
        whereArgs: [text, status.name, branch],
      );
      await txn.insert('search_history', {
        'query_text': text,
        'status': status.name,
        'branch_label': branch,
        'searched_at': _stamp(_now()),
      });
      await txn.rawDelete(
        '''
        DELETE FROM search_history
        WHERE id NOT IN (
          SELECT id FROM search_history ORDER BY id DESC LIMIT ?
        )
      ''',
        [kept],
      );
    });
  }

  Future<void> delete(int id) async {
    final db = await _database.open();
    await db.delete('search_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SearchHistoryRecord>> list() async {
    final db = await _database.open();
    final rows = await db.query('search_history', orderBy: 'id DESC');
    return [for (final row in rows) _record(row)];
  }

  SearchHistoryRecord _record(Map<String, Object?> row) {
    final id = row['id'];
    final query = row['query_text'];
    final statusName = row['status'];
    final branch = row['branch_label'];
    final searchedAt = DateTime.tryParse('${row['searched_at']}');
    final status = EmployeeStatusFilter.values
        .where((item) => item.name == statusName)
        .firstOrNull;
    if (id is! int ||
        query is! String ||
        branch is! String ||
        status == null ||
        searchedAt == null) {
      throw const FormatException('ประวัติการค้นหาอ่านไม่ได้');
    }
    final label = branch.trim();
    return SearchHistoryRecord(
      id: id,
      query: query,
      status: status,
      branchLabel: label.isEmpty ? null : label,
      searchedAt: searchedAt,
    );
  }

  String _stamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    return '$year-${two(local.month)}-${two(local.day)}'
        'T${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
