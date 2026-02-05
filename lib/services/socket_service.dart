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

  /// 🔌 Conecta el socket (y espera a que realmente se conecte).
  /// Si ya está conectado, no hace nada.
  /// Si hay un error o timeout, NO bloquea: el socket seguirá intentando reconectar.
  Future<void> connect() async {
    if (_isConnected && _socket != null) {
      debugPrint('🟢 [Socket] Ya está conectado.');
      return;
    }

    // Si hay un intento en curso, esperamos un poco pero no bloqueamos indefinidamente
    if (_isConnecting) {
      debugPrint(
        '⏳ [Socket] Conexión ya en curso, esperando máximo 3 segundos...',
      );
      int attempts = 0;
      while (_isConnecting && attempts < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_isConnected && _socket != null) {
        debugPrint('✅ [Socket] Conexión completada durante la espera');
        return;
      }
      debugPrint(
        '⚠️ [Socket] La conexión anterior no se completó, iniciando nueva conexión',
      );
    }

    final baseUrl = dotenv.env['API_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint('❌ No se encontró API_URL en el .env');
      return;
    }

    // Limpiar URL: remover trailing slash
    String cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    debugPrint('🔌 [Socket] Intentando conectar a: $cleanUrl');
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

    // 🟢 Conectado
    _socket!.onConnect((_) {
      _isConnected = true;

      if (!connectionHandled) {
        connectionHandled = true;
        _isConnecting = false;
        debugPrint('✅ [Socket] Conectado al servidor Socket.IO exitosamente');
        if (!completer.isCompleted) completer.complete();
      } else {
        debugPrint('✅ [Socket] Reconectado exitosamente');
      }

      // ✅ Re-emitir registro usuario pendiente
      if (_pendingRegistration != null) {
        debugPrint(
          '🔄 [Socket] Re-emitiendo registro pendiente: $_pendingRegistration',
        );
        _socket!.emit('usuario_conectado', _pendingRegistration);
        // NO lo nulamos: nos sirve si vuelve a reconectar
      }

      // ✅ Re-join automático al último viaje
      if (_pendingJoinViaje != null) {
        debugPrint('🔄 [Socket] Re-join viaje pendiente: $_pendingJoinViaje');
        _socket!.emit('join_viaje', _pendingJoinViaje);
      }
    });

    // 🔴 Desconectado
    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('⚠️ [Socket] Desconectado. Razón: $reason');

      if (!connectionHandled && !completer.isCompleted) {
        connectionHandled = true;
        _isConnecting = false;
        completer.completeError('Desconectado: $reason');
      }
    });

    // ❌ Error de conexión
    _socket!.onConnectError((err) {
      debugPrint('❌ [Socket] Error de conexión: $err');
      if (!connectionHandled && !completer.isCompleted) {
        connectionHandled = true;
        _isConnected = false;
        _isConnecting = false;
        completer.completeError(err ?? 'Error de conexión al socket');
      }
    });

    // 🔁 Reconectado automáticamente
    _socket!.onReconnect((attemptNumber) {
      _isConnected = true;
      debugPrint(
        '🔁 [Socket] Reconexión automática exitosa (intento $attemptNumber)',
      );
      // El re-join/registro se hace en onConnect
    });

    // Error general
    _socket!.onError((err) {
      debugPrint('❌ [Socket] Error general: $err');
    });

    // Esperar hasta que se conecte o timeout (sin bloquear: el socket sigue intentando)
    try {
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          if (!connectionHandled) {
            connectionHandled = true;
            _isConnecting = false;
            debugPrint(
              '⏱️ [Socket] Timeout (20s). El socket seguirá intentando en segundo plano.',
            );
            if (!completer.isCompleted) completer.complete();
          }
        },
      );

      if (_isConnected) {
        debugPrint('✅ [Socket] Conexión establecida correctamente');
      } else {
        debugPrint(
          '⚠️ [Socket] Completer completó pero socket no está conectado aún. Seguirá intentando...',
        );
      }
    } catch (e) {
      debugPrint('❌ [Socket] Excepción durante conexión: $e');
      debugPrint(
        '⚠️ [Socket] Permitimos que continúe intentando reconectar en segundo plano',
      );
    } finally {
      _isConnecting = false;
      if (_socket != null && !_isConnected) {
        debugPrint(
          'ℹ️ [Socket] Socket creado pero no conectado aún, seguirá intentando automáticamente',
        );
      }
    }
  }

  /// 📤 Emite un evento genérico (si hay socket).
  /// Nota: Socket.IO puede encolar emits aunque todavía esté reconectando.
  void emit(String event, dynamic data) {
    if (_socket == null) {
      debugPrint('⚠️ [Socket] Emit "$event" sin socket inicializado.');
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
      // Ojo: este log puede ser MUY ruidoso en ubicaciones
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
  // 🧍 Usuario conectado / desconectado
  // =========================================================

  /// 🧍 Registrar usuario (pasajero o conductor) en el socket.
  Future<void> registrarUsuario({
    required int idUsuario,
    required String tipo,
  }) async {
    // Intentar conectar si no está conectado
    if (!_isConnected || _socket == null) {
      debugPrint('🔄 [Socket] Socket no conectado, intentando conectar...');
      try {
        await connect();
      } catch (e) {
        debugPrint(
          '⚠️ [Socket] Error en connect() durante registrarUsuario: $e',
        );
      }
    }

    if (_socket == null) {
      debugPrint('❌ [Socket] Socket es null, no se puede registrar usuario');
      return;
    }

    final payload = {'id_usuario': idUsuario, 'tipo': tipo};

    // Guardar para re-emitir al reconectar
    _pendingRegistration = payload;

    // Emitimos (aunque esté reconectando, quedará en cola)
    try {
      _socket!.emit('usuario_conectado', payload);
      debugPrint('🧍 [Socket] usuario_conectado emitido → $payload');
    } catch (e) {
      debugPrint('❌ [Socket] Error al emitir usuario_conectado: $e');
    }
  }

  /// 📴 Notificar usuario_desconectado
  Future<void> notificarDesconexionUsuario({
    required int idUsuario,
    required String tipo,
  }) async {
    if (_socket == null) {
      await connect();
    }

    if (_socket == null) {
      debugPrint(
        '⚠️ No se pudo notificar usuario_desconectado: sin socket. id=$idUsuario tipo=$tipo',
      );
      return;
    }

    final payload = {'id_usuario': idUsuario, 'tipo': tipo};

    _socket!.emit('usuario_desconectado', payload);
    debugPrint('📴 usuario_desconectado emitido → $payload');
  }

  /// Alias compat
  Future<void> emitirConexionUsuario(int idUsuario, String tipo) async {
    await registrarUsuario(idUsuario: idUsuario, tipo: tipo);
  }

  /// 🔴 Cierra la conexión manualmente (sin notificar usuario_desconectado).
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

  /// 🔴 Cierra conexión y, opcionalmente, notifica usuario_desconectado.
  Future<void> disconnectAndNotify({int? idUsuario, String? tipo}) async {
    if (idUsuario != null && tipo != null) {
      await notificarDesconexionUsuario(idUsuario: idUsuario, tipo: tipo);
    }
    disconnect();
  }

  // =========================================================
  // 🚕 Viajes
  // =========================================================

  /// 🚕 Unirse al room de un viaje (se guarda para re-join en reconexión)
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
    debugPrint('🚕 join_viaje emitido → viaje $idViaje como $tipo');
  }

  /// 🚕 Salir del room de un viaje
  Future<void> salirDeViaje({required int idViaje, required int userId}) async {
    if (_socket == null) return;

    _socket!.emit('leave_viaje', {'id_viaje': idViaje, 'user_id': userId});

    // Si salgo del viaje que tenía guardado, lo limpio
    final pendingId = _pendingJoinViaje?['id_viaje'];
    if (pendingId == idViaje) {
      _pendingJoinViaje = null;
    }

    debugPrint('🚕 leave_viaje emitido → viaje $idViaje');
  }

  /// 📍 Enviar ubicación actualizada (NO reconecta cada vez)
  Future<void> enviarUbicacion({
    required int idViaje,
    required double lat,
    required double lng,
    required int idUsuario,
    required String tipo,
  }) async {
    // Si no hay socket, intentamos conectar una vez
    if (_socket == null) {
      await connect();
    }
    if (_socket == null) return;

    // Emitimos igual aunque esté reconectando: quedará en cola
    _socket!.emit('ubicacion_actualizada', {
      'id_viaje': idViaje,
      'lat': lat,
      'lng': lng,
      'id_usuario': idUsuario,
      'tipo': tipo,
    });
    // ⚠️ Evitá debugPrint acá si se llama muy seguido (puede trabar)
    // debugPrint('📍 Ubicación enviada: $lat, $lng');
  }

  /// 🚨 Botón antipánico
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

    debugPrint('🚨 [Socket] panic_911 emitido');
  }

  // =========================================================
  // 📥 Listeners para eventos de viajes
  // =========================================================

  void onViajeCreado(Function(dynamic) callback) =>
      on('viaje_creado', callback);
  void onViajeAsignado(Function(dynamic) callback) =>
      on('viaje_asignado', callback);
  void onViajeAceptado(Function(dynamic) callback) =>
      on('viaje_aceptado', callback);
  void onConductorLlegoEncuentro(Function(dynamic) callback) =>
      on('conductor_llego_encuentro', callback);
  void onViajeEnCurso(Function(dynamic) callback) =>
      on('viaje_en_curso', callback);
  void onViajeFinalizado(Function(dynamic) callback) =>
      on('viaje_finalizado', callback);
  void onViajeCancelado(Function(dynamic) callback) =>
      on('viaje_cancelado', callback);
  void onViajeBuscandoConductor(Function(dynamic) callback) =>
      on('viaje_buscando_conductor', callback);
  void onUbicacionEnTiempoReal(Function(dynamic) callback) =>
      on('ubicacion_en_tiempo_real', callback);
  void onViajeTomado(Function(dynamic) callback) =>
      on('viaje_tomado', callback);
  void onViajeRechazado(Function(dynamic) callback) =>
      on('viaje_rechazado', callback);
  void onConductorDisponible(Function(dynamic) callback) =>
      on('conductor_disponible', callback);
}
