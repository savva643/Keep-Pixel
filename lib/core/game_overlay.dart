import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Owns the launcher panel. No DLL injection or graphics API hooking is used.
class GameOverlayController extends ChangeNotifier {
  static const channel = MethodChannel('keep_pixel/game_overlay');
  final Map<int, String> games = {};
  bool visible = false;
  int? gameId;
  String? error;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  GameOverlayController() {
    if (supported) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'hotkeyError') {
          error =
              'Shift+Tab занят другой программой. Панель можно открыть из игры через SDK.';
          notifyListeners();
        }
        if (call.method == 'changed') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          visible = args['visible'] == true;
          gameId = args['game_id'] as int?;
          notifyListeners();
        }
      });
    }
  }

  Future<void> register(int id, String title, int pid) async {
    games[id] = title;
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('register', {'game_id': id, 'pid': pid});
      error = null;
    } on PlatformException catch (e) {
      error = e.message ?? 'Shift+Tab недоступен';
    } on MissingPluginException {
      error = 'Обновите Windows-клиент для игрового меню';
    }
    notifyListeners();
  }

  Future<void> request(int id, bool show) async {
    if (!supported || !games.containsKey(id)) {
      throw PlatformException(
          code: 'overlay_unavailable',
          message: 'Панель доступна для запущенной игры в Windows');
    }
    await channel
        .invokeMethod<void>('setVisible', {'game_id': id, 'visible': show});
  }

  Future<void> close() async {
    if (gameId != null && supported) {
      await channel.invokeMethod<void>(
          'setVisible', {'game_id': gameId, 'visible': false});
    }
  }

  Future<void> unregister(int id) async {
    games.remove(id);
    if (supported) {
      try {
        await channel.invokeMethod<void>('unregister', {'game_id': id});
      } on PlatformException catch (_) {
        // The game may exit while the native window is already closing.
      } on MissingPluginException catch (_) {}
    }
    if (gameId == id) {
      visible = false;
      gameId = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
    super.dispose();
  }
}
