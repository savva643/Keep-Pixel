"""Probe a real launcher's temporary session; invoked by the Dart integration test."""
from keep_pixel import KeepPixelClient
client = KeepPixelClient()
session = client.session()
assert session['protocol'] == 1 and session['game_id'] == client.game_id
profile = client.profile()
assert 'global_id' in profile and not ({'login', 'email', 'token'} & profile.keys())
assert isinstance(client.friends(), list)
assert isinstance(client.license()['owned'], bool)
assert client.presence()['game_id'] == client.game_id
print('PYTHON_SDK_OK')
