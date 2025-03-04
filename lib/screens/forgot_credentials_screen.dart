import 'package:flutter/material.dart';
import 'package:keep_pixel/screens/main_screen.dart';
import 'package:keep_pixel/screens/register_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Для иконок
import '../api/api_services.dart';
import 'forgot_credentials_screen.dart';

class ForgotCredentialsPage extends StatefulWidget {
  @override
  _ForgotCredentialsPageState createState() => _ForgotCredentialsPageState();
}

class _ForgotCredentialsPageState extends State<ForgotCredentialsPage> {
  final TextEditingController _emailController = TextEditingController();
  final ApiService apiService = ApiService();
  bool _isLoading = false;

  // Функция отправки логина на почту
  void _sendLoginToEmail() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Введите вашу почту")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String result = await apiService.sendLoginToEmail(email);

    setState(() {
      _isLoading = false;
    });

    if (result == "success") {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Логин отправлен на вашу почту")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка при отправке логина")));
    }
  }

  // Функция для отправки кода на почту
  void _sendPasswordResetCode() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Введите вашу почту")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String result = await apiService.sendPasswordResetCode(email);

    setState(() {
      _isLoading = false;
    });

    if (result == "success") {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Код для восстановления пароля отправлен")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка при отправке кода")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF18181B),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Логотип приложения
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 80),
                SizedBox(width: 10),
                Text('Keep Pixel', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Montserrat')),
              ],
            ),
            SizedBox(height: 24),

            // Поле для ввода email
            TextField(
              controller: _emailController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Введите вашу почту",
                prefixIcon: Icon(Icons.email, color: Colors.white70),
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

            // Кнопка для отправки логина на почту
            ElevatedButton.icon(
              onPressed: _sendLoginToEmail,
              icon: Icon(FontAwesomeIcons.envelope, size: 18),
              label: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Отправить логин на почту", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4C6EFF),
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 16),

            // Кнопка для восстановления пароля
            ElevatedButton.icon(
              onPressed: _sendPasswordResetCode,
              icon: Icon(FontAwesomeIcons.key, size: 18),
              label: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Восстановить пароль", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4C6EFF),
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 16),

            // Возврат на экран логина
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Назад", style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
