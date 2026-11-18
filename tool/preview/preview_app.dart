import 'dart:async';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keep_pixel/core/api.dart';
import 'package:keep_pixel/core/downloads.dart';
import 'package:keep_pixel/core/installer.dart';
import 'package:keep_pixel/core/models.dart';

/// Demo data for design review. Nothing here reaches the server, and these
/// games and people do not exist: production data comes only from the API.
enum PreviewScene {
  /// Filled store for a signed-in player.
  full,

  /// What the real catalog holds today: one project in development, signed out.
  today,
}

Map<String, dynamic> _game(int id, String title, String genre, Object price,
        {String status = 'released', String created = '2026-10-01'}) =>
    {
      'id': id,
      'title': title,
      'description':
          'Демо-описание для проверки дизайна: как текст ложится на баннер и карточку.',
      'price': price,
      'version': '1.0',
      'genre': genre,
      'company': 'Демо-студия',
      'metadata': {
        'release_status': status,
        'platforms': ['Windows'],
        'has_windows_build': true
      },
      'created_at': '${created}T12:00:00Z',
      'updated_at': '${created}T12:00:00Z',
    };

final _fullCatalog = [
  _game(1, 'Демо: Звёздный огород', 'Симулятор', 0, created: '2026-11-04'),
  _game(2, 'Демо: Ночной курьер', 'Приключение', '349.00',
      created: '2026-10-30'),
  _game(3, 'Демо: Тихий бункер', 'Хоррор', '199.00', created: '2026-10-21'),
  _game(4, 'Демо: Гонки на тележках', 'Гонки', 0, created: '2026-10-15'),
  _game(5, 'Демо: Город из кубиков', 'Стратегия', '599.00',
      created: '2026-10-11'),
  _game(6, 'Демо: Пиксельный рейд', 'Экшен', '249.00', created: '2026-10-02'),
  _game(7, 'Демо: Кот-алхимик', 'Головоломка', 0, created: '2026-09-27'),
  _game(8, 'Демо: Мир в разработке', 'Платформа', 0,
      status: 'development', created: '2026-09-20'),
];

final _todayCatalog = [
  {
    ..._game(1, 'Keep Pixel Platform', 'Платформа миров', 0,
        status: 'development', created: '2026-11-05'),
    'description':
        'Платформа пользовательских миров на Godot: игровой клиент, создание миров и редактор для ПК. Проект разрабатывается; установочный релиз пока не опубликован.',
    'company': 'Keep Pixel',
  }
];

const _friends = [
  {
    'global_id': 'a',
    'name': 'Демо-Аня',
    'presence': 'in_game',
    'game_id': 2,
    'game_title': 'Демо: Ночной курьер',
    'relationship': 'accepted'
  },
  {
    'global_id': 'b',
    'name': 'Демо-Боря',
    'presence': 'online',
    'relationship': 'accepted'
  },
  {
    'global_id': 'c',
    'name': 'Демо-Вика',
    'presence': 'in_game',
    'game_id': 5,
    'game_title': 'Демо: Город из кубиков',
    'relationship': 'accepted'
  },
];

/// A phone: no installs, only the memory Keep Pixel takes.
class PhonePreviewInstaller extends PreviewInstaller {
  @override
  bool get supported => false;
  @override
  Future<PhoneStorage?> phoneStorage() async => const PhoneStorage(
      data: 38 << 20, cache: 146 << 20, free: 41 << 30, total: 128 << 30);
}

class PreviewInstaller extends GameInstaller {
  static const installedIds = {'2': '1.0', '3': '1.0', '5': '0.9'};
  final bool animate;
  final _cancel = Completer<void>();
  PreviewInstaller({this.animate = false});
  @override
  bool get supported => true;
  @override
  Future<Map<String, String>> installedGames() async => Map.of(installedIds);
  @override
  Future<Map<String, String>> installedLocations() async => {
        for (final id in installedIds.keys)
          id: id == '3'
              ? 'D:\\KeepPixelLibrary\\$id'
              : 'C:\\Users\\Игрок\\AppData\\Roaming\\Keep Pixel\\games-v2\\$id'
      };
  @override
  Future<List<Drive>> drives() async => const [
        Drive(root: 'C:\\', label: 'Система', free: 61 << 30, total: 237 << 30),
        Drive(root: 'D:\\', label: 'Игры', free: 702 << 30, total: 931 << 30),
        Drive(root: 'E:\\', label: 'Флешка', free: 21 << 30, total: 29 << 30),
      ];
  @override
  Future<List<LibraryFolder>> libraries() async => const [
        LibraryFolder(
            path: r'C:\Users\Игрок\AppData\Roaming\Keep Pixel\games-v2',
            isDefault: true,
            builtIn: true,
            games: 2,
            bytes: 214 << 20,
            free: 61 << 30,
            total: 237 << 30),
        LibraryFolder(
            path: r'D:\KeepPixelLibrary',
            games: 1,
            bytes: 104 << 20,
            free: 702 << 30,
            total: 931 << 30),
      ];
  @override
  Future<int> gameSize(String id) async => 104 << 20;
  @override
  Future<void> moveGame(
      String id, String library, void Function(double) progress) async {}
  @override
  Future<String> addLibrary(String chosen) async => chosen;

