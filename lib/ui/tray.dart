import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';

/// The tray icon of the desktop client. With it, closing the window only hides
/// it: downloads and friends keep running, and "Exit" in the tray menu quits.
class AppTray with TrayListener {
  static const _window = MethodChannel('keep_pixel/window');
  final void Function(int page) onPage;
  AppTray({required this.onPage});

  static const _pages = {'library': 1, 'friends': 2, 'downloads': 5};

  Future<void> start() async {
    try {
      await trayManager.setIcon(Platform.isWindows
          ? 'assets/images/tray.ico'
          : 'assets/images/logo.png');
      await trayManager.setToolTip('Keep Pixel');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'Открыть Keep Pixel'),
        MenuItem.separator(),
        MenuItem(key: 'library', label: 'Библиотека'),
        MenuItem(key: 'downloads', label: 'Загрузки'),
        MenuItem(key: 'friends', label: 'Друзья'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Выход'),
      ]));
      trayManager.addListener(this);
      // Only now may closing hide the window: there is a way back.
      if (Platform.isWindows) await _window.invokeMethod('trayReady');
    } catch (_) {
      // Without a tray icon the close button keeps quitting the app.
    }
  }

  void dispose() => trayManager.removeListener(this);

  Future<void> show() async {
    if (Platform.isWindows) {
      await _window.invokeMethod('show');
    } else {
      appWindow.show();
    }
  }

  Future<void> quit() async {
    try {
      await trayManager.destroy();
    } catch (_) {}
    if (Platform.isWindows) {
      await _window.invokeMethod('quit');
    } else {
      appWindow.close();
    }
  }

  @override
  void onTrayIconMouseDown() => show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'quit':
        quit();
      case final key? when _pages.containsKey(key):
        show();
        onPage(_pages[key]!);
      default:
        show();
    }
  }
}
