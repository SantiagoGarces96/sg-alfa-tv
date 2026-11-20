/*
 * SG Alfa Home — inicio «Tablero»: hora y fecha, clima, lo que suena, botones redondos,
 * «Continuar viendo» con Alfi sentado encima, franja de 8 apps y el resto debajo.
 * Todas las medidas son proporcionales a una pantalla de 1600×900 (u = ancho / 1600).
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/widgets_model.dart';
import 'home_widgets.dart';
import 'nav.dart';
import 'pro.dart';
import 'pro_dialogs.dart';
import '../core/parental.dart';

double dashUnit(BuildContext context) =>
    MediaQuery.sizeOf(context).width / 1600;

const _days = [
  'LUNES',
  'MARTES',
  'MIÉRCOLES',
  'JUEVES',
  'VIERNES',
  'SÁBADO',
  'DOMINGO',
];
const _months = [
  'ENERO',
  'FEBRERO',
  'MARZO',
  'ABRIL',
  'MAYO',
  'JUNIO',
  'JULIO',
  'AGOSTO',
  'SEPTIEMBRE',
  'OCTUBRE',
  'NOVIEMBRE',
  'DICIEMBRE',
];

const _shadow = [
  Shadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 1)),
];

BoxDecoration _glass(double u, {double radius = 22}) => BoxDecoration(
  color: Colors.black.withValues(alpha: 0.28),
  borderRadius: BorderRadius.circular(radius * u),
  border: Border.all(
    color: Colors.white.withValues(alpha: 0.28),
    width: 1.5 * u,
  ),
);

// ======================================================================= barra superior

class DashTopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onProtection;

  const DashTopBar({
    super.key,
    required this.onSettings,
    required this.onProtection,
  });

  @override
  Widget build(BuildContext context) {
    final u = dashUnit(context);
    final today = context.watch<TodayModel>();
    final inputs = context.watch<WidgetsModel>().inputs;
    final hasInputs = inputs.isNotEmpty;
    // Botones de la derecha (lupa, entradas en teles, escudo, wifi, ajustes) y, a su izquierda,
    // el reproductor completo (con pasar/devolver canción) y el clima. La hora se achica para que quepa.
    final circlesLeft = hasInputs ? 1090.0 : 1177.0;
    final mediaW = hasInputs ? 400.0 : 425.0;
    final mediaLeft = circlesLeft - 17 - mediaW;
    final weatherLeft = mediaLeft - 17 - 214;
    return Nav.arrows(
      down: Nav.belowTopBar,
      child: SizedBox(
        height: 140 * u,
        child: Stack(
          children: [
            Positioned(
              left: (hasInputs ? 60 : 95) * u,
              top: 47 * u,
              height: 82 * u,
              child: _ClockDate(u: u),
            ),
            Positioned(
              left: weatherLeft * u,
              top: 47 * u,
              width: 214 * u,
              height: 82 * u,
              child: _WeatherCard(u: u),
            ),
            Positioned(
              left: mediaLeft * u,
              top: 47 * u,
              width: mediaW * u,
              height: 82 * u,
              child: _MediaCard(u: u),
            ),
            Positioned(
              left: circlesLeft * u,
              top: 50 * u,
              child: Row(
                children: [
                  // Buscar a la vez en TizenTube, Spotify, WiwyXuper, Anime Cast...
                  _Circle(
                    u: u,
                    icon: Icons.search,
                    onPressed: () => showGlobalSearch(context),
                  ),
                  SizedBox(width: 17 * u),
                  if (hasInputs) ...[
                    // Entradas de la tele (HDMI, AV, antena...), al lado del escudo.
                    _Circle(
                      u: u,
                      icon: Icons.input,
                      onPressed: () => showInputsMenu(context),
                    ),
                    SizedBox(width: 17 * u),
                  ],
                  _Circle(
                    u: u,
                    icon: today.adblock ? Icons.shield : Icons.shield_outlined,
                    color: today.adblock
                        ? Colors.white
                        : const Color(0xFFFF8A8A),
                    onPressed: onProtection,
                  ),
                  SizedBox(width: 17 * u),
                  _Circle(
                    u: u,
                    icon: Icons.wifi,
                    onPressed: () =>
                        Native.launcher.invokeMethod('openWifiSettings'),
                  ),
                  SizedBox(width: 17 * u),
                  _Circle(
                    u: u,
                    icon: Icons.settings,
                    onPressed: onSettings,
                    focusNode: Nav.settings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockDate extends StatefulWidget {
  final double u;

  const _ClockDate({required this.u});

  @override
  State<_ClockDate> createState() => _ClockDateState();
}

class _ClockDateState extends State<_ClockDate> {
  DateTime _now = DateTime.now();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 10), (_) {
      final n = DateTime.now();
      if (n.minute != _now.minute) setState(() => _now = n);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final time = hora12(_now);
    final small = TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontSize: 13 * u,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2 * u,
      shadows: _shadow,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          time,
          style: TextStyle(
            color: Colors.white,
            fontSize: 56 * u,
            fontWeight: FontWeight.w300,
            height: 1,
            shadows: _shadow,
          ),
        ),
        SizedBox(width: 6 * u),
        Padding(
          padding: EdgeInsets.only(top: 16 * u),
          child: Text(
            ampm(_now),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 17 * u,
              fontWeight: FontWeight.w400,
              shadows: _shadow,
            ),
          ),
        ),
        SizedBox(width: 14 * u),
        Container(
          width: 1.5 * u,
          height: 40 * u,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        SizedBox(width: 14 * u),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_days[_now.weekday - 1], style: small),
            SizedBox(height: 8 * u),
            Text('${_now.day} DE ${_months[_now.month - 1]}', style: small),
          ],
        ),
      ],
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final double u;

  const _WeatherCard({required this.u});

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WidgetsModel>();
    final wx = w.weather;
    final st = TextStyle(
      color: Colors.white,
      fontSize: 17.5 * u,
      height: 1.1,
      fontWeight: FontWeight.w500,
    );
    return Container(
      decoration: _glass(u),
      padding: EdgeInsets.symmetric(horizontal: 15 * u, vertical: 8 * u),
      alignment: Alignment.centerLeft,
      child: wx == null
          ? Text(
              w.city.isEmpty
                  ? 'Clima: elige tu ciudad en Ajustes'
                  : 'Clima · ${w.city}\nCargando…',
              style: st,
              maxLines: 3,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  wx.city.length > 12
                      ? '${wx.temp} °C · ${wx.desc}'
                      : '${wx.temp} °C · ${wx.city}',
                  style: st,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  wx.city.length > 12 ? wx.city : wx.desc,
                  style: st,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Máx. ${wx.max}°  /  Mín. ${wx.min}°',
                  style: st,
                  maxLines: 1,
                ),
              ],
            ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final double u;
  /// En teles (con botón de entradas) hay menos sitio: solo ▶/❚❚.
  final bool compact;

  const _MediaCard({required this.u, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WidgetsModel>();
    final m = w.media;
    final access = m['access'] == true;
    final title = m['title'] as String?;
    final resume = m['resume'] == true;
    // Si la app se pausó al salir (TizenTube), se muestra en pausa y ▶ vuelve a abrirla.
    final artist = resume
        ? (m['app'] != null ? '${m['app']} · en pausa' : 'En pausa')
        : m['artist'] as String?;
    final art = m['art'] as Uint8List?;
    final playing = m['playing'] == true;
    final dur = (m['duration'] as num?)?.toDouble() ?? 0;
    final pos = (m['position'] as num?)?.toDouble() ?? 0;
    final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    final titleSt = TextStyle(
      color: Colors.white,
      fontSize: 20 * u,
      fontWeight: FontWeight.w600,
    );
    final subSt = TextStyle(
      color: Colors.white.withValues(alpha: 0.85),
      fontSize: 17 * u,
      fontWeight: FontWeight.w500,
    );

    return Container(
      decoration: _glass(u),
      padding: EdgeInsets.fromLTRB(14 * u, 13 * u, 14 * u, 13 * u),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6 * u),
            child: SizedBox.square(
              dimension: 54 * u,
              child: art != null
                  ? Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true)
                  : ColoredBox(
                      color: Colors.white.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.music_note,
                        color: Colors.white70,
                        size: 30 * u,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 13 * u),
          Expanded(
            child: !access
                ? _Pill(
                    u: u,
                    label: 'Mostrar lo que suena',
                    onPressed: () => w.openMediaAccess(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title ?? 'Nada sonando',
                        style: titleSt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (artist != null && artist.isNotEmpty)
                        Text(
                          artist,
                          style: subSt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      SizedBox(height: 6 * u),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2 * u),
                        child: SizedBox(
                          height: 4 * u,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF4DD0C8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (access) ...[
            SizedBox(width: 8 * u),
            if (!compact) ...[
              _MediaBtn(
                u: u,
                icon: Icons.skip_previous,
                onPressed: () => w.command('prev'),
              ),
              SizedBox(width: 6 * u),
            ],
            _MediaBtn(
              u: u,
              icon: playing ? Icons.pause : Icons.play_arrow,
              onPressed: () => w.command('toggle'),
            ),
            if (!compact) ...[
              SizedBox(width: 6 * u),
              _MediaBtn(
                u: u,
                icon: Icons.skip_next,
                onPressed: () => w.command('next'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Botón con foco: al enfocarlo se vuelve blanco con el icono oscuro.
class _Focusable extends StatefulWidget {
  final Widget Function(bool focused) builder;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final VoidCallback? onFocused;
  /** Mantener OK pulsado (≈0,7 s). */
  final VoidCallback? onLongPress;

  const _Focusable({
    this.onFocused,
    this.onLongPress,
    required this.builder,
    required this.onPressed,
    this.focusNode,
  });

  @override
  State<_Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<_Focusable> {
  bool _f = false;
  DateTime? _down;
  bool _longDone = false;

  bool _isOk(KeyEvent e) =>
      e.logicalKey == LogicalKeyboardKey.select ||
      e.logicalKey == LogicalKeyboardKey.enter ||
      e.logicalKey == LogicalKeyboardKey.numpadEnter;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: widget.focusNode,
    onFocusChange: (f) {
      setState(() => _f = f);
      if (f) widget.onFocused?.call();
    },
    onKeyEvent: (_, e) {
      if (!_isOk(e)) return KeyEventResult.ignored;
      if (widget.onLongPress == null) {
        if (e is KeyDownEvent) widget.onPressed();
        return KeyEventResult.handled;
      }
      // Con pulsación larga: OK corto abre, OK mantenido ofrece quitar.
      if (e is KeyDownEvent) {
        _down = DateTime.now();
        _longDone = false;
      } else if (e is KeyRepeatEvent) {
        // La repetición solo llega tras mantener el botón (≈0,5 s): eso ya es pulsación larga.
        if (!_longDone && _down != null) {
          _longDone = true;
          widget.onLongPress!();
        }
      } else if (e is KeyUpEvent) {
        if (!_longDone && _down != null) widget.onPressed();
        _down = null;
      }
      return KeyEventResult.handled;
    },
    child: GestureDetector(
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _f ? 1.1 : 1,
        duration: const Duration(milliseconds: 140),
        child: widget.builder(_f),
      ),
    ),
  );
}

