import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:keep_pixel/screens/library_screen.dart';
import 'package:keep_pixel/screens/profile_screen.dart';
import 'package:keep_pixel/screens/store_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_services.dart';
import 'login_screen.dart';

class KeepPixelHome extends StatefulWidget {
  @override
  _KeepPixelHomeState createState() => _KeepPixelHomeState();
}

class _KeepPixelHomeState extends State<KeepPixelHome> {
  int _selectedIndex = 0;
  String _currentTitle = "Магазин";
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
  List.generate(4, (_) => GlobalKey<NavigatorState>());
  final List<String> _tabTitles = ["Магазин", "Библиотека", "Профиль", "Пиксель"];
  dynamic user;


  Future<void> load() async {
    bool isAuthenticated = await apiService.checkAuth();
    if (isAuthenticated) {
      Map<String, dynamic> profileData = await apiService.getProfile();
      setState(() { // Обновляем UI, если виджет активен
        user = profileData;
      });
      print(user?["profile"]); // Используем ? чтобы избежать ошибки, если user == null
    }
  }

  late StorePage storePage;
  late ProfilePage profilePage;
  late StorePage pixelPage;
  @override
  void initState() {
    super.initState();
    storePage = StorePage(setTitle: _setTitle, navigateTo: _navigateTo);
    profilePage = ProfilePage();
    pixelPage = StorePage(setTitle: _setTitle, navigateTo: _navigateTo);
    _history.add({'page': storePage, 'title': 'Магазин'});
    _history.add({'page': profilePage, 'title': 'Профиль'});
    _history.add({'page': pixelPage, 'title': 'Пиксель'});
    load();

  }


