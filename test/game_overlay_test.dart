import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_pixel/core/api.dart';
import 'package:keep_pixel/core/game_overlay.dart';
import 'package:keep_pixel/ui/game_overlay.dart';

class PreviewOverlay extends GameOverlayController {
  int closes = 0;
  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
  testWidgets(
      'game panel renders friends, switches profile and returns to the game',
      (tester) async {
    tester.view.physicalSize = const Size(1120, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'keep_pixel_session_v2': jsonEncode({
        'token': 'test-session',
        'apiUrl': 'https://api.example',
        'authUrl': 'https://auth.example'
      })
    });
    final api = PixelApi(
        apiUrl: 'https://api.example',
        authUrl: 'https://auth.example',
        client: MockClient((r) async {
          Object data = [];
          if (r.url.path == '/friends') {
            data = [
              {
                'global_id': '1',
                'relationship': 'accepted',
                'game_title': 'Pixel Arena',
                'name': 'Alex',
                'username': 'alex',
                'presence': 'in_game',
                'game_id': 7
              },
              {
                'global_id': '2',
                'relationship': 'accepted',
                'name': 'PixelFox',
                'username': 'pixelfox',
                'presence': 'online'
              },
              {
                'global_id': '3',
                'relationship': 'accepted',
                'name': 'Moonlight',
                'username': 'moonlight',
                'presence': 'away'
              }
            ];
          }
          if (r.url.path == '/me') {
            data = {
              'global_id': 'self',
              'username': 'savva',
              'display_name': 'Savva',
              'avatar': '',
              'bio': 'Keep Pixel player'
            };
          }
          return http.Response(jsonEncode(data), 200,
              headers: {'content-type': 'application/json'});
        }));
    await api.initialize();
    final overlay = PreviewOverlay();
    overlay.games[7] = 'Keep Pixel — игровая сессия';
    overlay.gameId = 7;
    overlay.visible = true;
    final boundaryKey = GlobalKey();
    final screenshot = Platform.environment['KEEP_PIXEL_OVERLAY_SCREENSHOT'];
    if (screenshot != null) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (final family in ['Montserrat', 'Unbounded']) {
        final font = FontLoader(family)
          ..addFont(rootBundle.load(family == 'Unbounded'
              ? 'assets/fonts/Unbounded.ttf'
              : 'assets/fonts/Montserrat-Regular.ttf'));
        await font.load();
      }
    }
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamily: 'Montserrat',
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF83B7FF),
                brightness: Brightness.dark)),
        home: RepaintBoundary(
            key: boundaryKey, child: GamePanel(api: api, overlay: overlay))));
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('PixelFox'), findsOneWidget);
    if (screenshot != null) {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(screenshot).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Мой профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Savva'), findsWidgets);
    await tester.tap(find.text('Вернуться · Shift+Tab'));
    await tester.pumpAndSettle();
    expect(overlay.closes, 1);
    await tester.pumpWidget(const SizedBox());
    overlay.dispose();
    api.dispose();
  });
}
