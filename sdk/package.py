#!/usr/bin/env python3
"""Create source-only SDK kits, one per engine plus everything; never ship
Binaries/Intermediate/.godot. The kits are served by the Keep Pixel backend at
/static/sdk/ (write them to source/services/keeppixel/backend/public/sdk)."""
import argparse
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

VERSION = '0.2.0'
root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, default=root.parent / 'build/sdk')
args = parser.parse_args()
out = args.output_dir
out.mkdir(parents=True, exist_ok=True)


def clean(path: Path) -> bool:
    rel = path.relative_to(root).parts
    return path.is_file() and path.suffix != '.pyc' and not any(
        p.startswith('.') or p in ('__pycache__', 'Binaries', 'Intermediate') for p in rel)


def kit(name: str, files: list) -> None:
    with ZipFile(out / name, 'w', ZIP_DEFLATED) as z:
        for src, dst in files:
            z.write(src, dst)


readme = (root / 'README.md', 'README.md')
plugin = root / 'ue5/KeepPixelPlugin'
kit(f'KeepPixel-UE5-{VERSION}.zip', [readme] + [
    (p, str(Path('KeepPixelPlugin') / p.relative_to(plugin))) for p in sorted(plugin.rglob('*'))
    if clean(p) and (p.suffix in ('.cpp', '.h', '.cs', '.uplugin') or p.name == 'README.md')])
kit(f'KeepPixel-Unity-{VERSION}.zip', [readme, (root / 'unity/KeepPixelClient.cs', 'Assets/KeepPixel/KeepPixelClient.cs')])
kit(f'KeepPixel-Godot-{VERSION}.zip', [readme, (root / 'godot/keep_pixel_client.gd', 'addons/keep_pixel/keep_pixel_client.gd')])
kit(f'KeepPixel-Python-{VERSION}.zip', [readme, (root / 'python/keep_pixel.py', 'keep_pixel.py'),
                                        (root / 'examples/python_game.py', 'examples/python_game.py')])
kit(f'KeepPixelSDK-{VERSION}.zip', [(p, str(Path('KeepPixelSDK') / p.relative_to(root)))
                                    for p in sorted(root.rglob('*')) if clean(p)])
print('SDK kits written to', out)
