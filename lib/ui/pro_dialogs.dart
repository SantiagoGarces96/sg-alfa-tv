/*
 * SG Alfa Home — ventanas «pro»: PIN con el control y búsqueda en todas las apps.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import '../core/parental.dart';
import 'pro.dart';

// ======================================================================= PIN

/// Pide el PIN y lo comprueba. true si es correcto.
Future<bool> askParentalPin(BuildContext context, String title) async {
  final pin = await enterPin(context, title, check: Parental.i.check);
  return pin != null;
}

/// Escribe 4 números (con los números del control o con el teclado en pantalla).
/// Con [check], repite hasta que sea correcto o se cancele.
Future<String?> enterPin(BuildContext context, String title, {bool Function(String)? check}) =>
    showDialog<String>(
      context: context,
      barrierColor: const Color(0xCC000000),
      builder: (_) => _PinDialog(title: title, check: check),
    );

class _PinDialog extends StatefulWidget {
  final String title;
  final bool Function(String)? check;

  const _PinDialog({required this.title, this.check});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _v = '';
  String? _error;

  void _add(String d) {
    if (_v.length >= 4) return;
    setState(() {
      _v += d;
      _error = null;
    });
    if (_v.length == 4) {
      final c = widget.check;
      if (c == null || c(_v)) {
        Navigator.of(context).pop(_v);
      } else {
        setState(() {
          _v = '';
          _error = 'PIN incorrecto';
        });
      }
    }
  }

  void _del() {
    if (_v.isEmpty) return;
    setState(() => _v = _v.substring(0, _v.length - 1));
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final l = e.logicalKey.keyLabel;
    final m = RegExp(r'(\d)$').firstMatch(l);
    if (m != null && (l.length == 1 || l.startsWith('Numpad'))) {
      _add(m.group(1)!);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace || e.logicalKey == LogicalKeyboardKey.delete) {
      _del();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _btn(String label, VoidCallback onTap, {bool autofocus = false}) => SizedBox(
        width: 84,
        height: 64,
        child: ProButton(
          autofocus: autofocus,
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Center(child: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600))),
        ),
      );

  @override
  Widget build(BuildContext context) => Focus(
        onKeyEvent: _key,
        child: Dialog(
          backgroundColor: Pro.bg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 420, vertical: 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.title, style: Pro.title(22), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(_error ?? 'Escribe el PIN de 4 números',
                  style: TextStyle(fontSize: 15, color: _error != null ? Pro.danger : Pro.text.withValues(alpha: 0.7))),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _v.length ? Pro.text : Colors.transparent,
                      border: Border.all(color: Pro.text, width: 2),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (final d in row)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _btn(d, () => _add(d), autofocus: d == '5'),
                      ),
                  ]),
                ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _btn('⌫', _del)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _btn('0', () => _add('0'))),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _btn('✕', () => Navigator.of(context).pop())),
              ]),
            ]),
          ),
        ),
      );
}

// ======================================================================= buscar en todas las apps

Future<void> showGlobalSearch(BuildContext context) async {
  List<Map> apps = const [];
  try {
    apps = (await Native.protection.invokeMethod<List>('searchApps') ?? const []).whereType<Map>().toList();
  } catch (_) {}
  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierColor: const Color(0xCC000000),
    builder: (_) => _SearchDialog(apps: apps),
  );
}

class _SearchDialog extends StatefulWidget {
  final List<Map> apps;

  const _SearchDialog({required this.apps});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _go(Map app) async {
    final q = _text.text.trim();
    if (q.isEmpty) return;
    final pkg = '${app['package']}';
    if (!await Parental.i.allow(pkg)) return;
    await Native.protection.invokeMethod('searchIn', {'package': pkg, 'query': q});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Pro.bg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 300, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Buscar en tus apps', style: Pro.title(24)),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              style: const TextStyle(fontSize: 20),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Serie, película, canción…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Pro.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 12),
            if (widget.apps.isEmpty)
              Text('No hay apps compatibles instaladas.', style: TextStyle(color: Pro.text.withValues(alpha: 0.7)))
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final a in widget.apps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ProButton(
                          onPressed: () => _go(a),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text('Buscar en ${a['name']}', style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                  ]),
                ),
              ),
          ]),
        ),
      );
}
