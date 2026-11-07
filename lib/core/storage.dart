/// A folder where games are installed. Like Steam libraries, there can be one
/// on every drive; new games go to the default one unless the player picks.
class LibraryFolder {
  final String path;
  final bool isDefault, builtIn;
  final int games, bytes;

  /// Space on the drive, when the system reports it.
  final int? free, total;
  const LibraryFolder(
      {required this.path,
      this.isDefault = false,
      this.builtIn = false,
      this.games = 0,
      this.bytes = 0,
      this.free,
      this.total});

  /// "C:" for a Windows path.
  String get drive {
    final match = RegExp(r'^([A-Za-z]:)').firstMatch(path);
    return match == null ? path : match[1]!.toUpperCase();
  }
}

class Drive {
  /// "D:\".
  final String root;
  final String label;
  final int? free, total;
  const Drive({required this.root, this.label = '', this.free, this.total});
  String get name {
    final letter = root.replaceAll(r'\', '');
    return label.isEmpty ? 'Диск $letter' : '$label ($letter)';
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} КБ';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} ГБ';
}
