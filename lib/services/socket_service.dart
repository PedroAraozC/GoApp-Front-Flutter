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

  // Guarda registro pendiente si el socket no está conectado
  Map<String, dynamic>? _pendingRegistration;

  // ✅ Guarda el último join_viaje para re-join automático al reconectar
  Map<String, dynamic>? _pendingJoinViaje;

  bool get isConnected => _isConnected;
  IO.Socket? get rawSocket => _socket;

  // =========================================================
  // 🔌 Conexión
  // =========================================================

  Future<void> connect() async {
    if (_isConnected && _socket != null) {
      debugPrint('🟢 [Socket] Ya está conectado.');
      return;
    }

    if (_isConnecting) {
      debugPrint('⏳ [Socket] Conexión en curso, esperando máximo 3s...');
      int attempts = 0;
      while (_isConnecting && attempts < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_isConnected && _socket != null) {
        debugPrint('✅ [Socket] Conexión completada durante la espera');
        return;
      }
      debugPrint('⚠️ [Socket] Reintentando nueva conexión...');
    }

    final baseUrl = dotenv.env['API_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint('❌ No se encontró API_URL en el .env');
      return;
    }

    String cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    debugPrint('🔌 [Socket] Conectando a: $cleanUrl');
    _isConnecting = true;

    final completer = Completer<void>();
    bool connectionHandled = false;

    // Cerramos socket anterior si existía
    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {
        try {
          _socket!.disconnect();
        } catch (_) {}
      }
      _socket = null;
      _isConnected = false;
    }

    _socket = IO.io(
      cleanUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(10)
          .setTimeout(20000)
          .setExtraHeaders({})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;

      if (!connectionHandled) {
        connectionHandled = true;
        _isConnecting = false;
        debugPrint('✅ [Socket] Conectado OK');
        if (!completer.isCompleted) completer.complete();
      } else {
        debugPrint('✅ [Socket] Reconectado OK');
      }

      // Re-emitir registro usuario pendiente
      if (_pendingRegistration != null) {
        debugPrint('🔄 [Socket] Re-emitiendo registro: $_pendingRegistration');
        _socket!.emit('usuario_conectado', _pendingRegistration);
      }

      // Re-join automático al último viaje
      if (_pendingJoinViaje != null) {
        debugPrint('🔄 [Socket] Re-join viaje: $_pendingJoinViaje');
        _socket!.emit('join_viaje', _pendingJoinViaje);
      }
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('⚠️ [Socket] Desconectado. Razón: $reason');

      if (!connectionHandled && !completer.isCompleted) {
        connectionHandled = true;
        _isConnecting = false;
        completer.completeError('Desconectado: $reason');
      }
    });

    _socket!.onConnectError((err) {
      debugPrint('❌ [Socket] ConnectError: $err');
      if (!connectionHandled && !completer.isCompleted) {
        connectionHandled = true;
        _isConnected = false;
        _isConnecting = false;
        completer.completeError(err ?? 'Error de conexión al socket');
      }
    });

    _socket!.onReconnect((attemptNumber) {
      _isConnected = true;
      debugPrint('🔁 [Socket] Reconexión exitosa (intento $attemptNumber)');
    });

    _socket!.onError((err) {
      debugPrint('❌ [Socket] Error general: $err');
    });

    try {
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          if (!connectionHandled) {
            connectionHandled = true;
            _isConnecting = false;
            debugPrint('⏱️ [Socket] Timeout 20s. Seguirá intentando...');
            if (!completer.isCompleted) completer.complete();
          }
        },
      );
    } catch (e) {
      debugPrint('❌ [Socket] Excepción connect(): $e');
    } finally {
      _isConnecting = false;
    }
  }

  // =========================================================
  // 📤 Emit / 📥 Listen (con handler)
  // =========================================================

  void emit(String event, dynamic data) {
    if (_socket == null) {
      debugPrint('⚠️ [Socket] Emit "$event" sin socket inicializado.');
      return;
    }
    _socket!.emit(event, data);
    debugPrint('📤 Emitido: $event → $data');
  }

  /// ✅ Devuelve el handler real para poder removerlo luego
  Function(dynamic)? on(String event, Function(dynamic) callback) {
    if (_socket == null) {
      debugPrint('⚠️ [Socket] on("$event") sin socket.');
      return null;
    }

    void handler(dynamic data) {
      debugPrint('📥 "$event": $data');
      callback(data);
    }

    _socket!.on(event, handler);
    return handler;
  }

  /// ✅ Si pasás handler remueve SOLO ese. Si no, remueve todos.
  void off(String event, [Function(dynamic)? handler]) {
    if (_socket == null) return;

    if (handler != null) {
      _socket!.off(event, handler);
      debugPrint('🚫 off("$event", handler)');
    } else {
      _socket!.off(event);
      debugPrint('🚫 off("$event") ALL');
    }
  }

  // =========================================================
  // 🧍 Usuario conectado / desconectado
  // =========================================================

  Future<void> registrarUsuario({
    required int idUsuario,
    required String tipo,
  }) async {
    if (!_isConnected || _socket == null) {
      debugPrint('🔄 [Socket] No conectado, intentando connect()...');
      try {
        await connect();
      } catch (e) {
        debugPrint('⚠️ [Socket] connect() error registrarUsuario: $e');
      }
    }

    if (_socket == null) {
      debugPrint('❌ [Socket] Socket null, no se puede registrar usuario');
      return;
    }

    final payload = {'id_usuario': idUsuario, 'tipo': tipo};
    _pendingRegistration = payload;

    try {
      _socket!.emit('usuario_conectado', payload);
      debugPrint('🧍 usuario_conectado → $payload');
    } catch (e) {
      debugPrint('❌ Emit usuario_conectado error: $e');
    }
  }

  Future<void> notificarDesconexionUsuario({
    required int idUsuario,
    required String tipo,
  }) async {
    if (_socket == null) {
      await connect();
    }
    if (_socket == null) {
      debugPrint('⚠️ No se pudo notificar desconexión: sin socket');
      return;
    }

    final payload = {'id_usuario': idUsuario, 'tipo': tipo};
    _socket!.emit('usuario_desconectado', payload);
    debugPrint('📴 usuario_desconectado → $payload');
  }

  Future<void> emitirConexionUsuario(int idUsuario, String tipo) async {
    await registrarUsuario(idUsuario: idUsuario, tipo: tipo);
  }

  void disconnect() {
    if (_socket == null) {
      _isConnected = false;
      return;
    }
    try {
      _socket!.disconnect();
      _socket!.dispose();
    } catch (_) {
      try {
        _socket!.disconnect();
      } catch (_) {}
    }
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    debugPrint('🔴 Socket desconectado manualmente');
  }

  Future<void> disconnectAndNotify({int? idUsuario, String? tipo}) async {
    if (idUsuario != null && tipo != null) {
      await notificarDesconexionUsuario(idUsuario: idUsuario, tipo: tipo);
    }
    disconnect();
  }

  // =========================================================
  // 🚕 Viajes
  // =========================================================

  Future<void> unirseAViaje({
    required int idViaje,
    required int userId,
    required String tipo,
  }) async {
    if (_socket == null) {
      await connect();
    }
    if (_socket == null) {
      debugPrint('❌ No se pudo unir a viaje: sin socket');
      return;
    }

    _pendingJoinViaje = {'id_viaje': idViaje, 'user_id': userId, 'tipo': tipo};

    _socket!.emit('join_viaje', _pendingJoinViaje);
    debugPrint('🚕 join_viaje → viaje $idViaje como $tipo');
  }

  Future<void> salirDeViaje({required int idViaje, required int userId}) async {
    if (_socket == null) return;

    _socket!.emit('leave_viaje', {'id_viaje': idViaje, 'user_id': userId});

    final pendingId = _pendingJoinViaje?['id_viaje'];
    if (pendingId == idViaje) {
      _pendingJoinViaje = null;
    }

    debugPrint('🚕 leave_viaje → viaje $idViaje');
  }

  Future<void> enviarUbicacion({
    required int idViaje,
    required double lat,
    required double lng,
    required int idUsuario,
    required String tipo,
  }) async {
    if (_socket == null) {
      await connect();
    }
    if (_socket == null) return;

    _socket!.emit('ubicacion_actualizada', {
      'id_viaje': idViaje,
      'lat': lat,
      'lng': lng,
      'id_usuario': idUsuario,
      'tipo': tipo,
    });
  }

  Future<void> enviarPanic911({
    required int idUsuario,
    required double? lat,
    required double? lng,
  }) async {
    if (_socket == null) {
      await connect();
    }
    if (_socket == null) return;

    _socket!.emit('panic_911', {
      'id_usuario': idUsuario,
      'lat': lat,
      'lng': lng,
      'ts': DateTime.now().toIso8601String(),
    });

    debugPrint('🚨 panic_911 emitido');
  }

  // =========================================================
  // ✅ Wrappers (TODOS devuelven handler)
  // =========================================================

  Function(dynamic)? onViajeCreado(Function(dynamic) cb) =>
      on('viaje_creado', cb);

  Function(dynamic)? onViajeAsignado(Function(dynamic) cb) =>
      on('viaje_asignado', cb);

  Function(dynamic)? onViajeAceptado(Function(dynamic) cb) =>
      on('viaje_aceptado', cb);

  Function(dynamic)? onConductorLlegoEncuentro(Function(dynamic) cb) =>
      on('conductor_llego_encuentro', cb);

  Function(dynamic)? onViajeEnCurso(Function(dynamic) cb) =>
      on('viaje_en_curso', cb);

  Function(dynamic)? onViajeFinalizado(Function(dynamic) cb) =>
      on('viaje_finalizado', cb);

  Function(dynamic)? onViajeCancelado(Function(dynamic) cb) =>
      on('viaje_cancelado', cb);

  Function(dynamic)? onViajeBuscandoConductor(Function(dynamic) cb) =>
      on('viaje_buscando_conductor', cb);

  Function(dynamic)? onUbicacionEnTiempoReal(Function(dynamic) cb) =>
      on('ubicacion_en_tiempo_real', cb);

  Function(dynamic)? onViajeTomado(Function(dynamic) cb) =>
      on('viaje_tomado', cb);

  Function(dynamic)? onViajeRechazado(Function(dynamic) cb) =>
      on('viaje_rechazado', cb);

  Function(dynamic)? onConductorDisponible(Function(dynamic) cb) =>
      on('conductor_disponible', cb);
}
