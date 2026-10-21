String errorText(Object error) {
  if (error is FormatException) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return error.toString();
}
