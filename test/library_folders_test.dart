import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_pixel/core/installer_native.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Support extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  _Support(this.path);
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Future<void> installed(String dir, String version) async {
  await Directory(dir).create(recursive: true);
  await File(p.join(dir, 'game.exe')).writeAsString('exe');
  await File(p.join(dir, '.keep-pixel.json'))
      .writeAsString(jsonEncode({'version': version}));
}

void main() {
  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('keep-pixel-libraries-');
    PathProviderPlatform.instance = _Support(p.join(temp.path, 'support'));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('games live in several library folders and move between them',
      () async {
    final installer = GameInstaller();
    final builtIn = p.join(temp.path, 'support', 'games-v2');
    await installed(p.join(builtIn, '7'), '1.0');

    // A chosen drive or folder gets its own KeepPixelLibrary folder.
    final second = await installer.addLibrary(p.join(temp.path, 'D'));
    expect(second, p.join(temp.path, 'D', 'KeepPixelLibrary'));
    await installed(p.join(second, 'abc-123'), '2.0');
    // Folders that are not games stay out of the library.
    await Directory(p.join(second, 'notes')).create();
    await Directory(p.join(second, '42')).create();

    expect(await installer.installedGames(), {'7': '1.0', 'abc-123': '2.0'});
    final folders = await installer.libraries();
    expect(folders.map((f) => (f.path, f.isDefault, f.games)), [
      (builtIn, true, 1),
      (second, false, 1),
    ]);

    await installer.setDefaultLibrary(second);
    expect((await installer.libraries()).first.path, second);

    var progress = 0.0;
    await installer.moveGame('7', second, (v) => progress = v);
    expect(progress, 1);
    expect((await installer.installedLocations())['7'], p.join(second, '7'));
    expect(Directory(p.join(builtIn, '7')).existsSync(), isFalse);
    expect(await installer.installed('7', '1.0'), isTrue);

    await expectLater(installer.removeLibrary(second), throwsFormatException);
    await expectLater(installer.removeLibrary(builtIn), throwsFormatException);
    await installer.uninstall('7');
    await installer.uninstall('abc-123');
    await installer.removeLibrary(second);
    final left = await installer.libraries();
    expect(left.map((f) => f.path), [builtIn]);
    expect(left.single.isDefault, isTrue);
    // Taking a folder off the list never deletes the player's files.
    expect(Directory(p.join(second, 'notes')).existsSync(), isTrue);
  }, skip: !Platform.isWindows);

  test('moving refuses a folder that is not in the list', () async {
    final installer = GameInstaller();
    await installed(p.join(temp.path, 'support', 'games-v2', '7'), '1.0');
    await expectLater(installer.moveGame('7', temp.path, (_) {}),
        throwsFormatException);
  }, skip: !Platform.isWindows);
}
