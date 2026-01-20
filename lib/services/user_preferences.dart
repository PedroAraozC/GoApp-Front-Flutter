import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'socket_service.dart';

class UserPreferences {
  static const String _keyUser = 'user_data';
  static const String _keyLoggedIn = 'isLoggedIn';

  /// ============================================================
  /// 🔹 Guarda los datos del usuario de forma persistente
  /// ============================================================
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyUser, jsonEncode(user));
    await prefs.setBool(_keyLoggedIn, true);
  }

  /// ============================================================
  /// 🔹 Obtiene los datos del usuario persistidos
  /// ============================================================
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyUser);

    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// ============================================================\
  /// 🔹 Devuelve solo el ID del usuario logueado\
  /// ============================================================\
  static Future<int?> getIdUsuario() async {
    final user = await getUser();
    if (user == null) return null;
    // Asumimos que el ID se guarda como 'id_usuario' (tipo num)\
    if (user['id_usuario'] is num) {
      return (user['id_usuario'] as num).toInt();
    }
    return null;
  }

  // --- FIN DE LA NUEVA FUNCIÓN ---

  /// ============================================================
  /// 🔹 Devuelve si el usuario está logueado
  /// ============================================================
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  /// ============================================================
  /// 🔥 LOGOUT COMPLETO (Google + SharedPrefs + Socket)
  /// ============================================================
  static Future<void> fullLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Recuperamos datos antes de borrar
      final user = await getUser();
      final idUsuario = user?['id_usuario'];
      final tipo = user?['id_rol'] == 3 ? 'conductor' : 'pasajero';

      // 1) 🔌 Emitimos desconexión vía socket
      if (idUsuario != null) {
        final socket = SocketService.instance;
        socket.emit('usuario_desconectado', {
          'id_usuario': idUsuario,
          'tipo': tipo,
        });

        socket.disconnect();
      }

      // 2) 🔐 Cerramos sesión de Google (si aplica)
      try {
        final google = GoogleSignIn(scopes: ['email', 'profile']);
        await google.signOut();
        await google.disconnect();
      } catch (_) {
        // ignoramos errores si no había sesión de Google
      }

      // 3) 🧹 Limpiar SharedPreferences
      await prefs.remove(_keyUser);
      await prefs.remove(_keyLoggedIn);
    } catch (e) {
      print('⚠️ Error en fullLogout: $e');
    }
  }

  // Preferencias de UI / App
  static const String _keyThemeMode = 'theme_mode'; // system|light|dark

  // Preferencias de cobro
  static const String _keyCashEnabled = 'cash_enabled'; // bool
  static const String _keyPreferredPayment = 'preferred_payment'; // cash|debit

  /// 🎨 TEMA (claro / oscuro / sistema)
  static Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'system';
  }

  /// 💳 MÉTODOS DE PAGO
  /// - Débito siempre habilitado
  /// - Efectivo opcional
  /// - Método preferido: cash|debit
  static Future<void> setCashEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCashEnabled, enabled);

    // Si deshabilita efectivo y estaba preferido, pasa a débito.
    if (!enabled) {
      final current = prefs.getString(_keyPreferredPayment) ?? 'debit';
      if (current == 'cash') {
        await prefs.setString(_keyPreferredPayment, 'debit');
      }
    }
  }

  static Future<bool> getCashEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCashEnabled) ?? true;
  }

  static Future<void> setPreferredPayment(String method) async {
    final prefs = await SharedPreferences.getInstance();
    if (method == 'cash') {
      final cashEnabled = prefs.getBool(_keyCashEnabled) ?? true;
      if (!cashEnabled) return; // no se puede elegir cash si está deshabilitado
    }
    await prefs.setString(_keyPreferredPayment, method);
  }

  static Future<String> getPreferredPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final cashEnabled = prefs.getBool(_keyCashEnabled) ?? true;
    final saved = prefs.getString(_keyPreferredPayment) ?? 'debit';
    if (!cashEnabled && saved == 'cash') return 'debit';
    return saved;
  }
}
