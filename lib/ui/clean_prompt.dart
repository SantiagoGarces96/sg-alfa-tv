/*
 * SG Alfa Home — «¡Lunes de limpieza!»: Alfi avisa, cuenta 10 segundos y limpia la caché.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/alfi_model.dart';
import '../core/native.dart';
import 'home_widgets.dart';
import 'mascot.dart';
import 'retro.dart';

Future<void> showCleanPrompt(BuildContext context) => showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xAA000000),
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<AlfiModel>()),
          ChangeNotifierProvider.value(value: context.read<TodayModel>()),
        ],
        child: const _CleanPrompt(),
      ),
    );

class _CleanPrompt extends StatefulWidget {
  const _CleanPrompt();

  @override
  State<_CleanPrompt> createState() => _CleanPromptState();
}

class _CleanPromptState extends State<_CleanPrompt> {
  int _left = 10;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        _start();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _t?.cancel();
    if (mounted) Navigator.of(context).pop();
    await Native.protection.invokeMethod('cleanNow');
  }

  Future<void> _skip() async {
    _t?.cancel();
    await Native.protection.invokeMethod('cleanSkipToday');
    if (mounted) Navigator.of(context).pop();
    if (mounted) context.read<TodayModel>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AlfiModel>();
    final size = a.cacheTotalMb > 0 ? ' (unos ${AlfiModel.size(a.cacheTotalMb)})' : '';
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(18),
        decoration: Retro.box(color: Retro.night, shadow: 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const AlfiSprite(size: 84),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: Retro.box(color: Retro.cream, radius: 4, border: 3, shadow: 3),
                child: Text(
                  '¡Lunes de limpieza! Voy a borrar la caché de tus apps$size. '
                  'Solo la caché: tus cuentas y datos no se tocan. Tardo un minuto; no toques el mando.',
                  style: TextStyle(color: Retro.on(Retro.cream), fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            RetroButton(
              autofocus: true,
              color: Retro.teal,
              onPressed: _start,
              child: Text('EMPEZAR YA ($_left)'),
            ),
            RetroButton(onPressed: _skip, child: const Text('HOY NO')),
          ]),
        ]),
      ),
    );
  }
}
