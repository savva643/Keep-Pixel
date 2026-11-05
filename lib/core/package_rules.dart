// Use Windows rules on every host so archive verification is testable on Linux.
String safePackagePath(String raw) {
  final value = raw.replaceAll('\\', '/');
  final parts = value.endsWith('/')
      ? value.substring(0, value.length - 1).split('/')
      : value.split('/');
  if (value.isEmpty ||
      value.length > 240 ||
      parts.any((p) =>
          p.isEmpty ||
          p == '.' ||
          p == '..' ||
          RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(p) ||
          p.endsWith('.') ||
          p.endsWith(' ') ||
          RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)',
                  caseSensitive: false)
              .hasMatch(p))) {
    throw const FormatException('Небезопасный путь в игровом архиве');
  }
  return parts.join('/');
}
