/*
 * SG Alfa Home — estilo profesional para ajustes y ventanas (como los ajustes de Xiaomi o Huawei):
 * fondo neutro, tarjetas redondeadas, subtítulos en gris, un solo color de acento y foco discreto.
 * El inicio sigue el tema elegido; los menús siempre se ven así.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';

import 'retro.dart';

class Pro {
  Pro._();

  /// Oscuro o claro según el tema (los menús acompañan al inicio, pero en sobrio).
  static bool get dark => Retro.night.computeLuminance() < 0.35;

  static Color get bg => dark ? const Color(0xFF151518) : const Color(0xFFF2F2F7);
  static Color get card => dark ? const Color(0xFF222226) : const Color(0xFFFFFFFF);
  static Color get cardFocus => dark ? const Color(0xFF2C3446) : const Color(0xFFE6EEFF);

  /// Fondo de botones sin enfocar (gris translúcido) y del elemento enfocado (blanco).
  static Color get chip => dark ? const Color(0x1FFFFFFF) : const Color(0x0F000000);
  static Color get focusBg => Colors.white;
  static Color get focusFg => const Color(0xFF111114);
  static Color get text => dark ? const Color(0xFFF2F2F4) : const Color(0xFF1C1C1E);
  static Color get sub => dark ? const Color(0xFF9A9AA2) : const Color(0xFF6E6E73);
  static Color get line => dark ? const Color(0x1FFFFFFF) : const Color(0x1A000000);
  static Color get accent => dark ? const Color(0xFF3D8BFF) : const Color(0xFF007AFF);
  static Color get green => const Color(0xFF34C759);

  /// Acciones peligrosas (desinstalar, borrar): texto rojo sobre tarjeta neutra.
  static const danger = Color(0xFFFF453A);

  /// Texto legible sobre un fondo cualquiera.
  static Color on(Color c) => c.computeLuminance() > 0.45 ? const Color(0xFF1C1C1E) : Colors.white;

  static bool _neutral(Color? c) =>
      c == null || c == text || c == card || c == bg || c == sub || c == Retro.night || c == Retro.panel;

  /// Título de página (grande) o encabezado de sección (pequeño, gris y espaciado).
  static TextStyle title(double size, {Color? color}) => size <= 18
      ? TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: color ?? sub)
      : TextStyle(fontSize: size * 0.95, fontWeight: FontWeight.w600, color: color ?? text, height: 1.1);

  static TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w500}) => TextStyle(
        fontSize: size,
        color: color ?? text,
        fontWeight: weight.index > FontWeight.w600.index ? FontWeight.w600 : weight,
      );

  /// Tarjeta plana: sin contornos de cómic ni sombras duras.
  static BoxDecoration box({
    Color? color,
    double radius = 14,
    double border = 0,
    double shadow = 0,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: _neutral(color) ? card : color,
        borderRadius: BorderRadius.circular(radius.clamp(8.0, 18.0)),
        border: Border.all(color: line, width: 1),
      );
}

/// Botón sobrio: neutro, o relleno de acento si se le da un color.
class ProButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? focusColor; // se acepta por compatibilidad; el foco siempre es el acento
  final bool autofocus;
  final EdgeInsetsGeometry padding;
  final double radius;
  final FocusNode? focusNode;

  /// Fila de lista: sin fondo hasta que se enfoca.
  final bool plain;

  const ProButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.focusColor,
    this.autofocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    this.radius = 12,
    this.focusNode,
    this.plain = false,
  });

  @override
  State<ProButton> createState() => _ProButtonState();
}

class _ProButtonState extends State<ProButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final danger = widget.color == Pro.danger;
    final filled = !danger && !Pro._neutral(widget.color);
    // Como en Apple TV: lo enfocado se vuelve blanco con texto oscuro y crece un poco.
    final bg = _focused
        ? Pro.focusBg
        : (filled ? Pro.accent : (widget.plain ? Colors.transparent : Pro.chip));
    final fg = danger ? Pro.danger : (_focused ? Pro.focusFg : (filled ? Colors.white : Pro.text));
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 6),
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
        borderRadius: BorderRadius.circular(widget.radius),
        child: AnimatedScale(
          scale: _focused ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: _focused
                ? const [BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8))]
                : const [],
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 16),
            child: IconTheme.merge(data: IconThemeData(color: fg, size: 22), child: widget.child),
          ),
        ),
        ),
      ),
    );
  }
}

/// Etiqueta discreta (antes «pegatina»): texto pequeño en gris.
class ProTag extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;

  const ProTag(this.text, {super.key, this.color, this.textColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Pro.sub)),
      );
}

/// Interruptor como el de los ajustes del móvil.
class ProSwitch extends StatelessWidget {
  final bool value;

  const ProSwitch(this.value, {super.key});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? Pro.accent : (Pro.dark ? const Color(0xFF48484E) : const Color(0xFFD1D1D6)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      );
}
