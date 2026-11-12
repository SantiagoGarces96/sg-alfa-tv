/*
 * SG Alfa Home — ventana de actualización: Alfi cuenta las novedades, descarga e instala.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/update_model.dart';
import 'mascot.dart';
import 'retro.dart';

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
      message = '¡Hay una versión nueva! Tienes la ${u.current} y ya está la ${u.latest}.';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(18),
        decoration: Retro.box(color: Retro.night, shadow: 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const AlfiSprite(size: 80),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: Retro.box(color: Retro.cream, radius: 4, border: 3, shadow: 3),
                child: Text(message,
                    style: TextStyle(color: Retro.on(Retro.cream), fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
              ),
            ),
          ]),
          if (u.available && !downloading && u.state != 'ready') ...[
            const SizedBox(height: 14),
            Text('NOVEDADES', style: Retro.title(15)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(child: Text(notes, style: Retro.body(13, weight: FontWeight.w500))),
            ),
          ],
          if (downloading || u.state == 'ready') ...[
            const SizedBox(height: 14),
            Container(
              height: 22,
              decoration: Retro.box(color: Retro.panel, radius: 4, border: 3, shadow: 2),
              child: LayoutBuilder(
                builder: (_, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(width: c.maxWidth * (u.state == 'ready' ? 1 : u.fraction), color: Retro.teal),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            if (u.available && !downloading && u.state != 'ready')
              RetroButton(
                autofocus: true,
                color: Retro.teal,
                onPressed: u.download,
                child: const Row(children: [Icon(Icons.system_update_alt), SizedBox(width: 6), Text('ACTUALIZAR')]),
              ),
            if (u.state == 'ready')
              RetroButton(
                autofocus: true,
                color: Retro.teal,
                onPressed: u.install,
                child: const Text('INSTALAR'),
              ),
            if (!u.available)
              RetroButton(
                autofocus: true,
                color: Retro.teal,
                onPressed: u.check,
                child: const Text('BUSCAR OTRA VEZ'),
              ),
            RetroButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(downloading ? 'SEGUIR EN SEGUNDO PLANO' : 'MÁS TARDE'),
            ),
          ]),
        ]),
      ),
    );
  }
}
