/*
 * SG Alfa — el dibujo de Alfi: guerrero espartano con casco corintio y visera en T,
 * cresta roja, capa, hombreras de bronce, escudo con la lambda y lanza.
 * Personaje original de SG Alfa.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

class AlfiPainter extends CustomPainter {
  final bool blink;

  AlfiPainter(this.blink);

  static const _bronzeLight = Color(0xFFF4D37E);
  static const _bronze = Color(0xFFC9973B);
  static const _bronzeDark = Color(0xFF7A5418);
  static const _red = Color(0xFFCB2F27);
  static const _redDark = Color(0xFF7E1A16);
  static const _skin = Color(0xFFE2A272);
  static const _skinDark = Color(0xFFB06C42);
  static const _ink = Color(0xFF24150C);
  static const _visor = Color(0xFF1A0F09);

  Paint _outline([double w = 2.2]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _ink;

  void _fill(Canvas c, Path path, Paint fill, {bool outline = true}) {
    c.drawPath(path, fill);
    if (outline) c.drawPath(path, _outline());
  }

  Paint _grad(List<Color> colors, Rect r,
          {Alignment begin = Alignment.topLeft, Alignment end = Alignment.bottomRight}) =>
      Paint()..shader = LinearGradient(begin: begin, end: end, colors: colors).createShader(r);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);

    // Lanza detrás, a la derecha.
    canvas.drawLine(const Offset(86, 100), const Offset(93, 44), _outline(4.2));
    canvas.drawLine(
        const Offset(86, 100),
        const Offset(93, 44),
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0xFF8A5A2B));
    _fill(
        canvas,
        Path()
          ..moveTo(93.6, 30)
          ..quadraticBezierTo(98, 40, 93.2, 47)
          ..quadraticBezierTo(88.6, 40, 93.6, 30)
          ..close(),
        _grad([_bronzeLight, _bronzeDark], const Rect.fromLTWH(88, 30, 10, 17)));

    // Capa roja que cae de los hombros.
    _fill(
        canvas,
        Path()
          ..moveTo(22, 68)
          ..quadraticBezierTo(8, 84, 4, 100)
          ..lineTo(98, 100)
          ..quadraticBezierTo(92, 82, 80, 68)
          ..close(),
        _grad([_red, _redDark], const Rect.fromLTWH(4, 68, 94, 32),
            begin: Alignment.topCenter, end: Alignment.bottomCenter));

    // Torso musculoso.
    final torso = Path()
      ..moveTo(26, 70)
      ..quadraticBezierTo(50, 60, 76, 70)
      ..lineTo(78, 100)
      ..lineTo(24, 100)
      ..close();
    _fill(canvas, torso, _grad([_skin, _skinDark], const Rect.fromLTWH(24, 62, 54, 38)));
    final muscle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = _skinDark;
    canvas.drawArc(const Rect.fromLTWH(37, 72, 15, 11), 0.1 * math.pi, 0.8 * math.pi, false, muscle);
    canvas.drawArc(const Rect.fromLTWH(53, 72, 15, 11), 0.1 * math.pi, 0.8 * math.pi, false, muscle);
    canvas.drawLine(const Offset(52.5, 78), const Offset(52.5, 100), muscle);
    canvas.drawLine(const Offset(46, 90), const Offset(51, 90), muscle);
    canvas.drawLine(const Offset(54, 90), const Offset(60, 90), muscle);

    // Cuello.
    _fill(canvas, Path()..addRect(const Rect.fromLTWH(50, 56, 14, 12)), Paint()..color = _skinDark);

    // Hombreras: broches de bronce que sujetan la capa.
    for (final c in const [Offset(27, 70), Offset(76, 70)]) {
      canvas.drawCircle(c, 5.2, Paint()..color = _bronze);
      canvas.drawCircle(c, 5.2, _outline());
      canvas.drawCircle(c, 2.2, Paint()..color = _bronzeDark);
    }

    // Cresta de crin: nace en la frente y barre hacia atrás.
    final crest = Path()
      ..moveTo(33, 24)
      ..cubicTo(32, -10, 82, -12, 98, 32)
      ..cubicTo(92, 27, 84, 25, 77, 27)
      ..cubicTo(70, 13, 50, 9, 39, 25)
      ..close();
    canvas.drawPath(crest, _grad([_red, _redDark], const Rect.fromLTWH(33, -4, 65, 36)));
    // Crin: trazos que salen del casco, recortados a la forma de la cresta.
    canvas.save();
    canvas.clipPath(crest);
    final hair = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = _redDark;
    for (var i = 0; i < 16; i++) {
      final ang = math.pi * (1.05 + i * 0.062);
      const c = Offset(57, 40);
      canvas.drawLine(c + Offset(math.cos(ang), math.sin(ang)) * 30, c + Offset(math.cos(ang), math.sin(ang)) * 60, hair);
    }
    canvas.restore();
    canvas.drawPath(crest, _outline());

    // Casco corintio (de tres cuartos, mirando a la izquierda).
    final helmet = Path()
      ..moveTo(34, 32)
      ..cubicTo(35, 15, 64, 11, 74, 25)
      ..cubicTo(81, 35, 81, 49, 75, 58)
      ..lineTo(63, 60)
      ..lineTo(57, 67)
      ..lineTo(44, 67)
      ..cubicTo(38, 61, 34, 53, 34, 45)
      ..close();
    _fill(
        canvas,
        helmet,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.5),
            radius: 1.0,
            colors: [_bronzeLight, _bronze, _bronzeDark],
            stops: [0, 0.55, 1],
          ).createShader(const Rect.fromLTWH(34, 12, 47, 55)));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = _bronzeDark;
    canvas.drawPath(
        Path()
          ..moveTo(63, 59)
          ..quadraticBezierTo(66, 46, 72, 40),
        edge);
    // Visera oscura en T.
    _fill(
        canvas,
        Path()
          ..moveTo(35, 37)
          ..lineTo(64, 34.5)
          ..quadraticBezierTo(65, 38, 63, 41)
          ..lineTo(51.5, 42.5)
          ..lineTo(52.5, 67)
          ..lineTo(44.5, 67)
          ..lineTo(44.5, 43.5)
          ..lineTo(36, 44)
          ..quadraticBezierTo(34.5, 40.5, 35, 37)
          ..close(),
        Paint()..color = _visor,
        outline: false);
    // Protector nasal.
    _fill(
        canvas,
        Path()
          ..moveTo(46.5, 31)
          ..lineTo(50.5, 30.6)
          ..lineTo(50, 49)
          ..lineTo(47, 49)
          ..close(),
        Paint()..color = _bronze);
    // Mirada: dos brillos en la visera (desaparecen al parpadear).
    if (!blink) {
      final eye = Paint()..color = const Color(0xFFFFE9B0);
      canvas.drawOval(Rect.fromCenter(center: const Offset(41, 40.3), width: 5, height: 2.4), eye);
      canvas.drawOval(Rect.fromCenter(center: const Offset(57.5, 38.8), width: 5, height: 2.4), eye);
    }
    // Brillo del bronce.
    canvas.drawArc(
      const Rect.fromLTWH(38, 16, 34, 30),
      1.08 * math.pi,
      0.36 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.6),
    );

    // Escudo de bronce delante, con la lambda de Esparta.
    final shield = Path()
      ..moveTo(10, 70)
      ..cubicTo(20, 63, 38, 63, 47, 70)
      ..lineTo(45, 88)
      ..cubicTo(41, 96, 33, 100, 28, 101)
      ..cubicTo(21, 99, 13, 93, 11, 87)
      ..close();
    _fill(canvas, shield, _grad([_bronzeLight, _bronze, _bronzeDark], const Rect.fromLTWH(10, 63, 37, 38)));
    canvas.drawPath(
        Path()
          ..moveTo(14, 72)
          ..cubicTo(22, 67, 36, 67, 43, 72)
          ..lineTo(41.5, 87)
          ..cubicTo(38, 93, 32, 96, 28, 97)
          ..cubicTo(22, 95, 16, 91, 14.5, 86)
          ..close(),
        edge);
    canvas.drawPath(
      Path()
        ..moveTo(21, 91)
        ..lineTo(28.5, 73)
        ..lineTo(36, 91),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = _red,
    );
  }

  @override
  bool shouldRepaint(AlfiPainter old) => old.blink != blink;
}
