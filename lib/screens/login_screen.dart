import 'package:flutter/material.dart';
import 'package:keep_pixel/screens/main_screen.dart';
import 'package:keep_pixel/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Иконки
import '../api/api_services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'forgot_credentials_screen.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService apiService = ApiService();
  bool _obscurePassword = true;

  void _login() async {
    String login = _loginController.text.trim();
    String password = _passwordController.text.trim();

    if (login.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Введите логин и пароль")),
      );
      return;
    }

    var response = await apiService.login(login, password);
    if (response['success']) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response['token']);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => KeepPixelHome()),
            (Route<dynamic> route) => false, // Удаляет все предыдущие маршруты
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'])),
      );
    }
  }




  @override
  Widget build(BuildContext context) {
    bool isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

    return Scaffold(
      backgroundColor: Color(0xFF18181B),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 80 : kToolbarHeight), // На ПК выше
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  "Вход",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ),
            if (isDesktop)
              Positioned(
                top: 30, // Опускаем кнопку ниже на ПК
                left: 10,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            else
              Positioned(
                top: 0, // Обычная позиция для мобильных
                left: 0,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Image.asset('assets/images/logo.png', width: 80),
              SizedBox(width: 10),
              Text('Keep Pixel', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Montserrat')),
            ]),
            SizedBox(height: 24),

            // Поле ввода логина
            TextField(
              controller: _loginController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Логин",
                prefixIcon: Icon(Icons.person, color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF27272A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            SizedBox(height: 16),

            // Поле ввода пароля
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Пароль",
                prefixIcon: Icon(Icons.lock, color: Colors.white70),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Color(0xFF27272A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            SizedBox(height: 24),

            // Кнопка Войти
            ElevatedButton.icon(
              onPressed: _login,
              icon: Icon(FontAwesomeIcons.signInAlt, size: 18),
              label: Text("Войти", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4C6EFF),
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 16),

            // Регистрация и восстановление пароля
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Нет аккаунта?", style: TextStyle(color: Colors.white70)),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterPage()),
                  ),
                  child: Text("Регистрация", style: TextStyle(color: Color(0xFF4C6EFF))),
                ),
              ],
            ),

            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ForgotCredentialsPage()),
              ),
              child: Text("Забыли пароль или логин?", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

}