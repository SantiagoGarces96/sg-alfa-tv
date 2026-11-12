/*
 * SG Alfa Home — estilo de la interfaz. Los valores salen del tema activo
 * (ver core/theme_model.dart): colores, contorno, sombra, esquinas y tipografía.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';

import '../core/theme_model.dart';

class Retro {
  Retro._();

  // Colores del tema activo. Los nombres vienen del tema «Retro Cómic» original:
  // red = acento principal, mustard = acento de foco, teal = acento extra.
  static Color ink = SgThemes.retro.ink;
  static Color cream = SgThemes.retro.cream;
  static Color red = SgThemes.retro.primary;
  static Color mustard = SgThemes.retro.secondary;
  static Color teal = SgThemes.retro.tertiary;
  static Color night = SgThemes.retro.night;
  static Color panel = SgThemes.retro.panel;
  static Color positive = const Color(0xFF8FD694);
  static Color muted = const Color(0xFFB9B4A8);

  // Forma
  static double borderK = 1; // multiplicador del grosor del contorno
  static double shadowK = 1; // multiplicador de la sombra dura
  static double radiusK = 1; // multiplicador de las esquinas
  static String? display = SgFonts.bungee;
  static double titleK = 1; // la letra pixel es más ancha: se reduce un poco

  static SgTheme theme = SgThemes.retro;

  static void apply(SgTheme t) {
    theme = t;
    ink = t.ink;
    cream = t.cream;
    red = t.primary;
    mustard = t.secondary;
    teal = t.tertiary;
    night = t.night;
    panel = t.panel;
    borderK = t.border / 3;
    shadowK = t.shadow / 5;
    radiusK = t.radius / 14;
    display = t.font == SgFonts.system ? null : t.font;
    if (t.font == SgFonts.mono) display = 'monospace';
    titleK = t.font == SgFonts.pixel ? 0.72 : 1;
  }

  /// Color de texto legible sobre un fondo dado.
  static Color on(Color bg) => bg.computeLuminance() > 0.4 ? const Color(0xFF15120F) : cream;

  /// Texto de título: tipografía del tema con «borde» de tinta.
  static TextStyle title(double size, {Color? color}) => TextStyle(
        fontFamily: display,
        fontWeight: display == null ? FontWeight.w900 : FontWeight.w400,
        fontSize: size * titleK,
        color: color ?? cream,
        height: 1.0,
        letterSpacing: display == SgFonts.pixel ? 0 : 1,
        shadows: _inkOutline(size >= 40 ? 3 : 2),
      );

  /// Texto normal legible, con sombra dura para leerse sobre cualquier fondo.
  static TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w600}) => TextStyle(
        fontSize: size,
        color: color ?? cream,
        fontWeight: weight,
        shadows: shadowK > 0 ? [Shadow(color: ink, offset: const Offset(2, 2))] : const [],
      );

  static List<Shadow> _inkOutline(double d) {
    if (borderK <= 0 && shadowK <= 0) return const [];
    final k = borderK.clamp(0.3, 2.0);
    final o = d * k;
    return [
      Shadow(color: ink, offset: Offset(o, o)),
      Shadow(color: ink, offset: Offset(-o / 2, -o / 2)),
      Shadow(color: ink, offset: Offset(o / 2, -o / 2)),
      Shadow(color: ink, offset: Offset(-o / 2, o / 2)),
      if (shadowK > 0) Shadow(color: ink, offset: Offset(o + 2 * shadowK, o + 2 * shadowK)),
    ];
  }

  /// Decoración de «caja de cómic» según el tema.
  static BoxDecoration box({
    Color? color,
    double radius = 14,
    double border = 3,
    double shadow = 5,
    Color? borderColor,
  }) {
    final b = border * borderK;
    final s = shadow * shadowK;
    return BoxDecoration(
      color: color ?? cream,
      borderRadius: BorderRadius.circular(radius * radiusK),
      border: b > 0.2 ? Border.all(color: borderColor ?? ink, width: b) : null,
      boxShadow: s > 0.2 ? [BoxShadow(color: ink, offset: Offset(s, s))] : null,
    );
  }
}

/// Caja de cómic que se «hunde» y cambia de color al recibir el foco del mando.
class RetroButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? focusColor;
  final bool autofocus;
  final EdgeInsetsGeometry padding;
  final double radius;
  final FocusNode? focusNode;

  const RetroButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.focusColor,
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
    final bg = _focused ? (widget.focusColor ?? Retro.mustard) : (widget.color ?? Retro.cream);
    final fg = Retro.on(bg);
    // Sin contorno ni sombra (tema Minimal), el foco se marca con un borde del color de acento.
    final flat = Retro.borderK <= 0 && Retro.shadowK <= 0;
    final push = Retro.shadowK > 0 && _focused ? 3.0 * Retro.shadowK : 0.0;
    return Padding(
      padding: const EdgeInsets.only(right: 5, bottom: 5),
      child: InkWell(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onTap: widget.onPressed,
        onFocusChange: (f) {
          setState(() => _focused = f);
          if (f) {
            Scrollable.ensureVisible(context,
                alignment: 0.5, duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic);
          }
        },
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.radius * Retro.radiusK),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: Matrix4.translationValues(push, push, 0),
          padding: widget.padding,
          decoration: Retro.box(color: bg, radius: widget.radius, shadow: shadow).copyWith(
            border: flat && _focused ? Border.all(color: Retro.red, width: 3) : null,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
            child: IconTheme.merge(data: IconThemeData(color: fg), child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta-sticker (p. ej. «CUANDO»).
class RetroSticker extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;

  const RetroSticker(this.text, {super.key, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Retro.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: Retro.box(color: bg, radius: 8, border: 2.5, shadow: 3),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: Retro.display,
          fontWeight: Retro.display == null ? FontWeight.w900 : FontWeight.w400,
          fontSize: 14 * Retro.titleK,
          color: textColor ?? Retro.on(bg),
          letterSpacing: 1,
        ),
      ),
    );
  }
}
