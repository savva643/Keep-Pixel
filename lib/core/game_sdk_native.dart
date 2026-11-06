import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'api.dart';
import 'game_overlay.dart';

class _GameSession {
  final int id, generation;
  final String title, secret;
  int active = 0, requests = 0;
  DateTime window = DateTime.now();
  _GameSession(this.id, this.title, this.secret, this.generation);
}

/// Engine-neutral v1 API. Account tokens never cross this loopback boundary.
class GameSdkHost {
  final PixelApi api;
  final GameOverlayController overlay;
  final _sessions = <int, _GameSession>{};
  HttpServer? _server;
  Future<HttpServer>? _starting;
  bool _disposed = false;
  GameSdkHost(this.api, this.overlay) {
    api.addListener(_sessionChanged);
  }
  void _sessionChanged() {
    _sessions.removeWhere(
        (_, s) => !api.signedIn || s.generation != api.sessionGeneration);
  }

  Future<Map<String, String>> create(int id, String title) async {
    if (_disposed || !api.signedIn || id < 1) {
      throw const ApiError('Войдите перед запуском игры', status: 401);
    }
    final generation = api.sessionGeneration;
    _starting ??=
        HttpServer.bind(InternetAddress.loopbackIPv4, 0).then((server) {
      if (_disposed) {
        unawaited(server.close(force: true));
        throw StateError('SDK host disposed');
      }
      _server = server;
      server.listen((request) => unawaited(_handle(request)));
      return server;
    }).catchError((Object e) {
      _starting = null;
      throw e;
    });
    final server = await _starting!;
    if (_disposed || generation != api.sessionGeneration || !api.signedIn) {
      throw const ApiError('Сеанс изменился во время запуска', status: 401);
    }
    final random = Random.secure();
    final secret = base64Url
        .encode(List<int>.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    _sessions[id] = _GameSession(id, title, secret, generation);
    return {
      'KEEPPIXEL_SDK_URL': 'http://127.0.0.1:${server.port}/v1',
      'KEEPPIXEL_SDK_TOKEN': secret,
      'KEEPPIXEL_GAME_ID': '$id'
    };
  }

  bool _equal(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> _handle(HttpRequest request) async {
    _GameSession? session;
    var counted = false;
    var status = 200;
    Object? data;
    Object? error;
    try {
      if (_disposed ||
          request.headers.value('origin') != null ||
          request.headers.value('sec-fetch-site') != null ||
          request.headers.value('host') != '127.0.0.1:${_server?.port}' ||
          request.connectionInfo?.remoteAddress.isLoopback != true) {
        throw const ApiError('Local native SDK requests only',
            code: 'local_only', status: 403);
      }
      final auth = request.headers.value('authorization') ?? '';
      if (!auth.startsWith('Bearer ') || auth.length > 128) {
        throw const ApiError('Game capability required',
            code: 'unauthorized', status: 401);
      }
      for (final s in _sessions.values) {
        if (_equal(auth.substring(7), s.secret)) {
          session = s;
          break;
        }
      }
      if (session == null ||
          !api.signedIn ||
          session.generation != api.sessionGeneration) {
        throw const ApiError('Game capability expired',
            code: 'unauthorized', status: 401);
      }
      final now = DateTime.now();
      if (now.difference(session.window).inSeconds >= 60) {
        session.window = now;
        session.requests = 0;
      }
      if (++session.requests > 120 || session.active >= 4) {
        throw const ApiError('SDK rate limit exceeded',
            code: 'rate_limited', status: 429);
      }
      session.active++;
      counted = true;
      Map<String, dynamic> body = {};
      if (request.method == 'POST') {
        if (request.headers.contentType?.mimeType != 'application/json' ||
            request.contentLength > 4096) {
          throw const ApiError('Expected JSON up to 4096 bytes',
              code: 'invalid_request', status: 400);
        }
        final bytes = <int>[];
        await for (final chunk in request.timeout(const Duration(seconds: 5))) {
          bytes.addAll(chunk);
          if (bytes.length > 4096) {
            throw const FormatException('Body too large');
          }
        }
        final parsed = jsonDecode(utf8.decode(bytes));
        if (parsed is! Map<String, dynamic>) {
          throw const FormatException('JSON object required');
        }
        body = parsed;
      }
      switch ('${request.method} ${request.uri.path}') {
        case 'GET /v1/session':
          data = {
            'protocol': 1,
            'game_id': session.id,
            'title': session.title,
            'features': {
              'profile': true,
              'friends': true,
              'license': true,
              'presence': true,
              'overlay': overlay.supported,
              'invites': false,
              'achievements': false,
              'cloud_saves': false
            }
          };
        case 'GET /v1/profile':
          final p = await api.profile();
          data = {
            'global_id': p.id,
            'username': p.username,
            'name': p.name,
            'avatar': p.fields['avatar'],
            'banner': p.fields['banner'],
            'bio': p.fields['bio']
          };
        case 'GET /v1/friends':
          data = (await api.friends())
              .map((f) => {
                    'global_id': f.id,
                    'username': f.username,
                    'name': f.name,
                    'avatar': f.avatar,
                    'presence': f.status,
                    'game_id': f.gameId ?? 0,
                    'game_title': f.gameTitle
                  })
              .toList();
        case 'GET /v1/license':
          data = {
            'game_id': session.id,
            'owned': await api.checkLicense(session.id)
          };
        case 'POST /v1/presence':
          if (body.keys.any((k) => k != 'status') ||
              !['in_game', 'away'].contains(body['status'])) {
            throw const FormatException(
                'Use status in_game or away; game ID is bound to the session');
          }
          await api.presence(
              status: body['status'] as String, gameId: session.id);
          data = {'game_id': session.id, 'status': body['status']};
        case 'POST /v1/overlay':
          if (body.length != 1 || body['visible'] is! bool) {
            throw const FormatException('visible boolean required');
          }
          await overlay.request(session.id, body['visible'] as bool);
          data = {'visible': body['visible']};
        default:
          throw const ApiError('SDK operation not supported',
              code: 'not_found', status: 404);
      }
      // An in-flight response from an old account must never reach the game.
      if (_sessions[session.id] != session ||
          session.generation != api.sessionGeneration ||
          !api.signedIn) {
        throw const ApiError('Game capability expired',
            code: 'unauthorized', status: 401);
      }
    } on ApiError catch (e) {
      status = e.status >= 400 && e.status <= 599 ? e.status : 503;
      error = {
        'code': e.code.isEmpty ? 'service_unavailable' : e.code,
        'message': e.message
      };
    } on FormatException {
      status = 400;
      error = {'code': 'invalid_request', 'message': 'Malformed SDK request'};
    } on TimeoutException {
      status = 408;
      error = {'code': 'request_timeout', 'message': 'SDK request timed out'};
    } on PlatformException {
      status = 501;
      error = {
        'code': 'overlay_unavailable',
        'message': 'Overlay is unavailable for this game'
      };
    } catch (_) {
      status = 503;
      error = {
        'code': 'service_unavailable',
        'message': 'Keep Pixel is temporarily unavailable'
      };
    } finally {
      if (session != null &&
          (_sessions[session.id] != session ||
              session.generation != api.sessionGeneration ||
              !api.signedIn)) {
        status = 401;
        error = {'code': 'unauthorized', 'message': 'Game capability expired'};
      }
      if (counted) session!.active--;
      try {
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.headers.set('Cache-Control', 'no-store');
        request.response.headers.set('X-Content-Type-Options', 'nosniff');
        request.response.write(jsonEncode(error == null
            ? {'ok': true, 'data': data}
            : {'ok': false, 'error': error}));
        await request.response.close();
      } catch (_) {
        request.response
            .detachSocket()
            .then((socket) => socket.destroy())
            .catchError((_) {});
      }
    }
  }

  void revoke(int id) => _sessions.remove(id);
  void dispose() {
    _disposed = true;
    api.removeListener(_sessionChanged);
    _sessions.clear();
    if (_server != null) unawaited(_server!.close(force: true));
  }
}
