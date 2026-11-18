import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'style.dart';

/// Windows, macOS and Linux: the app draws its own window buttons. Phones and
/// the website never show them.
bool get desktopWindow =>
    !kIsWeb &&
    const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
        .contains(defaultTargetPlatform);

/// Counts pages and dialogs opened over the main screen, such as sign-in.
class CoveringRoutes extends NavigatorObserver {
  final covering = ValueNotifier(0);
  final _routes = <Route<dynamic>>{};

  bool _covers(Route<dynamic> route) =>
      route is PageRoute ||
      route is RawDialogRoute ||
      route is ModalBottomSheetRoute;

  void _sync() => covering.value = _routes.length;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && _covers(route)) _routes.add(route);
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null && _routes.remove(oldRoute) && newRoute != null) {
      _routes.add(newRoute);
    }
    _sync();
  }
}

/// Keeps minimize, maximize and close reachable while a page or dialog
/// covers the main screen's own title bar. The top edge also moves the
/// window, except at the left where pages keep their back button.
class WindowControlsOverlay extends StatelessWidget {
  final CoveringRoutes routes;
  final Widget child;
  const WindowControlsOverlay(
      {super.key, required this.routes, required this.child});
  @override
  Widget build(BuildContext context) => Stack(children: [
        child,
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Same place as the buttons in the main title bar.
            height: 60,
            child: ValueListenableBuilder<int>(
                valueListenable: routes.covering,
                builder: (context, covering, _) => covering == 0
                    ? const SizedBox.shrink()
                    : Overlay(initialEntries: [
                        OverlayEntry(
                            builder: (context) => Row(children: [
                                  const SizedBox(width: 120),
                                  Expanded(child: MoveWindow()),
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(right: 12),
                                      child: StatefulBuilder(
                                          builder: (context, refresh) =>
                                              WindowButtons(
                                                  onMinimize:
                                                      appWindow.minimize,
                                                  onMaximize: () {
                                                    appWindow
                                                        .maximizeOrRestore();
                                                    refresh(() {});
                                                  },
                                                  maximized:
                                                      appWindow.isMaximized,
                                                  onClose: appWindow.close))),
                                ])),
                      ]))),
      ]);
}
