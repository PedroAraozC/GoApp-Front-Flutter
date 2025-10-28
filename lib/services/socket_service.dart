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

  void connect() {
    if (_socket != null && _isConnected) {
      print('⚠️ Socket ya está conectado');
      return;
    }

    final serverUrl = dotenv.env['API_URL'] ?? 'http://localhost:3000';
    
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'foo': 'bar'})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅ Socket conectado: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('🔴 Socket desconectado');
    });

    _socket!.onError((error) {
      print('❌ Socket error: $error');
    });
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      print('🔌 Socket desconectado manualmente');
    }
  }

  void registrarUsuario(int idUsuario, String tipo) {
    if (_socket == null || !_isConnected) {
      print('⚠️ Socket no conectado, no se puede registrar usuario');
      return;
    }
    _socket!.emit('registrar_usuario', {
      'idUsuario': idUsuario,
      'tipo': tipo, // 'pasajero' o 'conductor'
    });
    print('📤 Usuario $idUsuario registrado como $tipo');
  }

  void unirseAViaje(int idViaje, int idPasajero) {
    if (_socket == null || !_isConnected) {
      print('⚠️ Socket no conectado, no se puede unir al viaje');
      return;
    }
    _socket!.emit('viaje_creado', {
      'idViaje': idViaje,
      'idPasajero': idPasajero,
    });
    print('🚕 Pasajero unido al viaje $idViaje');
  }

  void escucharActualizacionesViaje(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      print('⚠️ Socket no inicializado');
      return;
    }
    _socket!.on('viaje_actualizado', (data) {
      print('📥 Actualización recibida: $data');
      callback(data as Map<String, dynamic>);
    });
  }

  void dejarDeEscucharViaje() {
    _socket?.off('viaje_actualizado');
  }
}