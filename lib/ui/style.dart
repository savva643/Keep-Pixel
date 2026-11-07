import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Keep Pixel visual language, taken from the logo: nested crescents in a
/// blue-to-violet gradient on near-black, with a faint pixel lattice behind.
class Kp {
  static const bg = Color(0xFF0A0B12);
  static const surface = Color(0xFF12131C);
  static const raised = Color(0xFF1B1D2A);
  static const line = Color(0xFF2B2D40);
  static const text = Color(0xFFF4F5FA);
  static const muted = Color(0xFFA5A9BC);
  static const blue = Color(0xFF2A4BBA);
  static const indigo = Color(0xFF4F57D6);
  static const violet = Color(0xFF7866EA);
  static const lilac = Color(0xFFA99DFF);
  static const online = Color(0xFF4ADE80);
  static const error = Color(0xFFF2545B);
  static const r10 = BorderRadius.all(Radius.circular(10));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));
  static const motion = Duration(milliseconds: 160);
  static const gradient = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [blue, violet]);

  static int seedOf(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

ThemeData kpTheme() {
  const button = RoundedRectangleBorder(borderRadius: Kp.r14);
  const buttonText = TextStyle(
      fontFamily: 'Montserrat',
      fontFamilyFallback: ['NotoSans'],
      fontWeight: FontWeight.w700,
      fontSize: 14);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 18);
  const panel = RoundedRectangleBorder(
      borderRadius: Kp.r20, side: BorderSide(color: Kp.line));
  OutlineInputBorder field(Color color) => OutlineInputBorder(
      borderRadius: Kp.r14, borderSide: BorderSide(color: color));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Montserrat',
    fontFamilyFallback: const ['NotoSans'],
    scaffoldBackgroundColor: Kp.bg,
    colorScheme: const ColorScheme.dark(
        primary: Kp.indigo,
        onPrimary: Colors.white,
        secondary: Kp.violet,
        onSecondary: Colors.white,
        tertiary: Kp.lilac,
        error: Kp.error,
        surface: Kp.surface,
        onSurface: Kp.text,
        onSurfaceVariant: Kp.muted,
        surfaceContainerLowest: Kp.bg,
        surfaceContainerLow: Kp.surface,
        surfaceContainer: Kp.surface,
        surfaceContainerHigh: Kp.raised,
        surfaceContainerHighest: Kp.raised,
        outline: Kp.line,
        outlineVariant: Kp.line),
    cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Kp.raised,
        shape: RoundedRectangleBorder(borderRadius: Kp.r20)),
    dividerTheme: const DividerThemeData(color: Kp.line, space: 1),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Kp.raised,
        hintStyle: const TextStyle(color: Kp.muted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: field(Kp.line),
        enabledBorder: field(Kp.line),
        focusedBorder: field(Kp.violet)),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            padding: buttonPadding, textStyle: buttonText, shape: button)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            padding: buttonPadding,
            textStyle: buttonText,
            foregroundColor: Kp.text,
            side: const BorderSide(color: Kp.line),
            shape: button)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: Kp.lilac, textStyle: buttonText, shape: button)),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: Kp.muted, shape: button)),
    dialogTheme: const DialogThemeData(
        backgroundColor: Kp.surface,
        surfaceTintColor: Colors.transparent,
        shape: panel),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Kp.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
    popupMenuTheme: const PopupMenuThemeData(
        color: Kp.raised, surfaceTintColor: Colors.transparent, shape: panel),
    snackBarTheme: const SnackBarThemeData(
        backgroundColor: Kp.raised,
        contentTextStyle: TextStyle(color: Kp.text),
        shape: panel),
    tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(color: Kp.text, fontSize: 12),
        decoration: ShapeDecoration(
            color: Kp.raised,
            shape: RoundedRectangleBorder(
                borderRadius: Kp.r10, side: BorderSide(color: Kp.line)))),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Kp.violet, linearTrackColor: Kp.line),
    navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: Kp.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Kp.violet.withValues(alpha: .24),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color:
                states.contains(WidgetState.selected) ? Kp.text : Kp.muted))),
  );
}

