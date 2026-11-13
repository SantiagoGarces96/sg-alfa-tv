/*
 * SG Alfa Home — opciones de una app (mantener OK).
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import 'retro.dart';

Future<void> showAppOptions(BuildContext context, TvApp app) => showDialog(
  context: context,
  barrierColor: const Color(0xAA000000),
  builder: (_) => ChangeNotifierProvider.value(
    value: context.read<AppsModel>(),
    child: _AppOptions(app: app),
  ),
);

class _AppOptions extends StatefulWidget {
  final TvApp app;

  const _AppOptions({required this.app});

  @override
  State<_AppOptions> createState() => _AppOptionsState();
}

/// El menú se abre MIENTRAS sigues apretando OK. Muchos mandos siguen mandando «OK» mientras
/// lo mantienes (repeticiones o ráfagas), y eso pulsaba «Abrir» solo. Aquí ignoramos el OK hasta
/// que lo sueltas y pasa un momento sin pulsarlo; a partir de ahí funciona normal.
class _AppOptionsState extends State<_AppOptions> {
  static const _quiet = Duration(milliseconds: 450);
  static final _ok = <LogicalKeyboardKey>{
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };
  bool _released = false;
  DateTime _last = DateTime.now();

  KeyEventResult _guard(FocusNode _, KeyEvent e) {
    if (!_ok.contains(e.logicalKey)) return KeyEventResult.ignored;
    final now = DateTime.now();
    if (e is KeyRepeatEvent) {
      _last = now;
      return KeyEventResult.handled; // mantener OK aquí nunca pulsa nada
    }
    if (e is KeyUpEvent) {
      final blocked = !_released;
      _released = true;
      _last = now;
      return blocked ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    // KeyDown: solo vale si ya soltaste y hubo un rato de calma (no es la ráfaga de mantener).
    if (!_released || now.difference(_last) < _quiet) {
      _released = false;
      _last = now;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final apps = context.watch<AppsModel>();
    final fav = apps.isFavorite(app.package);
    final favIndex = apps.favorites.indexWhere((a) => a.package == app.package);
    final favCount = apps.favorites.length;

    Widget option(IconData icon, String label, VoidCallback onTap, {bool autofocus = false, Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RetroButton(
        autofocus: autofocus,
        color: color,
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 18))),
          ],
        ),
      ),
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _guard,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(20),
          decoration: Retro.box(color: Retro.night, shadow: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(app.label.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: Retro.title(24)),
              const SizedBox(height: 16),
              option(
                Icons.play_arrow_rounded,
                'Abrir',
                () {
                  Navigator.pop(context);
                  apps.launch(app);
                },
                autofocus: true,
                color: Retro.mustard,
              ),
              option(
                fav ? Icons.star : Icons.star_border,
                fav ? 'Quitar del dock' : 'Añadir al dock',
                () => apps.toggleFavorite(app.package),
              ),
              if (fav && favIndex > 0)
                option(Icons.arrow_back, 'Mover a la izquierda', () => apps.moveFavorite(app.package, -1)),
              if (fav && favIndex >= 0 && favIndex < favCount - 1)
                option(Icons.arrow_forward, 'Mover a la derecha', () => apps.moveFavorite(app.package, 1)),
              option(Icons.visibility_off, 'Ocultar', () {
                apps.setHidden(app.package, true);
                Navigator.pop(context);
              }),
              option(Icons.info_outline, 'Información de la app', () {
                Navigator.pop(context);
                Native.appInfo(app.package);
              }),
              option(Icons.delete_outline, 'Desinstalar', () {
                Navigator.pop(context);
                Native.uninstall(app.package);
              }, color: const Color(0xFFFFB4B4)),
            ],
          ),
        ),
      ),
    );
  }
}
