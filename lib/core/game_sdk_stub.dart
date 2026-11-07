import 'api.dart';
import 'game_overlay.dart';

class GameSdkHost {
  GameSdkHost(PixelApi api, GameOverlayController overlay);
  Future<Map<String, String>> create(String id, String title) async => {};
  void revoke(String id) {}
  void dispose() {}
}
