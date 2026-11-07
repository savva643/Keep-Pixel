// necsoura/avatar_cropper.dart — обрезка фото профиля квадратом перед загрузкой.
// Фото двигается и масштабируется пальцами, поверх видно круг — так аватар и будет показан.
// Возвращает PNG 1024×1024 без искажений; null — человек отменил.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

Future<Uint8List?> cropAvatar(BuildContext context, Uint8List bytes) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => _AvatarCropScreen(bytes)),
  );
}

class _AvatarCropScreen extends StatefulWidget {
  final Uint8List bytes;
  const _AvatarCropScreen(this.bytes);

  @override
  State<_AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<_AvatarCropScreen> {
  static const _output = 1024.0;
  final _boundary = GlobalKey();
  final _transform = TransformationController();
  Size? _imageSize;
  double? _side;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ui.decodeImageFromList(widget.bytes, (img) {
      if (mounted) setState(() => _imageSize = Size(img.width.toDouble(), img.height.toDouble()));
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Size _childSize(double side) {
    final s = _imageSize!;
    final k = side / min(s.width, s.height);
    return Size(s.width * k, s.height * k);
  }

  Future<void> _done() async {
    final side = _side;
    final ro = _boundary.currentContext?.findRenderObject();
    if (side == null || ro is! RenderRepaintBoundary) return;
    setState(() => _saving = true);
    final image = await ro.toImage(pixelRatio: _output / side);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.of(context).pop(data?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Фото профиля'),
        actions: [
          TextButton(
            onPressed: _imageSize == null || _saving ? null : _done,
            child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _imageSize == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, c) {
              final side = min(c.maxWidth, c.maxHeight) - 32;
              final child = _childSize(side);
              if (_side != side) {
                _side = side;
                // Сначала по центру фото
                _transform.value = Matrix4.identity()
                  ..translate(-(child.width - side) / 2, -(child.height - side) / 2);
              }
              return Center(
                child: SizedBox.square(
                  dimension: side,
                  child: Stack(children: [
                    RepaintBoundary(
                      key: _boundary,
                      child: ClipRect(
                        child: InteractiveViewer(
                          transformationController: _transform,
                          constrained: false,
                          minScale: 1,
                          maxScale: 6,
                          boundaryMargin: EdgeInsets.zero,
                          child: Image.memory(widget.bytes,
                              width: child.width, height: child.height, fit: BoxFit.fill, gaplessPlayback: true),
                        ),
                      ),
                    ),
                    const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CirclePainter()))),
                  ]),
                ),
              );
            }),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Двигайте и увеличивайте фото — в круге то, что увидят другие',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(rect);
    canvas.drawPath(path, Paint()..color = Colors.black54);
    canvas.drawOval(rect.deflate(0.5), Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) => false;
}
