/*
 * SG Alfa Home — primera vez en un deco o tele nuevos: pedir de una vez todos los permisos.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/native.dart';
import 'pro.dart';

const _kDone = 'onboarded';

/// Si es la primera vez y falta algún permiso, muestra la ventana para activarlos todos.
Future<void> maybeFirstRun(BuildContext context) async {
  final p = await SharedPreferences.getInstance();
  if (p.getBool(_kDone) == true) return;
  final st = await _status();
  if (st.all) {
    await p.setBool(_kDone, true);
    return;
  }
  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC000000),
    builder: (_) => const _FirstRun(),
  );
  await p.setBool(_kDone, true);
}

class _Status {
  final bool adblock, automation, media, install;
  const _Status(this.adblock, this.automation, this.media, this.install);
  bool get all => adblock && automation && media && install;
}

Future<_Status> _status() async {
  bool ad = false, auto = false, media = false, install = true;
  try {
    final s = await Native.protection.invokeMethod<Map>('getState');
    ad = s?['adblock'] == true;
    auto = s?['automation'] == true;
  } catch (_) {}
  try {
    final m = await Native.widgets.invokeMethod<Map>('media');
    media = m?['access'] == true;
  } catch (_) {}
  try {
    install = await Native.protection.invokeMethod<bool>('canInstall') ?? true;
  } catch (_) {}
  return _Status(ad, auto, media, install);
}

class _FirstRun extends StatefulWidget {
  const _FirstRun();

  @override
  State<_FirstRun> createState() => _FirstRunState();
}

class _FirstRunState extends State<_FirstRun> with WidgetsBindingObserver {
  _Status _s = const _Status(false, false, false, false);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes del sistema se revisa qué quedó activado y se sigue con el siguiente.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final s = await _status();
    if (!mounted) return;
    setState(() {
      _s = s;
      _busy = false;
    });
  }

  /// Activa el siguiente permiso que falte, en orden: bloqueo de anuncios, automatizaciones, música.
  Future<void> _next() async {
    setState(() => _busy = true);
    try {
      if (!_s.adblock) {
        await Native.protection.invokeMethod('setAdblock', true);
        await _refresh();
        return;
      }
      if (!_s.automation) {
        await Native.protection.invokeMethod('openAccessibilitySettings');
        return; // se sigue al volver
      }
      if (!_s.media) {
        await Native.widgets.invokeMethod('openMediaAccess');
        return;
      }
      if (!_s.install) {
        await Native.protection.invokeMethod('openInstallPermission');
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Widget _item(IconData icon, String title, String sub, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 30, color: Pro.text),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              Text(sub, style: TextStyle(fontSize: 15, color: Pro.text.withValues(alpha: 0.65))),
            ]),
          ),
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              color: ok ? const Color(0xFF34C38F) : Pro.text.withValues(alpha: 0.5), size: 28),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final all = _s.all;
    return Dialog(
      backgroundColor: Pro.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 260, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(all ? 'Todo listo' : 'Bienvenido a SG Alfa', style: Pro.title(28)),
          const SizedBox(height: 6),
          Text(
            all
                ? 'Los anuncios se bloquean, las automatizaciones funcionan y se ve lo que suena.'
                : 'Para que todo funcione, activa estos permisos. Al volver de cada pantalla seguimos con el siguiente.',
            style: TextStyle(fontSize: 16, color: Pro.text.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 12),
          _item(Icons.shield, 'Bloqueo de anuncios', 'Acepta «Solicitud de conexión» (VPN local, no sale de la tele)',
              _s.adblock),
          _item(Icons.smart_button, 'Automatizaciones',
              'Accesibilidad → «SG Alfa · Automatizaciones» → Activar', _s.automation),
          _item(Icons.music_note, 'Lo que suena',
              'Acceso a notificaciones → «SG Alfa · Sonando ahora» → Permitir', _s.media),
          _item(Icons.system_update_alt, 'Actualizaciones automáticas',
              'Instalar apps desconocidas → «SG Alfa Home» → Permitir', _s.install),
          const SizedBox(height: 16),
          ProButton(
            autofocus: true,
            onPressed: _busy ? null : (all ? () => Navigator.of(context).pop() : _next),
            child: Text(all ? 'Empezar' : (_busy ? 'Un momento…' : 'Activar lo que falta'),
                style: const TextStyle(fontSize: 18)),
          ),
          if (!all) ...[
            const SizedBox(height: 8),
            ProButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Más tarde', style: TextStyle(fontSize: 18)),
            ),
          ],
        ]),
      ),
    );
  }
}
