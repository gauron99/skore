// Renders the launcher-icon PNGs from Flutter canvas code — no external
// image tools needed. Not part of the regular suite (lives outside test/);
// run explicitly after changing the artwork:
//
//   flutter test tool/gen_icons.dart
//   dart run flutter_launcher_icons
//
// Outputs (generate-time sources only, never bundled as runtime assets):
//   assets/icon/icon.png        1024x1024 full icon (teal + dice)
//   assets/icon/background.png  adaptive-icon background layer
//   assets/icon/foreground.png  adaptive-icon foreground (dice, transparent,
//                               scaled into the adaptive safe zone)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tealTop = Color(0xFF2BA393);
const _tealBottom = Color(0xFF00695C);
const _pip = Color(0xFF123A34);

void _paintBackground(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, 1024, 1024);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_tealTop, _tealBottom],
      ).createShader(rect),
  );
}

void _paintDie(
  Canvas canvas, {
  required Offset center,
  required double degrees,
  required List<Offset> pips,
  required Color fill,
  required double shadowAlpha,
  required double shadowDy,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(degrees * pi / 180);
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: 430, height: 430),
    const Radius.circular(62),
  );
  canvas.drawRRect(
    body.shift(Offset(0, shadowDy)),
    Paint()
      ..color = Colors.black.withValues(alpha: shadowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  canvas.drawRRect(body, Paint()..color = fill);
  final pipPaint = Paint()..color = _pip;
  for (final pip in pips) {
    canvas.drawCircle(pip, 42, pipPaint);
  }
  canvas.restore();
}

/// The dice cluster exactly as in the approved mock: back die showing 2 at
/// -14 degrees, front die showing 5 at +10 degrees.
void _paintDice(Canvas canvas) {
  _paintDie(
    canvas,
    center: const Offset(415, 415),
    degrees: -14,
    pips: const [Offset(-105, -105), Offset(105, 105)],
    fill: const Color(0xFFFDFFFE),
    shadowAlpha: 0.18,
    shadowDy: 10,
  );
  _paintDie(
    canvas,
    center: const Offset(640, 655),
    degrees: 10,
    pips: const [
      Offset(-112, -112),
      Offset(112, -112),
      Offset(0, 0),
      Offset(-112, 112),
      Offset(112, 112),
    ],
    fill: Colors.white,
    shadowAlpha: 0.30,
    shadowDy: 16,
  );
}

Future<void> _savePng(String path, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('wrote $path');
}

void main() {
  testWidgets('render launcher icon PNGs', (tester) async {
    await tester.runAsync(() async {
      await _savePng('assets/icon/icon.png', (canvas) {
        _paintBackground(canvas);
        _paintDice(canvas);
      });
      await _savePng('assets/icon/background.png', _paintBackground);
      await _savePng('assets/icon/foreground.png', (canvas) {
        // Transparent layer; center the dice cluster and scale it into the
        // adaptive-icon safe zone (inner ~66% of the canvas).
        canvas.translate(512, 512);
        canvas.scale(0.62);
        canvas.translate(-527.5, -535);
        _paintDice(canvas);
      });
    });
  });
}
