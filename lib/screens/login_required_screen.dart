import 'package:flutter/material.dart';

import 'login_screen.dart';

class LoginRequiredPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF18181B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/logo.png", width: 150),
            SizedBox(height: 20),
            Text(
              "Войдите, чтобы просмотреть библиотеку",
              style: TextStyle(
                color: Color(0xFFF4F4F5),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4C6EFF),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Перенаправление на страницу входа
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );

              },
              child: Text("Войти"),
            ),
          ],
        ),
      ),
    );
  }
}
