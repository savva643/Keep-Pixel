import 'package:flutter/material.dart';

class GameDetailsPage extends StatelessWidget {
  final Map<String, dynamic> game;

  const GameDetailsPage({Key? key, required this.game}) : super(key: key);

  String getActionButtonText(Map<String, dynamic> game) {
    if (game['typeUser'].toString() == "1") {
      return "Скачать";
    } else if (game['price'].toString() == "0") {
      return "Получить";
    } else {
      return "Купить";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF18181B),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: Image.network(
                    game['imggame'],
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
                          game['img'],
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        game['game'],
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
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game['opica'],
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 12),
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
                    game['description'] ?? "Описание отсутствует.",
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        game['price'].toString() != "0" ? game['price'] : "Бесплатно",
                        style: TextStyle(
                          color: Color(0xFFF4F4F5),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF4C6EFF),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // TODO: Добавить логику покупки
                        },
                        child: Text(
                          getActionButtonText(game),
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}