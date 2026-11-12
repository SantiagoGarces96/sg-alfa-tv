/*
 * SG Alfa Home — Alfi, la mascota 8-bit de SG Alfa.
 * Un pequeño espartano pixelado que saluda, avisa y sugiere.
 * Personaje y dibujo originales de SG Alfa. Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/alfi_model.dart';
import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/device_model.dart';
import 'home_widgets.dart';
import 'nav.dart';
import 'retro.dart';

/// Sprite 16×16. k contorno · y penacho · r casco · d sombra · w brillo · c cara · e ojo · b botas.
const _frameIdle = [
  '......kkkk......',
  '.....kyyyyk.....',
  '....kyyyyyyk....',
  '...kkrrrrrrkk...',
  '..krrrrrrrrrrk..',
  '.krwrrrrrrrrrrk.',
  '.krrrrrrrrrrrrk.',
  '.krkkkkkkkkkkrk.',
  '.krkcccccccckrk.',
  '.krkcekcckeckrk.',
  '.krkcccccccckrk.',
  '.krrkcckkcckrrk.',
  '..krrkkkkkkrrk..',
  '...kddrrrrddk...',
  '....kkk..kkk....',
  '....kbbk.kbbk...',
];

final _frameBlink = [
  ..._frameIdle.sublist(0, 9),
  '.krkckkcckkckrk.',
  ..._frameIdle.sublist(10),
];

const _colors = {
  'k': Color(0xFF000000),
  'y': Color(0xFFFFEC27),
  'r': Color(0xFFFF004D),
  'd': Color(0xFF7E2553),
  'w': Color(0xFFFFF1E8),
  'c': Color(0xFFFFCCAA),
  'e': Color(0xFFFFF1E8),
  'b': Color(0xFF29366F),
};

class _SpritePainter extends CustomPainter {
  final List<String> frame;

  _SpritePainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 16;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < frame.length; y++) {
      final row = frame[y];
      for (var x = 0; x < row.length; x++) {
        final c = _colors[row[x]];
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x * px, y * px, px + 0.5, px + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) => !identical(old.frame, frame);
}

/// Alfi animado: rebota y parpadea.
class AlfiSprite extends StatefulWidget {
  final double size;

  const AlfiSprite({super.key, this.size = 80});

  @override
  State<AlfiSprite> createState() => _AlfiSpriteState();
}

class _AlfiSpriteState extends State<AlfiSprite> {
  Timer? _t;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 450), (_) => setState(() => _tick++));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blink = _tick % 9 == 0;
    final up = _tick.isOdd;
    return Transform.translate(
      offset: Offset(0, up ? -widget.size / 16 : 0),
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _SpritePainter(blink ? _frameBlink : _frameIdle),
      ),
    );
  }
}


/// Tarjeta de Alfi en el inicio: habla, da el resumen del día y sugiere.
class AlfiCard extends StatefulWidget {
  const AlfiCard({super.key});

  @override
  State<AlfiCard> createState() => _AlfiCardState();
}

class _AlfiCardState extends State<AlfiCard> {
  Timer? _rotate;
  Timer? _typing;
  int _index = 0;
  String _full = '';
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _say());
    _rotate = Timer.periodic(const Duration(seconds: 15), (_) {
      _index++;
      _say();
    });
  }

  @override
  void dispose() {
    _rotate?.cancel();
    _typing?.cancel();
    super.dispose();
  }

  /// Lo que Alfi puede decir ahora, según lo que sabe de la tele.
  List<String> _lines() {
    final now = DateTime.now();
    final t = context.read<TodayModel>();
    final d = context.read<DeviceModel>();
    final a = context.read<AlfiModel>();
    final apps = context.read<AppsModel>();
    final your = d.your;
    final h = now.hour;
    final hello = h >= 6 && h < 12 ? '¡Buenos días!' : (h >= 12 && h < 19 ? '¡Buenas tardes!' : '¡Buenas noches!');
    final slotNow = h >= 6 && h < 12 ? 'mañana' : (h >= 12 && h < 19 ? 'tarde' : (h >= 19 ? 'noche' : 'madrugada'));
    final learned = a.slots[slotNow];
    return [
      '$hello Soy Alfi y cuido de $your.',
      if (t.adblock) 'Hoy he bloqueado ${t.ads} anuncios. ¡Ni uno se me escapa!',
      if (!t.adblock) 'El bloqueo de anuncios está apagado. Actívalo en Ajustes → Protección.',
      if (t.automation && t.actions > 0) 'He cerrado ${t.actions} avisos por ti hoy.',
      if (a.todayMinutes > 0 && a.today.isNotEmpty)
        'Hoy llevas ${AlfiModel.duration(a.todayMinutes)} de tele, sobre todo ${a.today.first.name}.',
      if (a.week.isNotEmpty)
        'Tu app de la semana: ${a.week.first.name} (${AlfiModel.duration(a.week.first.value.toInt())}).',
      if (learned != null) 'He aprendido que por la $slotNow sueles ver ${learned.name}.',
      if (t.suggestion != null) 'A esta hora sueles ver ${t.suggestion!['name']}. Pulsa ▶ aquí abajo.',
      if (a.cacheTotalMb > 300)
        'Hay ${AlfiModel.size(a.cacheTotalMb)} de caché acumulada. Entra en «Mi resumen» y limpiamos.',
      if (a.forgotten.isNotEmpty) 'No abres ${a.forgotten.first.name} desde hace semanas. ¿La ocultamos?',
      if (d.isTv) 'Para cambiar a HDMI o la antena, usa el botón de entradas de arriba.',
      if (!d.isTv && d.lowStorage) 'A $your le queda poco espacio (${d.freeGb!.toStringAsFixed(1)} GB).',
      if (h >= 23 || h < 5) 'Es tarde… ¿el último capítulo y a dormir?',
      if (apps.favorites.isEmpty) 'Tu dock está vacío. Mantén OK sobre una app para añadirla.',
      'Puedes cambiar mi mundo en Ajustes → Temas.',
    ];
  }

  void _say() {
    if (!mounted) return;
    final lines = _lines();
    _full = lines[_index % lines.length];
    _shown = 0;
    _typing?.cancel();
    _typing = Timer.periodic(const Duration(milliseconds: 26), (tm) {
      if (!mounted) return tm.cancel();
      setState(() => _shown = (_shown + 1).clamp(0, _full.length));
      if (_shown >= _full.length) tm.cancel();
    });
  }

  Widget _chip(IconData icon, String text, Color color) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: Retro.box(color: color, radius: 8, border: 2, shadow: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Retro.on(color)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: Retro.on(color), fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TodayModel>();
    final a = context.watch<AlfiModel>();
    final s = t.suggestion;
    final hasSuggestion = s != null;

    return Container(
      width: 420,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: Retro.box(color: Retro.night.withValues(alpha: 0.92), shadow: 6),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const AlfiSprite(size: 64),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
              decoration: Retro.box(color: Retro.cream, radius: 4, border: 2.5, shadow: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('ALFI', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8, color: Retro.red)),
                const SizedBox(height: 4),
                Text(_full.substring(0, _shown.clamp(0, _full.length)),
                    style: TextStyle(
                        color: Retro.on(Retro.cream), fontSize: 13, fontWeight: FontWeight.w700, height: 1.25)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _chip(Icons.shield, t.adblock ? '${t.ads} bloqueados' : 'sin bloqueo',
              t.adblock ? Retro.positive : Retro.muted),
          _chip(Icons.bolt, '${t.actions} avisos', t.automation ? Retro.mustard : Retro.muted),
          _chip(Icons.tv, AlfiModel.duration(a.todayMinutes), Retro.teal),
        ]),
        const SizedBox(height: 8),
        Nav.arrows(
          up: Nav.toTopBar,
          down: Nav.toDock,
          child: Row(children: [
            if (hasSuggestion)
              Flexible(
                child: RetroButton(
                  focusNode: Nav.suggestion,
                  color: Retro.red,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  onPressed: () => Native.launch('${s['packageName']}'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_arrow_rounded, size: 22),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${s['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
                    ),
                  ]),
                ),
              ),
            RetroButton(
              focusNode: hasSuggestion ? null : Nav.suggestion,
              color: Retro.panel,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onPressed: () => AlfiReportScreen.open(context),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.insights, size: 20),
                SizedBox(width: 4),
                Text('MI RESUMEN', style: TextStyle(fontSize: 14)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// «Mi resumen»: lo que Alfi ha visto y aprendido, y la limpieza de caché.
class AlfiReportScreen extends StatefulWidget {
  const AlfiReportScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute(builder: (_) => const AlfiReportScreen()));

  @override
  State<AlfiReportScreen> createState() => _AlfiReportScreenState();
}

class _AlfiReportScreenState extends State<AlfiReportScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    final up = e.logicalKey == LogicalKeyboardKey.arrowUp;
    if ((!down && !up) || !_scroll.hasClients) return KeyEventResult.ignored;
    final target = (_scroll.offset + (down ? 180 : -180)).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic);
    return KeyEventResult.ignored; // y que el foco siga a los botones si los hay
  }

  @override
  void initState() {
    super.initState();
    context.read<AlfiModel>().refresh();
  }

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 16, right: 6),
        padding: const EdgeInsets.all(14),
        decoration: Retro.box(color: Retro.panel, shadow: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RetroSticker(title, color: Retro.mustard),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _bar(AlfiApp app, int max) {
    final f = max == 0 ? 0.0 : (app.value / max).clamp(0.04, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 170, child: Text(app.name, overflow: TextOverflow.ellipsis, style: Retro.body(14))),
        Expanded(
          child: LayoutBuilder(
            builder: (_, c) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: c.maxWidth * f,
                height: 14,
                decoration: BoxDecoration(color: Retro.red, border: Border.all(color: Retro.ink, width: 2)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: Text(AlfiModel.duration(app.value.toInt()), style: Retro.body(13))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AlfiModel>();
    final t = context.watch<TodayModel>();
    final apps = context.read<AppsModel>();
    final your = context.read<DeviceModel>().your;
    String slotName(String s) => switch (s) {
          'mañana' => 'Por la mañana',
          'tarde' => 'Por la tarde',
          'noche' => 'Por la noche',
          _ => 'De madrugada',
        };
    final maxToday = a.today.isEmpty ? 0 : a.today.first.value.toInt();
    final maxWeek = a.week.isEmpty ? 0 : a.week.first.value.toInt();
    final summary = 'Llevas ${AlfiModel.duration(a.todayMinutes)} de tele. '
        '${t.adblock ? 'He bloqueado ${t.ads} anuncios' : 'El bloqueo de anuncios está apagado'}'
        ' y he cerrado ${t.actions} avisos.';
    final cacheText = a.cacheTotalMb > 0
        ? 'Las apps de $your guardan ${AlfiModel.size(a.cacheTotalMb)} de caché. '
            'Borrarla libera espacio y no pierdes nada (solo tarda un poco más la primera vez).'
        : 'No he podido medir la caché.';

    return Scaffold(
      backgroundColor: Retro.night,
      body: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const AlfiSprite(size: 56),
            const SizedBox(width: 12),
            Expanded(child: Text('MI RESUMEN', style: Retro.title(28))),
            RetroButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Row(children: [Icon(Icons.arrow_back), SizedBox(width: 6), Text('VOLVER')]),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(controller: _scroll, padding: const EdgeInsets.only(bottom: 30), children: [
              _section('HOY', [
                Text(summary, style: Retro.body(15)),
                const SizedBox(height: 10),
                if (a.today.isEmpty) Text('Aún no has visto nada hoy.', style: Retro.body(14)),
                for (final x in a.today) _bar(x, maxToday),
              ]),
              _section('ESTA SEMANA', [
                Text('${AlfiModel.duration(a.weekMinutes)} en total.', style: Retro.body(15)),
                const SizedBox(height: 10),
                for (final x in a.week) _bar(x, maxWeek),
              ]),
              _section('LO QUE HE APRENDIDO', [
                if (a.slots.isEmpty)
                  Text('Todavía estoy aprendiendo tus costumbres. Vuelve en unos días.', style: Retro.body(14)),
                for (final e in a.slots.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${slotName(e.key)} sueles ver ${e.value.name} (${e.value.value} días).',
                        style: Retro.body(15)),
                  ),
              ]),
              _section('LIMPIEZA', [
                Text(cacheText, style: Retro.body(14)),
                const SizedBox(height: 10),
                for (final x in a.cache)
                  Row(children: [
                    Expanded(child: Text('${x.name} · ${AlfiModel.size(x.value.toDouble())}', style: Retro.body(14))),
                    RetroButton(
                      color: Retro.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      onPressed: () => Native.appInfo(x.package),
                      child: const Text('LIMPIAR', style: TextStyle(fontSize: 13)),
                    ),
                  ]),
                if (a.cache.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('«Limpiar» abre la ficha de la app: pulsa «Borrar caché» (nunca «Borrar datos»).',
                        style: Retro.body(13, color: Retro.mustard)),
                  ),
              ]),
              if (a.forgotten.isNotEmpty)
                _section('APPS OLVIDADAS', [
                  Text('No las abres desde hace más de 3 semanas.', style: Retro.body(14)),
                  const SizedBox(height: 8),
                  for (final x in a.forgotten)
                    Row(children: [
                      Expanded(child: Text(x.name, style: Retro.body(14))),
                      RetroButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        onPressed: () => apps.setHidden(x.package, true),
                        child: const Text('OCULTAR', style: TextStyle(fontSize: 13)),
                      ),
                    ]),
                ]),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}
