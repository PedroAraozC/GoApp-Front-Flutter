import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  // Singleton
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  static SocketService get instance => _instance;

  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;

  bool get isConnected => _isConnected;
  IO.Socket? get rawSocket =>
      _socket; // por si alguna vez necesitás acceso crudo

  /// 🔌 Conecta el socket (y espera a que realmente se conecte).
  /// Si ya está conectado, no hace nada.
  Future<void> connect() async {
    if (_isConnected) {
      debugPrint('🟢 Socket ya está conectado.');
      return;
    }
    if (_isConnecting) {
      debugPrint('⏳ Conexión ya en curso, esperando...');
      // Espera a que termine un intento de conexión previo
      while (_isConnecting) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    final baseUrl = dotenv.env['API_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint('❌ No se encontró API_URL en el .env');
      return;
    }

    debugPrint('🔌 Intentando conectar a socket: $baseUrl');
    _isConnecting = true;

    final completer = Completer<void>();

    // Si ya había un socket viejo, lo cerramos
    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    // 🟢 Conectado
    _socket!.onConnect((_) {
      _isConnected = true;
      _isConnecting = false;
      debugPrint('✅ Conectado al servidor Socket.IO');
      if (!completer.isCompleted) completer.complete();
    });

    // 🔴 Desconectado
    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('⚠️ Socket desconectado');
    });

    // ❌ Error de conexión
    _socket!.onConnectError((err) {
      _isConnected = false;
      _isConnecting = false;
      debugPrint('❌ Error de conexión al socket: $err');
      if (!completer.isCompleted) {
        completer.completeError(err ?? 'Error de conexión');
      }
    });

    // 🔁 Reconectado automáticamente
    _socket!.onReconnect((_) {
      _isConnected = true;
      debugPrint('🔁 Reconexion automática exitosa');
    });

    // Esperar hasta que se conecte o falle
    try {
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _isConnecting = false;
          throw Exception('⏱️ Timeout al conectar con el socket.');
        },
      );
    } catch (e) {
      debugPrint('❌ No se pudo establecer conexión con el socket: $e');
    } finally {
      _isConnecting = false;
    }
  }

  /// 📤 Emite un evento genérico (solo si está conectado)
  void emit(String event, dynamic data) {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Intento de emitir evento "$event" sin conexión.');
      return;
    }
    _socket!.emit(event, data);
    debugPrint('📤 Emitido evento: $event → $data');
  }

  /// 📥 Escucha un evento específico
  void on(String event, Function(dynamic) callback) {
    if (_socket == null) {
      debugPrint(
        '⚠️ Intento de registrar listener "$event" sin socket inicializado.',
      );
      return;
    }
    _socket!.on(event, (data) {
      debugPrint('📥 Recibido evento "$event": $data');
      callback(data);
    });
  }

  /// 🚫 Deja de escuchar un evento
  void off(String event) {
    if (_socket == null) return;
    _socket!.off(event);
    debugPrint('🚫 Listener removido: $event');
  }

  // =========================================================
  // 🧍 Eventos unificados de usuario_conectado / usuario_desconectado
  // =========================================================

  /// 🧍 Registrar usuario (pasajero o conductor) en el socket.
  ///
  /// [tipo] debería ser 'pasajero' o 'conductor'.
  Future<void> registrarUsuario({
    required int idUsuario,
    required String tipo,
  }) async {
    await connect();
    if (!_isConnected || _socket == null) {
      debugPrint(
        '❌ No se pudo registrar usuario en socket: sin conexión. id=$idUsuario tipo=$tipo',
      );
      return;
    }

    final payload = {'id_usuario': idUsuario, 'tipo': tipo};

    _socket!.emit('usuario_conectado', payload);
    debugPrint('🧍 Evento usuario_conectado emitido → $payload');
  }

  /// 📴 Notificar al servidor que el usuario se desconectó (pasajero o conductor).
  ///
  /// Útil para logout, cierre de app, etc.
  Future<void> notificarDesconexionUsuario({
    required int idUsuario,
    required String tipo,
  }) async {
    // Si no hay conexión, intentamos una cortita sólo para avisar
    if (!_isConnected) {
      await connect();
    }

    if (!_isConnected || _socket == null) {
      debugPrint(
        '⚠️ No se pudo notificar usuario_desconectado: sin conexión. id=$idUsuario tipo=$tipo',
      );
      return;
    }

    final payload = {'id_usuario': idUsuario, 'tipo': tipo};

    _socket!.emit('usuario_desconectado', payload);
    debugPrint('📴 Evento usuario_desconectado emitido → $payload');
  }

  /// 🔁 Alias para compatibilidad con tu código anterior
  /// (internamente usa [registrarUsuario])
  Future<void> emitirConexionUsuario(int idUsuario, String tipo) async {
    await registrarUsuario(idUsuario: idUsuario, tipo: tipo);
  }

  /// 🔴 Cierra la conexión manualmente (sin notificar usuario_desconectado).
  void disconnect() {
    if (_socket == null) return;
    try {
      _socket!.disconnect();
      _socket!.dispose();
    } catch (_) {}
    _isConnected = false;
    debugPrint('🔴 Socket desconectado manualmente');
  }

  /// 🔴 Cierra conexión y, opcionalmente, notifica usuario_desconectado.
  ///
  /// Útil para usar desde logout (si ya tenés el id y tipo).
  Future<void> disconnectAndNotify({int? idUsuario, String? tipo}) async {
    if (idUsuario != null && tipo != null) {
      await notificarDesconexionUsuario(idUsuario: idUsuario, tipo: tipo);
    }
    disconnect();
  }
}
