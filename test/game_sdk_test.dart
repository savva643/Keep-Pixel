import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_pixel/core/api.dart';
import 'package:keep_pixel/core/game_overlay.dart';
import 'package:keep_pixel/core/game_sdk_native.dart';

class NativeHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PixelApi api;
  late GameSdkHost host;
  late GameOverlayController overlay;
  late Map<String, String> env;
  final calls = <http.Request>[];
  Completer<void>? holdProfile, started;
  setUp(() async {
    calls.clear();
    holdProfile = null;
    started = null;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'keep_pixel_session_v2': jsonEncode({
        'token': 'ACCOUNT_TOKEN_MUST_NOT_LEAK',
        'refreshToken': 'PRIVATE_REFRESH',
        'apiUrl': 'https://api.example',
        'authUrl': 'https://auth.example'
      })
    });
    api = PixelApi(
        apiUrl: 'https://api.example',
        authUrl: 'https://auth.example',
        client: MockClient((r) async {
          calls.add(r);
          Object data = {'ok': true};
          if (r.url.path == '/me') {
            started?.complete();
            if (holdProfile != null) await holdProfile!.future;
            data = {
              'global_id': 'public-uuid',
              'login': 'PRIVATE_LOGIN',
              'username': 'user',
              'display_name': 'Player',
              'avatar': '',
              'bio': '',
              'email': 'PRIVATE_EMAIL'
            };
          }
          if (r.url.path == '/friends') {
            data = [
              {
                'global_id': 'friend-uuid',
                'name': 'Friend',
                'presence': 'in_game',
                'game_id': 8
              }
            ];
          }
          if (r.url.path == '/license/check') data = {'success': true};
          return http.Response(jsonEncode(data), 200,
              headers: {'content-type': 'application/json'});
        }));
    await api.initialize();
    overlay = GameOverlayController();
    host = GameSdkHost(api, overlay);
    env = await host.create(7, 'Game');
  });
  tearDown(() {
    host.dispose();
    overlay.dispose();
    api.dispose();
  });
  Future<(int, Map<String, dynamic>)> request(String path,
          {String method = 'GET',
          Object? body,
          String? token,
          Map<String, String> headers = const {}}) =>
      HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        try {
          final r = await client.openUrl(
              method, Uri.parse('${env['KEEPPIXEL_SDK_URL']}$path'));
          r.headers.set(
              'Authorization', 'Bearer ${token ?? env['KEEPPIXEL_SDK_TOKEN']}');
          headers.forEach(r.headers.set);
          if (body != null) {
            r.headers.contentType = ContentType.json;
            r.write(jsonEncode(body));
          }
          final response = await r.close();
          return (
            response.statusCode,
            jsonDecode(await utf8.decoder.bind(response).join())
                as Map<String, dynamic>
          );
        } finally {
          client.close(force: true);
        }
      }, NativeHttp());

  test(
      'ephemeral environment exposes no account secrets and SDK profile filters private identity',
      () async {
    expect(env['KEEPPIXEL_SDK_URL'], startsWith('http://127.0.0.1:'));
    expect(env['KEEPPIXEL_SDK_TOKEN']!.length, 43);
    expect(jsonEncode(env), isNot(contains('ACCOUNT_TOKEN')));
    final r = await request('/profile');
    expect(r.$1, 200);
    expect(r.$2['data']['global_id'], 'public-uuid');
    expect(jsonEncode(r.$2), isNot(contains('PRIVATE')));
    final f = await request('/friends');
    expect(f.$2['data'][0]['game_id'], 8);
    expect(
        (await request('/session')).$2['data']['features']['invites'], false);
  });
  test('unauthorized and browser requests never reach the account API',
      () async {
    expect((await request('/profile', token: 'wrong')).$1, 401);
    expect((await request('/profile', token: 'ACCOUNT_TOKEN_MUST_NOT_LEAK')).$1,
        401);
    expect(
        (await request('/profile', headers: {'Origin': 'https://evil.example'}))
            .$1,
        403);
    expect(
        (await request('/profile', headers: {'Host': 'rebinding.example'})).$1,
        403);
    expect(
        (await request('/friends/requests', method: 'POST', body: {})).$1, 404);
    expect(calls, isEmpty);
  });
  test(
      'license and presence are bound to the launched game, and malformed bodies fail closed',
      () async {
    expect((await request('/license')).$2['data']['owned'], true);
    expect(jsonDecode(calls.last.body)['game_id'], 7);
    expect(
        (await request('/presence',
                method: 'POST', body: {'status': 'in_game', 'game_id': 99}))
            .$1,
        400);
    expect((await request('/presence', method: 'POST', body: [])).$1, 400);
    expect(
        (await request('/presence',
                method: 'POST', body: {'status': 'in_game'}))
            .$1,
        200);
    expect(jsonDecode(calls.last.body)['game_id'], 7);
    expect(
        (await request('/overlay', method: 'POST', body: {'visible': true})).$1,
        501);
  });
  test('game exit, replacement session and logout revoke local capabilities',
      () async {
    final old = env['KEEPPIXEL_SDK_TOKEN']!;
    env = await host.create(7, 'Game again');
    expect((await request('/session', token: old)).$1, 401);
    host.revoke(7);
    expect((await request('/profile')).$1, 401);
    env = await host.create(7, 'Game');
    await api.logout();
    expect((await request('/profile')).$1, 401);
  });
  test(
      'logout during a profile fetch cannot leak the previous account response',
      () async {
    holdProfile = Completer<void>();
    started = Completer<void>();
    final pending = request('/profile');
    await started!.future;
    await api.logout();
    holdProfile!.complete();
    final r = await pending;
    expect(r.$1, 401);
    expect(jsonEncode(r.$2), isNot(contains('Player')));
  });
  test('Python adapter exchanges the real native SDK protocol', () async {
    final result = await Process.run(
        'python3', ['sdk/python/test_live_client.py'],
        environment: env);
    expect(result.exitCode, 0, reason: '${result.stdout} ${result.stderr}');
    expect(result.stdout, contains('PYTHON_SDK_OK'));
  }, skip: Platform.environment['KEEP_PIXEL_TEST_ENGINE_ADAPTERS'] != '1');
  test('Godot adapter exchanges the real native SDK protocol', () async {
    final result = await Process.run('godot', [
      '--headless',
      '--path',
      'sdk/godot',
      '--script',
      'res://test_client.gd'
    ], environment: {
      ...env,
      'XDG_DATA_HOME': '/workspace/keeppixel-plugin-review/godot-data',
      'XDG_CACHE_HOME': '/workspace/keeppixel-plugin-review/godot-cache'
    }).timeout(const Duration(seconds: 25));
    expect(result.exitCode, 0, reason: '${result.stdout} ${result.stderr}');
    expect(result.stdout, contains('GODOT_SDK_OK'));
  }, skip: Platform.environment['KEEP_PIXEL_TEST_ENGINE_ADAPTERS'] != '1');
  test('per-game rate limit bounds local API traffic', () async {
    for (var i = 0; i < 120; i++) {
      expect((await request('/session')).$1, 200);
    }
    expect((await request('/session')).$1, 429);
    expect(calls, isEmpty);
  });
}
