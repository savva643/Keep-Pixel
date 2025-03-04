import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_services.dart';
import '../parts/install.dart';
import 'login_required_screen.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({Key? key}) : super(key: key);

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final StateGame stateGame = StateGame();
  final ApiService apiService = ApiService();
  List<dynamic> games = [];
  bool isAuthenticated = false;
  bool isLoading = true;
  dynamic selectedGame;
  Map<int, double> downloadProgress = {};
  Map<int, String> downloadStatus = {};

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  void _checkAuthentication() async {
    isAuthenticated = await apiService.checkAuth();
    if (isAuthenticated) {
      await _loadLibrary();
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadLibrary() async {
    final library = await apiService.getUserLibrary();
    setState(() {
      games = library;
      if (games.isNotEmpty) {
        selectedGame = games[0];
      }
    });
  }

  Future<void> installGame(dynamic game) async {
    print(game);
    int gameId = int.parse(game['id']); // Получаем gameId
    // Инициализируем прогресс скачивания на 0
    setState(() {
      downloadProgress[gameId] = 0.0;
      downloadStatus[gameId] = "Скачивание";
    });

    // Обновляем прогресс скачивания в реальном времени
    await stateGame.downloadAndInstallGame(game, (progress, status) {
      setState(() {
        downloadProgress[gameId] = progress; // Обновляем прогресс
        downloadStatus[gameId] = status; // Обновляем статус
      });
    });

    // После завершения установки, удаляем прогресс из карты
    setState(() {
      downloadProgress.remove(gameId);
      downloadStatus.remove(gameId);
    });
  }

  Future<void> updateGame(dynamic game) async {
    print(game);
    int gameId = int.parse(game['id']); // Получаем gameId
    // Инициализируем прогресс скачивания на 0
    setState(() {
      downloadProgress[gameId] = 0.0;
      downloadStatus[gameId] = "Скачивание";
    });

    // Обновляем прогресс скачивания в реальном времени
    await stateGame.updateGameIfNeeded(game, (progress, status) {
      setState(() {
        downloadProgress[gameId] = progress; // Обновляем прогресс
        downloadStatus[gameId] = status; // Обновляем статус
      });
    });

    // После завершения установки, удаляем прогресс из карты
    setState(() {
      downloadProgress.remove(gameId);
      downloadStatus.remove(gameId);
    });
  }




  Widget getActionButton(dynamic game) {
    int gameId = int.parse(game['id']);

    if (downloadProgress.containsKey(gameId)) {
      // Получаем статус
      String status = downloadStatus[gameId] ?? "Загрузка...";

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded( // Добавляем, чтобы прогресс-бар занимал всю ширину
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8), // Закругленные края
              child: LinearProgressIndicator(
                value: downloadProgress[gameId] ?? 0.0,
                minHeight: 8, // Делаем его толще
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), // Красивый цвет
                backgroundColor: Colors.grey[800], // Темный фон
              ),
            ),
          ),
          SizedBox(width: 10),
          Text(
            "$status ${ (downloadProgress[gameId] ?? 0.0 * 100).toStringAsFixed(0) }%",
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    return FutureBuilder<bool>(
      future: stateGame.isGameInstalled(gameId),
      builder: (context, installSnapshot) {
        bool installed = installSnapshot.data ?? false;

        return FutureBuilder<bool>(
          future: stateGame.needsUpdate(game),
          builder: (context, updateSnapshot) {
            bool needsUpdate = updateSnapshot.data ?? false;

            return ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: installed
                    ? (needsUpdate ? Colors.orange : Colors.green) // Оранжевый для обновления, зелёный для игры
                    : Color(0xFF4C6EFF), // Голубой для установки
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Увеличенный padding
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Скруглённые углы
              ),
              onPressed: () async {
                if (!installed) {
                  await installGame(game);
                } else if (needsUpdate) {
                  await updateGame(game);
                } else {
                  await stateGame.launchGame(game);
                }
              },
              icon: Icon(
                installed
                    ? (needsUpdate ? Icons.system_update : Icons.play_arrow) // Иконка обновления или запуска
                    : Icons.download, // Иконка скачивания
                color: Colors.white,
              ),
              label: Text(
                installed ? (needsUpdate ? "Обновить" : "Играть") : "Установить",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            );
          },
        );
      },
    );
  }





  Widget buildMenu(dynamic game) {
    return FutureBuilder<bool>(
      future: stateGame.isGameInstalled(int.parse(game['id'])),
      builder: (context, installSnapshot) {
        bool installed = installSnapshot.data ?? false;

        return FutureBuilder<bool>(
          future: stateGame.needsUpdate(game),
          builder: (context, updateSnapshot) {
            bool needsUpdate = updateSnapshot.data ?? false;

            return Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: Color(0xFF27272A), // Тёмный фон (zinc-800)
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Скругленные углы
                ),
                textTheme: TextTheme(
                  bodyMedium: TextStyle(color: Color(0xFFF4F4F5)), // Белый текст (zinc-100)
                ),
                iconTheme: IconThemeData(color: Color(0xFFF4F4F5)), // Белые иконки
              ),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (String value) async {
                  if (value == 'properties') {
                    // Открыть свойства
                  } else if (value == 'delete') {
                    await stateGame.removeGame(game['id']);
                    await _loadLibrary();
                  } else if (value == 'play_without_update') {
                    await stateGame.launchGame(game['id']);
                  }
                },
                itemBuilder: (BuildContext context) {
                  List<PopupMenuEntry<String>> menuItems = [
                    PopupMenuItem(
                      value: 'properties',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Text("Свойства", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ];

                  if (installed) {
                    menuItems.add(
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text("Удалить", style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    );
                  }

                  if (needsUpdate && installed) {
                    menuItems.add(
                      PopupMenuItem(
                        value: 'play_without_update',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, color: Colors.green),
                            SizedBox(width: 8),
                            Text("Играть без обновления", style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    );
                  }

                  return menuItems;
                },
              ),
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF18181B),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAuthenticated) {
      return LoginRequiredPage();
    }

    return Scaffold(
      backgroundColor: Color(0xFF18181B),
      body: Row(
        children: [
          // Боковая панель с играми
          Container(
            width: 250,
            color: Color(0xFF27272A),
            child: ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return Container(
                  decoration: BoxDecoration(
                    color: selectedGame == game ? Color(0xFF3B5BDB) : Colors.transparent, // Выделенный цвет
                    //borderRadius: BorderRadius.circular(8), // Скругленные углы
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        game['img'],
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                    title: Text(
                      game['game'],
                      style: TextStyle(
                        color: selectedGame == game ? Colors.white : Color(0xFFF4F4F5), // Цвет текста
                        fontWeight: selectedGame == game ? FontWeight.bold : FontWeight.normal, // Жирный текст
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        selectedGame = game; // Обновляем состояние
                      });
                    },
                  ),
                );



              },
            ),
          ),

          // Основной контент
          Expanded(
            child: selectedGame == null
                ? Padding(
              padding: EdgeInsets.all(16),
              child: Text("Выберите игру", style: TextStyle(color: Color(0xFFF4F4F5))),
            )
                : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Обложка игры
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                        child: Image.network(
                          selectedGame['imggame'],
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xFF18181B)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                selectedGame['img'],
                                width: 64,
                                height: 64,
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              selectedGame['game'],
                              style: TextStyle(
                                color: Color(0xFFF4F4F5),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Описание и кнопки
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [


                        // Кнопки "Установить" и "Дополнительно"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            getActionButton(selectedGame),
                            SizedBox(width: 8),
                            buildMenu(selectedGame),
                          ],
                        ),
                        SizedBox(height: 16),
                        // Короткое описание (если есть)
                        if (selectedGame['opica'] != null && selectedGame['opica'].isNotEmpty)
                          Text(
                            selectedGame['opica'],
                            style: TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 14,
                            ),
                          ),

                        SizedBox(height: 12),

                        // Длинное описание
                        Text(
                          "Описание",
                          style: TextStyle(
                            color: Color(0xFFF4F4F5),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          selectedGame['description'] ?? "Описание отсутствует.",
                          style: TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 14,
                          ),
                        ),


                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

}