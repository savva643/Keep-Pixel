import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/api.dart';
import 'ui/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = PixelApi();
  runApp(KeepPixelApp(api: api));
  api.initialize();
  if (!kIsWeb &&
      {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
          .contains(defaultTargetPlatform)) {
    doWhenWindowReady(() {
      appWindow.minSize = const Size(420, 640);
      appWindow.size = const Size(1360, 900);
      appWindow.alignment = Alignment.center;
      appWindow.title = 'Keep Pixel';
      appWindow.show();
    });
  }
}

class KeepPixelApp extends StatelessWidget {
  final PixelApi api;
  const KeepPixelApp({super.key, required this.api});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Keep Pixel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: 'Montserrat',
          fontFamilyFallback: const ['NotoSans'],
          scaffoldBackgroundColor: const Color(0xFF101414),
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFAAE8BC),
              brightness: Brightness.dark,
              surface: const Color(0xFF191F1E)),
          cardTheme: CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: const Color(0xFF1C2422),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24))),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF222B28),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none)),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)))),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)))),
        ),
        home: PixelShell(api: api),
      );
}