  @override
  Future<void> install(
      String id, Map<String, dynamic> manifest, void Function(double) progress,
      {String? library}) async {
    progress(.62);
    if (!animate) return _cancel.future;
    for (var p = .62; p < 1 && !_cancel.isCompleted; p += .01) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      progress(p);
    }
  }

  @override
  void cancel() {
    if (!_cancel.isCompleted) _cancel.complete();
  }

  @override
  Future<void> openFolder([String? path]) async {}

  @override
  Future<void> uninstall(String id) async {}
  @override
  Future<void> launch(String id, Map<String, dynamic> manifest,
      {void Function()? onExit,
      Map<String, String>? environment,
      void Function(int)? onStarted}) async {}
}

/// Answers the shared Necsoura account screens, which make their own requests:
/// wrap what opens them in http.runWithClient.
final previewAccountClient = MockClient((r) async {
  http.Response reply(Object value) =>
      http.Response.bytes(utf8.encode(jsonEncode(value)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
  final path = r.url.path;
  if (path == '/me') {
    return reply({
      'global_id': 'demo',
      'username': 'demo',
      'display_name': 'Демо-игрок',
      'bio': 'Профиль для проверки дизайна.',
      'account': {
        'display_name': 'Демо-игрок',
        'bio': 'Профиль для проверки дизайна.'
      },
      'overrides': {}
    });
  }
  if (path == '/health') return reply({'status': 'ok'});
  if (path.endsWith('/prelogin')) return reply({'scheme': 2});
  if (path.endsWith('/users/profile')) {
    return reply({
      'globalId': 'demo',
      'login': 'demo_login',
      'email': 'demo@example.com',
      'emailVerified': true,
      'kompotName': 'Демо-игрок',
      'kompotUsername': 'demo',
      'publicId': 12
    });
  }
  if (path.endsWith('/sessions')) {
    return reply([
      {
        'sessionId': '1',
        'current': true,
        'service': 'keeppixel',
        'platform': 'windows',
        'deviceName': 'Keep Pixel · windows',
        'deviceType': 'desktop',
        'createdAt': '2026-11-01T12:00:00Z',
        'lastActiveAt': '2026-11-07T12:00:00Z'
      },
      {
        'sessionId': '2',
        'service': 'kompot',
        'platform': 'android',
        'deviceName': 'Kompot · телефон',
        'deviceType': 'mobile',
        'createdAt': '2026-10-20T12:00:00Z',
        'lastActiveAt': '2026-11-06T18:00:00Z'
      }
    ]);
  }
  if (path.endsWith('/oauth/identities')) {
    return reply({
      'hasPassword': true,
      'available': ['vk', 'yandex'],
      'identities': []
    });
  }
  return reply({});
});

Future<PixelApi> previewApi(PreviewScene scene) async {
  final full = scene == PreviewScene.full;
  final catalog = full ? _fullCatalog : _todayCatalog;
  http.Response reply(Object value) =>
      http.Response.bytes(utf8.encode(jsonEncode(value)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
  // ignore: invalid_use_of_visible_for_testing_member
  FlutterSecureStorage.setMockInitialValues(full
      ? {
          'keep_pixel_session_v2': jsonEncode({
            'token': 'demo',
            'refreshToken': 'demo',
            'apiUrl': 'https://demo.invalid',
            'authUrl': 'https://demo.invalid/auth'
          })
        }
      : {});
  final now = DateTime.now();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(full
      ? {
          'keep_pixel_favorites': ['2'],
          'keep_pixel_play_stats': jsonEncode({
            '2': {
              'seconds': 13 * 3600 + 1500,
              'last': now.subtract(const Duration(hours: 2)).toIso8601String()
            },
            '5': {
              'seconds': 2 * 3600 + 600,
              'last': now.subtract(const Duration(days: 1)).toIso8601String()
            },
            '3': {
              'seconds': 2400,
              'last': now.subtract(const Duration(days: 9)).toIso8601String()
            },
          })
        }
      : {});
  final api = PixelApi(
      apiUrl: 'https://demo.invalid',
      authUrl: 'https://demo.invalid/auth',
      client: MockClient((r) async {
        final path = r.url.path;
        if (path == '/games') {
          final q = r.url.queryParameters['q']?.toLowerCase() ?? '';
          final filter = r.url.queryParameters['filter'];
          return reply(catalog
              .where((g) =>
                  '${g['title']}'.toLowerCase().contains(q) &&
                  (filter != 'free' || '${g['price']}' == '0') &&
                  (filter != 'development' ||
                      (g['metadata'] as Map)['release_status'] != 'released'))
              .toList());
        }
        if (path == '/library') {
          return reply(
              catalog.where((g) => [1, 2, 3, 4, 5].contains(g['id'])).toList());
        }
        if (path.startsWith('/games/')) {
          final id = int.tryParse(path.split('/')[2]);
          if (path.endsWith('/download')) {
            return reply({'version': '1.0', 'url': ''});
          }
          final game = catalog.firstWhere((g) => g['id'] == id);
          return reply({
            ...game,
            'metadata': {
              ...(game['metadata'] as Map),
              'trailer': 'https://www.youtube.com/watch?v=demo',
              'screenshots': ['', '', '', ''],
              'achievements': [
                {
                  'title': 'Первая доставка',
                  'description': 'Доставьте первый заказ'
                },
                {
                  'title': 'Ночной рейс',
                  'description': 'Пройдите район ночью без аварий'
                },
                {
                  'title': 'Город наизусть',
                  'description': 'Откройте все районы'
                },
                {
                  'title': 'Без опозданий',
                  'description': '10 заказов подряд вовремя'
                },
              ],
            },
            'features': [
              'Одиночная игра',
              'Сохранения в облаке',
              'Поддержка геймпада'
            ],
            'publisher': 'Keep Pixel',
            'release_date': '2026-10-01',
            'online_stats': [
              {'current_players': 128, 'peak_today': 342}
            ],
            'reviews': [
              {'rating': 5, 'review': 'Атмосферная игра, отличная музыка.'},
              {'rating': 4, 'review': 'Коротко, но очень приятно.'},
            ],
            'social_links': {
              'web': 'https://necsoura.ru',
              'discord': 'https://discord.gg/demo'
            },
            'recommended_requirements': {
              'os': 'Windows 11',
              'processor': '4 ядра, 3 ГГц',
              'memory': '8 ГБ',
              'graphics': 'GTX 1050',
              'storage': '200 МБ'
            },
            'updates': [
              {
                'version': '1.0',
                'title': 'Ночные маршруты',
                'description':
                    'Новый район, ночные заказы и исправления сохранений.'
              },
              {
                'version': '0.9',
                'title': 'Первая публичная версия',
                'description': 'Три района города и режим доставки.'
              },
            ],
            'minimum_requirements': {
              'os': 'Windows 10 64-бит',
              'processor': '2 ядра, 2.5 ГГц',
              'memory': '4 ГБ',
              'graphics': 'С поддержкой OpenGL 3.3',
              'storage': '200 МБ'
            }
          });
        }
        if (path.startsWith('/people/')) {
          return reply({
            'global_id': path.split('/').last,
            'username': 'demo_friend',
            'display_name': 'Демо-друг',
            'avatar': '',
            'banner': '',
            'bio': 'Шапка и фото этого профиля заменены только в Keep Pixel.'
          });
        }
        if (path == '/friends') return reply(_friends);
        if (path.startsWith('/friends/')) return reply([]);
        if (path == '/me') {
          return reply({
            'global_id': 'demo',
            'login': 'demo',
            'username': 'demo',
            'display_name': 'Демо-игрок',
            'avatar': '',
            'banner': '',
            'bio': 'Профиль для проверки дизайна.',
            'account': {'display_name': 'Демо-игрок'},
            'overrides': {}
          });
        }
        if (path.endsWith('/2fa/status')) {
          return reply({
            'isEnabled': true,
            'backupCodesGenerated': true,
            'backupCodesLeft': 6
          });
        }
        if (path.endsWith('/2fa/backup-codes')) {
          return reply({
            'backupCodes': [
              'K7Q2M9XA',
              'P4ZD8L1C',
              'W9N3T6RB',
              'H2V5Y8QE',
              'M6C1J4UF',
              'R3X7B2KD',
              'T8L5P9GN',
              'A1F6W3ZS'
            ]
          });
        }
        return reply({'status': 'ok', 'success': true});
      }));
  await api.initialize();
  return api;
}

/// Starts one demo install so the dock's progress ring is visible.
void startDemoDownload(DownloadsController downloads) {
  scheduleMicrotask(() async {
    final g = await downloads.api.game('4');
    downloads.enqueue(Game(
        id: g.id, title: g.title, version: g.version, metadata: g.metadata));
  });
}
