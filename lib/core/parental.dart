/*
 * SG Alfa Home — control parental: PIN, apps protegidas y «Modo niños».
 * Copyright (c) 2026 SG Alfa.
 */

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Para mostrar el PIN desde cualquier sitio (al abrir una app protegida).
final navKey = GlobalKey<NavigatorState>();

/// Función que pide el PIN (la pone la interfaz al arrancar).
typedef PinAsker = Future<bool> Function(BuildContext context, String title);

class Parental extends ChangeNotifier {
  Parental._();
  static final i = Parental._();

  static PinAsker? asker;

  String _pin = '';
  Set<String> _locked = {};
  bool _kids = false;

  bool get hasPin => _pin.isNotEmpty;
  bool get kids => _kids;
  Set<String> get locked => _locked;
  bool isLocked(String pkg) => hasPin && _locked.contains(pkg);

  /// En «Modo niños» las apps con PIN ni se ven.
  bool hidden(String pkg) => _kids && isLocked(pkg);

  bool check(String pin) => pin == _pin;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _pin = p.getString('parental_pin') ?? '';
    _locked = (p.getStringList('parental_locked') ?? const []).toSet();
    _kids = p.getBool('parental_kids') ?? false;
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    _pin = pin;
    if (pin.isEmpty) _kids = false;
    final p = await SharedPreferences.getInstance();
    await p.setString('parental_pin', pin);
    await p.setBool('parental_kids', _kids);
    notifyListeners();
  }

  Future<void> setLocked(String pkg, bool on) async {
    on ? _locked.add(pkg) : _locked.remove(pkg);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('parental_locked', _locked.toList());
    notifyListeners();
  }

  Future<void> setKids(bool on) async {
    _kids = on && hasPin;
    final p = await SharedPreferences.getInstance();
    await p.setBool('parental_kids', _kids);
    notifyListeners();
  }

  /// ¿Se puede abrir? Si la app tiene PIN, lo pide.
  Future<bool> allow(String pkg) async {
    if (!isLocked(pkg)) return true;
    final ctx = navKey.currentContext;
    final ask = asker;
    if (ctx == null || ask == null) return false;
    return ask(ctx, 'Esta app tiene PIN');
  }
}