/// Nested rings sharing one right edge, as in the logo.
void _paintEclipse(Canvas canvas, Offset center, double radius, Shader shader,
    {double opacity = 1}) {
  const rings = [(1.0, .035), (.81, .07), (.62, .07)];
  final right = center.dx + radius;
  for (final (ratio, stroke) in rings) {
    final r = radius * ratio;
    canvas.drawCircle(
        Offset(right - r, center.dy),
        r - radius * stroke / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * stroke
          ..shader = shader
          ..color = Colors.white.withValues(alpha: opacity));
  }
}

/// Generated cover for games without published art. The same title always
/// gets the same picture, so a game stays recognisable between screens.
class KpArt extends StatelessWidget {
  final String seed;
  const KpArt(this.seed, {super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: CustomPaint(
          painter: _ArtPainter(seed), child: const SizedBox.expand()));
}

class _ArtPainter extends CustomPainter {
  final String seed;
  const _ArtPainter(this.seed);
  static const _pairs = [
    (Kp.blue, Kp.violet),
    (Color(0xFF1E5FD0), Color(0xFF5B8DEF)),
    (Color(0xFF4B32B8), Color(0xFFA35CE8)),
    (Color(0xFF2B3CA8), Color(0xFF3F9FE0)),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(Kp.seedOf(seed));
    final (a, b) = _pairs[random.nextInt(_pairs.length)];
    final area = Offset.zero & size;
    canvas.drawRect(
        area,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                Color.lerp(Kp.bg, a, .35)!,
                Color.lerp(Kp.bg, b, .6)!
              ]).createShader(area));
    final radius = math.max(size.width, size.height * 1.4) *
        (.3 + random.nextDouble() * .18);
    final center = Offset(size.width * (.52 + random.nextDouble() * .24),
        size.height * (.38 + random.nextDouble() * .24));
    final ringArea = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    canvas.clipRect(area);
    _paintEclipse(
        canvas,
        center,
        radius,
        LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Color.lerp(a, Colors.white, .1)!,
              Color.lerp(b, Colors.white, .35)!
            ]).createShader(ringArea));
    canvas.restore();
    final cell = (size.width / 48).clamp(6.0, 22.0).floorToDouble();
    final columns = (size.width / cell).ceil(),
        rows = (size.height / cell).ceil();
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < columns * rows / 16; i++) {
      final x = random.nextInt(columns), y = random.nextInt(rows);
      // Pixels thicken toward the right, where the logo's rings meet.
      if (random.nextDouble() > x / columns) continue;
      paint.color =
          Colors.white.withValues(alpha: .03 + random.nextDouble() * .1);
      canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell - 1, cell - 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.seed != seed;
}

/// Faint pixel lattice behind the app with the logo's rings in the corner.
class KpBackdrop extends StatelessWidget {
  const KpBackdrop({super.key});
  @override
  Widget build(BuildContext context) => const RepaintBoundary(
      child:
          CustomPaint(painter: _BackdropPainter(), child: SizedBox.expand()));
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const gap = 28.0;
    final dots = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..isAntiAlias = false;
    for (var y = gap; y < size.height; y += gap) {
      for (var x = gap; x < size.width; x += gap) {
        canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), dots);
      }
    }
    final radius = math.max(size.width, size.height) * .42;
    final center = Offset(size.width - radius * .55, size.height - radius * .5);
    _paintEclipse(
        canvas,
        center,
        radius,
        LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Kp.blue.withValues(alpha: .06),
              Kp.violet.withValues(alpha: .06)
            ]).createShader(Rect.fromCircle(center: center, radius: radius)));
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}

class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  const ProgressRing({super.key, required this.value, this.size = 32});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _RingPainter(value));
}

class _RingPainter extends CustomPainter {
  final double value;
  const _RingPainter(this.value);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Kp.line);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
                  colors: [Kp.lilac, Kp.violet, Kp.indigo, Kp.lilac])
              .createShader(rect));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// Hover state for mouse pointers; touch screens simply never report it.
