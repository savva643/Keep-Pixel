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

class GameInstaller {
  CancelToken? _cancel;
  bool get supported => Platform.isWindows;
  Future<Directory> _root() async => Directory(
      p.join((await getApplicationSupportDirectory()).path, 'games-v2'));
  Future<Directory> _game(int id) async {
    if (id < 1) throw const FormatException('Некорректный ID игры');
    return Directory(p.join((await _root()).path, '$id'));
  }

  Future<Map<int, String>> installedGames() async {
    if (!supported) return {};
    final root = await _root();
    if (!await root.exists()) return {};
    final found = <int, String>{};
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory ||
          !RegExp(r'^[1-9]\d*$').hasMatch(p.basename(entry.path))) {
        continue;
      }
      final receipt = File(p.join(entry.path, '.keep-pixel.json'));
      try {
        if (await receipt.length() > 4096) continue;
        final j = jsonDecode(await receipt.readAsString()) as Map;
        if (j['version'] is String) {
          found[int.parse(p.basename(entry.path))] = j['version'] as String;
        }
      } catch (_) {}
    }
    return found;
  }

  Future<void> uninstall(int id) async {
    if (!supported) {
      throw UnsupportedError('Управление установками доступно в Windows');
    }
    final root = await _root(), game = await _game(id);
    if (!await game.exists()) return;
    if (!p.isWithin(await root.resolveSymbolicLinks(),
            await game.resolveSymbolicLinks()) ||
        await FileSystemEntity.isLink(game.path)) {
      throw const FormatException('Небезопасная папка установки');
    }
    await game.delete(recursive: true);
  }

  Future<bool> installed(int id, String version) async {
    if (!supported) return false;
    final file = File(p.join((await _game(id)).path, '.keep-pixel.json'));
    try {
      return (jsonDecode(await file.readAsString()) as Map)['version'] ==
          version;
    } catch (_) {
      return false;
    }
  }

  Future<void> install(int id, Map<String, dynamic> manifest,
      void Function(double) progress) async {
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
    final root = await _root();
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
      final target = await _game(id);
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

  Future<void> launch(int id, Map<String, dynamic> manifest,
      {void Function()? onExit,
      Map<String, String>? environment,
      void Function(int)? onStarted}) async {
    if (!supported) throw UnsupportedError('Запуск доступен в клиенте Windows');
    if (!await installed(id, '${manifest['version']}')) {
      throw const FormatException('Сначала установите актуальную версию игры');
    }
    final root = await _game(id);
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
