// lib/screens/.../buscando_viaje_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/socket_service.dart';
import '../../services/api_service.dart';

import 'viaje_asignado_screen.dart';
import 'pasajero_viaje_en_curso_screen.dart';

class BuscandoViajeScreen extends StatefulWidget {
  final int idViaje;

  const BuscandoViajeScreen({super.key, required this.idViaje});

  @override
  State<BuscandoViajeScreen> createState() => _BuscandoViajeScreenState();
}

class _BuscandoViajeScreenState extends State<BuscandoViajeScreen> {
  final SocketService _socket = SocketService.instance;
  final ApiService _api = ApiService();

  bool _viajeAsignado = false;
  bool _viajeCancelado = false;
  bool _viajeEnCurso = false;
  bool _cancelando = false;

  bool _navegando = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String estadoActual = 'Buscando conductor...';
    if (_viajeAsignado) estadoActual = 'Conductor asignado 🚕';
    if (_viajeEnCurso) estadoActual = 'Viaje en curso ▶️';
    if (_viajeCancelado) estadoActual = 'Viaje cancelado ❌';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Buscando viaje'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_viajeCancelado && !_cancelando)
              const CircularProgressIndicator(color: Colors.amber),
            if (_cancelando) const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 20),
            Text(
              _cancelando ? 'Cancelando...' : estadoActual,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (!_viajeCancelado)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: _cancelando ? null : _cancelarViaje,
                icon: _cancelando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cancel),
                label: Text(_cancelando ? 'Cancelando...' : 'Cancelar viaje'),
              ),
          ],
        ),
      ),
    );
  }
}
