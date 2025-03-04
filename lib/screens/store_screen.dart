import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:keep_pixel/screens/game_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_services.dart';

class StorePage extends StatefulWidget {
  final Function(String title) setTitle;
  final Function(BuildContext context, Widget page, String title) navigateTo;
  const StorePage({Key? key, required this.setTitle, required this.navigateTo}) : super(key: key);

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final ApiService apiService = ApiService();
  List<dynamic> recommendations = [];
  bool isStoreOpen = false;


  String _currentTitle = "Магазин";

  void _openGameDetails(Map<String, dynamic> game) async {
    // Обновляем название на текущей странице
    setState(() {
      _currentTitle = 'Страница "${game['game']}"';
      widget.setTitle(_currentTitle); // Обновляем через родительский виджет
    });

    // Переход на страницу деталей игры

    widget.navigateTo(context, GameDetailsPage(game: game), 'Страница "${game['game']}"');
    // После возвращения на главную страницу
    setState(() {
      //_currentTitle = "Магазин"; // Возвращаем название при закрытии страницы
      //widget.setTitle(_currentTitle); // Обновляем через родительский виджет
    });
  }




  @override
  void initState() {
    super.initState();
    isStoreOpen = true;
    _loadRecommendations();
  }

  @override
  void dispose() {
    isStoreOpen = false;
    super.dispose();
  }

  void _loadRecommendations() async {
    final recs = await apiService.getRecommendations();
    if (mounted) {
      setState(() {
        recommendations = recs;
      });
    }
  }

  Future<bool> _isGameDownloaded(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(gameId) ?? false;
  }

  String getActionButtonText(Map<String, dynamic> game) {
    if (game['typeUser'].toString() == "1") {
      return "Скачать";
    } else if (game['price'].toString() == "0") {
      return "Получить";
    } else {
      return "Купить";
    }
  }

  Color getActionButtonColor(Map<String, dynamic> game) {
    return game['typeUser'] == 1 ? Colors.green : Color(0xFF4C6EFF);
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 1200 ? 4 : screenWidth > 800 ? 3 : 2;

    return Scaffold(
      backgroundColor: Color(0xFF18181B),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: MasonryGridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          itemCount: recommendations.length,
          itemBuilder: (context, index) {
            final game = recommendations[index];

            return GestureDetector(
              onTap: () {
                _openGameDetails(game);
              },
              child: Card(
                color: Color(0xFF27272A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                      child: Image.network(
                        game['imggame'],
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game['game'],
                            style: TextStyle(
                              color: Color(0xFFF4F4F5),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            game['opica'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: getActionButtonColor(game),
                                minimumSize: Size(80, 30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: () {
                                // TODO: Добавить логику обработки покупки/скачивания/запуска
                              },
                              child: Text(
                                getActionButtonText(game),
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
