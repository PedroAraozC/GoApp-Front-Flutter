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

  /// Conecta el socket si no está conectado aún
  void connect() {
    if (_isConnected) {
      debugPrint('🟢 Socket ya está conectado.');
      return;
    }

    final baseUrl = dotenv.env['SOCKET_URL'] ?? 'http://10.0.2.2:3000';
    debugPrint('🔌 Conectando a socket: $baseUrl');

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket.onConnect((_) {
      _isConnected = true;
      debugPrint('✅ Conectado al servidor Socket.IO');
    });

    _socket.onDisconnect((_) {
      _isConnected = false;
      debugPrint('⚠️ Socket desconectado');
    });

    _socket.onConnectError((err) {
      _isConnected = false;
      debugPrint('❌ Error de conexión al socket: $err');
    });

    _socket.onReconnect((_) {
      _isConnected = true;
      debugPrint('🔁 Reconexion automática exitosa');
    });
  }

  /// Emite un evento genérico
  void emit(String event, dynamic data) {
    if (!_isConnected) {
      debugPrint('⚠️ Intento de emitir evento "$event" sin conexión.');
      return;
    }
    _socket.emit(event, data);
    debugPrint('📤 Emitido evento: $event → $data');
  }

  /// Escucha un evento específico
  void on(String event, Function(dynamic) callback) {
    _socket.on(event, (data) {
      debugPrint('📥 Recibido evento "$event": $data');
      callback(data);
    });
  }

  /// Deja de escuchar un evento
  void off(String event) {
    _socket.off(event);
    debugPrint('🚫 Listener removido: $event');
  }

  /// Emite el registro del usuario (pasajero/chofer)
  void emitirConexionUsuario(int idUsuario, String tipo) {
    if (!_isConnected) connect();
    final payload = {
      'id_usuario': idUsuario,
      'tipo': tipo,
    };
    _socket.emit('registrar_usuario', payload);
    debugPrint('🧍 Usuario registrado en socket → $payload');
  }

  /// Cierra la conexión (si querés hacerlo explícitamente)
  void disconnect() {
    if (!_isConnected) return;
    _socket.disconnect();
    _isConnected = false;
    debugPrint('🔴 Socket desconectado manualmente');
  }
}
