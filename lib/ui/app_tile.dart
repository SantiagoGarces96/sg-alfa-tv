/*
 * SG Alfa Home — tarjeta de app estilo cómic.
 * OK abre la app; mantener OK abre sus opciones.
 * Copyright (c) 2026 SG Alfa.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import 'retro.dart';

class AppTile extends StatefulWidget {
  final TvApp app;
  final bool autofocus;
  final bool showName;
  final FocusNode? focusNode;

  /// Cómo desplazar la página al enfocar (por defecto, centrar la tarjeta).
  final void Function(BuildContext context)? onFocusScroll;
  final VoidCallback onOpen;
  final VoidCallback onOptions;

  const AppTile({
    super.key,
    required this.app,
    required this.onOpen,
    required this.onOptions,
    this.autofocus = false,
    this.showName = false,
    this.focusNode,
    this.onFocusScroll,
  });

  @override
  State<AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<AppTile> {
  bool _focused = false;
  bool _pressed = false;
  Timer? _hold;
  bool _longFired = false;
  Future<Uint8List?>? _image;

  static final _selectKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _image ??= context.read<AppsModel>().image(widget.app.package);
  }

  @override
  void didUpdateWidget(AppTile old) {
    super.didUpdateWidget(old);
    if (old.app.package != widget.app.package) {
      _image = context.read<AppsModel>().image(widget.app.package);
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _openLater?.cancel();
    super.dispose();
  }

  /// Al soltar OK esperamos un poco antes de abrir: muchos mandos, al MANTENER OK, mandan una
  /// ráfaga de pulsaciones cortas (bajar-subir-bajar-subir…). Si llega otra pulsación en ese rato,
  /// sigue «mantenido».
  Timer? _openLater;
  static const _holdTime = Duration(milliseconds: 600);
  static const _releaseGrace = Duration(milliseconds: 320);

  void _fireOptions() {
    _hold?.cancel();
    _openLater?.cancel();
    if (_longFired) return;
    _longFired = true;
    if (mounted) setState(() => _pressed = false);
    widget.onOptions();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    // Tecla Menú / Info del mando: opciones directamente.
    if (e is KeyDownEvent &&
        (e.logicalKey == LogicalKeyboardKey.contextMenu || e.logicalKey == LogicalKeyboardKey.info)) {
      _longFired = false;
      _fireOptions();
      return KeyEventResult.handled;
    }
    if (!_selectKeys.contains(e.logicalKey)) return KeyEventResult.ignored;

    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      if (_openLater?.isActive ?? false) {
        // Otra pulsación justo después de soltar: es una ráfaga de «mantener».
        _openLater!.cancel();
      } else if (e is KeyDownEvent && !(_hold?.isActive ?? false)) {
        // Primera pulsación de verdad.
        _longFired = false;
        setState(() => _pressed = true);
        _hold = Timer(_holdTime, _fireOptions);
      }
      if (e is KeyRepeatEvent) _fireOptions(); // el sistema ya dice que se está manteniendo
    } else if (e is KeyUpEvent) {
      if (_longFired) {
        _hold?.cancel();
        if (mounted) setState(() => _pressed = false);
        return KeyEventResult.handled;
      }
      _openLater?.cancel();
      _openLater = Timer(_releaseGrace, () {
        _hold?.cancel();
        if (mounted) setState(() => _pressed = false);
        if (!_longFired) widget.onOpen();
      });
    }
    return KeyEventResult.handled;
  }

  void _onFocus(bool f) {
    setState(() => _focused = f);
    if (f) {
      context.read<AppsModel>().setFocused(widget.app.label);
      if (widget.onFocusScroll != null) {
        widget.onFocusScroll!(context);
      } else {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      _hold?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.94 : (_focused ? 1.07 : 1.0);
    final card = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: Retro.night,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _focused ? Retro.mustard : Retro.ink, width: _focused ? 3.5 : 2.5),
          boxShadow: [BoxShadow(color: Retro.ink, offset: _focused ? const Offset(5, 5) : const Offset(3, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FutureBuilder<Uint8List?>(
            future: _image,
            builder: (context, snap) => _content(snap.data),
          ),
        ),
      ),
    );

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _onFocus,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: widget.onOpen,
        onLongPress: widget.onOptions,
        child: !widget.showName
            ? AspectRatio(aspectRatio: 16 / 9, child: card)
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: card),
            if (widget.showName)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.app.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Retro.body(15)),
              ),
          ],
        ),
      ),
    );
  }

  /// Banner de TV a pantalla completa; si la app solo tiene icono, icono + nombre.
  Widget _content(Uint8List? bytes) {
    if (bytes == null) {
      return Center(child: Text(widget.app.label, textAlign: TextAlign.center, style: Retro.body(16)));
    }
    final img = Image.memory(bytes, gaplessPlayback: true, filterQuality: FilterQuality.medium);
    if (widget.app.hasBanner) {
      return SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: img));
    }
    // Solo icono: icono + nombre sobre fondo nocturno.
    return Container(
      color: Retro.panel,
      padding: const EdgeInsets.all(7),
      child: Row(children: [
        AspectRatio(aspectRatio: 1, child: img),
        const SizedBox(width: 7),
        Expanded(
          child: Text(widget.app.label, maxLines: 3, overflow: TextOverflow.ellipsis, style: Retro.body(12)),
        ),
      ]),
    );
  }
}
