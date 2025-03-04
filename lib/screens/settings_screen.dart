import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class SettingsPage extends StatelessWidget {
  // Проверка, является ли устройство ПК
  bool isDesktop() {
    return !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF18181B),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            SizedBox(height: 40),
            // Заголовок страницы
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Настройки',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20),
            // Опции настроек
            Expanded(
              child: ListView(
                children: [
                  // Переключатель темы
                  SwitchListTile(
                    title: Text(
                      'Темная тема',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: true,
                    onChanged: (bool value) {
                      // Логика смены темы
                    },
                    activeColor: Color(0xFF4C6EFF),
                    inactiveTrackColor: Color(0xFF4C6EFF).withOpacity(0.3),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SizedBox(height: 20),

                  // Настройка уведомлений
                  SwitchListTile(
                    title: Text(
                      'Уведомления',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: true,
                    onChanged: (bool value) {
                      // Логика уведомлений
                    },
                    activeColor: Color(0xFF4C6EFF),
                    inactiveTrackColor: Color(0xFF4C6EFF).withOpacity(0.3),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SizedBox(height: 20),

                  // Переключатель звука
                  SwitchListTile(
                    title: Text(
                      'Звук в приложении',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: true,
                    onChanged: (bool value) {
                      // Логика звука
                    },
                    activeColor: Color(0xFF4C6EFF),
                    inactiveTrackColor: Color(0xFF4C6EFF).withOpacity(0.3),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SizedBox(height: 20),

                  // Кнопка для сохранения
                  ElevatedButton(
                    onPressed: () {
                      // Логика сохранения настроек
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4C6EFF),
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Сохранить',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Кнопка выхода из аккаунта
                  ElevatedButton(
                    onPressed: () {
                      // Логика выхода из аккаунта
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Выйти из аккаунта',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Страница с переходом в окно
class SettingsPageWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Если устройство ПК, открываем в новом окне
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return GestureDetector(
        onTap: () {
          // Открыть страницу настроек в новом окне
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          );
        },
        child: Container(), // Пустой контейнер для gesture detection
      );
    } else {
      // Для мобильных устройств и веба открываем страницу настроек внутри текущего экрана
      return SettingsPage();
    }
  }
}
