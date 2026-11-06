import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'game_overlay.dart';
import 'game_sdk.dart';
import 'installer.dart';
import 'models.dart';

enum DownloadState { queued, downloading, complete, cancelled, failed }

class DownloadJob {
  final Game game;
  final GameInstaller installer;
  DownloadState state = DownloadState.queued;
  double progress = 0;
  String? error;
  DownloadJob(this.game, this.installer);
  bool get active =>
      state == DownloadState.queued || state == DownloadState.downloading;
  String get label => switch (state) {
        DownloadState.queued => 'В очереди',
        DownloadState.downloading => progress >= .8
            ? 'Установка…'
            : 'Загрузка ${(progress * 100).round()}%',
        DownloadState.complete => 'Установлено',
        DownloadState.cancelled => 'Отменено',
        DownloadState.failed => 'Ошибка загрузки'
      };
}

class DownloadsController extends ChangeNotifier {
  final PixelApi api;
  final overlay = GameOverlayController();
  late final GameSdkHost sdk;
  final GameInstaller Function() factory;
  final Map<int, DownloadJob> jobs = {};
  Map<int, String> installed = {};
  bool _running = false, _disposed = false;
  final _runningGames = <int>{};
  int? activeGameId;
  int _generation;
  DownloadsController(this.api, {GameInstaller Function()? factory})
      : factory = factory ?? GameInstaller.new,
        _generation = api.sessionGeneration {
    sdk = GameSdkHost(api, overlay);
    api.addListener(_sessionChanged);
  }
  bool get supported => factory().supported;
  Iterable<DownloadJob> get active => jobs.values.where((j) => j.active);
  Future<void> initialize() async {
    installed = await factory().installedGames();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_generation != api.sessionGeneration) {
      _generation = api.sessionGeneration;
      for (final id in _runningGames) {
        sdk.revoke(id);
        unawaited(overlay.unregister(id));
      }
      _runningGames.clear();
      activeGameId = null;
      for (final j in jobs.values.where((j) => j.active)) {
        j.state = DownloadState.cancelled;
        j.installer.cancel();
      }
      _notify();
    }
  }

  bool isRunning(Game g) => _runningGames.contains(g.id);
  bool isCurrent(Game g) => installed[g.id] == g.version;
  bool hasInstall(Game g) => installed.containsKey(g.id);
  void enqueue(Game g) {
    if (!supported ||
        _runningGames.contains(g.id) ||
        jobs[g.id]?.active == true) {
      return;
    }
    jobs[g.id] = DownloadJob(g, factory());
    _notify();
    unawaited(_pump());
  }

  void cancel(int id) {
    final j = jobs[id];
    if (j == null || !j.active) return;
    j.state = DownloadState.cancelled;
    j.installer.cancel();
    _notify();
  }

  Future<void> _pump() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (!_disposed) {
        final waiting =
            jobs.values.where((j) => j.state == DownloadState.queued);
        if (waiting.isEmpty) break;
        final j = waiting.first;
        j.state = DownloadState.downloading;
        _notify();
        try {
          final manifest = await api.buildManifest(j.game.id);
          if (j.state == DownloadState.cancelled) continue;
          await j.installer.install(j.game.id, manifest, (p) {
            j.progress = p;
            _notify();
          });
          if (j.state != DownloadState.cancelled) {
            installed[j.game.id] = '${manifest['version']}';
            j.state = DownloadState.complete;
          }
        } catch (e) {
          if (j.state != DownloadState.cancelled) {
            j.state = DownloadState.failed;
            j.error = '$e';
          }
        }
        _notify();
      }
    } finally {
      _running = false;
    }
  }

  Future<void> launch(Game g) async {
    if (_runningGames.contains(g.id)) throw const ApiError('Игра уже запущена');
    final generation = api.sessionGeneration;
    final manifest = await api.buildManifest(g.id);
    if (generation != api.sessionGeneration) return;
    _runningGames.add(g.id);
    activeGameId = g.id;
    try {
      final environment = await sdk.create(g.id, g.title);
      if (generation != api.sessionGeneration) {
        sdk.revoke(g.id);
        return;
      }
      await factory().launch(g.id, manifest, environment: environment,
          onStarted: (pid) {
        if (!_disposed && generation == api.sessionGeneration) {
          unawaited(overlay.register(g.id, g.title, pid));
        }
      }, onExit: () {
        if (_disposed || generation != api.sessionGeneration) return;
        sdk.revoke(g.id);
        unawaited(overlay.unregister(g.id));
        _runningGames.remove(g.id);
        if (activeGameId == g.id) {
          activeGameId = _runningGames.isEmpty ? null : _runningGames.last;
        }
        if (api.signedIn) {
          unawaited(api
              .presence(
                  status: activeGameId == null ? 'online' : 'in_game',
                  gameId: activeGameId)
              .catchError((_) {}));
        }
        _notify();
      });
    } catch (_) {
      if (_disposed || generation != api.sessionGeneration) rethrow;
      sdk.revoke(g.id);
      unawaited(overlay.unregister(g.id));
      _runningGames.remove(g.id);
      if (activeGameId == g.id) {
        activeGameId = _runningGames.isEmpty ? null : _runningGames.last;
      }
      _notify();
      rethrow;
    }
    if (generation != api.sessionGeneration || !_runningGames.contains(g.id)) {
      return;
    }
    _notify();
    unawaited(api.presence(status: 'in_game', gameId: g.id).catchError((_) {}));
  }

  Future<void> uninstall(Game g) async {
    if (_runningGames.contains(g.id)) {
      throw const ApiError('Сначала завершите игру');
    }
    if (jobs[g.id]?.active == true) {
      throw const ApiError('Сначала отмените загрузку');
    }
    await factory().uninstall(g.id);
    installed.remove(g.id);
    jobs.remove(g.id);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    api.removeListener(_sessionChanged);
    sdk.dispose();
    unawaited(Future.wait(_runningGames.map(overlay.unregister))
        .whenComplete(overlay.dispose));
    // Native cleanup is also performed when the runner window is destroyed.
    for (final j in jobs.values) {
      j.installer.cancel();
    }
    super.dispose();
  }
}
