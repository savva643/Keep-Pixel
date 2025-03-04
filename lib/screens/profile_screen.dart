import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_services.dart';
import 'login_required_screen.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({Key? key, this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService apiService = ApiService();
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  bool isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  void _checkAuthentication() async {
    bool isAuthenticated = await apiService.checkAuth();
    if (isAuthenticated) {
      await _loadProfile();
    } else {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginRequiredPage())
      );
    }
  }

  Future<void> _loadProfile() async {
    final data = await apiService.getProfile();
    setState(() {
      profileData = data['profile'];
      isOwnProfile = true;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView( // Добавляем прокрутку для профиля
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1200), // Максимальная ширина страницы
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Картинка профиля и текст справа
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          profileData?["img"] ?? "https://via.placeholder.com/150",
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileData?["nick"] ?? "Неизвестный",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 5),
                          Text(
                            profileData?["opic"] ?? "Отсутствует",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 10),
                          if (profileData?["status"] == 1 && isOwnProfile) ...[
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text("Вы в сети", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Виджеты с уровнями, друзьями и достижениями
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(), // Отключаем прокрутку внутри GridView
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 3 элемента в ряд
                      crossAxisSpacing: 16.0, // Расстояние между колонками
                      mainAxisSpacing: 16.0, // Расстояние между строками
                      childAspectRatio: 1.0, // Уменьшаем соотношение для более компактных карточек
                    ),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      if (index == 0) return _levelWidget();
                      if (index == 1) return _friendsWidget();
                      return _achievementsWidget();
                    },
                  ),

                  SizedBox(height: 20),

                  // Если это не свой профиль, кнопка добавления в друзья
                  if (!isOwnProfile) ...[
                    ElevatedButton(
                      onPressed: () {},
                      child: Text("Добавить в друзья"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _levelWidget() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 30), // Ограничиваем высоту
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(Icons.star, color: Colors.yellow, size: 25),
            SizedBox(width: 8),
            Text("Уровень ${profileData?["level"] ?? 0}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _friendsWidget() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 30), // Ограничиваем высоту
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(Icons.group, color: Colors.blue, size: 25),
            SizedBox(width: 8),
            Text(
              "Друзья: ${profileData?["friend_count"] ?? 0}",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementsWidget() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 30), // Ограничиваем высоту
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.orange, size: 25),
            SizedBox(width: 8),
            Text(
              "Достижения: 0",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

}
