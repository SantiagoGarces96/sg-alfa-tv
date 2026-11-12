/*
 * SG Alfa Home — estilo retro-cartoon: contorno de tinta grueso, sombras duras
 * desplazadas (sin difuminar) y colores de cómic/arcade.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';

class Retro {
  Retro._();

  // Paleta
  static const ink = Color(0xFF1D1A16); // contorno y sombras
  static const cream = Color(0xFFFFF1D0);
  static const red = Color(0xFFE63946);
  static const mustard = Color(0xFFFFB703);
  static const teal = Color(0xFF2A9D8F);
  static const sky = Color(0xFF8ECAE6);
  static const night = Color(0xFF26203A);

  static const display = 'Bungee';

  /// Texto de título: Bungee con un «borde» de tinta (sombras duras alrededor).
  static TextStyle title(double size, {Color color = cream}) => TextStyle(
        fontFamily: display,
        fontSize: size,
        color: color,
        height: 1.0,
        letterSpacing: 1,
        shadows: _inkOutline(size >= 40 ? 3 : 2),
      );

  /// Texto normal legible con sombra dura para leerse sobre cualquier fondo.
  static TextStyle body(double size, {Color color = cream, FontWeight weight = FontWeight.w600}) => TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        shadows: const [Shadow(color: ink, offset: Offset(2, 2))],
      );

  static List<Shadow> _inkOutline(double d) => [
        Shadow(color: ink, offset: Offset(d, d)),
        Shadow(color: ink, offset: Offset(-d / 2, -d / 2)),
        Shadow(color: ink, offset: Offset(d / 2, -d / 2)),
        Shadow(color: ink, offset: Offset(-d / 2, d / 2)),
        Shadow(color: ink, offset: Offset(d + 2, d + 2)),
      ];

  /// Decoración de «caja de cómic».
  static BoxDecoration box({
    Color color = cream,
    double radius = 14,
    double border = 3,
    double shadow = 5,
    Color borderColor = ink,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: border),
        boxShadow: shadow > 0 ? [BoxShadow(color: ink, offset: Offset(shadow, shadow))] : null,
      );
}

/// Caja de cómic que se «hunde» y cambia de color al recibir el foco del mando.
class RetroButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final Color focusColor;
  final bool autofocus;
  final EdgeInsetsGeometry padding;
  final double radius;
  final FocusNode? focusNode;

  const RetroButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color = Retro.cream,
    this.focusColor = Retro.mustard,
    this.autofocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.radius = 12,
    this.focusNode,
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final shadow = _focused ? 2.0 : 5.0;
    return Padding(
      padding: const EdgeInsets.only(right: 5, bottom: 5),
      child: InkWell(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onTap: widget.onPressed,
        onFocusChange: (f) => setState(() => _focused = f),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: Matrix4.translationValues(_focused ? 3 : 0, _focused ? 3 : 0, 0),
          padding: widget.padding,
          decoration: Retro.box(
            color: _focused ? widget.focusColor : widget.color,
            radius: widget.radius,
            shadow: shadow,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Retro.ink, fontWeight: FontWeight.w700),
            child: IconTheme.merge(data: const IconThemeData(color: Retro.ink), child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta-sticker (p. ej. «CUANDO»).
class RetroSticker extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const RetroSticker(this.text, {super.key, this.color = Retro.red, this.textColor = Retro.cream});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: Retro.box(color: color, radius: 8, border: 2.5, shadow: 3),
        child: Text(text, style: TextStyle(fontFamily: Retro.display, fontSize: 14, color: textColor, letterSpacing: 1)),
      );
}
