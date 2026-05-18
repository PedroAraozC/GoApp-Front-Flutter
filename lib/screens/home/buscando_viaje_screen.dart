// lib/screens/.../buscando_viaje_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/socket_service.dart';
import '../../services/api_service.dart';

import 'viaje_asignado_screen.dart';
import 'pasajero_viaje_en_curso_screen.dart';
import 'dart:math' as Math;

class BuscandoViajeScreen extends StatefulWidget {
  final int idViaje;
  final String direccionOrigen;
  final String direccionDestino;
  const BuscandoViajeScreen({
    super.key,
    required this.idViaje,
    required this.direccionOrigen,
    required this.direccionDestino,
  });

  @override
  State<BuscandoViajeScreen> createState() => _BuscandoViajeScreenState();
}

class _BuscandoViajeScreenState extends State<BuscandoViajeScreen>
    with TickerProviderStateMixin {
  final SocketService _socket = SocketService.instance;
  final ApiService _api = ApiService();

  bool _viajeAsignado = false;
  bool _viajeCancelado = false;
  bool _viajeEnCurso = false;
  bool _cancelando = false;

  bool _navegando = false;

  late AnimationController _pulseController;
  late AnimationController _floatController;

  int? _idUsuario;

  // Cache por si llega viaje_en_curso antes de navegar
  String _dirO = '';
  String _dirD = '';
  double _latO = 0.0, _lngO = 0.0, _latD = 0.0, _lngD = 0.0;
  double _precioFinal = 0.0;
  double? _latConductorIni;
  double? _lngConductorIni;

  Function(dynamic)? _hViajeAsignado;
  Function(dynamic)? _hViajeAceptado;
  Function(dynamic)? _hViajeEnCurso;
  Function(dynamic)? _hViajeCancelado;
  Function(dynamic)? _hViajeBuscando;

  @override
  void initState() {
    super.initState();
    _dirO = widget.direccionOrigen;
    _dirD = widget.direccionDestino;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _inicializarSocketListeners();
  }

  void _mostrarSnack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double? _parseMoney(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  double? _readDouble(dynamic data, List<String> keys) {
    for (final k in keys) {
      final v = (data is Map) ? data[k] : null;
      if (v == null) continue;
      final d = (v is num) ? v.toDouble() : double.tryParse(v.toString());
      if (d != null) return d;
    }
    return null;
  }

  int? _readViajeId(dynamic data) {
    final rawId = data?['id_viajes'] ?? data?['id_viaje'] ?? data?['id'];
    if (rawId == null) return null;
    if (rawId is num) return rawId.toInt();
    return int.tryParse(rawId.toString());
  }

  void _cacheDesdeData(Map data) {
    _dirO =
        (data['direccion_desde'] ??
                data['direccionDesde'] ??
                data['direccion_origen'] ??
                '')
            .toString();
    _dirD =
        (data['direccion_hasta'] ??
                data['direccionHasta'] ??
                data['direccion_destino'] ??
                '')
            .toString();

    _precioFinal =
        (_parseMoney(data['precio_pactado']) ??
        _parseMoney(data['precio_final']) ??
        _parseMoney(data['precio_estimado']) ??
        _parseMoney(data['valor']) ??
        0.0);

    _latO =
        _readDouble(data, [
          'lat_desde',
          'latDesde',
          'origen_lat',
          'lat_origen',
        ]) ??
        _latO;
    _lngO =
        _readDouble(data, [
          'lon_desde',
          'lonDesde',
          'origen_lng',
          'lng_desde',
          'lng_origen',
        ]) ??
        _lngO;

    _latD =
        _readDouble(data, [
          'lat_hasta',
          'latHasta',
          'lat_destino',
          'destino_lat',
        ]) ??
        _latD;
    _lngD =
        _readDouble(data, [
          'lon_hasta',
          'lonHasta',
          'lng_destino',
          'lon_destino',
          'destino_lng',
        ]) ??
        _lngD;

    _latConductorIni = _readDouble(data, [
      'lat_conductor',
      'latConductor',
      'driver_lat',
    ]);
    _lngConductorIni = _readDouble(data, [
      'lng_conductor',
      'lon_conductor',
      'lngConductor',
      'driver_lng',
    ]);
  }

  void _irAViajeAsignado(Map data) {
    final idSocket = _readViajeId(data);
    if (idSocket == null || idSocket != widget.idViaje) return;
    if (!mounted || _navegando || _viajeCancelado) return;

    _cacheDesdeData(data);

    setState(() {
      _viajeAsignado = true;
      _navegando = true;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ViajeAsignadoScreen(
          idViaje: widget.idViaje,
          direccionOrigen: _dirO,
          direccionDestino: _dirD,
          latOrigen: _latO,
          lngOrigen: _lngO,
          latDestino: _latD,
          lngDestino: _lngD,
          precioFinal: _precioFinal,
        ),
      ),
    );
  }

  void _irAPasajeroViajeEnCurso(Map data) {
    final idSocket = _readViajeId(data);
    if (idSocket == null || idSocket != widget.idViaje) return;
    if (!mounted || _navegando || _viajeCancelado) return;

    _cacheDesdeData(data);

    setState(() {
      _viajeEnCurso = true;
      _navegando = true;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PasajeroViajeEnCursoScreen(
          idViaje: widget.idViaje,
          latDestino: _latD,
          lngDestino: _lngD,
          direccionOrigen: _dirO,
          direccionDestino: _dirD,
          latConductorInicial: _latConductorIni,
          lngConductorInicial: _lngConductorIni,
          idConductor: data["id_conductor"],
        ),
      ),
    );
  }

  Future<void> _inicializarSocketListeners() async {
    final prefs = await SharedPreferences.getInstance();
    _idUsuario = prefs.getInt('id_usuario');

    if (!_socket.isConnected) {
      await _socket.connect();
      debugPrint('🔌 Socket conectado desde BuscandoViajeScreen');
    }

    if (_idUsuario != null) {
      await _socket.emitirConexionUsuario(_idUsuario!, 'pasajero');
      debugPrint('✅ Pasajero $_idUsuario registrado en socket (Buscando)');
    }

    if (_idUsuario != null) {
      await _socket.unirseAViaje(
        idViaje: widget.idViaje,
        userId: _idUsuario!,
        tipo: 'pasajero',
      );
      debugPrint('🚪 join_viaje ok → viaje_${widget.idViaje}');
    }

    _hViajeAsignado = _socket.on('viaje_asignado', (data) {
      debugPrint('🚕 Evento: viaje_asignado -> $data');
      if (data is Map) _irAViajeAsignado(Map<String, dynamic>.from(data));
    });

    _hViajeAceptado = _socket.on('viaje_aceptado', (data) {
      debugPrint('✅ Evento: viaje_aceptado -> $data');
      _mostrarSnack('✅ Un conductor aceptó tu viaje');
      if (data is Map) _irAViajeAsignado(Map<String, dynamic>.from(data));
    });

    _hViajeEnCurso = _socket.on('viaje_en_curso', (data) {
      debugPrint('▶️ Evento: viaje_en_curso -> $data');

      final idSocket = _readViajeId(data);
      if (idSocket != null && idSocket != widget.idViaje) return;

      if (mounted) setState(() => _viajeEnCurso = true);
      _mostrarSnack('▶️ Tu viaje comenzó');

      if (data is Map) {
        _irAPasajeroViajeEnCurso(Map<String, dynamic>.from(data));
      }
    });

    _hViajeCancelado = _socket.on('viaje_cancelado', (data) {
      debugPrint('❌ Evento: viaje_cancelado -> $data');

      final idSocket = _readViajeId(data);
      if (idSocket == null || idSocket != widget.idViaje) return;

      if (!mounted) return;
      setState(() {
        _viajeCancelado = true;
        _cancelando = false;
      });
      _mostrarSnack('Tu viaje fue cancelado.');

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      });
    });

    _hViajeBuscando = _socket.on('viaje_buscando_conductor', (data) {
      debugPrint('🔄 Evento: viaje_buscando_conductor -> $data');

      final idSocket = _readViajeId(data);
      if (idSocket == null || idSocket != widget.idViaje) return;

      if (!mounted) return;
      setState(() {
        _viajeAsignado = false;
        _viajeEnCurso = false;
        _navegando = false;
      });
      _mostrarSnack('El conductor canceló. Buscando otro conductor...');
    });
  }

  Future<void> _cancelarViaje() async {
    if (_cancelando) return;
    setState(() => _cancelando = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      int? idUsuario = prefs.getInt('id_usuario');

      if (idUsuario == null) {
        final userData = prefs.getString('user_data');
        if (userData != null) {
          try {
            final user = jsonDecode(userData) as Map<String, dynamic>;
            final rawId = user['id_usuario'];
            if (rawId != null) {
              idUsuario = rawId is int ? rawId : int.tryParse(rawId.toString());
              if (idUsuario != null)
                await prefs.setInt('id_usuario', idUsuario);
            }
          } catch (e) {
            debugPrint('❌ Error parseando user_data: $e');
          }
        }
      }

      if (idUsuario == null) {
        _mostrarSnack(
          'Error: No se encontró el ID de usuario. Cierra sesión y vuelve a iniciar.',
        );
        if (mounted) setState(() => _cancelando = false);
        return;
      }

      final ok = await _api.cancelarViaje(
        idViaje: widget.idViaje,
        idUsuario: idUsuario,
        tipo: 'pasajero',
      );

      if (ok) {
        _mostrarSnack('Cancelando viaje...');
      } else {
        _mostrarSnack('Error al cancelar el viaje');
        if (mounted) setState(() => _cancelando = false);
      }
    } catch (e) {
      debugPrint('❌ Error al cancelar viaje: $e');
      _mostrarSnack('Error al cancelar el viaje: $e');
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  void dispose() {
    _socket.off('viaje_asignado', _hViajeAsignado);
    _socket.off('viaje_aceptado', _hViajeAceptado);
    _socket.off('viaje_en_curso', _hViajeEnCurso);
    _socket.off('viaje_cancelado', _hViajeCancelado);
    _socket.off('viaje_buscando_conductor', _hViajeBuscando);
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String estadoActual = 'Estamos buscando un taxi para vos...';

    if (_viajeAsignado) {
      estadoActual = 'Conductor asignado 🚕';
    }

    if (_viajeEnCurso) {
      estadoActual = 'Tu viaje comenzó ▶️';
    }

    if (_viajeCancelado) {
      estadoActual = 'Viaje cancelado ❌';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Buscando viaje',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  /// ANIMACIÓN CENTRAL
                  SizedBox(
                    height: 300,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _pulseController,
                        _floatController,
                      ]),
                      builder: (_, __) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            /// BURBUJAS
                            ...List.generate(8, (index) {
                              final progress =
                                  ((_floatController.value + (index * 0.12)) %
                                  1);

                              final radius = 120 + (progress * 40);

                              final angle = progress * 6.28;

                              final dx = radius * Math.cos(angle);
                              final dy = radius * Math.sin(angle);

                              return Positioned(
                                left: 130 + dx,
                                top: 130 + dy,
                                child: Opacity(
                                  opacity: 1 - progress,
                                  child: Container(
                                    width: 10 + (progress * 10),
                                    height: 10 + (progress * 10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amber.withOpacity(0.15),
                                    ),
                                  ),
                                ),
                              );
                            }),

                            /// CÍRCULO 1
                            Transform.scale(
                              scale: 1 + (_pulseController.value * 0.05),
                              child: Container(
                                width: 260,
                                height: 260,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.amber.withOpacity(0.06),
                                ),
                              ),
                            ),

                            /// CÍRCULO 2
                            Transform.scale(
                              scale: 1 + (_pulseController.value * 0.08),
                              child: Container(
                                width: 190,
                                height: 190,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.amber.withOpacity(0.10),
                                ),
                              ),
                            ),

                            /// CÍRCULO 3
                            Transform.scale(
                              scale: 1 + (_pulseController.value * 0.12),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.amber.withOpacity(0.18),
                                ),
                              ),
                            ),

                            /// TAXI CENTRAL
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.45),
                                    blurRadius: 25,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_taxi,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),

                            /// MINI TAXIS ORBITANDO
                            ...List.generate(4, (index) {
                              final angle =
                                  (_floatController.value * 6.28) +
                                  (index * 1.57);

                              final radius = 115.0;

                              final dx = radius * Math.cos(angle);
                              final dy = radius * Math.sin(angle);

                              return Transform.translate(
                                offset: Offset(dx, dy),
                                child: _miniTaxi(),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// TEXOS
                  Text(
                    estadoActual,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _cancelando
                        ? 'Estamos cancelando tu solicitud...'
                        : 'Puede tardar unos segundos.\nTe avisaremos cuando tengamos un conductor disponible cerca tuyo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 32),

                  /// CARD DIRECCIONES
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.amber,
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Desde',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _dirO.isEmpty ? 'Origen' : _dirO,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Divider(color: Colors.grey.shade200),
                        ),

                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.flag,
                                color: Colors.amber,
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hasta',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _dirD.isEmpty ? 'Destino' : _dirD,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// BOTÓN CANCELAR
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _cancelando ? null : _cancelarViaje,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _cancelando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Text(
                              'Cancelar búsqueda',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniTaxi() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.local_taxi, color: Colors.amber, size: 24),
    );
  }
}
