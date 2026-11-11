abstract class EmployeeSnapshotSource {
  Future<String> download({
    required void Function(int received, int? total) onProgress,
  });
}
