/*
 * SG Alfa Home — ventana de actualización: Alfi cuenta las novedades, descarga e instala.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/update_model.dart';
import 'mascot.dart';
import 'pro.dart';

Future<void> showUpdateDialog(BuildContext context) => showDialog(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<UpdateModel>(),
        child: const _UpdateDialog(),
      ),
    );

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context) {
    final u = context.watch<UpdateModel>();
    final downloading = u.state == 'downloading';
    final notes = u.notes.trim().isEmpty ? 'Mejoras y arreglos.' : u.notes.trim();

    String message;
    if (!u.available) {
      message = u.checking
          ? 'Estoy mirando si hay una versión nueva…'
          : 'Tienes la última versión (${u.current}). ¡Todo al día!';
    } else if (downloading) {
      message = 'Descargando la versión ${u.latest}… ${(u.fraction * 100).round()} %';
    } else if (u.state == 'ready') {
      message = 'Listo. Pulsa «Instalar» en la ventana de Android. Tus ajustes, temas y automatizaciones se quedan.';
    } else if (u.state == 'error') {
      message = 'No pude descargarla (${u.error}). Revisa la conexión e inténtalo otra vez.';
    } else {
      message = '¡Nueva actualización disponible! Ya está la ${u.latest} (tienes la ${u.current}). Pulsa «Actualizar ahora».';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(18),
        decoration: Pro.box(color: Pro.bg, shadow: 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const AlfiSprite(size: 80),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: Pro.box(color: Pro.text, radius: 4, border: 3, shadow: 3),
                child: Text(message,
                    style: TextStyle(color: Pro.text, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
              ),
            ),
          ]),
          if (u.available && !downloading && u.state != 'ready') ...[
            const SizedBox(height: 14),
            Text('Novedades', style: Pro.title(15)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(child: Text(notes, style: Pro.body(13, weight: FontWeight.w500))),
            ),
          ],
          if (downloading || u.state == 'ready') ...[
            const SizedBox(height: 14),
            Container(
              height: 22,
              decoration: Pro.box(color: Pro.card, radius: 4, border: 3, shadow: 2),
              child: LayoutBuilder(
                builder: (_, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(width: c.maxWidth * (u.state == 'ready' ? 1 : u.fraction), color: Pro.accent),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            if (u.available && !downloading && u.state != 'ready')
              ProButton(
                autofocus: true,
                color: Pro.accent,
                onPressed: u.download,
                child: const Row(children: [Icon(Icons.system_update_alt), SizedBox(width: 6), Text('Actualizar ahora')]),
              ),
            if (u.state == 'ready')
              ProButton(
                autofocus: true,
                color: Pro.accent,
                onPressed: u.install,
                child: const Text('Instalar'),
              ),
            if (!u.available)
              ProButton(
                autofocus: true,
                color: Pro.accent,
                onPressed: u.check,
                child: const Text('Buscar otra vez'),
              ),
            ProButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(downloading ? 'Seguir en segundo plano' : (u.available ? 'Más tarde' : 'Cerrar')),
            ),
          ]),
        ]),
      ),
    );
  }
}
