#!/usr/bin/env python3
"""Create source-only SDK distributions; never ship Binaries/Intermediate/.godot."""
import argparse
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, default=root.parent / 'build/sdk')
args = parser.parse_args()
args.output_dir.mkdir(parents=True, exist_ok=True)
plugin = root / 'ue5/KeepPixelPlugin'
with ZipFile(args.output_dir / 'KeepPixelPlugin-0.2.0.zip', 'w', ZIP_DEFLATED) as z:
    for path in sorted(plugin.rglob('*')):
        if path.is_file() and (path.suffix in ('.cpp', '.h', '.cs', '.uplugin') or path.name == 'README.md'):
            z.write(path, Path('KeepPixelPlugin') / path.relative_to(plugin))
with ZipFile(args.output_dir / 'KeepPixelSDK-0.2.0.zip', 'w', ZIP_DEFLATED) as z:
    for path in sorted(root.rglob('*')):
        if path.is_file() and not any(p.startswith('.') or p == '__pycache__' for p in path.relative_to(root).parts) and path.suffix != '.pyc':
            z.write(path, Path('KeepPixelSDK') / path.relative_to(root))
print('Created UE5 plugin and multi-engine SDK source archives in', args.output_dir)
