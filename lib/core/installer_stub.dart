class GameInstaller {
  bool get supported => false;
  Future<Map<int, String>> installedGames() async => {};
  Future<void> uninstall(int id) async =>
      throw UnsupportedError('Управление установками доступно в Windows');
  Future<bool> installed(int id, String version) async => false;
  Future<void> install(int id, Map<String, dynamic> manifest,
          void Function(double) progress) async =>
      throw UnsupportedError('Установка игр доступна в клиенте Windows');
  Future<void> launch(int id, Map<String, dynamic> manifest,
          {void Function()? onExit}) async =>
      throw UnsupportedError('Установка игр доступна в клиенте Windows');
  void cancel() {}
}
