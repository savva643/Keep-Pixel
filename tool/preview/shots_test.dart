import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:keep_pixel/core/installer.dart';
import 'package:keep_pixel/core/downloads.dart';
import 'package:keep_pixel/main.dart';
import 'package:keep_pixel/ui/downloads_page.dart';
import 'package:keep_pixel/ui/style.dart';
import 'package:keep_pixel/ui/settings.dart';
import 'package:keep_pixel/ui/shell.dart';
import 'preview_app.dart';

/// Renders screenshots of every screen into tool/preview/shots:
/// flutter test tool/preview/shots_test.dart
const out = 'tool/preview/shots';

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await family('Montserrat', [
    for (final w in [
      'Light',
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black'
    ])
      'assets/fonts/Montserrat-$w.ttf'
  ]);
  await family('Unbounded', ['assets/fonts/Unbounded.ttf']);
  final icons = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
}

typedef Steps = Future<void> Function(WidgetTester);

Steps openSettings(SettingsSection? section) => (t) async {
      await t.tap(find.text('Профиль').last);
      await settle(t);
      await t.tap(find.byTooltip('Настройки'));
      await settle(t);
      if (section != null) {
        await t.tap(find.byKey(ValueKey('settings-${section.name}')));
        await settle(t);
      }
    };

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

Steps open(String label) => (t) async {
      await t.tap(find.text(label).last);
      await settle(t);
    };

Future<void> shoot(WidgetTester tester, String name, Size size,
    {PreviewScene scene = PreviewScene.full,
    NavStyle nav = NavStyle.dock,
    bool web = false,
    GameInstaller Function()? installer,
    Steps? steps}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = await tester.runAsync(() => previewApi(scene));
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: KeepPixelApp(
          api: api!,
          navStyle: nav,
          web: web,
          installerFactory: installer ?? () => PreviewInstaller(),
          onDownloads:
              scene == PreviewScene.full && !web ? startDemoDownload : null)));
  await settle(tester);
  final context = tester.element(find.byType(PixelShell));
  await tester.runAsync(() async {
    for (final image in [
      'logo.png',
      'keeppixel_logo.png',
      'necsoura_logo.png',
      'necsoura_wordmark.png',
      'blast_log2.png',
      'kompot_logo.png'
    ]) {
      if (context.mounted) {
        await precacheImage(AssetImage('assets/images/$image'), context);
      }
    }
  });
  await tester.pump(const Duration(milliseconds: 400));
  if (steps != null) {
    await http.runWithClient(() => steps(tester), () => previewAccountClient);
  }
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  expect(tester.takeException(), isNull, reason: name);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  api.dispose();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Directory(out).create(recursive: true);
    await loadFonts();
    Localization.load(const Locale('ru'),
        translations: Translations(jsonDecode(
            await rootBundle.loadString('assets/translations/ru.json'))));
  });
  const phone = Size(390, 844), desktop = Size(1440, 900);
  final screens = <String, Steps?>{
    'store': null,
    'library': open('Библиотека'),
    'friends': open('Друзья'),
    'profile': open('Профиль'),
    'downloads': (t) async {
      await t.tap(find.byTooltip('Загрузки').last);
      await settle(t);
    },
    'settings': openSettings(null),
    for (final section in SettingsSection.values)
      if (section != SettingsSection.storage)
        'settings-${section.name}': openSettings(section),
    'game': (t) async {
      await t.tap(find.text('Об игре').first);
      await settle(t);
    },
    'library-game': (t) async {
      await open('Библиотека')(t);
      await t.tap(find.text('Демо: Ночной курьер').first);
      await settle(t);
    },
    'library-menu': (t) async {
      await open('Библиотека')(t);
      await t.longPress(find.text('Демо: Ночной курьер').first);
      await settle(t);
    },
    'library-properties': (t) async {
      await open('Библиотека')(t);
      await t.longPress(find.text('Демо: Ночной курьер').first);
      await settle(t);
      await t.ensureVisible(find.text('Свойства…'));
      await t.tap(find.text('Свойства…'));
      await settle(t);
      await t.tap(find.text('Установка'));
      await settle(t);
    },
  };
  for (final entry in screens.entries) {
    testWidgets('desktop ${entry.key}', (t) async {
      await shoot(t, 'desktop-${entry.key}', desktop, steps: entry.value);
    });
    testWidgets('phone ${entry.key}', (t) async {
      await shoot(t, 'phone-${entry.key}', phone, steps: entry.value);
    });
  }
  testWidgets('desktop right-click menu', (t) async {
    await shoot(t, 'desktop-library-right-click', desktop, steps: (t) async {
      await open('Библиотека')(t);
      await t.tap(find.text('Демо: Город из кубиков').first,
          buttons: kSecondaryButton);
      await settle(t);
    });
  });
  testWidgets('desktop add library folder', (t) async {
    await shoot(t, 'desktop-settings-add-folder', desktop, steps: (t) async {
      await openSettings(SettingsSection.games)(t);
      await t.tap(find.text('Добавить папку на диске'));
      await settle(t);
    });
  });
  testWidgets('phone storage', (t) async {
    await shoot(t, 'phone-settings-storage', phone,
        installer: () => PhonePreviewInstaller(),
        steps: openSettings(SettingsSection.storage));
  });
  for (final (name, size) in [('desktop', desktop), ('phone', phone)]) {
    testWidgets('$name two-factor', (t) async {
      await shoot(t, '$name-settings-2fa', size, steps: (t) async {
        await openSettings(SettingsSection.account)(t);
        await t.tap(find.text('Двухфакторная аутентификация').first);
        await settle(t);
        await t.tap(find.text('Создать новые коды'));
        await settle(t);
        await t.enterText(find.byType(TextField).last, '123456');
        await settle(t);
        await t.tap(find.text('Создать'));
        await settle(t);
      });
    });
  }
  testWidgets('desktop downloads page', (t) async {
    t.view.physicalSize = desktop * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = await t.runAsync(() => previewApi(PreviewScene.full));
    final downloads =
        DownloadsController(api!, factory: () => PreviewInstaller());
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: kpTheme(),
            home: Scaffold(
                body: DownloadsPage(downloads: downloads, onLibrary: () {})))));
    startDemoDownload(downloads);
    await settle(t);
    await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$out/desktop-downloads-page.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    downloads.dispose();
    api.dispose();
  });
  testWidgets('desktop top menu', (t) async {
    await shoot(t, 'desktop-top-menu', desktop, nav: NavStyle.top);
  });
  testWidgets('website', (t) async {
    await shoot(t, 'web-store', desktop, web: true);
  });
  testWidgets('website narrow', (t) async {
    await shoot(t, 'web-phone', phone, web: true);
  });
  testWidgets('store with one game', (t) async {
    await shoot(t, 'desktop-store-one-game', desktop,
        scene: PreviewScene.today);
  });
  testWidgets('phone store with one game', (t) async {
    await shoot(t, 'phone-store-one-game', phone, scene: PreviewScene.today);
  });
  testWidgets('sign in', (t) async {
    await shoot(t, 'desktop-login', desktop, scene: PreviewScene.today,
        steps: (t) async {
      await t.tap(find.text('Войти').first);
      await settle(t);
    });
  });
  testWidgets('sign in on a phone', (t) async {
    await shoot(t, 'phone-login', phone, scene: PreviewScene.today,
        steps: (t) async {
      await t.tap(find.text('Войти').first);
      await settle(t);
    });
  });
}
