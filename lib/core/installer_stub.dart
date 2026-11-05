class GameInstaller {
  bool get supported => false;
  Future<bool> installed(int id, String version) async => false;
  Future<void> install(int id, Map<String, dynamic> manifest,
          void Function(double) progress) async =>
      throw UnsupportedError('Установка игр доступна в клиенте Windows');
  Future<void> launch(int id, Map<String, dynamic> manifest) async =>
      throw UnsupportedError('Установка игр доступна в клиенте Windows');
  void cancel() {}
}
