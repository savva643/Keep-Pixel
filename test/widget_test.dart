import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_pixel/core/api.dart';
import 'package:keep_pixel/main.dart';

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
          'keep_pixel_session_v2':
              jsonEncode({'token': 'session', 'refreshToken': 'refresh'})
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
      expect(find.text('Найди свою следующую игру'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Библиотека').last);
      await tester.pumpAndSettle();
      expect(find.text('Твои игры будут здесь'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    });
  }
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
    await tester.tap(find.text('Мой профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Общее имя'), findsOneWidget);
    await tester.tap(find.text('Настроить профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Имя в магазине');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(sent.single, {'display_name': 'Имя в магазине'});
    expect(find.text('Имя в магазине'), findsOneWidget);
    await tester.tap(find.text('Настроить профиль'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Всё из основного профиля'));
    await tester.tap(find.text('Всё из основного профиля'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(sent.last, {'display_name': null});
    expect(find.text('Общее имя'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
