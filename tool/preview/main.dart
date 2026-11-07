import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:keep_pixel/main.dart';
import 'package:keep_pixel/ui/settings.dart';
import 'package:keep_pixel/ui/settings_window.dart';
import 'preview_app.dart';

/// Live design prototype on demo data:
/// flutter run -d windows -t tool/preview/main.dart --dart-define=NAV=dock --dart-define=SCENE=full
/// NAV is dock or top; without it the menu follows the settings. SCENE is full or today.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final settingsWindow = SettingsWindow.fromArguments(args);
  if (settingsWindow != null) {
    http.runWithClient(() => runApp(withAccountStrings(settingsWindow)),
        () => previewAccountClient);
    return;
  }
  const nav = String.fromEnvironment('NAV');
  const sceneName = String.fromEnvironment('SCENE', defaultValue: 'full');
  const scene = sceneName == 'today' ? PreviewScene.today : PreviewScene.full;
  final api = await previewApi(scene);
  runApp(withAccountStrings(KeepPixelApp(
      api: api,
      navStyle:
          nav.isEmpty ? null : (nav == 'top' ? NavStyle.top : NavStyle.dock),
      web: const bool.fromEnvironment('WEB', defaultValue: kIsWeb),
      installerFactory: () => PreviewInstaller(animate: true),
      onDownloads: scene == PreviewScene.full ? startDemoDownload : null)));
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    doWhenWindowReady(() {
      appWindow.minSize = const Size(420, 640);
      appWindow.size = const Size(1360, 900);
      appWindow.alignment = Alignment.center;
      appWindow.title = 'Keep Pixel: прототип';
      appWindow.show();
      if (const bool.fromEnvironment('OPEN_SETTINGS')) {
        Future<void>.delayed(const Duration(seconds: 3),
            () => SettingsWindow.open(navStyle: NavStyle.dock, startPage: 0));
      }
      if (const bool.fromEnvironment('MAXIMIZED')) appWindow.maximize();
    });
  }
}
