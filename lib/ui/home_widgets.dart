/*
 * SG Alfa Home — barra superior, zona destacada y «TU TELE HOY».
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/device_model.dart';
import '../core/theme_model.dart';
import 'mascot.dart';
import 'nav.dart';
import 'retro.dart';

const _days = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String _greeting(DateTime now) {
  if (now.hour >= 6 && now.hour < 12) return '¡Buenos días!';
  if (now.hour >= 12 && now.hour < 19) return '¡Buenas tardes!';
  return '¡Buenas noches!';
}

/// Estado de protección compartido por la barra y la tarjeta (se refresca cada 30 s).
class TodayModel extends ChangeNotifier with WidgetsBindingObserver {
  Map<dynamic, dynamic> data = const {};
  Timer? _timer;

  bool get adblock => data['adblock'] == true;
  bool get automation => data['automation'] == true;
  int get ads => (data['ads'] as num?)?.toInt() ?? 0;
  int get actions => (data['actions'] as num?)?.toInt() ?? 0;
  Map? get suggestion => data['suggestion'] is Map ? data['suggestion'] as Map : null;
  bool get cleanDue => data['cleanDue'] == true;
  bool get cleanWeekly => data['cleanWeekly'] != false;
  int get cleanWeekday => (data['cleanWeekday'] as num?)?.toInt() ?? 2;
  String get cleanLast => '${data['cleanLast'] ?? ''}';
  bool get alfiToasts => data['alfiToasts'] != false;
  int get missingTemplates => (data['missingTemplates'] as num?)?.toInt() ?? 0;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      final t = await Native.protection.invokeMethod('getToday');
      if (t is Map) {
        data = t;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ---------------------------------------------------------------- barra

class TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onProtection;

  const TopBar({super.key, required this.onSettings, required this.onProtection});

  @override
  Widget build(BuildContext context) {
    final today = context.watch<TodayModel>();
    return Nav.arrows(
      down: Nav.belowTopBar,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: Retro.box(color: Retro.cream, radius: 10, border: 2.5, shadow: 3),
          child: Image.asset('assets/helmet.png'),
        ),
        const SizedBox(width: 10),
        Text('SG ALFA', style: Retro.title(20)),
        const SizedBox(width: 16),
        BarIcon(icon: Icons.settings_outlined, onPressed: onSettings, focusNode: Nav.settings),
        const SizedBox(width: 6),
        const _NetworkBadge(),
        const SizedBox(width: 6),
        const _DeviceActions(),
        const Spacer(),
        RetroButton(
          color: today.adblock ? Retro.positive : Retro.cream,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          radius: 20,
          onPressed: onProtection,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(today.adblock ? Icons.shield : Icons.shield_outlined, size: 18),
            const SizedBox(width: 6),
            Text(today.adblock ? 'Anuncios bloqueados' : 'Sin bloqueo', style: const TextStyle(fontSize: 13)),
          ]),
        ),
      ]),
    ),
    );
  }
}

class _NetworkBadge extends StatefulWidget {
  const _NetworkBadge();

  @override
  State<_NetworkBadge> createState() => _NetworkBadgeState();
}

class _NetworkBadgeState extends State<_NetworkBadge> {
  String _type = 'wifi';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final t = await Native.networkType();
      if (mounted && t != _type) setState(() => _type = t);
    } catch (_) {}
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (_type) {
      'ethernet' => Icons.settings_ethernet,
      'none' => Icons.wifi_off,
      _ => Icons.wifi,
    };
    return BarIcon(icon: icon, onPressed: Native.openWifiSettings, alert: _type == 'none');
  }
}

// ---------------------------------------------------------------- zona destacada

class HomeHero extends StatefulWidget {
  const HomeHero({super.key});

  @override
  State<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<HomeHero> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      final n = DateTime.now();
      if (n.minute != _now.minute || n.hour != _now.hour) setState(() => _now = n);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = '${_days[_now.weekday - 1]} ${_now.day} de ${_months[_now.month - 1]}';
    final time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final focused = context.select<AppsModel, String?>((m) => m.focusedLabel);
    final theme = context.watch<ThemeModel>().current;
    final showToday = theme.today;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  RetroSticker(_greeting(_now), color: Retro.mustard, textColor: Retro.ink),
                  const SizedBox(width: 12),
                  Text(date, style: Retro.body(18)),
                ]),
                const SizedBox(height: 10),
                if (theme.clock != 'oculto') Text(time, style: Retro.title(theme.clock == 'mediano' ? 56 : 84)),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: focused == null
                      ? const SizedBox(height: 46, key: ValueKey('none'))
                      : Row(key: ValueKey(focused), children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: Retro.box(color: Retro.red, radius: 10, shadow: 4),
                            child: Text(focused,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Retro.title(24)),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Text('OK para abrir  ·  mantén OK para opciones',
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: Retro.body(15)),
                          ),
                        ]),
                ),
              ],
            ),
          ),
          if (theme.mascot) ...[
            const SizedBox(width: 24),
            const AlfiCard(),
          ] else if (showToday) ...[
            const SizedBox(width: 24),
            const TodayCard(),
          ],
        ],
      ),
    );
  }
}

/// «TU TELE HOY»: anuncios bloqueados, avisos cerrados y la app que sueles ver a esta hora.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key});

  Widget _stat(IconData icon, String number, String label, Color color, bool on) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: Retro.box(color: on ? color : Retro.muted, radius: 9, border: 2.5, shadow: 2),
            child: Icon(icon, size: 20, color: Retro.ink),
          ),
          const SizedBox(width: 10),
          Text(number, style: Retro.title(26)),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: Retro.body(14))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TodayModel>();
    final s = t.suggestion;
    return Container(
      width: 400,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: Retro.box(color: Retro.night.withValues(alpha: 0.9), shadow: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RetroSticker('TU TELE HOY', color: Retro.teal),
          const SizedBox(height: 12),
          _stat(Icons.shield, '${t.ads}', t.adblock ? 'anuncios bloqueados' : 'bloqueo apagado',
              Retro.positive, t.adblock),
          const SizedBox(height: 8),
          _stat(Icons.bolt, '${t.actions}', t.automation ? 'avisos cerrados solos' : 'automatizaciones apagadas',
              Retro.mustard, t.automation),
          if (s != null) ...[
            const SizedBox(height: 14),
            Text('A ESTA HORA SUELES VER', style: Retro.body(13, color: Retro.mustard, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Nav.arrows(
              up: Nav.toTopBar,
              down: Nav.toDock,
              child: RetroButton(
              focusNode: Nav.suggestion,
              color: Retro.red,
              focusColor: Retro.mustard,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onPressed: () => Native.launch('${s['packageName']}'),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.play_arrow_rounded, size: 26),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('${s['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18)),
                ),
              ]),
            ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Título de sección («TODAS LAS APPS»).
class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        child: Row(children: [
          Container(width: 5, height: 22, color: Retro.red),
          const SizedBox(width: 10),
          Text(text, style: Retro.title(18)),
        ]),
      );
}

/// Deja pasar teclas de dirección a la navegación por foco normal.
bool isArrow(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.arrowUp ||
    k == LogicalKeyboardKey.arrowDown ||
    k == LogicalKeyboardKey.arrowLeft ||
    k == LogicalKeyboardKey.arrowRight;

/// Icono suelto de la barra superior; al enfocarlo aparece un círculo con contorno.
class BarIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool alert;
  final FocusNode? focusNode;

  const BarIcon({super.key, required this.icon, required this.onPressed, this.alert = false, this.focusNode});

  @override
  State<BarIcon> createState() => _BarIconState();
}

class _BarIconState extends State<BarIcon> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => InkWell(
        focusNode: widget.focusNode,
        onTap: widget.onPressed,
        onFocusChange: (f) => setState(() => _focused = f),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _focused ? Retro.panel : Colors.transparent,
            border: Border.all(color: _focused ? Retro.mustard : Colors.transparent, width: 2.5),
          ),
          child: Icon(widget.icon,
              size: 21,
              color: widget.alert ? Color(0xFFFF8A8A) : Retro.cream,
              shadows: [Shadow(color: Retro.ink, offset: Offset(2, 2))]),
        ),
      );
}

/// Accesos que cambian según el aparato: en un televisor, entradas e imagen;
/// en un deco, el espacio libre (avisa si queda poco).
class _DeviceActions extends StatelessWidget {
  const _DeviceActions();

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DeviceModel>();
    if (!d.loaded) return const SizedBox.shrink();
    if (d.isTv) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        BarIcon(icon: Icons.input, onPressed: () => Native.launcher.invokeMethod('openInputs')),
        const SizedBox(width: 6),
        BarIcon(icon: Icons.tune, onPressed: () => Native.launcher.invokeMethod('openPicture')),
      ]);
    }
    return BarIcon(
      icon: Icons.sd_storage_outlined,
      alert: d.lowStorage,
      onPressed: () => Native.launcher.invokeMethod('openStorage'),
    );
  }
}