  final ApiService apiService = ApiService();
  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
        _currentTitle = _tabTitles[index];
      });
    }
  }

  // Для сохранения истории страниц
  List<Map<String, dynamic>> _history = [];
  int _historyIndex = 0;

  List<Map<String, dynamic>> _historyProfile = [];
  int _historyIndexProfile = 0;

  List<Map<String, dynamic>> _historyPixel = [];
  int _historyIndexPixel = 0;


  void _setTitle(String title) {
    setState(() {
      _currentTitle = title;
      _tabTitles[_selectedIndex] = title;
    });
  }

  List<Map<String, dynamic>> get _currentHistory {
    switch (_selectedIndex) {
      case 2:
        return _historyProfile;
      case 3:
        return _historyPixel;
      default:
        return _history;
    }
  }

  int get _currentHistoryIndex {
    switch (_selectedIndex) {
      case 2:
        return _historyIndexProfile;
      case 3:
        return _historyIndexPixel;
      default:
        return _historyIndex;
    }
  }

  set _currentHistoryIndex(int value) {
    switch (_selectedIndex) {
      case 2:
        _historyIndexProfile = value;
        break;
      case 3:
        _historyIndexPixel = value;
        break;
      default:
        _historyIndex = value;
        break;
    }
  }

  void _navigateTo(BuildContext context, Widget page, String title) {
    var route = MaterialPageRoute(builder: (context) => page);

    setState(() {
      // Очищаем историю вперед, если идем на новую страницу
      _currentHistory.removeRange(_currentHistoryIndex + 1, _currentHistory.length);

      // Добавляем страницу в историю
      _currentHistory.add({'page': page, 'title': title, 'route': route, 'context': context});
      _currentHistoryIndex++;

      // Обновляем заголовок
      _setTitle(title);
    });

    // Открываем страницу
    Navigator.push(context, route);
  }

  void _goBack() {
    if (_currentHistoryIndex > 0) {
      setState(() {
        _currentHistoryIndex--;
        _setTitle(_currentHistory[_currentHistoryIndex]['title']);
      });

      // Закрываем текущую страницу
      Navigator.pop(_currentHistory[_currentHistoryIndex + 1]['context']);
    }
  }

  void _goForward() {
    if (_currentHistoryIndex < _currentHistory.length - 1) {
      _currentHistoryIndex++;
      _setTitle(_currentHistory[_currentHistoryIndex]['title']);

      // Открываем страницу вперед
      Navigator.push(
        _currentHistory[_currentHistoryIndex]['context'],
        MaterialPageRoute(builder: (context) => _currentHistory[_currentHistoryIndex]['page']),
      );
    }
  }


  Widget _buildOffstageNavigator(int index, Widget child) {
    return Offstage(
      offstage: _selectedIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (routeSettings) =>
            MaterialPageRoute(builder: (_) => child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: Stack(
              children: [
                _buildOffstageNavigator(0, storePage),
                _buildOffstageNavigator(1, LibraryPage()),
                _buildOffstageNavigator(2, profilePage),
                _buildOffstageNavigator(3, Center(child: Text('Пиксель', style: TextStyle(fontSize: 24)))),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAppBar() {
    return WindowTitleBarBox(
      child: Container(
        color: Color(0xFF27272A),
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (!Platform.isMacOS)
              Padding(
                padding: EdgeInsets.only(right: 10),
                child: Row(children: [
                  Image.asset('assets/images/logo.png', width: 20),
                  SizedBox(width: 4),
                  Text('Keep Pixel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Montserrat')),
                ]),
              ),
            if (Platform.isMacOS)
              Container(width: 50,),
            IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.arrow_back,
                color: _selectedIndex != 1 ? _historyIndex > 0 ? Colors.white : Colors.grey : Colors.grey,
              ),
              onPressed: _selectedIndex != 1 ? _historyIndex > 0
                  ? () {
                _goBack(); // Переход назад
              }
                  : null : null,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.arrow_forward,
                color: _selectedIndex != 1 ? _historyIndex < _history.length - 1 ? Colors.white : Colors.grey : Colors.grey,
              ),
              onPressed: _selectedIndex != 1 ? _historyIndex < _history.length - 1
                  ? () {
                _goForward(); // Переход вперед
              }
                  : null : null,
            ),


            Expanded(child: MoveWindow()),
            Text(_currentTitle, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            if (Platform.isMacOS)
              Padding(
                padding: EdgeInsets.only(left: 10),
                child: Row(children: [
                  Image.asset('assets/images/logo.png', width: 20),
                  SizedBox(width: 4),
                  Text('Keep Pixel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Montserrat')),
                ]),
              ),
            MinimizeWindowButton(),
            MaximizeWindowButton(),
            CloseWindowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      color: Color(0xFF27272A),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _navItem(Icons.store, "Магазин", 0),
              _navItem(Icons.library_books, "Библиотека", 1),
              _navItem(Icons.person, "Профиль", 2),
              _navItem(Icons.square, "Пиксель", 3),
            ],
          ),
          FutureBuilder<bool>(
            future: ApiService().checkAuth(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return CircularProgressIndicator();
              }

              bool isLoggedIn = snapshot.data ?? false;

              return isLoggedIn && user != null
                  ? PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == "logout") {
                    apiService.logout(context);
                  }
                },
                color: Color(0xFF27272A), // Цвет фона меню (темный)
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Закругленные углы
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: "settings",
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.white), // Иконка настроек
                        SizedBox(width: 10),
                        Text("Настройки", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "switch",
                    child: Row(
                      children: [
                        Icon(Icons.switch_account, color: Colors.white), // Иконка смены аккаунта
                        SizedBox(width: 10),
                        Text("Сменить аккаунт", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "logout",
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.redAccent), // Красная иконка выхода
                        SizedBox(width: 10),
                        Text("Выйти", style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: user["profile"]?["img"] != null
                          ? NetworkImage(user["profile"]["img"])
                          : AssetImage("assets/default_avatar.png") as ImageProvider, // Заглушка
                      radius: 16, // Чуть больше аватар
                    ),
                    SizedBox(width: 8),
                    Text(
                      user["profile"]?["login"] ?? "Неизвестный",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white), // Иконка стрелки вниз
                  ],
                ),
              )

                  : GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.account_circle, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text("Войти", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _navItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _selectedIndex == index ? Color(0xFF3B5BDB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
