"""Run as a launched game or import sdk/python into your game. Never print keys."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from keep_pixel import KeepPixelClient, KeepPixelError

try:
    pixel = KeepPixelClient()
    print(pixel.profile()['name'])
    for friend in pixel.friends():
        print(friend['name'], friend['presence'], friend['game_id'])
except KeepPixelError as error:
    print(f'Keep Pixel: {error.code}: {error}', file=sys.stderr)
    sys.exit(1)
