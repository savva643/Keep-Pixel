import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_services.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nickController = TextEditingController();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _password2Controller = TextEditingController();
  final ApiService apiService = ApiService();

  bool _obscurePassword = true;
  bool _obscurePassword2 = true;

  void _register() async {
    var response = await apiService.register(
      _nickController.text,
      _loginController.text,
      _emailController.text,
      _passwordController.text,
      _password2Controller.text,
    );
    if (response['success']) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response['token']);
      Navigator.pushReplacementNamed(context, '/store');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

    return Scaffold(
      backgroundColor: Color(0xFF18181B),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 80 : kToolbarHeight),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  "Регистрация",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ),
            Positioned(
              top: isDesktop ? 30 : 0,
              left: isDesktop ? 10 : 0,
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

            _buildTextField("Ник", _nickController, Icons.person),
            SizedBox(height: 16),
            _buildTextField("Логин", _loginController, Icons.account_circle),
            SizedBox(height: 16),
            _buildTextField("Email", _emailController, Icons.email),
            SizedBox(height: 16),
            _buildPasswordField("Пароль", _passwordController, _obscurePassword, () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            }),
            SizedBox(height: 16),
            _buildPasswordField("Повторите пароль", _password2Controller, _obscurePassword2, () {
              setState(() {
                _obscurePassword2 = !_obscurePassword2;
              });
            }),
            SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _register,
              icon: Icon(Icons.check, size: 18),
              label: Text("Зарегистрироваться", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4C6EFF),
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Уже есть аккаунт? Войти", style: TextStyle(color: Color(0xFF4C6EFF))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Color(0xFF27272A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscureText, Function() toggleVisibility) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
          onPressed: toggleVisibility,
        ),
        filled: true,
        fillColor: Color(0xFF27272A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: Colors.white70),
      ),
    );
  }
}
