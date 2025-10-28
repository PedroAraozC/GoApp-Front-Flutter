// lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// 🔹 Conecta al servidor Socket.IO (por defecto puerto 3000)
  void connect() {
    if (_isConnected) {
      print('⚠️ Socket ya está conectado');
      return;
    }

    final serverUrl = dotenv.env['API_URL'] ?? 'http://localhost:3000';
    print('🌐 Conectando Socket.IO a: $serverUrl');

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection() // se reconecta si se corta Internet
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(5)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅ Socket conectado → ID: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('🔴 Socket desconectado');
    });

    _socket!.onError((error) {
      print('❌ Error de socket: $error');
    });
  }

  /// 🔹 Desconecta el socket completamente
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      print('🔌 Socket desconectado manualmente');
    }
  }

  /// 🔹 Registra usuario (pasajero o conductor)
  void registrarUsuario({required int idUsuario, required String tipo}) {
    if (!_isConnected || _socket == null) {
      print('⚠️ No conectado al socket, no se pudo registrar usuario');
      return;
    }

    _socket!.emit('registrar_usuario', {'idUsuario': idUsuario, 'tipo': tipo});
    print('📤 Usuario registrado en socket: $idUsuario como $tipo');
  }

  /// 🔹 Unirse al canal de un viaje (para recibir actualizaciones)
  void unirseAViaje(int idViaje) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('unirse_viaje', {'idViaje': idViaje});
    print('🚗 Suscrito a viaje $idViaje');
  }

  /// 🔹 Salir del canal de un viaje
  void salirDeViaje(int idViaje) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('salir_viaje', {'idViaje': idViaje});
    print('🏁 Saliste del canal viaje $idViaje');
  }

  /// 🔹 Emitir actualización manual del viaje (ej: cambio de ubicación)
  void emitirActualizacionViaje(Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('viaje_actualizado', data);
    print('📤 Emitiendo actualización de viaje: $data');
  }

  /// 🔹 Escuchar eventos del servidor y manejar callbacks
  void escucharEventos({
    Function(Map<String, dynamic>)? onNuevoViaje,
    Function(Map<String, dynamic>)? onAsignado,
    Function(Map<String, dynamic>)? onEnCurso,
    Function(Map<String, dynamic>)? onFinalizado,
    Function(Map<String, dynamic>)? onCancelado,
    Function(Map<String, dynamic>)? onActualizado,
  }) {
    if (_socket == null) return;

    _socket!.on('viaje_nuevo', (data) {
      print('🆕 Nuevo viaje recibido: $data');
      if (data is Map && onNuevoViaje != null) {
        onNuevoViaje(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('viaje_asignado', (data) {
      print('🚕 Viaje asignado: $data');
      if (data is Map && onAsignado != null) {
        onAsignado(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('viaje_en_curso', (data) {
      print('▶️ Viaje en curso: $data');
      if (data is Map && onEnCurso != null) {
        onEnCurso(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('viaje_finalizado', (data) {
      print('🏁 Viaje finalizado: $data');
      if (data is Map && onFinalizado != null) {
        onFinalizado(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('viaje_cancelado', (data) {
      print('❌ Viaje cancelado: $data');
      if (data is Map && onCancelado != null) {
        onCancelado(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('viaje_actualizado', (data) {
      print('📡 Viaje actualizado: $data');
      if (data is Map && onActualizado != null) {
        onActualizado(Map<String, dynamic>.from(data));
      }
    });
  }

  /// 🔹 Dejar de escuchar eventos
  void limpiarListeners() {
    _socket?.off('viaje_nuevo');
    _socket?.off('viaje_asignado');
    _socket?.off('viaje_en_curso');
    _socket?.off('viaje_finalizado');
    _socket?.off('viaje_cancelado');
    _socket?.off('viaje_actualizado');
    print('🧹 Listeners Socket limpiados');
  }
}
