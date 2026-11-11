String? dataUpdatedLabel(DateTime? value) {
  if (value == null) return null;
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return 'อัปเดตล่าสุด ${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
