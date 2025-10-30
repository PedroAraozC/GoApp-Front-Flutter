import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  static SocketService get instance => _instance;

  late IO.Socket _socket;
  bool _isConnected = false;

  SocketService._internal();

  bool get isConnected => _isConnected;
  IO.Socket get socket => _socket;

  /// 🔌 Conecta el socket (y espera a que realmente se conecte)
  Future<void> connect() async {
    if (_isConnected) {
      debugPrint('🟢 Socket ya está conectado.');
      return;
    }

    final baseUrl = dotenv.env['API_URL'];
    if (baseUrl == null) {
      debugPrint('❌ No se encontró API_URL en el .env');
      return;
    }

    debugPrint('🔌 Intentando conectar a socket: $baseUrl');

    final completer = Completer<void>();

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
    _socket.onConnect((_) {
      _isConnected = true;
      debugPrint('✅ Conectado al servidor Socket.IO');
      if (!completer.isCompleted) completer.complete();
    });

    // 🔴 Desconectado
    _socket.onDisconnect((_) {
      _isConnected = false;
      debugPrint('⚠️ Socket desconectado');
    });

    // ❌ Error de conexión
    _socket.onConnectError((err) {
      _isConnected = false;
      debugPrint('❌ Error de conexión al socket: $err');
      if (!completer.isCompleted) completer.completeError(err);
    });

    // 🔁 Reconectado automáticamente
    _socket.onReconnect((_) {
      _isConnected = true;
      debugPrint('🔁 Reconexion automática exitosa');
    });

    // Esperar hasta que se conecte o falle
    try {
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('⏱️ Timeout al conectar con el socket.');
        },
      );
    } catch (e) {
      debugPrint('❌ No se pudo establecer conexión con el socket: $e');
    }
  }

  /// 📤 Emite un evento genérico (solo si está conectado)
  void emit(String event, dynamic data) {
    if (!_isConnected) {
      debugPrint('⚠️ Intento de emitir evento "$event" sin conexión.');
      return;
    }
    _socket.emit(event, data);
    debugPrint('📤 Emitido evento: $event → $data');
  }

  /// 📥 Escucha un evento específico
  void on(String event, Function(dynamic) callback) {
    _socket.on(event, (data) {
      debugPrint('📥 Recibido evento "$event": $data');
      callback(data);
    });
  }

  /// 🚫 Deja de escuchar un evento
  void off(String event) {
    _socket.off(event);
    debugPrint('🚫 Listener removido: $event');
  }

  /// 🧍 Registrar usuario en el socket (pasajero / chofer)
  Future<void> emitirConexionUsuario(int idUsuario, String tipo) async {
    await connect();
    final payload = {'id_usuario': idUsuario, 'tipo': tipo};
    _socket.emit('registrar_usuario', payload);
    debugPrint('🧍 Usuario registrado en socket → $payload');
  }

  /// 🔴 Cierra la conexión manualmente (opcional)
  void disconnect() {
    if (!_isConnected) return;
    _socket.disconnect();
    _isConnected = false;
    debugPrint('🔴 Socket desconectado manualmente');
  }
}
