import 'storage.dart';

export 'storage.dart';

class GameInstaller {
  bool get supported => false;
  Future<Map<String, String>> installedGames() async => {};
  Future<Map<String, String>> installedLocations() async => {};
  Future<List<Drive>> drives() async => [];
  Future<List<LibraryFolder>> libraries() async => [];
  Future<String> addLibrary(String chosen) async =>
      throw UnsupportedError('Папки с играми есть только в клиенте Windows');
  Future<void> removeLibrary(String path) async {}
  Future<void> setDefaultLibrary(String path) async {}
  Future<int> gameSize(String id) async => 0;
  Future<void> openFolder([String? path]) async =>
      throw UnsupportedError('Папка с играми есть только в клиенте Windows');
  Future<void> moveGame(
          String id, String library, void Function(double) progress) async =>
      throw UnsupportedError('Перенос игр доступен в клиенте Windows');
  Future<void> uninstall(String id) async =>
      throw UnsupportedError('Управление установками доступно в Windows');
  Future<bool> installed(String id, String version) async => false;
  Future<void> install(String id, Map<String, dynamic> manifest,
          void Function(double) progress,
          {String? library}) async =>
      throw UnsupportedError('Установка игр доступна в клиенте Windows');
  Future<void> launch(String id, Map<String, dynamic> manifest,
          {void Function()? onExit,
          Map<String, String>? environment,
          void Function(int)? onStarted}) async =>
      throw UnsupportedError('Установка игр доступна в клиенте Windows');
  void cancel() {}
}
