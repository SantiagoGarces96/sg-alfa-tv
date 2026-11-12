/*
 * SG Alfa Home — opciones de una app (mantener OK).
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
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

class _AppOptions extends StatelessWidget {
  final TvApp app;

  const _AppOptions({required this.app});

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppsModel>();
    final fav = apps.isFavorite(app.package);
    final favIndex = apps.favorites.indexWhere((a) => a.package == app.package);
    final favCount = apps.favorites.length;

    Widget option(IconData icon, String label, VoidCallback onTap,
            {bool autofocus = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RetroButton(
            autofocus: autofocus,
            color: color,
            onPressed: onTap,
            child: Row(children: [
              Icon(icon, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 18))),
            ]),
          ),
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        decoration: Retro.box(color: Retro.night, shadow: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(app.label.toUpperCase(),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: Retro.title(24)),
            const SizedBox(height: 16),
            option(Icons.play_arrow_rounded, 'Abrir', () {
              Navigator.pop(context);
              apps.launch(app);
            }, autofocus: true, color: Retro.mustard),
            option(fav ? Icons.star : Icons.star_border, fav ? 'Quitar del dock' : 'Añadir al dock',
                () => apps.toggleFavorite(app.package)),
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
    );
  }
}
