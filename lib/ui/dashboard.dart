/*
 * SG Alfa Home — inicio «Tablero»: hora y fecha, clima, lo que suena, botones redondos,
 * «Continuar viendo» con Alfi sentado encima, franja de 8 apps y el resto debajo.
 * Todas las medidas son proporcionales a una pantalla de 1600×900 (u = ancho / 1600).
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import '../core/native.dart';
import '../core/widgets_model.dart';
import 'home_widgets.dart';
import 'mascot.dart';
import 'nav.dart';

double dashUnit(BuildContext context) => MediaQuery.sizeOf(context).width / 1600;

const _days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];
const _months = [
  'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
  'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
];

const _shadow = [Shadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 1))];

BoxDecoration _glass(double u, {double radius = 22}) => BoxDecoration(
      color: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(radius * u),
      border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5 * u),
    );

// ======================================================================= barra superior

class DashTopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onProtection;

  const DashTopBar({super.key, required this.onSettings, required this.onProtection});

  @override
  Widget build(BuildContext context) {
    final u = dashUnit(context);
    final today = context.watch<TodayModel>();
    return Nav.arrows(
      down: Nav.belowTopBar,
      child: SizedBox(
        height: 140 * u,
        child: Stack(children: [
          Positioned(left: 95 * u, top: 40 * u, child: _ClockDate(u: u)),
          Positioned(left: 572 * u, top: 47 * u, width: 214 * u, height: 82 * u, child: _WeatherCard(u: u)),
          Positioned(left: 803 * u, top: 47 * u, width: 425 * u, height: 82 * u, child: _MediaCard(u: u)),
          Positioned(
            left: 1264 * u,
            top: 50 * u,
            child: Row(children: [
              _Circle(
                u: u,
                icon: today.adblock ? Icons.shield : Icons.shield_outlined,
                color: today.adblock ? Colors.white : const Color(0xFFFF8A8A),
                onPressed: onProtection,
              ),
              SizedBox(width: 17 * u),
              _Circle(u: u, icon: Icons.wifi, onPressed: () => Native.launcher.invokeMethod('openWifiSettings')),
              SizedBox(width: 17 * u),
              _Circle(u: u, icon: Icons.settings, onPressed: onSettings, focusNode: Nav.settings),
            ]),
          ),
        ]),
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
    final time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final small = TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 17 * u,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.6 * u,
        shadows: _shadow);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(time,
          style: TextStyle(
              color: Colors.white, fontSize: 76 * u, fontWeight: FontWeight.w300, height: 1, shadows: _shadow)),
      SizedBox(width: 36 * u),
      Container(width: 1.5 * u, height: 50 * u, color: Colors.white.withValues(alpha: 0.4)),
      SizedBox(width: 28 * u),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(_days[_now.weekday - 1], style: small),
        SizedBox(height: 14 * u),
        Text('${_now.day} DE ${_months[_now.month - 1]}', style: small),
      ]),
    ]);
  }
}

class _WeatherCard extends StatelessWidget {
  final double u;

  const _WeatherCard({required this.u});

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WidgetsModel>();
    final wx = w.weather;
    final st = TextStyle(color: Colors.white, fontSize: 17.5 * u, height: 1.1, fontWeight: FontWeight.w500);
    return Container(
      decoration: _glass(u),
      padding: EdgeInsets.symmetric(horizontal: 15 * u, vertical: 8 * u),
      alignment: Alignment.centerLeft,
      child: wx == null
          ? Text(w.city.isEmpty ? 'Clima: elige tu ciudad en Ajustes' : 'Clima · ${w.city}\nCargando…',
              style: st, maxLines: 3)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${wx.temp} °C · ${wx.city}', style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(wx.desc, style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Máx. ${wx.max}°  /  Mín. ${wx.min}°', style: st, maxLines: 1),
            ]),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final double u;

  const _MediaCard({required this.u});

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WidgetsModel>();
    final m = w.media;
    final access = m['access'] == true;
    final title = m['title'] as String?;
    final artist = m['artist'] as String?;
    final art = m['art'] as Uint8List?;
    final playing = m['playing'] == true;
    final dur = (m['duration'] as num?)?.toDouble() ?? 0;
    final pos = (m['position'] as num?)?.toDouble() ?? 0;
    final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    final titleSt = TextStyle(color: Colors.white, fontSize: 20 * u, fontWeight: FontWeight.w600);
    final subSt = TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 17 * u, fontWeight: FontWeight.w500);

    return Container(
      decoration: _glass(u),
      padding: EdgeInsets.fromLTRB(14 * u, 13 * u, 14 * u, 13 * u),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6 * u),
          child: SizedBox.square(
            dimension: 54 * u,
            child: art != null
                ? Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true)
                : ColoredBox(
                    color: Colors.white.withValues(alpha: 0.12),
                    child: Icon(Icons.music_note, color: Colors.white70, size: 30 * u),
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
              : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(title ?? 'Nada sonando', style: titleSt, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (artist != null && artist.isNotEmpty)
                    Text(artist, style: subSt, maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 6 * u),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2 * u),
                    child: SizedBox(
                      height: 4 * u,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF4DD0C8)),
                      ),
                    ),
                  ),
                ]),
        ),
        if (access) ...[
          SizedBox(width: 8 * u),
          _MediaBtn(u: u, icon: Icons.skip_previous, onPressed: () => w.command('prev')),
          SizedBox(width: 6 * u),
          _MediaBtn(u: u, icon: playing ? Icons.pause : Icons.play_arrow, onPressed: () => w.command('toggle')),
          SizedBox(width: 6 * u),
          _MediaBtn(u: u, icon: Icons.skip_next, onPressed: () => w.command('next')),
        ],
      ]),
    );
  }
}

/// Botón con foco: al enfocarlo se vuelve blanco con el icono oscuro.
class _Focusable extends StatefulWidget {
  final Widget Function(bool focused) builder;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const _Focusable({required this.builder, required this.onPressed, this.focusNode});

  @override
  State<_Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<_Focusable> {
  bool _f = false;

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _f = f),
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent &&
              (e.logicalKey == LogicalKeyboardKey.select ||
                  e.logicalKey == LogicalKeyboardKey.enter ||
                  e.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onPressed,
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

  const _Circle({required this.u, required this.icon, required this.onPressed, this.color = Colors.white, this.focusNode});

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
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2 * u),
          ),
          child: Icon(icon, size: 36 * u, color: f ? const Color(0xFF111114) : color),
        ),
      );
}

class _MediaBtn extends StatelessWidget {
  final double u;
  final IconData icon;
  final VoidCallback onPressed;

  const _MediaBtn({required this.u, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => _Focusable(
        onPressed: onPressed,
        builder: (f) => Container(
          width: 50 * u,
          height: 50 * u,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: f ? Colors.white : Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5 * u),
          ),
          child: Icon(icon, size: 28 * u, color: f ? const Color(0xFF111114) : Colors.white),
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
            child: Text(label,
                style: TextStyle(
                    color: f ? const Color(0xFF111114) : Colors.white, fontSize: 18 * u, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

// ======================================================================= continuar viendo

/// «Continuar viendo»: las últimas apps que usaste, con Alfi sentado encima.
class ContinueHero extends StatelessWidget {
  final double topBarHeight;

  const ContinueHero({super.key, required this.topBarHeight});

  @override
  Widget build(BuildContext context) {
    final u = dashUnit(context);
    final recent = context.watch<WidgetsModel>().recent.take(4).toList();
    // Coordenadas de la imagen de referencia, pasadas a este recuadro (empieza bajo la barra).
    double y(double v) => v * u - topBarHeight;
    return Stack(clipBehavior: Clip.none, children: [
      if (recent.isNotEmpty)
        Positioned(
          left: 95 * u,
          top: y(500),
          child: Text('Continuar viendo',
              style: TextStyle(color: Colors.white, fontSize: 30 * u, fontWeight: FontWeight.w500, shadows: _shadow)),
        ),
      Positioned(
        left: 95 * u,
        top: y(540),
        child: Nav.arrows(
          up: Nav.toTopBar,
          down: Nav.toDock,
          child: Row(children: [
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) SizedBox(width: 15 * u),
              _ContinueCard(u: u, app: recent[i], focusNode: i == 0 ? Nav.suggestion : null),
            ],
          ]),
        ),
      ),
      // Alfi sentado sobre las tarjetas (como la mascota de la imagen).
      Positioned(left: 676 * u, top: y(420), child: IgnorePointer(child: AlfiSprite(size: 140 * u))),
    ]);
  }
}

class _ContinueCard extends StatefulWidget {
  final double u;
  final Map app;
  final FocusNode? focusNode;

  const _ContinueCard({required this.u, required this.app, this.focusNode});

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  Future<Uint8List?>? _img;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _img ??= context.read<AppsModel>().image('${widget.app['package']}');
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final name = '${widget.app['name']}';
    final minutes = (widget.app['minutesToday'] as num?)?.toDouble() ?? 0;
    final progress = (minutes / 90).clamp(0.06, 1.0);
    return _Focusable(
      focusNode: widget.focusNode,
      onPressed: () => Native.launch('${widget.app['package']}'),
      builder: (f) => Container(
        width: 338 * u,
        height: 92 * u,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * u),
          border: Border.all(color: f ? Colors.white : Colors.white.withValues(alpha: 0.15), width: (f ? 3 : 1) * u),
          boxShadow: f ? [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16 * u)] : const [],
        ),
        child: Stack(fit: StackFit.expand, children: [
          FutureBuilder<Uint8List?>(
            future: _img,
            builder: (_, s) => s.data == null
                ? ColoredBox(color: Colors.white.withValues(alpha: 0.1))
                : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xCC000000), Color(0x33000000)]),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16 * u, 8 * u, 16 * u, 8 * u),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white, fontSize: 21 * u, height: 1.15, fontWeight: FontWeight.w600, shadows: _shadow)),
              SizedBox(height: 6 * u),
              ClipRRect(
                borderRadius: BorderRadius.circular(2 * u),
                child: SizedBox(
                  height: 4 * u,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4DD0C8)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
