import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/api.dart';
import 'core/downloads.dart';
import 'core/installer.dart';
import 'ui/settings.dart';
import 'ui/settings_window.dart';
import 'ui/shell.dart';
import 'ui/style.dart';

/// Translations for the shared Necsoura account screens.
Widget withAccountStrings(Widget child) => EasyLocalization(
    supportedLocales: const [Locale('ru')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('ru'),
    useOnlyLangCode: true,
    saveLocale: false,
    path: 'assets/translations',
    child: child);

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final settingsWindow = SettingsWindow.fromArguments(args);
  if (settingsWindow != null) {
    runApp(withAccountStrings(settingsWindow));
    return;
  }
  final api = PixelApi();
  runApp(withAccountStrings(KeepPixelApp(api: api)));
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
  final NavStyle? navStyle;
  final bool web;
  final void Function(DownloadsController)? onDownloads;
  const KeepPixelApp(
      {super.key,
      required this.api,
      this.installerFactory,
      this.navStyle,
      this.web = kIsWeb,
      this.onDownloads});
  @override
  Widget build(BuildContext context) {
    final strings = EasyLocalization.of(context);
    return MaterialApp(
      title: 'Keep Pixel',
      debugShowCheckedModeBanner: false,
      theme: kpTheme(),
      localizationsDelegates:
          strings?.delegates ?? GlobalMaterialLocalizations.delegates,
      supportedLocales: strings?.supportedLocales ?? const [Locale('ru')],
      locale: strings?.locale ?? const Locale('ru'),
      home: PixelShell(
          api: api,
          installerFactory: installerFactory,
          navStyle: navStyle,
          web: web,
          onDownloads: onDownloads),
    );
  }
}
