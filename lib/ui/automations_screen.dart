/*
 * SG Alfa Home — Automatizaciones en la tele, estilo MacroDroid:
 * CUANDO aparece algo · SOLO SI se cumple · ENTONCES la tele hace algo.
 * Mismo formato que la app del teléfono.
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/apps_model.dart';
import 'pro.dart';

const _channel = MethodChannel('tv.sgalfa.home/protection');

typedef MacroMap = Map<String, dynamic>;

MacroMap _clean(Map raw) => raw.map((k, v) => MapEntry(k.toString(), v));

List<MacroMap> _list(dynamic raw) =>
    raw is List ? raw.whereType<Map>().map(_clean).toList() : <MacroMap>[];

/// Fondo de las pantallas de SG Alfa: noche retro con «sol» rojo.
class _RetroScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;

  const _RetroScaffold({required this.title, required this.child, this.actions = const []});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Pro.bg,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 28, 48, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: Pro.title(34)),
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// =====================================================================
// Lista
// =====================================================================

class SgAutomationsScreen extends StatefulWidget {
  const SgAutomationsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute(builder: (_) => const SgAutomationsScreen()));

  @override
  State<SgAutomationsScreen> createState() => _SgAutomationsScreenState();
}

class _SgAutomationsScreenState extends State<SgAutomationsScreen> {
  List<MacroMap> _macros = [];
  List<MacroMap> _templates = [];
  bool _automationOn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final macros = _list(await _channel.invokeMethod('getMacrosFull'));
      final templates = _list(await _channel.invokeMethod('getTemplates'));
      final state = await _channel.invokeMethod('getState');
      if (!mounted) return;
      setState(() {
        _macros = macros;
        _templates = templates;
        _automationOn = state is Map && state['automation'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(MacroMap m) async {
    final list = _list(await _channel.invokeMethod('saveMacro', m));
    if (mounted) setState(() => _macros = list);
  }

  Future<void> _edit(MacroMap? m, {bool isNew = false}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SgMacroEditor(initial: m, isNew: isNew || m == null)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final ids = _macros.map((m) => m['id']).toSet();
    final missing = _templates.where((t) => !ids.contains(t['id'])).toList();
    final on = _macros.where((m) => m['enabled'] == true).length;

    return _RetroScaffold(
      title: 'Automatizaciones',
      actions: [
        ProButton(
          color: Pro.accent,
          focusColor: Pro.accent,
          onPressed: () => _edit(null, isNew: true),
          child: const Row(children: [Icon(Icons.add), SizedBox(width: 6), Text('Crear')]),
        ),
        const SizedBox(width: 12),
        ProButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Row(children: [Icon(Icons.arrow_back), SizedBox(width: 6), Text('Volver')]),
        ),
      ],
      child: _loading
          ? Center(child: CircularProgressIndicator(color: Pro.accent))
          : ListView(
              padding: const EdgeInsets.only(bottom: 40, right: 8),
              children: [
                Text(
                  'CUANDO aparece algo en la tele → la tele lo hace sola. '
                  'Para que funcionen, el servicio «SG Alfa · Automatizaciones» tiene que estar activado.',
                  style: Pro.body(16, weight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                if (!_automationOn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ProButton(
                      color: Pro.accent,
                      focusColor: Pro.text,
                      onPressed: () async {
                        await _channel.invokeMethod('openAccessibilitySettings');
                      },
                      child: const Text('⚠ EL SERVICIO ESTÁ APAGADO — PULSA PARA ACTIVARLO'),
                    ),
                  ),
                ProTag('MIS AUTOMATIZACIONES · $on/${_macros.length} ENCENDIDAS'),
                const SizedBox(height: 12),
                if (_macros.isEmpty)
                  Text('No tienes ninguna. Pulsa CREAR o añade una plantilla.', style: Pro.body(16)),
                for (final m in _macros) _MacroRow(
                  macro: m,
                  autofocus: m == _macros.first,
                  onEdit: () => _edit(m),
                  onToggle: () => _save({...m, 'enabled': m['enabled'] != true}),
                ),
                const SizedBox(height: 22),
                ProTag('PLANTILLAS', color: Pro.accent),
                const SizedBox(height: 12),
                for (final t in _templates)
                  _TemplateRow(
                    template: t,
                    added: !missing.contains(t),
                    onAdd: () => _save(t),
                    onCopy: () => _edit({
                      ...t,
                      'id': '',
                      'name': '${t['name']} (copia)',
                    }, isNew: true),
                  ),
              ],
            ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final MacroMap macro;
  final bool autofocus;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _MacroRow({required this.macro, required this.onEdit, required this.onToggle, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final on = macro['enabled'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ProButton(
              autofocus: autofocus,
              onPressed: onEdit,
              child: Row(
                children: [
                  const Icon(Icons.bolt, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${macro['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('${macro['description']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Editar ›', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: ProButton(
              color: on ? Pro.green : Pro.sub,
              focusColor: Pro.accent,
              onPressed: onToggle,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text(on ? 'Encendida' : 'Apagada', style: const TextStyle(fontSize: 14))),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final MacroMap template;
  final bool added;
  final VoidCallback onAdd;
  final VoidCallback onCopy;

  const _TemplateRow({required this.template, required this.added, required this.onAdd, required this.onCopy});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(right: 5, bottom: 5),
                decoration: Pro.box(color: Pro.text, shadow: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${template['name']}',
                        style: TextStyle(color: Pro.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${template['description']}',
                        style: TextStyle(color: Pro.text, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (added)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('✓ YA ESTÁ', style: Pro.body(14)),
              )
            else
              ProButton(color: Pro.accent, onPressed: onAdd, child: const Text('Añadir')),
            ProButton(onPressed: onCopy, child: const Text('Copiar y cambiar')),
          ],
        ),
      );
}

// =====================================================================
// Editor
// =====================================================================

class SgMacroEditor extends StatefulWidget {
  final MacroMap? initial;
  final bool isNew;

  const SgMacroEditor({super.key, this.initial, this.isNew = true});

  @override
  State<SgMacroEditor> createState() => _SgMacroEditorState();
}

class _SgMacroEditorState extends State<SgMacroEditor> {
  late final TextEditingController _name;
  late final TextEditingController _text;
  late final TextEditingController _context;
  late String _id;
  late bool _enabled;
  late String _trigger;
  late String _action;
  late String _app;
  late int _delay;
  String _summary = '';
  String? _error;
  bool _confirmDelete = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? const <String, dynamic>{};
    _id = '${m['id'] ?? ''}';
    _name = TextEditingController(text: '${m['name'] ?? ''}');
    _text = TextEditingController(text: '${m['text'] ?? ''}');
    final ctx = m['context'];
    _context = TextEditingController(text: ctx is List ? ctx.join(', ') : '');
    _enabled = m['enabled'] != false;
    _trigger = m['trigger'] == 'TEXT' ? 'TEXT' : 'BUTTON';
    _action = '${m['action'] ?? 'CLICK'}';
    _app = '${m['app'] ?? ''}';
    final d = m['delaySeconds'];
    _delay = d is num ? d.toInt() : 0;
    for (final c in [_name, _text, _context]) {
      c.addListener(_refreshSummary);
    }
    _refreshSummary();
  }

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    _context.dispose();
    super.dispose();
  }

  MacroMap get _current => {
        'id': _id,
        'name': _name.text,
        'enabled': _enabled,
        'trigger': _trigger,
        'text': _text.text,
        'context': _context.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'action': _action,
        'app': _app,
        'delaySeconds': _delay,
      };

  Future<void> _refreshSummary() async {
    if (_trigger == 'TEXT' && _action == 'CLICK') _action = 'BACK';
    if (_text.text.trim().isEmpty) {
      if (mounted) setState(() => _summary = 'Escribe qué tiene que aparecer en la tele.');
      return;
    }
    try {
      final s = await _channel.invokeMethod('describe', _current);
      if (mounted) setState(() => _summary = '$s');
    } catch (_) {}
  }

  void _set(VoidCallback f) {
    setState(f);
    _refreshSummary();
  }

  Future<void> _save() async {
    try {
      await _channel.invokeMethod('saveMacro', _current);
      if (mounted) Navigator.of(context).pop(true);
    } on PlatformException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _delete() async {
    await _channel.invokeMethod('deleteMacro', _id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickApp() async {
    final apps = context.read<AppsModel>().others.followedBy(context.read<AppsModel>().favorites).toList();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 520,
          height: 560,
          padding: const EdgeInsets.all(16),
          decoration: Pro.box(color: Pro.text, shadow: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿En qué app?', style: Pro.title(22, color: Pro.accent)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    ProButton(
                      autofocus: true,
                      color: Pro.accent,
                      onPressed: () => Navigator.of(ctx).pop(''),
                      child: const Text('En todas las apps'),
                    ),
                    for (final a in apps)
                      ProButton(
                        onPressed: () => Navigator.of(ctx).pop(a.package),
                        child: Text(a.label),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _set(() => _app = picked);
  }

  String _appLabel() {
    if (_app.isEmpty) return 'En todas las apps';
    final a = context.read<AppsModel>().others.followedBy(context.read<AppsModel>().favorites).toList().where((x) => x.package == _app);
    return a.isEmpty ? _app : a.first.label;
  }

  Widget _choice(String label, bool selected, VoidCallback onTap, {IconData? icon}) => ProButton(
        color: selected ? Pro.accent : Pro.text,
        focusColor: selected ? Pro.accent : Pro.text,
        onPressed: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 20),
          const SizedBox(width: 8),
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 6)],
          Text(label),
        ]),
      );

  /// Campo de texto «de tele»: un botón con el valor; OK abre una ventanita con el teclado.
  /// Así el mando nunca se queda atrapado dentro de un campo de texto.
  Widget _field(TextEditingController c, String label, String hint, {bool autofocus = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Pro.body(14, color: Pro.accent, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            ProButton(
              autofocus: autofocus,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onPressed: () => _editText(c, label, hint),
              child: Row(children: [
                Expanded(
                  child: Text(
                    c.text.isEmpty ? hint : c.text,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: c.text.isEmpty ? const Color(0xFF8A8172) : Pro.text,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard, size: 22),
                const SizedBox(width: 6),
                const Text('Escribir', style: TextStyle(fontSize: 13)),
              ]),
            ),
          ],
        ),
      );

  Future<void> _editText(TextEditingController c, String label, String hint) async {
    final temp = TextEditingController(text: c.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 760,
          padding: const EdgeInsets.all(20),
          decoration: Pro.box(color: Pro.text, shadow: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Pro.title(22, color: Pro.accent)),
              const SizedBox(height: 12),
              TextField(
                controller: temp,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
                style: TextStyle(color: Pro.text, fontSize: 22, fontWeight: FontWeight.w700),
                cursorColor: Pro.accent,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Color(0xFF8A8172)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Pro.text, width: 3),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Pro.text, width: 3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Pro.accent, width: 4),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('Escribe con el teclado de la tele y pulsa «Listo» o «Intro».',
                  style: TextStyle(color: Pro.text, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Row(children: [
                ProButton(
                  color: Pro.accent,
                  onPressed: () => Navigator.of(ctx).pop(temp.text),
                  child: const Text('Listo'),
                ),
                ProButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
              ]),
            ],
          ),
        ),
      ),
    );
    // Se libera cuando termina la animación de cierre (si no, Flutter falla).
    Future.delayed(const Duration(seconds: 1), temp.dispose);
    if (result != null) {
      setState(() => c.text = result.trim());
    }
  }

  Widget _block(String sticker, Color color, String subtitle, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 16, right: 6),
        padding: const EdgeInsets.all(16),
        decoration: Pro.box(color: Pro.card, shadow: 6, borderColor: Pro.text),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ProTag(sticker, color: color, textColor: color == Pro.accent ? Pro.text : Pro.text),
              const SizedBox(width: 12),
              Expanded(child: Text(subtitle, style: Pro.body(15, weight: FontWeight.w500))),
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isButton = _trigger == 'BUTTON';
    return _RetroScaffold(
      title: widget.isNew ? 'Nueva automatización' : 'Editar automatización',
      actions: [
        ProButton(
          color: Pro.accent,
          onPressed: _save,
          child: const Row(children: [Icon(Icons.save), SizedBox(width: 6), Text('Guardar')]),
        ),
        const SizedBox(width: 12),
        ProButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40, right: 8),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field(_name, 'Nombre', 'Ej. Quitar «¿Sigues viendo?»', autofocus: true)),
              const SizedBox(width: 12),
              _choice(_enabled ? 'Encendida' : 'Apagada', _enabled, () => _set(() => _enabled = !_enabled)),
            ],
          ),
          const SizedBox(height: 6),
          _block('CUANDO', Pro.accent, 'Qué tiene que aparecer en la pantalla de la tele.', [
            Wrap(spacing: 4, children: [
              _choice('Aparece un botón', isButton, () => _set(() => _trigger = 'BUTTON'), icon: Icons.smart_button),
              _choice('Aparece un texto', !isButton, () => _set(() => _trigger = 'TEXT'), icon: Icons.text_fields),
            ]),
            const SizedBox(height: 10),
            _field(
              _text,
              isButton ? 'Texto del botón' : 'Texto en pantalla',
              isButton ? 'Ej. Continuar usando' : 'Ej. Publicidad',
            ),
            Text(
              isButton
                  ? 'Escríbelo como sale en la tele. Da igual mayúsculas o signos.'
                  : 'Al menos 3 letras. Se busca en todo lo que hay en pantalla.',
              style: Pro.body(14, weight: FontWeight.w500),
            ),
          ]),
          _block('SOLO SI', Pro.accent, 'Opcional: para no pulsar donde no debe.', [
            _field(_context, 'También se ve alguno de estos textos', 'Ej. sigues viendo, deseas continuar'),
            Text('Sepáralos con comas. Muy útil para botones cortos como «Sí» u «OK».',
                style: Pro.body(14, weight: FontWeight.w500)),
            const SizedBox(height: 10),
            Row(children: [
              ProButton(
                onPressed: _pickApp,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.apps),
                  const SizedBox(width: 8),
                  Text('APP: ${_appLabel()}'),
                ]),
              ),
            ]),
          ]),
          _block('ENTONCES', Pro.accent, 'Qué hace la tele.', [
            Wrap(spacing: 4, children: [
              if (isButton)
                _choice('Pulsar ese botón', _action == 'CLICK', () => _set(() => _action = 'CLICK'),
                    icon: Icons.touch_app),
              _choice('Pulsar Atrás', _action == 'BACK', () => _set(() => _action = 'BACK'), icon: Icons.arrow_back),
              _choice('Ir al inicio', _action == 'HOME', () => _set(() => _action = 'HOME'), icon: Icons.home),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text('Esperar antes:', style: Pro.body(16)),
              const SizedBox(width: 12),
              ProButton(
                onPressed: _delay > 0 ? () => _set(() => _delay--) : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: const Text('−', style: TextStyle(fontSize: 22)),
              ),
              Container(
                width: 120,
                alignment: Alignment.center,
                child: Text(_delay == 0 ? 'Nada' : '$_delay s', style: Pro.title(22)),
              ),
              ProButton(
                onPressed: _delay < 30 ? () => _set(() => _delay++) : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: const Text('+', style: TextStyle(fontSize: 22)),
              ),
            ]),
            Text('Si esperas, la tele vuelve a mirar antes de actuar: si el aviso ya se fue, no hace nada.',
                style: Pro.body(14, weight: FontWeight.w500)),
          ]),
          Container(
            margin: const EdgeInsets.only(right: 6, bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: Pro.box(color: Pro.text, shadow: 6),
            child: Row(children: [
              Icon(Icons.chat_bubble, color: Pro.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_summary,
                    style: TextStyle(color: Pro.text, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('✗ $_error', style: Pro.body(18, color: const Color(0xFFFF8A8A))),
            ),
          if (!widget.isNew)
            Row(children: [
              if (!_confirmDelete)
                ProButton(
                  color: const Color(0xFFFFB4B4),
                  onPressed: () => setState(() => _confirmDelete = true),
                  child: const Text('Eliminar'),
                )
              else ...[
                Text('¿Eliminarla?', style: Pro.body(18)),
                const SizedBox(width: 12),
                ProButton(color: Pro.accent, onPressed: _delete, child: const Text('SÍ, ELIMINAR')),
                ProButton(onPressed: () => setState(() => _confirmDelete = false), child: const Text('NO')),
              ],
            ]),
        ],
      ),
    );
  }
}
