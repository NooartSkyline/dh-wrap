class EmployeeUpdateRecord {
  const EmployeeUpdateRecord({
    required this.id,
    required this.updatedAt,
    required this.previousCount,
    required this.addedCount,
    required this.removedCount,
    required this.currentCount,
  });

  final int id;
  final DateTime updatedAt;
  final int previousCount;
  final int addedCount;
  final int removedCount;
  final int currentCount;
}
