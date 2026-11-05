import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_pixel/core/installer_native.dart';
import 'package:keep_pixel/core/package_rules.dart';

void main() {
  test(
      'archive paths reject traversal, absolute paths, alternate streams and Windows device names',
      () {
    for (final path in [
      '../evil.exe',
      '/evil.exe',
      r'C:\evil.exe',
      r'..\evil.exe',
      'dir/../../evil',
      'game.exe:ads',
      'NUL',
      'dir/COM1.exe',
      'file. ',
      'dir//file'
    ]) {
      expect(() => safePackagePath(path), throwsFormatException, reason: path);
    }
    expect(safePackagePath('bin/game.exe'), 'bin/game.exe');
  });
  test(
      'verified extraction writes a real executable and rejects escape archives before writing files',
      () {
    final temp = Directory.systemTemp.createTempSync('keep-pixel-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final zip = File('${temp.path}/test.zip');
    final out = Directory('${temp.path}/out')..createSync();
    final archive = Archive()
      ..addFile(ArchiveFile('bin/game.exe', 3, [1, 2, 3]));
    zip.writeAsBytesSync(ZipEncoder().encode(archive));
    extractPackage({
      'archive': zip.path,
      'destination': out.path,
      'executable': 'bin/game.exe'
    });
    expect(File('${out.path}/bin/game.exe').readAsBytesSync(), [1, 2, 3]);
    final malicious = Archive()
      ..addFile(ArchiveFile('safe.txt', 1, [1]))
      ..addFile(ArchiveFile('../escape.exe', 1, [1]));
    zip.writeAsBytesSync(ZipEncoder().encode(malicious));
    expect(
        () => extractPackage({
              'archive': zip.path,
              'destination': out.path,
              'executable': 'escape.exe'
            }),
        throwsFormatException);
    expect(File('${temp.path}/escape.exe').existsSync(), false);
    expect(File('${out.path}/safe.txt').existsSync(), false);
  });
  test(
      'case-colliding entries and missing executables cannot become an installed game',
      () {
    final temp = Directory.systemTemp.createTempSync('keep-pixel-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final zip = File('${temp.path}/test.zip');
    final out = Directory('${temp.path}/out')..createSync();
    zip.writeAsBytesSync(ZipEncoder().encode(Archive()
      ..addFile(ArchiveFile('Game.exe', 1, [1]))
      ..addFile(ArchiveFile('game.exe', 1, [2]))));
    expect(
        () => extractPackage({
              'archive': zip.path,
              'destination': out.path,
              'executable': 'game.exe'
            }),
        throwsFormatException);
    zip.writeAsBytesSync(ZipEncoder()
        .encode(Archive()..addFile(ArchiveFile('readme.txt', 1, [1]))));
    expect(
        () => extractPackage({
              'archive': zip.path,
              'destination': out.path,
              'executable': 'missing.exe'
            }),
        throwsFormatException);
  });
}