class _Circle extends StatelessWidget {
  final double u;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const _Circle({
    required this.u,
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) => _Focusable(
    focusNode: focusNode,
    onPressed: onPressed,
    builder: (f) => Container(
      width: 70 * u,
      height: 70 * u,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: f ? Colors.white : Colors.black.withValues(alpha: 0.32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2 * u,
        ),
      ),
      child: Icon(
        icon,
        size: 36 * u,
        color: f ? const Color(0xFF111114) : color,
      ),
    ),
  );
}

class _MediaBtn extends StatelessWidget {
  final double u;
  final IconData icon;
  final VoidCallback onPressed;

  const _MediaBtn({
    required this.u,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => _Focusable(
    onPressed: onPressed,
    builder: (f) => Container(
      width: 50 * u,
      height: 50 * u,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: f ? Colors.white : Colors.white.withValues(alpha: 0.12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5 * u,
        ),
      ),
      child: Icon(
        icon,
        size: 28 * u,
        color: f ? const Color(0xFF111114) : Colors.white,
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  final double u;
  final String label;
  final VoidCallback onPressed;

  const _Pill({required this.u, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: _Focusable(
      onPressed: onPressed,
      builder: (f) => Container(
        padding: EdgeInsets.symmetric(horizontal: 16 * u, vertical: 10 * u),
        decoration: BoxDecoration(
          color: f ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20 * u),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: f ? const Color(0xFF111114) : Colors.white,
            fontSize: 18 * u,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

// ======================================================================= continuar viendo

/// «Continuar viendo»: lo que estabas viendo dentro de cada app (episodio, imagen y progreso).
class ContinueHero extends StatelessWidget {
  final double topBarHeight;

  const ContinueHero({super.key, required this.topBarHeight});

  @override
  Widget build(BuildContext context) {
    final u = dashUnit(context);
    final items = context.watch<WidgetsModel>().watching.take(6).toList();
    double y(double v) => v * u - topBarHeight;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 95 * u,
          top: y(500),
          child: Text(
            'Continuar viendo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30 * u,
              fontWeight: FontWeight.w500,
              shadows: _shadow,
            ),
          ),
        ),
        Positioned(
          left: items.isEmpty ? 95 * u : 0,
          right: items.isEmpty ? null : 0,
          top: y(540),
          child: items.isEmpty
              ? Container(
                  width: 700 * u,
                  height: 92 * u,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: 22 * u),
                  decoration: _glass(u, radius: 16),
                  child: Text(
                    'Aquí aparecerá lo que estés viendo en tus apps (series, capítulos, videos).',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 20 * u,
                    ),
                  ),
                )
              : Nav.arrows(
                  up: Nav.toTopBar,
                  down: Nav.toDock,
                  // Fila que crece con lo que vas viendo y se desliza con el mando.
                  child: _ContinueRow(u: u, items: items),
                ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatefulWidget {
  final double u;
  final Map item;
  final FocusNode? focusNode;

  final VoidCallback? onFocused;

  const _ContinueCard({
    required this.u,
    required this.item,
    this.focusNode,
    this.onFocused,
  });

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  Future<Uint8List?>? _banner;

  /** Mantener OK sobre la tarjeta: preguntar si se quita de «Continuar viendo». */
  Future<void> _askRemove(BuildContext context, String title) async {
    final it = widget.item;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Pro.bg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 340, vertical: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Quitar de Continuar viendo', style: Pro.title(24)),
            const SizedBox(height: 10),
            Text(title.isEmpty ? '${it['app'] ?? ''}' : title,
                style: TextStyle(fontSize: 17, color: Pro.text.withValues(alpha: 0.75)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 18),
            ProButton(
              autofocus: true,
              color: Pro.danger,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Quitar', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 8),
            ProButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
            ),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await Native.widgets.invokeMethod('removeContinue', {'package': '${it['package']}', 'title': it['title']});
    } catch (_) {}
    if (context.mounted) await context.read<WidgetsModel>().refreshRecent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.item['image'] == null)
      _banner ??= context.read<AppsModel>().image('${widget.item['package']}');
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final it = widget.item;
    final title = '${it['title'] ?? ''}'.trim();
    final app = '${it['app'] ?? ''}';
    final pos = (it['pos'] as num?)?.toDouble() ?? -1;
    final dur = (it['dur'] as num?)?.toDouble() ?? -1;
    final progress = pos > 0 && dur > 0 ? (pos / dur).clamp(0.02, 1.0) : null;
    final image = it['image'] as String?;
    return _Focusable(
      onFocused: widget.onFocused,
      focusNode: widget.focusNode,
      onLongPress: () => _askRemove(context, title),
      // Abre lo que se estaba viendo (no solo la app); si no se puede, abre la app.
      onPressed: () async {
        if (!await Parental.i.allow('${it['package']}')) return;
        bool ok = false;
        try {
          ok = await Native.widgets.invokeMethod<bool>('openContinue', {
                'package': '${it['package']}',
                'title': it['title'],
                'sub': it['sub'],
                'pos': it['pos'],
              }) ??
              false;
        } catch (_) {}
        if (!ok) Native.launch('${it['package']}');
      },
      builder: (f) => Container(
        width: 338 * u,
        height: 92 * u,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * u),
          boxShadow: f
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16 * u,
                  ),
                ]
              : const [],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * u),
          border: Border.all(
            color: f ? Colors.white : Colors.white.withValues(alpha: 0.12),
            width: (f ? 3 : 1) * u,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image.file(
                File(image),
                fit: BoxFit.cover,
                cacheWidth: 480,
                gaplessPlayback: true,
              )
            else
              FutureBuilder<Uint8List?>(
                future: _banner,
                builder: (_, s) => s.data == null
                    ? ColoredBox(color: Colors.white.withValues(alpha: 0.1))
                    : Image.memory(
                        s.data!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xDD000000), Color(0x00000000)],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16 * u, 8 * u, 16 * u, 9 * u),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title.isEmpty ? app : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21 * u,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      shadows: _shadow,
                    ),
                  ),
                  if (progress != null) ...[
                    SizedBox(height: 6 * u),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2 * u),
                      child: SizedBox(
                        height: 4 * u,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF4DD0C8),
                          ),
                        ),
                      ),
                    ),
                  ] else if (title.isNotEmpty && title != app)
                    Text(
                      it['approxMin'] != null ? '$app · ibas por el min ~${it['approxMin']}' : app,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16 * u,
                        shadows: _shadow,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de «Continuar viendo»: se desliza tarjeta a tarjeta sin cortar la primera.
class _ContinueRow extends StatefulWidget {
  final double u;
  final List<Map> items;

  const _ContinueRow({required this.u, required this.items});

  @override
  State<_ContinueRow> createState() => _ContinueRowState();
}

class _ContinueRowState extends State<_ContinueRow> {
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _show(int i) {
    if (!_ctrl.hasClients) return;
    final step = (338 + 15) * widget.u;
    final target = (i <= 2 ? 0.0 : (i - 2) * step).clamp(
      0.0,
      _ctrl.position.maxScrollExtent,
    );
    _ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.symmetric(horizontal: 95 * u),
      child: Row(
        children: [
          for (var i = 0; i < widget.items.length; i++) ...[
            if (i > 0) SizedBox(width: 15 * u),
            _ContinueCard(
              u: u,
              item: widget.items[i],
              focusNode: i == 0 ? Nav.suggestion : null,
              onFocused: () => _show(i),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================= entradas

IconData _inputIcon(int type) => switch (type) {
  1007 => Icons.settings_input_hdmi,
  1001 => Icons.settings_input_composite,
  1004 => Icons.settings_input_component,
  1005 => Icons.desktop_windows_outlined,
  0 => Icons.live_tv,
  _ => Icons.input,
};

/// Menú de entradas: HDMI 1, HDMI 2, AV, TV digital… y se abre la elegida.
Future<void> showInputsMenu(BuildContext context) async {
  final model = context.read<WidgetsModel>();
  await model.refreshInputs();
  if (!context.mounted) return;
  final inputs = model.inputs;
  final id = await showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: Pro.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 300, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Entradas', style: Pro.title(26)),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < inputs.length; i++)
                      ProButton(
                        autofocus: i == 0,
                        onPressed: () =>
                            Navigator.of(ctx).pop('${inputs[i]['id']}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _inputIcon(
                                (inputs[i]['type'] as num?)?.toInt() ?? -1,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                '${inputs[i]['name']}',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (id != null) await model.openInput(id);
}
