import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_pixel/core/api.dart';
import 'package:keep_pixel/main.dart';
import 'dart:io';
import 'package:keep_pixel/ui/settings.dart';

const games = [
  {
    'id': 1,
    'title': 'Тестовая игра',
    'description': 'Описание настоящей карточки из API.',
    'price': '0.00',
    'genre': 'Приключение',
    'metadata': {}
  },
  {
    'id': '2',
    'title': 'Будущий проект',
    'description': 'В разработке',
    'price': 0,
    'metadata': {'release_status': 'development'}
  },
];

Future<PixelApi> apiFor(http.Response Function(http.Request) handle,
    {bool signedIn = false}) async {
  FlutterSecureStorage.setMockInitialValues(signedIn
      ? {
          'keep_pixel_session_v2': jsonEncode({
            'token': 'session',
            'refreshToken': 'refresh',
            'apiUrl': 'https://api.example',
            'authUrl': 'https://auth.example'
          })
        }
      : {});
  final api = PixelApi(
      apiUrl: 'https://api.example',
      authUrl: 'https://auth.example',
      client: MockClient((r) async => handle(r)));
  await api.initialize();
  return api;
}

http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('catalog and authenticated-only library fit $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = await apiFor((r) => json(games));
      await tester.pumpWidget(KeepPixelApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('Магазин'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Библиотека').last);
      await tester.pumpAndSettle();
      expect(find.text('Твои игры будут здесь'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    });
  }
  testWidgets('the website has a top menu and no library, like Steam',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = await apiFor((r) => json(games));
    await tester.pumpWidget(KeepPixelApp(api: api, web: true));
    await tester.pumpAndSettle();
    expect(find.text('Магазин'), findsOneWidget);
    expect(find.text('Библиотека'), findsNothing);
    expect(find.text('Загрузки'), findsNothing);
    expect(find.text('Скачать клиент'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets('a phone uses the floating dock, not a bottom bar',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = await apiFor((r) => json(games));
    await tester.pumpWidget(KeepPixelApp(api: api, navStyle: NavStyle.top));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Библиотека'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets('catalog with one game shows it once and explains the rest',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = await apiFor((r) => json([
          {
            'id': '4f516806-ae26-46e4-ba87-bba1ca2c59c9',
            'title': 'Единственная игра',
            'description': 'Описание',
            'price': '0.00',
            'metadata': {'release_status': 'development'}
          }
        ]));
    await tester.pumpWidget(KeepPixelApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Единственная игра'), findsOneWidget);
    expect(find.text('Каталог только начинается'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  test('the version in the settings matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
        RegExp(r'^version: ([\d.]+)', multiLine: true).firstMatch(pubspec)![1],
        appVersion);
  });
  test('a second window borrows the session and never stores it', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final calls = <String>[];
    var tokens = 0;
    final api = PixelApi(
        client: MockClient((r) async =>
            r.headers['Authorization'] == 'Bearer fresh'
                ? json({'global_id': 'id', 'overrides': {}})
                : json({'message': 'expired'}, 401)),
        owner: SessionOwner(
            renew: () async {
              tokens++;
              return 'fresh';
            },
            apply: (_) async => calls.add('apply'),
            logout: () async => calls.add('logout'),
            profileChanged: () async => calls.add('profile')));
    api.adoptSession(
        token: 'old',
        apiUrl: 'https://api.example',
        authUrl: 'https://auth.example',
        device: 'abc');
    final generation = api.sessionGeneration;
    await api.profile();
    expect(tokens, 1);
    expect(api.sessionToken, 'fresh');
    expect(api.sessionGeneration, generation);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    await api.applySession({'token': 'next'});
    api.profileChanged();
    await api.logout();
    expect(calls, ['apply', 'profile', 'logout']);
    expect(api.signedIn, isFalse);
  });
  testWidgets('settings keep categories at the left and open the chosen one',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = await apiFor((r) => json(games));
    NavStyle? chosen;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SettingsView(
                api: api,
                installer: null,
                navStyle: NavStyle.dock,
                onNavStyle: (style) => chosen = style,
                startPage: 0,
                onSaveEndpoints: (_, __) async => '',
                onSignIn: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Войди в аккаунт Necsoura'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-games')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-interface')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Верхнее меню'));
    expect(chosen, NavStyle.top);
    await tester.tap(find.byKey(const ValueKey('settings-connection')));
    await tester.pumpAndSettle();
    expect(find.text('Адрес API магазина'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets('catalog failures show a real retry action', (tester) async {
    var calls = 0;
    final api = await apiFor((r) => ++calls == 1
        ? json({'message': 'Каталог недоступен'}, 503)
        : json(games));
    await tester.pumpWidget(KeepPixelApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить каталог'), findsOneWidget);
    await tester.ensureVisible(find.text('Повторить'));
    await tester.ensureVisible(find.text('Повторить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Не удалось загрузить каталог'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets(
      'profile editing sends only changed local fields and can restore inheritance',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var overrides = <String, dynamic>{};
    final sent = <Map<String, dynamic>>[];
    final api = await apiFor((r) {
      if (r.url.path == '/games') return json(games);
      if (r.method == 'PATCH') {
        final patch =
            Map<String, dynamic>.from((jsonDecode(r.body) as Map)['overrides']);
        sent.add(patch);
        overrides.addAll(patch);
        overrides.removeWhere((k, v) => v == null);
      }
      return json({
        'global_id': 'id',
        'login': 'shared_login',
        'username': 'public_name',
        'display_name': overrides['display_name'] ?? 'Общее имя',
        'avatar': '',
        'banner': '',
        'bio': '',
        'account': {'display_name': 'Общее имя'},
        'overrides': overrides
      });
    }, signedIn: true);
    await tester.pumpWidget(KeepPixelApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Общее имя'), findsOneWidget);
    await tester.tap(find.text('Настроить профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Имя в магазине');
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(sent.single, {'display_name': 'Имя в магазине'});
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Имя в магазине'), findsOneWidget);
    await tester.tap(find.text('Настроить профиль'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Всё из основного профиля'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Всё из основного профиля'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(sent.last, {'display_name': null});
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Общее имя'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
