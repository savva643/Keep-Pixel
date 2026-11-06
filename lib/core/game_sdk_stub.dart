import 'api.dart';
import 'game_overlay.dart';

class GameSdkHost {
  GameSdkHost(PixelApi api, GameOverlayController overlay);
  Future<Map<String, String>> create(int id, String title) async => {};
  void revoke(int id) {}
  void dispose() {}
}
