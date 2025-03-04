import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StateGame {
final StreamController<Map<String, dynamic>> downloadProgressController = StreamController.broadcast();
final StreamController<void> updateCheckController = StreamController.broadcast();

StateGame() {
  // Запускаем проверку обновлений каждые 60 секунд
  Timer.periodic(Duration(minutes: 1), (_) => checkForUpdates());
}


Future<String?> getInstallPath() async {
  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
  return selectedDirectory;
}

Future<void> saveGameInfo(Map<String, dynamic> game, String installPath) async {
  final prefs = await SharedPreferences.getInstance();
  String gamePath = '$installPath/${game["papka"]}';
  String exePath = '$gamePath/${game["cmd"]}.exe';

  Map<String, dynamic> gameData = {
    "id": game["id"],
    "name": game["game"],
    "path": gamePath,
    "exe": exePath,
    "version": game["version"],
    "cmd": game["cmd"],
  };
  print(gameData.toString());
  await prefs.setString('game_${game["id"]}', jsonEncode(gameData));
}

Future<Map<String, dynamic>?> getGameInfo(int gameId) async {
  final prefs = await SharedPreferences.getInstance();
  String? gameJson = prefs.getString('game_$gameId');
  return gameJson != null ? jsonDecode(gameJson) : null;
}

Future<bool> isGameInstalled(int gameId) async {
  final prefs = await SharedPreferences.getInstance();
  String? gameData = prefs.getString('game_$gameId');
  if (gameData == null) return false;

  Map<String, dynamic> gameInfo = jsonDecode(gameData);
  String exePath = gameInfo['exe'];

  return await File(exePath).exists();
}

Future<void> downloadAndInstallGame(Map<String, dynamic> game, Function(double, String) onProgress) async {
  String? installPath = await getInstallPath();
  if (installPath == null || installPath.isEmpty) {
    print("Ошибка: Путь установки не выбран!");
    return;
  }

  String zipPath = '$installPath/${game["papka"]}.zip';

  print("Скачивание начато в: $zipPath");

  // Отправляем статус о начале скачивания
  onProgress(0.0, "Downloading");

  try {
    await downloadFile("https://keeppixel.store/${game["file"]}", zipPath, (progress) {
      onProgress(progress, "Downloading"); // Обновление статуса и прогресса скачивания
    });

    // Отправляем статус о начале установки
    onProgress(0.0, "Installing");

    // Извлекаем архив
    await extractZip(zipPath, installPath, (progress) {
      onProgress(progress, "Installing"); // Обновление статуса и прогресса установки
    });

    await File(zipPath).delete();

    print("${game["game"]} установлена в: $installPath");

    // Сохраняем информацию об игре
    await saveGameInfo(game, installPath);

    // Отправляем финальный прогресс (100%)
    onProgress(1.0, "Completed");

  } catch (e) {
    print("Ошибка при установке: $e");
  }
}



Future<void> downloadFile(String url, String savePath, Function(double) onProgress) async {
  Dio dio = Dio();
  await dio.download(url, savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          double progress = received / total;
          onProgress(progress);
          // Отправляем прогресс скачивания
          downloadProgressController.add({
            'status': 'Downloading',
            'progress': progress,
            'game': '',
          });
          onProgress(progress);
        }
      }
  );
}

Future<void> extractZip(String zipPath, String extractTo, Function(double) onProgress) async {
  final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
  int totalFiles = archive.length;
  int extractedFiles = 0;

  for (final file in archive) {
    final filePath = '$extractTo/${file.name}';
    if (file.isFile) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content);
    } else {
      Directory(filePath).createSync(recursive: true);
    }

    extractedFiles++;
    double progress = extractedFiles / totalFiles;
    onProgress(progress);

    // Отправляем прогресс извлечения
    downloadProgressController.add({
      'status': 'Installing',
      'progress': progress,
      'game': '',
    });
    onProgress(progress);
  }
}


Future<void> launchGame(Map<String, dynamic> game) async {
  int gameId = int.parse(game['id']);
  Map<String, dynamic>? gamei = await getGameInfo(gameId);
  if (gamei == null) {
    print("Путь установки не выбран!");
    return;
  }

  String exePath = gamei['exe'];
  if (await File(exePath).exists()) {
    Process.run(exePath, []);
  } else {
    print("Файл запуска не найден: $exePath");
  }
}

bool isNewerVersion(String serverVersion, String localVersion) {
  List<int> serverParts = serverVersion.split('.').map(int.parse).toList();
  List<int> localParts = localVersion.split('.').map(int.parse).toList();
  for (int i = 0; i < serverParts.length; i++) {
    if (serverParts[i] > (i < localParts.length ? localParts[i] : 0)) return true;
    if (serverParts[i] < (i < localParts.length ? localParts[i] : 0)) return false;
  }
  return false;
}

Future<bool> needsUpdate(dynamic game) async {
  int gameId = int.parse(game['id']);
  final prefs = await SharedPreferences.getInstance();
  String? gameData = prefs.getString('game_$gameId');
  if (gameData == null) return true; // Если игры нет в памяти, значит обновление (или установка) требуется

  Map<String, dynamic> gameInfo = jsonDecode(gameData);
  String localVersion = gameInfo['version'] ?? '0.0.0'; // Если нет версии, считаем её 0.0.0

  return isNewerVersion(game['version'], localVersion);
}


Future<void> updateGameIfNeeded(Map<String, dynamic> game, Function(double, String) onProgress) async {
  bool installed = await isGameInstalled(game["id"]);
  Map<String, dynamic>? localGame = await getGameInfo(game["id"]);

  if (!installed) {
    await downloadAndInstallGame(game, onProgress);
    return;
  }

  if (isNewerVersion(game["version"], localGame!["version"])) {
    print("Обновление ${game["game"]}...");
    await downloadAndInstallGame(game, onProgress);
  }
}


Future<void> checkForUpdates() async {
  print("Проверка обновлений...");
  updateCheckController.add(null);
}

Future<void> removeGame(int gameId) async {
  final prefs = await SharedPreferences.getInstance();
  Map<String, dynamic>? game = await getGameInfo(gameId);
  if (game == null) {
    print("Игра не найдена!");
    return;
  }
  Directory(game["path"]).deleteSync(recursive: true);
  await prefs.remove('game_$gameId');
  print("Игра ${game["name"]} удалена.");
}
}
