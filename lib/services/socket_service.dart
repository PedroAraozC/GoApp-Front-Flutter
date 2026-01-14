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
  Map<String, dynamic>? _pendingRegistration; // Para guardar registro pendiente si el socket no está conectado

  bool get isConnected => _isConnected;
  IO.Socket? get rawSocket =>
      _socket; // acceso crudo si alguna vez lo necesitás

  /// 🔌 Conecta el socket (y espera a que realmente se conecte).
  /// Si ya está conectado, no hace nada.
  /// Si hay un error, permite que el socket intente reconectar en segundo plano.
  Future<void> connect() async {
    if (_isConnected && _socket != null) {
      debugPrint('🟢 [Socket] Ya está conectado.');
      return;
    }

    // Si hay un intento en curso, esperamos un poco pero no bloqueamos indefinidamente
    if (_isConnecting) {
      debugPrint('⏳ [Socket] Conexión ya en curso, esperando máximo 3 segundos...');
      int attempts = 0;
      while (_isConnecting && attempts < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      // Después de esperar, si quedó conectado, listo
      if (_isConnected && _socket != null) {
        debugPrint('✅ [Socket] Conexión completada durante la espera');
        return;
      }
      // Si no quedó conectado, seguimos y reintentamos
      debugPrint('⚠️ [Socket] La conexión anterior no se completó, iniciando nueva conexión');
    }

    final baseUrl = dotenv.env['API_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint('❌ No se encontró API_URL en el .env');
      return;
    }

    // Limpiar URL: remover trailing slash y asegurar formato correcto
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

    // Crear socket con configuración mejorada
    _socket = IO.io(
      cleanUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling']) // Permitir ambos transportes
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(10)
          .setTimeout(20000) // Timeout de 20 segundos
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
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else {
        debugPrint('✅ [Socket] Reconectado exitosamente');
      }
      
      // Si hay un usuario pendiente de registrar, registrarlo ahora
      if (_pendingRegistration != null) {
        debugPrint('🔄 [Socket] Re-emitiendo registro pendiente: $_pendingRegistration');
        _socket!.emit('usuario_conectado', _pendingRegistration);
        _pendingRegistration = null;
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
      debugPrint('🔁 [Socket] Reconexión automática exitosa (intento $attemptNumber)');
    });

    // Error general
    _socket!.onError((err) {
      debugPrint('❌ [Socket] Error general: $err');
    });

    // Esperar hasta que se conecte o falle (aumentado a 20 segundos)
    // Si hay timeout, no lanzar excepción, permitir que reconecte en segundo plano
    try {
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          if (!connectionHandled) {
            connectionHandled = true;
            _isConnecting = false;
            debugPrint('⏱️ [Socket] Timeout después de 20 segundos, pero el socket seguirá intentando');
            debugPrint('⏱️ [Socket] La conexión puede establecerse en segundo plano');
            // Completar sin error para no bloquear, el socket seguirá intentando
            if (!completer.isCompleted) {
              completer.complete(); // Completar sin error
            }
          }
        },
      );
      if (_isConnected) {
        debugPrint('✅ [Socket] Conexión establecida correctamente');
      } else {
        debugPrint('⚠️ [Socket] Completer completó pero socket no está conectado aún');
        debugPrint('⚠️ [Socket] El socket seguirá intentando en segundo plano');
      }
    } catch (e) {
      debugPrint('❌ [Socket] Excepción durante conexión: $e');
      // No marcar como desconectado si el socket sigue intentando
      if (e.toString().contains('Timeout')) {
        debugPrint('⚠️ [Socket] Timeout, pero el socket seguirá intentando reconectar en segundo plano');
        // El socket seguirá intentando reconectar automáticamente
        // No lanzar la excepción para no bloquear
      } else {
        // Para otros errores, también permitir que continúe
        debugPrint('⚠️ [Socket] Error, pero permitiendo que el socket continúe intentando');
      }
    } finally {
      _isConnecting = false;
      // Si el socket existe pero no está conectado, seguirá intentando en segundo plano
      if (_socket != null && !_isConnected) {
        debugPrint('ℹ️ [Socket] Socket creado pero no conectado aún, seguirá intentando automáticamente');
      }
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
  /// Si el socket no está conectado, intentará conectarse primero.
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
        debugPrint('⚠️ [Socket] Error en connect() durante registrarUsuario: $e');
        // Continuar de todas formas
      }
    }

    // Esperar un momento para que la conexión se establezca
    await Future.delayed(const Duration(milliseconds: 500));

    if (_socket == null) {
      debugPrint('❌ [Socket] Socket es null, no se puede registrar usuario');
      return;
    }

    final payload = {'id_usuario': idUsuario, 'tipo': tipo};

    // Guardar el payload por si el socket se desconecta y necesita re-registrarse
    _pendingRegistration = payload;

    // Emitir el evento incluso si no está completamente conectado
    // El socket lo procesará cuando se conecte
    try {
      _socket!.emit('usuario_conectado', payload);
      debugPrint('🧍 [Socket] Evento usuario_conectado emitido → $payload');
      
      // Si no está conectado, guardar el payload para emitirlo cuando se conecte
      if (!_isConnected) {
        debugPrint('⚠️ [Socket] Socket no conectado aún, el evento se procesará cuando se conecte');
        debugPrint('⚠️ [Socket] El payload se guardó para re-emitir cuando se conecte');
      }
      
      // Esperar un momento para que el servidor procese el join
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verificar que el socket está en los rooms correctos
      if (tipo == 'conductor') {
        debugPrint('✅ [Socket] Conductor $idUsuario debería estar en room "conductores"');
      } else if (tipo == 'pasajero') {
        debugPrint('✅ [Socket] Pasajero $idUsuario debería estar en room "pasajeros"');
      }
    } catch (e) {
      debugPrint('❌ [Socket] Error al emitir usuario_conectado: $e');
      // No lanzar excepción, permitir que continúe
    }
  }

  /// 📴 Notificar al servidor que el usuario se desconectó (pasajero o conductor).
  ///
  /// Útil para logout, cierre de app, etc.
  Future<void> notificarDesconexionUsuario({
    required int idUsuario,
    required String tipo,
  }) async {
    // Si no hay conexión, intentamos conectar brevemente solo para avisar
    if (!_isConnected || _socket == null) {
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

  // =========================================================
  // 🚕 Eventos de viajes
  // =========================================================

  /// 🚕 Unirse al room de un viaje para seguimiento en tiempo real
  Future<void> unirseAViaje({
    required int idViaje,
    required int userId,
    required String tipo,
  }) async {
    await connect();
    if (!_isConnected || _socket == null) {
      debugPrint('❌ No se pudo unir a viaje: sin conexión');
      return;
    }

    _socket!.emit('join_viaje', {
      'id_viaje': idViaje,
      'user_id': userId,
      'tipo': tipo,
    });
    debugPrint('🚕 Unido a viaje $idViaje como $tipo');
  }

  /// 🚕 Salir del room de un viaje
  Future<void> salirDeViaje({
    required int idViaje,
    required int userId,
  }) async {
    if (!_isConnected || _socket == null) return;

    _socket!.emit('leave_viaje', {
      'id_viaje': idViaje,
      'user_id': userId,
    });
    debugPrint('🚕 Salido de viaje $idViaje');
  }

  /// 📍 Enviar ubicación actualizada en tiempo real
  Future<void> enviarUbicacion({
    required int idViaje,
    required double lat,
    required double lng,
    required int idUsuario,
    required String tipo,
  }) async {
    await connect();
    if (!_isConnected || _socket == null) {
      debugPrint('❌ No se pudo enviar ubicación: sin conexión');
      return;
    }

    _socket!.emit('ubicacion_actualizada', {
      'id_viaje': idViaje,
      'lat': lat,
      'lng': lng,
      'id_usuario': idUsuario,
      'tipo': tipo,
    });
    debugPrint('📍 Ubicación enviada: $lat, $lng');
  }

  // =========================================================
  // 📥 Listeners para eventos de viajes
  // =========================================================

  /// 📥 Escuchar cuando se crea un nuevo viaje (para conductores)
  void onViajeCreado(Function(dynamic) callback) {
    on('viaje_creado', callback);
  }

  /// 📥 Escuchar cuando un viaje es asignado (para pasajero)
  void onViajeAsignado(Function(dynamic) callback) {
    on('viaje_asignado', callback);
  }

  /// 📥 Escuchar cuando un viaje es aceptado (para conductor)
  void onViajeAceptado(Function(dynamic) callback) {
    on('viaje_aceptado', callback);
  }

  /// 📥 Escuchar cuando el conductor llegó al punto de encuentro
  void onConductorLlegoEncuentro(Function(dynamic) callback) {
    on('conductor_llego_encuentro', callback);
  }

  /// 📥 Escuchar cuando el viaje comienza
  void onViajeEnCurso(Function(dynamic) callback) {
    on('viaje_en_curso', callback);
  }

  /// 📥 Escuchar cuando el viaje finaliza
  void onViajeFinalizado(Function(dynamic) callback) {
    on('viaje_finalizado', callback);
  }

  /// 📥 Escuchar cuando un viaje es cancelado
  void onViajeCancelado(Function(dynamic) callback) {
    on('viaje_cancelado', callback);
  }

  /// 📥 Escuchar cuando un viaje vuelve a buscar conductor (cancelado por conductor)
  void onViajeBuscandoConductor(Function(dynamic) callback) {
    on('viaje_buscando_conductor', callback);
  }

  /// 📥 Escuchar actualizaciones de ubicación en tiempo real
  void onUbicacionEnTiempoReal(Function(dynamic) callback) {
    on('ubicacion_en_tiempo_real', callback);
  }

  /// 📥 Escuchar cuando un viaje fue tomado por otro conductor
  void onViajeTomado(Function(dynamic) callback) {
    on('viaje_tomado', callback);
  }

  /// 📥 Escuchar cuando un viaje fue rechazado
  void onViajeRechazado(Function(dynamic) callback) {
    on('viaje_rechazado', callback);
  }

  /// 📥 Escuchar cuando el conductor está disponible nuevamente
  void onConductorDisponible(Function(dynamic) callback) {
    on('conductor_disponible', callback);
  }
}
