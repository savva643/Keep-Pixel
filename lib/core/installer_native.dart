import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:keep_pixel/core/package_rules.dart';
import 'package:keep_pixel/core/storage.dart';

export 'storage.dart';

// Game ids become folder names: digits or a UUID, never a path.
final _safeId = RegExp(r'^[A-Za-z0-9-]{1,64}$');
const _configName = 'libraries.json';
const _libraryName = 'KeepPixelLibrary';
const _libraryMarker = '.keep-pixel-library';

class GameInstaller {
  CancelToken? _cancel;
  bool get supported => Platform.isWindows;
  Future<String> _support() async =>
      (await getApplicationSupportDirectory()).path;
  Future<String> _builtIn() async => p.join(await _support(), 'games-v2');

  /// Library folders, the default one first, and which one is the default.
  Future<({List<String> folders, String main})> _config() async {
    final builtIn = await _builtIn();
    var main = builtIn;
    final folders = <String>[builtIn];
    try {
      final j = jsonDecode(
              await File(p.join(await _support(), _configName)).readAsString())
          as Map;
      for (final f in j['folders'] as List? ?? const []) {
        if (f is String &&
            p.isAbsolute(f) &&
            !folders.any((x) => p.equals(x, f))) {
          folders.add(f);
        }
      }
      final chosen = j['default'];
      if (chosen is String && folders.any((x) => p.equals(x, chosen))) {
        main = folders.firstWhere((x) => p.equals(x, chosen));
      }
    } catch (_) {}
    folders
      ..remove(main)
      ..insert(0, main);
    return (folders: folders, main: main);
  }

  Future<void> _writeConfig(List<String> folders, String main) async {
    final builtIn = await _builtIn();
    await File(p.join(await _support(), _configName)).writeAsString(jsonEncode({
      'folders': [
        for (final f in folders)
          if (!p.equals(f, builtIn)) f
      ],
      'default': main
    }));
  }

