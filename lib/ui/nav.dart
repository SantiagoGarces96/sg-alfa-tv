/*
 * SG Alfa Home — recorrido del mando en el inicio, fijo y predecible:
 *   barra superior ⇅ sugerencia («A esta hora sueles ver») ⇅ dock ⇅ todas las apps.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class Nav {
  Nav._();

  static final settings = FocusNode(debugLabel: 'nav-settings');
  static final suggestion = FocusNode(debugLabel: 'nav-suggestion');
  static final dock = FocusNode(debugLabel: 'nav-dock-first');

  static bool _usable(FocusNode n) => n.context != null && n.canRequestFocus;

  static void toTopBar() => settings.requestFocus();

  static void toDock() {
    if (_usable(dock)) dock.requestFocus();
  }

  /// Desde la barra hacia abajo: la sugerencia si la hay; si no, el dock.
  static void belowTopBar() => _usable(suggestion) ? suggestion.requestFocus() : toDock();

  /// Desde el dock hacia arriba: la sugerencia si la hay; si no, la barra.
  static void aboveDock() => _usable(suggestion) ? suggestion.requestFocus() : toTopBar();

  /// Envuelve una zona para que ↑/↓ vayan a sitios concretos (null = navegación normal).
  static Widget arrows({required Widget child, VoidCallback? up, VoidCallback? down}) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
          if (up != null && e.logicalKey == LogicalKeyboardKey.arrowUp) {
            up();
            return KeyEventResult.handled;
          }
          if (down != null && e.logicalKey == LogicalKeyboardKey.arrowDown) {
            down();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: child,
      );
}