class Hovered extends StatefulWidget {
  final Widget Function(BuildContext context, bool hover) builder;
  final VoidCallback? onTap;
  const Hovered({super.key, required this.builder, this.onTap});
  @override
  State<Hovered> createState() => _HoveredState();
}

class _HoveredState extends State<Hovered> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: widget.builder(context, hover)));
}

/// Main call to action, filled with the logo's gradient.
class KpButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const KpButton(this.label, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      enabled: onTap != null,
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedOpacity(
              duration: Kp.motion,
              opacity: onTap == null ? .45 : 1,
              child: AnimatedContainer(
                  duration: Kp.motion,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                  decoration: BoxDecoration(
                      borderRadius: Kp.r14,
                      gradient: Kp.gradient,
                      boxShadow: [
                        BoxShadow(
                            color:
                                Kp.violet.withValues(alpha: hover ? .55 : .25),
                            blurRadius: hover ? 26 : 16)
                      ]),
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700))))));
}

class KpChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const KpChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedContainer(
              duration: Kp.motion,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                  borderRadius: Kp.r20,
                  gradient: selected ? Kp.gradient : null,
                  color: selected
                      ? null
                      : hover
                          ? Kp.raised
                          : Kp.surface,
                  border: selected
                      ? null
                      : Border.all(color: hover ? Kp.violet : Kp.line)),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Kp.text)))));
}

class KpHeading extends StatelessWidget {
  final String title;
  final String? trailing;
  const KpHeading(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 4,
            height: 18,
            decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(2)),
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Kp.blue, Kp.violet]))),
        const SizedBox(width: 10),
        Flexible(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3))),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(trailing!,
              style: const TextStyle(
                  fontSize: 13, color: Kp.muted, fontWeight: FontWeight.w600))
        ]
      ]);
}

/// Scrolling page with the app's gutter and an optional title.
class KpPage extends StatelessWidget {
  final String? title;
  final double maxWidth;
  final List<Widget> children;
  const KpPage(
      {super.key, this.title, this.maxWidth = 1100, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final gutter = box.maxWidth > 700 ? 32.0 : 16.0;
        return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 28),
            child: Center(
                child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (title != null) ...[
                            Text(title!,
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.6)),
                            const SizedBox(height: 16),
                          ],
                          ...children
                        ]))));
      });
}

/// The app's own minimize, maximize and close buttons.
class WindowButtons extends StatelessWidget {
  final VoidCallback onMinimize, onClose;
  final VoidCallback? onMaximize;
  final bool maximized;
  const WindowButtons(
      {super.key,
      required this.onMinimize,
      required this.onClose,
      this.onMaximize,
      this.maximized = false});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        _WindowButton(
            icon: Icons.remove_rounded, tooltip: 'Свернуть', onTap: onMinimize),
        if (onMaximize != null)
          _WindowButton(
              icon: maximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              iconSize: maximized ? 14 : 16,
              tooltip: maximized ? 'Восстановить' : 'Развернуть',
              onTap: onMaximize!),
        _WindowButton(
            icon: Icons.close_rounded,
            tooltip: 'Закрыть',
            hoverColor: Kp.error,
            onTap: onClose),
      ]);
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final Color hoverColor;
  final VoidCallback onTap;
  const _WindowButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.iconSize = 18,
      this.hoverColor = Kp.raised});
  @override
  Widget build(BuildContext context) => Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: Hovered(
          onTap: onTap,
          builder: (context, hover) => AnimatedContainer(
              duration: Kp.motion,
              width: 34,
              height: 32,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                  borderRadius: Kp.r10,
                  color: hover ? hoverColor : Colors.transparent),
              child: Icon(icon,
                  size: iconSize,
                  color: hover && hoverColor == Kp.error
                      ? Colors.white
                      : hover
                          ? Kp.text
                          : Kp.muted))));
}

class KpPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const KpPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18)});
  @override
  Widget build(BuildContext context) => Container(
      padding: padding,
      decoration: BoxDecoration(
          color: Kp.surface,
          borderRadius: Kp.r20,
          border: Border.all(color: Kp.line)),
      child: child);
}
