import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = "https://keeppixel.store/api.php";

  Future<Map<String, dynamic>> login(String login, String password) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "login",
        "login": login,
        "password": password,
      }),
    );
    final data = jsonDecode(response.body);
    if (data["success"] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", data["token"]);
    }
    return data;
  }

  Future<Map<String, dynamic>> register(
      String nick, String login, String email, String password, String password2) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "register",
        "nick": nick,
        "login": login,
        "email": email,
        "password": password,
        "password2": password2,
      }),
    );
    final data = jsonDecode(response.body);
    if (data["success"] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", data["token"]);
    }
    return data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "profile",
        if (token != null) "token": token,
      }),
    );
    return jsonDecode(response.body);
  }

  // В ApiService
  Future<Map<String, dynamic>> getOtherProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "idprofile",
        "user_id": userId,  // Передаем userId для получения чужого профиля
        if (token != null) "token": token,
      }),
    );
    return jsonDecode(response.body);
  }


  Future<bool> checkAuth() async {
    final profile = await getProfile();
    if (profile['success'] == true) {
      return true;
    } else {
      return false;
    }
  }

  Future<List<dynamic>> getUserLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "library",
        if (token != null) "token": token,
      }),
    );
    final data = jsonDecode(response.body);
    print(jsonEncode({
      "action": "library",
      if (token != null) "token": token,
    }.toString()));
    print(data);
    return data['success'] ? data['games'] : [];
  }

  Future<List<dynamic>> getRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "recommendations",
        if (token != null) "token": token,
      }),
    );
    final data = jsonDecode(response.body);
    print(data['recommendations']);
    return data['success'] ? data['recommendations'] : [];
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    Phoenix.rebirth(context); // Перезапускаем приложение
  }

  // Получение логина по email
  Future<Map<String, dynamic>?> getLoginByEmail(String email) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "getLoginByEmail",
        "email": email,
      }),
    );

    final data = jsonDecode(response.body);
    print("Response: $data");

    if (data['success']) {
      return {
        'login': data['login'], // Логин
        'email': data['email'], // Почта
      };
    } else {
      return null;
    }
  }

  // Отправка кода на почту для восстановления пароля
  Future<String> sendPasswordResetCode(String email) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "sendPasswordResetCode",
        "email": email,
      }),
    );

    final data = jsonDecode(response.body);
    print("Response: $data");

    if (data['success']) {
      return "success"; // Успешно отправлен код
    } else {
      return "error"; // Ошибка при отправке
    }
  }

  // Отправка логина на почту
  Future<String> sendLoginToEmail(String email) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "action": "sendLoginToEmail",
        "email": email,
      }),
    );

    final data = jsonDecode(response.body);
    print("Response: $data");

    if (data['success']) {
      return "success"; // Логин успешно отправлен
    } else {
      return "error"; // Ошибка при отправке логина
    }
  }
}
