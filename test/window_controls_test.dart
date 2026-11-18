import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_pixel/ui/window_controls.dart';

void main() {
  testWidgets('window buttons appear only over covering pages on a computer',
      (tester) async {
    for (final (platform, expected) in [
      (TargetPlatform.windows, true),
      (TargetPlatform.android, false),
      (TargetPlatform.iOS, false),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(desktopWindow, expected, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;

    final routes = CoveringRoutes();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [routes],
        home: const Scaffold(body: Text('main'))));
    expect(routes.covering.value, 0);
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const Text('page')));
    await tester.pumpAndSettle();
    expect(routes.covering.value, 1);
    showDialog(context: nav.currentContext!, builder: (_) => const Text('d'));
    await tester.pumpAndSettle();
    expect(routes.covering.value, 2);
    nav.currentState!.pop();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(routes.covering.value, 0);
  });
}
