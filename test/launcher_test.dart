import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_pixel/core/api.dart';
import 'package:keep_pixel/core/installer.dart';
import 'package:keep_pixel/core/downloads.dart';
import 'package:keep_pixel/core/models.dart';
import 'package:keep_pixel/main.dart';

class SlowInstaller extends GameInstaller {
  final done = Completer<void>();
  bool cancelled = false;
  @override
  bool get supported => true;
  @override
  Future<Map<int, String>> installedGames() async => {};
  @override
  Future<void> install(
      int id, Map<String, dynamic> manifest, void Function(double) progress) {
    progress(.3);
    return done.future;
  }

  @override
  void cancel() {
    cancelled = true;
    if (!done.isCompleted) done.complete();
  }
}

class TrackedInstaller extends GameInstaller {
  void Function()? finished;
  @override
  Future<void> launch(int id, Map<String, dynamic> manifest,
      {void Function()? onExit}) async {
    finished = onExit;
  }
}

http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
Future<PixelApi> makeApi(
    Future<http.Response> Function(http.Request) handler) async {
  FlutterSecureStorage.setMockInitialValues({
    'keep_pixel_session_v2': jsonEncode({
      'token': 'session',
      'refreshToken': 'refresh',
      'apiUrl': 'https://api.example',
      'authUrl': 'https://auth.example'
    })
  });
  final api = PixelApi(
      apiUrl: 'https://api.example',
      authUrl: 'https://auth.example',
      client: MockClient(handler));
  await api.initialize();
  return api;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('game presence follows process completion and cannot stay stuck in-game',
      () async {
    final api = await makeApi((_) async => json({'version': '1.0'}));
    final installer = TrackedInstaller(),
        game = const Game(id: 1, title: 'Тест', version: '1.0');
    final downloads = DownloadsController(api, factory: () => installer);
    await downloads.launch(game);
    expect(downloads.activeGameId, 1);
    await expectLater(downloads.uninstall(game), throwsA(isA<ApiError>()));
    await expectLater(downloads.launch(game), throwsA(isA<ApiError>()));
    installer.finished!();
    expect(downloads.activeGameId, isNull);
    downloads.dispose();
    api.dispose();
  });
  test(
      'account links use the real public IP rather than an API port or parked domain',
      () {
    final api = PixelApi(
        apiUrl: 'http://85.112.56.145:4002',
        authUrl: 'http://85.112.56.145:3001/api/auth');
    expect(api.accountSite, 'http://85.112.56.145');
    api.dispose();
  });
  test(
      'changing server clears authentication and never sends an old bearer to the new host',
      () async {
    final calls = <http.Request>[];
    final api = await makeApi((r) async {
      calls.add(r);
      return json([]);
    });
    expect(api.signedIn, true);
    await api.setEndpoints(
        'http://85.112.56.145:4002', 'http://85.112.56.145:3001/api/auth');
    expect(api.signedIn, false);
    await expectLater(api.library(), throwsA(isA<ApiError>()));
    expect(calls, isEmpty);
    api.dispose();
  });
  test(
      'late unauthorized response from an old server cannot refresh against the new server',
      () async {
    final pending = Completer<http.Response>(), started = Completer<void>();
    final calls = <http.Request>[];
    final api = await makeApi((r) {
      calls.add(r);
      if (!started.isCompleted) started.complete();
      return pending.future;
    });
    final request = api.library();
    await started.future;
    await api.setEndpoints(
        'https://other.example', 'https://other-auth.example');
    pending.complete(json({'code': 'token_expired'}, 401));
    await expectLater(request, throwsA(isA<ApiError>()));
    expect(calls.length, 1);
    expect(api.signedIn, false);
    api.dispose();
  });
  test(
      'HTML 404 reports server and route failure instead of blaming internet access',
      () async {
    final api = await makeApi(
        (r) async => http.Response('<html>Wrong upstream</html>', 404));
    await expectLater(
        api.games(),
        throwsA(predicate((e) =>
            e is ApiError &&
            e.message.contains('404') &&
            e.message.contains('api.example'))));
    api.dispose();
  });
  testWidgets(
      'installation stays active after leaving the library and can be cancelled from downloads',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = {
      'id': 1,
      'title': 'Проверочная игра',
      'description': 'Тест очереди',
      'price': 0,
      'version': '1.0',
      'typeuser': true,
      'metadata': {'has_windows_build': true}
    };
    final api = await makeApi((r) async {
      if (r.url.path == '/games' || r.url.path == '/library') {
        return json([game]);
      }
      if (r.url.path == '/games/1') return json(game);
      if (r.url.path.endsWith('/download')) return json({'version': '1.0'});
      return json({'ok': true});
    });
    final installer = SlowInstaller();
    await tester
        .pumpWidget(KeepPixelApp(api: api, installerFactory: () => installer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Библиотека'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Установить'));
    await tester.pumpAndSettle();
    expect(installer.cancelled, false);
    await tester.tap(find.text('Магазин').first);
    await tester.pumpAndSettle();
    expect(installer.cancelled, false);
    await tester.tap(find.byTooltip('Загрузки'));
    await tester.pumpAndSettle();
    expect(find.text('Установка продолжается при переходе между разделами.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Отменить загрузку'));
    await tester.pumpAndSettle();
    expect(installer.cancelled, true);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets(
      'friends incoming action uses relation ID and refreshes real state',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var accepted = false;
    final actions = <String>[];
    final api = await makeApi((r) async {
      if (r.url.path == '/friends/requests') {
        return json(accepted
            ? []
            : [
                {
                  'global_id': 'friend',
                  'relation_id': 'relation',
                  'name': 'Друг',
                  'direction': 'incoming',
                  'relationship': 'pending'
                }
              ]);
      }
      if (r.url.path == '/friends/relation/accept') {
        accepted = true;
        actions.add(r.url.path);
        return json({'success': true});
      }
      if (r.url.path.startsWith('/friends') || r.url.path == '/games') {
        return json([]);
      }
      return json({'ok': true});
    });
    await tester.pumpWidget(KeepPixelApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Друзья'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Заявки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Принять'));
    await tester.pumpAndSettle();
    expect(actions, ['/friends/relation/accept']);
    expect(find.text('Новых заявок нет'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
