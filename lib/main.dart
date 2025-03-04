import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:keep_pixel/screens/main_screen.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';


void main() {
  runApp(Phoenix(child:KeepPixelApp()));

  // Настройка окна для Windows/macOS
  doWhenWindowReady(() {
    final win = appWindow;
    win.minSize = Size(800, 600);
    win.size = Size(1280, 720);
    win.alignment = Alignment.center;
    win.title = "Keep Pixel";
    win.show();
  });
}

class KeepPixelApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFF18181B),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFF4F4F5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4C6EFF), // Цвет кнопки
            foregroundColor: Color(0xFFF4F4F5), // Цвет текста
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: Color(0xFF27272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: KeepPixelHome(),
    );
  }
}

