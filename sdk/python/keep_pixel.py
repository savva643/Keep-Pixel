"""Keep Pixel native SDK v1. Python 3.9+, no external dependencies."""
import http.client
import json
import os
import re
from urllib.parse import urlsplit


class KeepPixelError(RuntimeError):
    def __init__(self, code, message, status=0):
        super().__init__(message)
        self.code, self.status = code, status


class KeepPixelClient:
    def __init__(self, environment=None):
        env = os.environ if environment is None else environment
        url = urlsplit(env.get('KEEPPIXEL_SDK_URL', ''))
        token = env.get('KEEPPIXEL_SDK_TOKEN', '')
        game = env.get('KEEPPIXEL_GAME_ID', '')
        if (url.scheme != 'http' or url.hostname != '127.0.0.1' or url.path != '/v1'
                or url.username or url.password or url.query or url.fragment
                or not url.port or not re.fullmatch(r'[A-Za-z0-9_-]{43}', token)
                or not re.fullmatch(r'[1-9][0-9]{0,8}', game)):
            raise KeepPixelError('not_initialized', 'Start this game from Keep Pixel')
        self._port, self._token, self.game_id = url.port, token, int(game)

    def _request(self, path, body=None):
        connection = http.client.HTTPConnection('127.0.0.1', self._port, timeout=8)
        try:
            headers = {'Authorization': 'Bearer ' + self._token, 'Accept': 'application/json'}
            if body is not None:
                headers['Content-Type'] = 'application/json'
            connection.request('GET' if body is None else 'POST', '/v1/' + path,
                               None if body is None else json.dumps(body), headers)
            response = connection.getresponse()
            raw = response.read(1024 * 1024 + 1)
            if len(raw) > 1024 * 1024:
                raise KeepPixelError('invalid_response', 'SDK response exceeds limit')
            data = json.loads(raw)
            if response.status != 200 or data.get('ok') is not True:
                error = data.get('error') or {}
                raise KeepPixelError(error.get('code', 'request_failed'),
                                     error.get('message', 'SDK request failed'), response.status)
            return data['data']
        except (OSError, ValueError, KeyError, TypeError) as exc:
            raise KeepPixelError('launcher_unavailable', 'Invalid response or Keep Pixel unavailable') from exc
        finally:
            connection.close()

    def session(self): return self._request('session')
    def profile(self): return self._request('profile')
    def friends(self): return self._request('friends')
    def license(self): return self._request('license')
    def presence(self, status='in_game'):
        if status not in ('in_game', 'away'):
            raise ValueError('Use in_game or away')
        return self._request('presence', {'status': status})
    def overlay(self, visible=True):
        if not isinstance(visible, bool):
            raise ValueError('visible must be bool')
        return self._request('overlay', {'visible': visible})
