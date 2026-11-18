import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// The developer profile of the signed-in account, if any.
class DeveloperAccount {
  final Map<String, dynamic>? profile;
  final bool isAdmin;
  final int maxBuild, chunkSize;
  const DeveloperAccount(
      {this.profile,
      this.isAdmin = false,
      this.maxBuild = 8 << 30,
      this.chunkSize = 8 << 20});
  factory DeveloperAccount.fromJson(Map<String, dynamic> j) {
    final limits = j['limits'] is Map ? j['limits'] as Map : const {};
    return DeveloperAccount(
        profile: j['developer'] is Map
            ? Map<String, dynamic>.from(j['developer'] as Map)
            : null,
        isAdmin: j['is_admin'] == true,
        maxBuild: (limits['max_build'] as num?)?.toInt() ?? 8 << 30,
        chunkSize: (limits['chunk_size'] as num?)?.toInt() ?? 8 << 20);
  }
  bool get registered => profile != null;
  bool get blocked => profile?['status'] == 'blocked';
  String get name => '${profile?['studio'] ?? ''}'.isNotEmpty
      ? '${profile!['studio']}'
      : '${profile?['display_name'] ?? ''}';
}

List<String> _strings(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : const [];

/// A game as the developer edits it (the public one lives in the catalog).
class DevGame {
  final Map<String, dynamic> j;
  DevGame(this.j);
  String get id => '${j['id']}';
  String get title => '${j['title'] ?? ''}';
  String get shortDescription => '${j['short_description'] ?? ''}';
  String get description => '${j['description'] ?? ''}';
  String get genre => '${j['genre'] ?? ''}';
  String get engine => '${j['engine'] ?? ''}';
  String get ageRating => '${j['age_rating'] ?? ''}';
  String get cover => '${j['cover'] ?? ''}';
  String get banner => '${j['banner'] ?? ''}';
  String get trailer => '${j['trailer'] ?? ''}';
  String get status => '${j['status'] ?? 'draft'}';
  String get storeStatus => '${j['store_status'] ?? 'none'}';
  String get publishMode => '${j['publish_mode'] ?? 'auto'}';
  DateTime? get publishAt => DateTime.tryParse('${j['publish_at'] ?? ''}');
  String get reviewNote => '${j['review_note'] ?? ''}';
  String? get catalogId => j['game_id'] == null ? null : '${j['game_id']}';
  List<String> get tags => _strings(j['tags']);
  List<String> get features => _strings(j['features']);
  List<String> get languages => _strings(j['languages']);
  List<String> get screenshots => _strings(j['screenshots']);
  List<String> get missing => _strings(j['missing']);
  Map<String, dynamic> get requirements =>
      j['requirements'] is Map ? Map<String, dynamic>.from(j['requirements'] as Map) : {};
  Map<String, dynamic> get social =>
      j['social'] is Map ? Map<String, dynamic>.from(j['social'] as Map) : {};
  List<Map<String, dynamic>> get achievements => j['achievements'] is List
      ? (j['achievements'] as List)
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList()
      : [];
  List<DevBuild> get builds => j['builds'] is List
      ? (j['builds'] as List)
          .whereType<Map>()
          .map((b) => DevBuild(Map<String, dynamic>.from(b)))
          .toList()
      : [];
  DevBuild? get latestBuild => j['latest_build'] is Map
      ? DevBuild(Map<String, dynamic>.from(j['latest_build'] as Map))
      : builds.firstOrNull;
  List<Map<String, dynamic>> get history => j['history'] is List
      ? (j['history'] as List)
          .whereType<Map>()
          .map((h) => Map<String, dynamic>.from(h))
          .toList()
      : [];
  bool get editable => status != 'rejected';
  bool get canSubmit =>
      (status == 'draft' || status == 'changes' || storeStatus == 'changes');
  bool get live => status == 'published' || status == 'hidden';
}

class DevBuild {
  final Map<String, dynamic> j;
  DevBuild(this.j);
  String get id => '${j['id']}';
  String get version => '${j['version'] ?? ''}';
  String get status => '${j['status'] ?? ''}';
  String get executable => '${j['executable'] ?? ''}';
  String get notes => '${j['notes'] ?? ''}';
  String get reviewNote => '${j['review_note'] ?? ''}';
  int get size => (j['size'] is String ? int.tryParse(j['size'] as String) : (j['size'] as num?)?.toInt()) ?? 0;
  int get chunkSize => (j['chunk_size'] as num?)?.toInt() ?? 8 << 20;
  int get chunks => (size / chunkSize).ceil();
  Set<int> get received =>
      j['received'] is List ? (j['received'] as List).map((e) => (e as num).toInt()).toSet() : {};
  DateTime? get created => DateTime.tryParse('${j['created_at'] ?? ''}');
  Map<String, dynamic> get scan =>
      j['scan'] is Map ? Map<String, dynamic>.from(j['scan'] as Map) : {};
  bool get sdk => j['sdk'] is Map && (j['sdk'] as Map)['detected'] == true;
  List<String> get sdkEvidence =>
      j['sdk'] is Map ? _strings((j['sdk'] as Map)['evidence']) : const [];
  List<String> get problems => _strings(scan['problems']);
}

/// SHA-256 of a file without reading it into memory (in a background isolate).
Future<String> fileSha256(String path) => compute(_sha256, path);
Future<String> _sha256(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();

/// Sends a game archive in parts; an interrupted upload continues from the
/// parts the server already has, even after the client restarts.
class BuildUploader extends ChangeNotifier {
  final PixelApi api;
  BuildUploader(this.api);

  String? gameId, buildId, file, stage, error;
  double progress = 0;
  bool running = false, _stop = false;

  static const _resumeKey = 'keep_pixel_build_upload';

  /// The unfinished upload of [gameId] from an earlier run, if the file is still there.
  static Future<({String buildId, String file})?> pending(String gameId) async {
    final saved = (await SharedPreferences.getInstance()).getStringList(_resumeKey);
    if (saved == null || saved.length != 3 || saved[0] != gameId) return null;
    if (!await File(saved[2]).exists()) return null;
    return (buildId: saved[1], file: saved[2]);
  }

  Future<void> start(
      {required String gameId,
      required String file,
      required String version,
      required String executable,
      String notes = ''}) async {
    if (running) return;
    this.gameId = gameId;
    this.file = file;
    error = null;
    running = true;
    _stop = false;
    try {
      stage = 'Считаем контрольную сумму…';
      progress = 0;
      notifyListeners();
      final size = await File(file).length();
      final hash = await fileSha256(file);
      final created = await api.createBuild(gameId, {
        'version': version,
        'executable': executable,
        'notes': notes,
        'size': size,
        'sha256': hash
      });
      buildId = '${created['id']}';
      await (await SharedPreferences.getInstance())
          .setStringList(_resumeKey, [gameId, buildId!, file]);
      await _send();
    } catch (e) {
      error = '$e';
    } finally {
      running = false;
      notifyListeners();
    }
  }

  Future<void> resume(String gameId, String buildId, String file) async {
    if (running) return;
    this.gameId = gameId;
    this.buildId = buildId;
    this.file = file;
    error = null;
    running = true;
    _stop = false;
    notifyListeners();
    try {
      await _send();
    } catch (e) {
      error = '$e';
    } finally {
      running = false;
      notifyListeners();
    }
  }

  void cancel() => _stop = true;

  Future<void> _send() async {
    final build = await api.buildState(buildId!);
    if (build.status != 'uploading') {
      await _forget();
      stage = 'Сборка уже загружена';
      progress = 1;
      return;
    }
    final have = build.received;
    final raf = await File(file!).open();
    try {
      final total = build.chunks;
      for (var n = 0; n < total; n++) {
        if (_stop) throw const ApiError('Загрузка приостановлена');
        if (have.contains(n)) continue;
        await raf.setPosition(n * build.chunkSize);
        final bytes = await raf.read(build.chunkSize);
        for (var attempt = 0;; attempt++) {
          try {
            await api.uploadBuildChunk(buildId!, n, Uint8List.fromList(bytes));
            break;
          } catch (e) {
            if (attempt >= 4 || _stop) rethrow;
            await Future.delayed(Duration(seconds: 2 << attempt));
          }
        }
        have.add(n);
        progress = have.length / total;
        stage = 'Загружено ${(progress * 100).toStringAsFixed(0)}%';
        notifyListeners();
      }
    } finally {
      await raf.close();
    }
    stage = 'Сервер проверяет архив…';
    notifyListeners();
    await api.completeBuild(buildId!);
    await _forget();
    stage = 'Загружено. Идёт автоматическая проверка';
    progress = 1;
  }

  Future<void> _forget() async =>
      (await SharedPreferences.getInstance()).remove(_resumeKey);
}
