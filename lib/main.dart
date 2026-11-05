import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/api.dart';
import 'core/installer.dart';
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
  final GameInstaller Function()? installerFactory;
  const KeepPixelApp({super.key, required this.api, this.installerFactory});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Keep Pixel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: 'Montserrat',
          fontFamilyFallback: const ['NotoSans'],
          scaffoldBackgroundColor: const Color(0xFF11161D),
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF83B7FF),
              brightness: Brightness.dark,
              surface: const Color(0xFF19212B)),
          cardTheme: CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: const Color(0xFF1C2632),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF202B38),
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
        home: PixelShell(api: api, installerFactory: installerFactory),
      );
}
