import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'necsoura_api.dart';
import 'necsoura_kit.dart';
import 'necsoura_ui.dart';

String _t(String key, [Map<String, String>? args]) => 'necsoura.$key'.tr(namedArgs: args);

/// Вход на другом устройстве по QR: камера → кто просит вход → подтвердить.
/// Понимает QR любого приложения Necsoura (компьютер, телевизор, другой телефон).
/// Возвращает true, если вход подтвердили.
class NecsouraQrScanScreen extends StatefulWidget {
  const NecsouraQrScanScreen({super.key});

  @override
  State<NecsouraQrScanScreen> createState() => _NecsouraQrScanScreenState();
}

class _NecsouraQrScanScreenState extends State<NecsouraQrScanScreen> with SingleTickerProviderStateMixin {
  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  bool _handling = false;
  String? _hint;

  NecsouraKit get kit => NecsouraKit.instance;

  @override
  void dispose() {
    _sweep.dispose();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    final parsed = NecsouraQr.parse(raw);
    if (parsed == null) {
      setState(() => _hint = _t('qr_not_login'));
      return;
    }
    _handling = true;
    HapticFeedback.mediumImpact();
    await _camera.stop();
    try {
      final req = await kit.api.qrScan(parsed.sessionId);
      if (!mounted) return;
      final ok = await _confirm(req);
      if (ok == true) {
        final payload = await kit.qrPayload?.call(req);
        await kit.api.qrApprove(req.sessionId, e2eePayload: payload);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      await kit.api.qrCancel(req.sessionId);
      if (mounted) setState(() => _hint = _t('qr_cancelled'));
    } catch (e) {
      if (mounted) setState(() => _hint = e.toString());
    }
    _handling = false;
    if (mounted) await _camera.start();
  }

  Future<bool?> _confirm(NecsouraQrRequest req) {
    final accent = kit.brand.accent;
    final service = NecsouraBrand.services[req.service];
    final device = req.deviceName.isNotEmpty ? req.deviceName : (req.platform.isEmpty || req.platform == 'unknown' ? _t('device_unknown') : req.platform);
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1A1A20) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(22)),
                  child: service != null ? Image.asset(service.icon) : const NecsouraLogo(size: 52),
                ),
                const SizedBox(height: 16),
                Text(
                  _t('qr_confirm_title', {'service': NecsouraBrand.serviceName(req.service)}),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface, fontFamily: kit.brand.fontFamily),
                ),
                const SizedBox(height: 8),
                Text(
                  [device, if (req.ip != null && req.ip!.isNotEmpty) req.ip!].join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: scheme.onSurface.withOpacity(0.65)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.orange.shade400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_t('qr_confirm_warn'), style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.75)))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: NecsouraButton(text: _t('cancel'), accent: accent, outlined: true, onPressed: () => Navigator.pop(ctx, false))),
                    const SizedBox(width: 12),
                    Expanded(child: NecsouraButton(text: _t('qr_confirm'), accent: accent, autofocus: true, onPressed: () => Navigator.pop(ctx, true))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = kit.brand.accent;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_t('qr_scan'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: _t('flash'),
            onPressed: () => _camera.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              errorBuilder: (_, e, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(_t('camera_error'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ),
              ),
            ),
          ),
          // Затемнение вокруг окна и бегущая линия цвета приложения
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sweep,
              builder: (_, __) => CustomPaint(painter: _Viewfinder(accent, Curves.easeInOut.transform(_sweep.value))),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 40,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _hint == null
                      ? const SizedBox()
                      : Container(
                          key: ValueKey(_hint),
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(14)),
                          child: Text(_hint!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                ),
                Text(_t('qr_scan_where'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Viewfinder extends CustomPainter {
  final Color accent;
  final double t;
  _Viewfinder(this.accent, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.68;
    final rect = Rect.fromCenter(center: size.center(const Offset(0, -30)), width: side, height: side);
    final window = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(window)),
      Paint()..color = Colors.black.withOpacity(0.55),
    );
    canvas.drawRRect(window, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = accent);
    final y = rect.top + 18 + (rect.height - 36) * t;
    canvas.drawLine(
      Offset(rect.left + 22, y),
      Offset(rect.right - 22, y),
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [accent.withOpacity(0), accent, accent.withOpacity(0)])
            .createShader(Rect.fromLTWH(rect.left, y, rect.width, 1)),
    );
  }

  @override
  bool shouldRepaint(_Viewfinder old) => old.t != t || old.accent != accent;
}