  /// Installed games: id, version and folder. A game found in two libraries
  /// counts where the default library order finds it first.
  Future<Map<String, ({String version, String dir})>> _scan(
      [String? only]) async {
    final found = <String, ({String version, String dir})>{};
    for (final root in only == null ? (await _config()).folders : [only]) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      try {
        await for (final entry in dir.list(followLinks: false)) {
          final id = p.basename(entry.path);
          if (entry is! Directory ||
              !_safeId.hasMatch(id) ||
              found.containsKey(id)) {
            continue;
          }
          final version = await _receiptVersion(entry.path);
          if (version != null) found[id] = (version: version, dir: entry.path);
        }
      } on FileSystemException {
        // A drive that went away keeps its place in the list.
      }
    }
    return found;
  }

  Future<String?> _receiptVersion(String dir) async {
    final receipt = File(p.join(dir, '.keep-pixel.json'));
    try {
      if (await receipt.length() > 4096) return null;
      final j = jsonDecode(await receipt.readAsString()) as Map;
      return j['version'] is String ? j['version'] as String : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _locate(String id) async {
    if (!_safeId.hasMatch(id)) throw StateError('Некорректный ID игры');
    if (!supported) return null;
    return (await _scan())[id]?.dir;
  }

  Future<Map<String, String>> installedGames() async {
    if (!supported) return {};
    return {for (final e in (await _scan()).entries) e.key: e.value.version};
  }

  /// Folder of every installed game.
  Future<Map<String, String>> installedLocations() async {
    if (!supported) return {};
    return {for (final e in (await _scan()).entries) e.key: e.value.dir};
  }

  Future<List<Drive>> drives() async {
    try {
      final r = await Process.run(
              'powershell',
              [
                '-NoProfile',
                '-NonInteractive',
                '-Command',
                r'[Console]::OutputEncoding = [Text.Encoding]::UTF8; '
                    r'Get-CimInstance Win32_LogicalDisk | '
                    r'Where-Object { $_.DriveType -in 2,3 } | '
                    r'Select-Object DeviceID,VolumeName,FreeSpace,Size | '
                    r'ConvertTo-Json -Compress'
              ],
              stdoutEncoding: utf8)
          .timeout(const Duration(seconds: 10));
      var j = jsonDecode('${r.stdout}'.trim());
      if (j is Map) j = [j];
      return [
        for (final d in j as List)
          if (RegExp(r'^[A-Z]:$').hasMatch('${d['DeviceID']}'))
            Drive(
                root: '${d['DeviceID']}\\',
                label: '${d['VolumeName'] ?? ''}',
                free: (d['FreeSpace'] as num?)?.toInt(),
                total: (d['Size'] as num?)?.toInt())
      ];
    } catch (_) {
      return [
        for (final letter in 'CDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
          if (Directory('$letter:\\').existsSync()) Drive(root: '$letter:\\')
      ];
    }
  }

  Future<List<LibraryFolder>> libraries() async {
    final config = await _config(), builtIn = await _builtIn();
    final drives = await this.drives();
    final result = <LibraryFolder>[];
    for (final folder in config.folders) {
      final games = await _scan(folder);
      var bytes = 0;
      for (final game in games.values) {
        bytes += await _size(game.dir);
      }
      final drive = drives
          .where(
              (d) => d.root.toUpperCase() == p.rootPrefix(folder).toUpperCase())
          .firstOrNull;
      result.add(LibraryFolder(
          path: folder,
          isDefault: p.equals(folder, config.main),
          builtIn: p.equals(folder, builtIn),
          games: games.length,
          bytes: bytes,
          free: drive?.free,
          total: drive?.total));
    }
    return result;
  }

  /// Makes a library in the chosen place: a drive or folder gets its own
  /// KeepPixelLibrary folder, so games never mix with the player's files.
  Future<String> addLibrary(String chosen) async {
    if (!p.isAbsolute(chosen)) {
      throw const FormatException('Нужен полный путь к папке');
    }
    final dir = p.basename(chosen) == _libraryName
        ? p.normalize(chosen)
        : p.join(chosen, _libraryName);
    final config = await _config();
    if (config.folders.any((f) => p.equals(f, dir))) return dir;
    try {
      await Directory(dir).create(recursive: true);
      await File(p.join(dir, _libraryMarker)).writeAsString('{}');
    } on FileSystemException catch (e) {
      throw FormatException(
          'Не удалось создать папку: ${e.osError?.message ?? e.message}');
    }
    await _writeConfig([...config.folders, dir], config.main);
    return dir;
  }

  /// Takes a folder off the list. Its files stay on the drive.
  Future<void> removeLibrary(String path) async {
    final config = await _config(), builtIn = await _builtIn();
    if (p.equals(path, builtIn)) {
      throw const FormatException('Основную папку убрать нельзя');
    }
    if ((await _scan(path)).isNotEmpty) {
      throw const FormatException(
          'В папке есть игры. Сначала перенеси или удали их');
    }
    await _writeConfig([
      for (final f in config.folders)
        if (!p.equals(f, path)) f
    ], p.equals(config.main, path) ? builtIn : config.main);
  }

  Future<void> setDefaultLibrary(String path) async {
    final config = await _config();
    if (!config.folders.any((f) => p.equals(f, path))) {
      throw const FormatException('Такой папки нет в списке');
    }
    await _writeConfig(config.folders, path);
  }

  Future<int> _size(String dir) async {
    var total = 0;
    try {
      await for (final entry
          in Directory(dir).list(recursive: true, followLinks: false)) {
        if (entry is File) total += await entry.length();
      }
    } on FileSystemException {
      // Counted as far as readable.
    }
    return total;
  }

  Future<int> gameSize(String id) async {
    final dir = await _locate(id);
    return dir == null ? 0 : _size(dir);
  }

  /// Opens a library or game folder, or the default library, in Explorer.
  Future<void> openFolder([String? path]) async {
    final config = await _config();
    final known = path == null ||
        config.folders.any((f) => p.equals(f, path)) ||
        (await _scan()).values.any((g) => p.equals(g.dir, path));
    if (!known) throw const FormatException('Неизвестная папка');
    final dir = Directory(path ?? config.main);
    await dir.create(recursive: true);
    await Process.start('explorer', [dir.path]);
  }

  /// Moves an installed game to another library, the way Steam does.
  Future<void> moveGame(
      String id, String library, void Function(double) progress) async {
    final source = await _locate(id);
    if (source == null) throw const FormatException('Игра не установлена');
    final config = await _config();
    if (!config.folders.any((f) => p.equals(f, library))) {
      throw const FormatException('Такой папки нет в списке');
    }
    if (p.equals(p.dirname(source), library)) return;
    final target = Directory(p.join(library, id));
    if (await target.exists()) {
      throw const FormatException('В выбранной папке уже есть эта игра');
    }
    await Directory(library).create(recursive: true);
    try {
      await Directory(source).rename(target.path);
      progress(1);
      return;
    } on FileSystemException {
      // Another drive: copy, then remove the old files.
    }
    final temp = Directory(p.join(library, '.moving-$id'));
    if (await temp.exists()) await temp.delete(recursive: true);
    try {
      final files = <File>[];
      await for (final entry
          in Directory(source).list(recursive: true, followLinks: false)) {
        if (entry is Link) {
          throw const FormatException('В папке игры есть ссылки');
        }
        if (entry is File) files.add(entry);
      }
      var total = 0, done = 0;
      for (final f in files) {
        total += await f.length();
      }
      for (final f in files) {
        final out = File(p.join(temp.path, p.relative(f.path, from: source)));
        await out.parent.create(recursive: true);
        await f.copy(out.path);
        done += await f.length();
        progress(total == 0 ? .95 : done / total * .95);
      }
      await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete(recursive: true);
      rethrow;
    }
    await Directory(source).delete(recursive: true);
    progress(1);
  }

  Future<void> uninstall(String id) async {
    if (!supported) {
      throw UnsupportedError('Управление установками доступно в Windows');
    }
    final dir = await _locate(id);
    if (dir == null) return;
    final game = Directory(dir);
    if (!p.isWithin(await Directory(p.dirname(dir)).resolveSymbolicLinks(),
            await game.resolveSymbolicLinks()) ||
        await FileSystemEntity.isLink(game.path)) {
      throw const FormatException('Небезопасная папка установки');
    }
    await game.delete(recursive: true);
  }

  Future<bool> installed(String id, String version) async {
    if (!supported) return false;
    final dir = await _locate(id);
    return dir != null && await _receiptVersion(dir) == version;
  }

  Future<void> install(
      String id, Map<String, dynamic> manifest, void Function(double) progress,
      {String? library}) async {
    if (!supported) {
      throw UnsupportedError('Установка доступна в клиенте Windows');
    }
    final uri = Uri.parse(manifest['url'] as String);
    final size = manifest['size'] as int, hash = manifest['sha256'] as String;
    final executable = safePackagePath(manifest['executable'] as String);
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        size < 1 ||
        size > 150 * 1024 * 1024 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Некорректный манифест игры');
    }
    // An installed game updates where it is; a new one goes where chosen.
    final existing = await _locate(id);
    final config = await _config();
    final root = Directory(existing != null
        ? p.dirname(existing)
        : library != null && config.folders.any((f) => p.equals(f, library))
            ? library
            : config.main);
    await root.create(recursive: true);
    final stage = await Directory(p.join(root.path, '.staging-')).createTemp();
    final archiveFile = File(p.join(stage.path, 'package.zip'));
    final payload = Directory(p.join(stage.path, 'payload'));
    await payload.create();
    final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: false));
    final cancel = _cancel = CancelToken();
    try {
      var current = uri;
      for (var redirects = 0;; redirects++) {
        final response = await dio.downloadUri(current, archiveFile.path,
            cancelToken: cancel,
            options: Options(
                validateStatus: (s) =>
                    s != null &&
                    (s == 200 ||
                        s == 301 ||
                        s == 302 ||
                        s == 303 ||
                        s == 307 ||
                        s == 308)), onReceiveProgress: (received, _) {
          if (received > size) {
            cancel.cancel('Размер архива превышает манифест');
          } else {
            progress(received / size * .8);
          }
        });
        if (response.statusCode == 200) break;
        if (redirects >= 5 || response.headers.value('location') == null) {
          throw const FormatException('Слишком много перенаправлений загрузки');
        }
        current = current.resolve(response.headers.value('location')!);
        if (current.scheme != 'https' || current.userInfo.isNotEmpty) {
          throw const FormatException('Небезопасное перенаправление загрузки');
        }
      }
      if (cancel.isCancelled) throw cancel.cancelError!;
      if (await archiveFile.length() != size ||
          (await sha256.bind(archiveFile.openRead()).first).toString() !=
              hash) {
        throw const FormatException(
            'Архив повреждён: размер или SHA-256 не совпадает');
      }
      await compute(extractPackage, {
        'archive': archiveFile.path,
        'destination': payload.path,
        'executable': executable
      });
      if (cancel.isCancelled) throw cancel.cancelError!;
      await File(p.join(payload.path, '.keep-pixel.json')).writeAsString(
          jsonEncode({'version': manifest['version'], 'sha256': hash}));
      final target = Directory(p.join(root.path, id));
      if (await target.exists() && await _receiptVersion(target.path) == null) {
        throw const FormatException(
            'Папка игры занята чужими файлами. Выбери другую папку');
      }
      final backup = Directory(p.join(stage.path, 'previous'));
      if (await target.exists()) await target.rename(backup.path);
      try {
        await payload.rename(target.path);
      } catch (_) {
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      progress(1);
    } finally {
      dio.close(force: true);
      _cancel = null;
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  Future<void> launch(String id, Map<String, dynamic> manifest,
      {void Function()? onExit,
      Map<String, String>? environment,
      void Function(int)? onStarted}) async {
    if (!supported) throw UnsupportedError('Запуск доступен в клиенте Windows');
    if (!await installed(id, '${manifest['version']}')) {
      throw const FormatException('Сначала установите актуальную версию игры');
    }
    final root = Directory((await _locate(id))!);
    final receipt = jsonDecode(
            await File(p.join(root.path, '.keep-pixel.json')).readAsString())
        as Map;
    if (receipt['sha256'] != manifest['sha256']) {
      throw const FormatException(
          'Сборка изменилась. Требуется переустановка игры');
    }
    final exe = File(p.joinAll([
      root.path,
      ...safePackagePath(manifest['executable'] as String).split('/')
    ]));
    if (!await exe.exists() ||
        !p.isWithin(await root.resolveSymbolicLinks(),
            await exe.resolveSymbolicLinks())) {
      throw const FormatException('Исполняемый файл игры не найден');
    }
    final process = await Process.start(exe.path, const [],
        workingDirectory: root.path, environment: environment);
    onStarted?.call(process.pid);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    unawaited(process.exitCode.then((_) {
      onExit?.call();
    }));
  }

  void cancel() => _cancel?.cancel('Загрузка отменена');
}

void extractPackage(Map<String, String> input) {
  final archive = ZipDecoder()
      .decodeBytes(File(input['archive']!).readAsBytesSync(), verify: true);
  if (archive.length > 10000) {
    throw const FormatException('Слишком много файлов в архиве');
  }
  final seen = <String>{};
  var total = 0;
  for (final file in archive) {
    final relative = safePackagePath(file.name);
    if (file.isSymbolicLink ||
        !seen.add(relative.toLowerCase()) ||
        relative.toLowerCase() == '.keep-pixel.json') {
      throw const FormatException('Недопустимый файл в архиве');
    }
    total += file.size;
    if (file.size < 0 || total > 512 * 1024 * 1024) {
      throw const FormatException('Слишком большой игровой архив');
    }
  }
  for (final file in archive) {
    final relative = safePackagePath(file.name);
    final path = p.joinAll([input['destination']!, ...relative.split('/')]);
    if (file.isFile) {
      final output = File(path)..parent.createSync(recursive: true);
      final content = file.content as List<int>;
      if (content.length != file.size) {
        throw const FormatException('Повреждённый файл в архиве');
      }
      output.writeAsBytesSync(content);
    } else {
      Directory(path).createSync(recursive: true);
    }
  }
  if (!File(p.joinAll([
    input['destination']!,
    ...safePackagePath(input['executable']!).split('/')
  ])).existsSync()) {
    throw const FormatException('В архиве нет файла запуска');
  }
}
