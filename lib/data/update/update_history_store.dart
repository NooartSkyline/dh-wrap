import '../../domain/entities/employee_update_record.dart';
import '../db/app_database.dart';

class UpdateHistoryStore {
  UpdateHistoryStore(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _now;

  Future<void> add({
    required int previousCount,
    required int addedCount,
    required int removedCount,
    required int currentCount,
  }) async {
    final db = await _database.open();
    await db.insert('update_history', {
      'updated_at': _stamp(_now()),
      'previous_count': previousCount,
      'added_count': addedCount,
      'removed_count': removedCount,
      'current_count': currentCount,
    });
  }

  Future<List<EmployeeUpdateRecord>> list() async {
    final db = await _database.open();
    final rows = await db.query('update_history', orderBy: 'id DESC');
    return [for (final row in rows) _record(row)];
  }

  EmployeeUpdateRecord _record(Map<String, Object?> row) {
    final id = row['id'];
    final updatedAt = DateTime.tryParse('${row['updated_at']}');
    final previous = row['previous_count'];
    final added = row['added_count'];
    final removed = row['removed_count'];
    final current = row['current_count'];
    if (id is! int ||
        updatedAt == null ||
        previous is! int ||
        added is! int ||
        removed is! int ||
        current is! int) {
      throw const FormatException('ประวัติการอัปเดตอ่านไม่ได้');
    }
    return EmployeeUpdateRecord(
      id: id,
      updatedAt: updatedAt,
      previousCount: previous,
      addedCount: added,
      removedCount: removed,
      currentCount: current,
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
