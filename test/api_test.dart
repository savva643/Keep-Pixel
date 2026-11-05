import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_pixel/core/api.dart';
import 'package:keep_pixel/core/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'real login derives the Necsoura key and completes the second factor without saving a pending token',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = PixelApi(
        authUrl: 'https://auth.example',
        client: MockClient((r) async {
          if (r.url.path == '/prelogin') {
            return http.Response(
                '{"scheme":2,"kdf":{"algorithm":"argon2id","memory":19456,"iterations":2,"parallelism":1,"salt":"AAECAwQFBgcICQoLDA0ODw=="}}',
                200);
          }
          final body = jsonDecode(r.body) as Map;
          if (r.url.path == '/login') {
            expect(body.containsKey('password'), false);
            expect(body['authKey'],
                't6VWDvyt30L3lnE3OKfXmgPbRtNs0drLEC/YhAT28cA=');
            return http.Response(
                '{"requires2FA":true,"twoFactorToken":"pending-only"}', 202);
          }
          expect(r.url.path, '/login/2fa');
          expect(body['twoFactorToken'], 'pending-only');
          expect(body['code'], '123456');
          return http.Response(
              '{"token":"verified-session","refreshToken":"verified-refresh"}',
              200);
        }));
    await api.initialize();
    expect(await api.login('user', 'пароль 🔑'), false);
    expect(api.signedIn, false);
    await api.confirm2fa('123456');
    expect(api.signedIn, true);
    api.dispose();
  });
  test(
      'numeric IDs/prices and future releases parse without legacy string assumptions',
      () {
    final g = Game.fromJson({
      'id': 7,
      'title': 'Игра',
      'price': '149.90',
      'metadata': {'release_status': 'development'}
    });
    expect(g.id, 7);
    expect(g.price, 149.9);
    expect(g.released, false);
    expect(g.priceLabel, 'В разработке');
  });
  test('protected calls refresh a session once and retry with the new bearer',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'keep_pixel_session_v2': jsonEncode({
        'token': 'expired',
        'refreshToken': 'refresh',
        'apiUrl': 'https://api.example',
        'authUrl': 'https://auth.example'
      })
    });
    final requests = <http.Request>[];
    final api = PixelApi(
        apiUrl: 'https://api.example',
        authUrl: 'https://auth.example',
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path == '/refresh') {
            expect(jsonDecode(r.body)['refreshToken'], 'refresh');
            return http.Response(
                '{"token":"new-token","refreshToken":"rotated"}', 200);
          }
          if (r.headers['Authorization'] == 'Bearer expired') {
            return http.Response('{"code":"token_expired"}', 401);
          }
          expect(r.headers['Authorization'], 'Bearer new-token');
          return http.Response('[]', 200);
        }));
    await api.initialize();
    await api.library();
    expect(requests.length, 3);
    expect(api.signedIn, true);
    api.dispose();
  });
  test('expired refresh clears credentials; HTTP errors are useful to callers',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'keep_pixel_session_v2':
          '{"token":"expired","refreshToken":"invalid","apiUrl":"https://api.example","authUrl":"https://auth.example"}'
    });
    final api = PixelApi(
        apiUrl: 'https://api.example',
        authUrl: 'https://auth.example',
        client: MockClient((r) async => http.Response(
            '{"code":"session_revoked","message":"Сеанс завершён"}', 401,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    await api.initialize();
    await expectLater(api.library(), throwsA(isA<ApiError>()));
    expect(api.signedIn, false);
    api.dispose();
  });
  test(
      'malformed responses produce a controlled error instead of dynamic crashes',
      () async {
    final api = PixelApi(
        client: MockClient(
            (r) async => http.Response('<html>gateway</html>', 502)));
    await expectLater(api.games(), throwsA(isA<ApiError>()));
    api.dispose();
  });
}
