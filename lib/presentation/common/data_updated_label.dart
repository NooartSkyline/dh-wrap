String? dataUpdatedLabel(DateTime? value) {
  if (value == null) return null;
  return 'อัปเดตล่าสุด ${updateHistoryWhen(value)}';
}

String updateHistoryWhen(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
