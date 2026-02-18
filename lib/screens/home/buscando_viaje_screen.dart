// lib/screens/.../buscando_viaje_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import 'viaje_asignado_screen.dart'; // 👈 ajustá la ruta si es necesario

class BuscandoViajeScreen extends StatefulWidget {
  final int idViaje; // ID del viaje actual

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

  bool _navegandoADetalle = false; // para evitar navegar dos veces

  @override
  void initState() {
    super.initState();
    _inicializarSocketListeners();
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

  Future<void> _inicializarSocketListeners() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario');

    // Conectamos si no está conectado todavía
    if (!_socket.isConnected) {
      await _socket.connect();
      debugPrint('🔌 Socket conectado desde BuscandoViajeScreen');
    }

    // Registramos al usuario en el socket como pasajero
    if (idUsuario != null) {
      await _socket.emitirConexionUsuario(idUsuario, 'pasajero');
      debugPrint(
        '✅ Pasajero $idUsuario registrado en socket desde BuscandoViajeScreen',
      );
      _mostrarSnack('Conectado al servidor.');
    }

    // 🚕 Evento: viaje asignado
    _socket.on('viaje_asignado', (data) {
      debugPrint('🚕 Evento: viaje_asignado -> $data');

      try {
        // 1) Validar que el viaje que llega por socket sea el mismo que este screen
        final rawId =
            data?['id_viajes'] ??
            data?['id_viaje'] ??
            data?['id']; // por las dudas
        if (rawId == null) return;

        final idSocket = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId.toString());

        if (idSocket == null || idSocket != widget.idViaje) {
          debugPrint(
            'ℹ️ viaje_asignado de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
          );
          return;
        }

        if (!mounted || _navegandoADetalle || _viajeCancelado) return;

        setState(() {
          _viajeAsignado = true;
          _navegandoADetalle = true;
        });

        _mostrarSnack('Un conductor fue asignado a tu viaje 🚕');

        // 2) Extraer datos del viaje para mostrar en la pantalla siguiente
        final direccionOrigen =
            (data['direccion_desde'] ?? data['direccionDesde'] ?? '')
                .toString();
        final direccionDestino =
            (data['direccion_hasta'] ?? data['direccionHasta'] ?? '')
                .toString();

        // ✅ Precio FIJO: preferimos precio_pactado / precio_final
        // (compat: precio_estimado / valor)
        final double precioMostrado =
            (_parseMoney(data['precio_pactado']) ??
            _parseMoney(data['precio_final']) ??
            _parseMoney(data['precio_estimado']) ??
            _parseMoney(data['valor']) ??
            0.0);

        // Coordenadas robustas (acepta keys nuevas y compat)
        final latOrigen = _readDouble(data, [
          'lat_desde',
          'latDesde',
          'origen_lat',
        ]);
        final lngOrigen = _readDouble(data, [
          'lon_desde',
          'lonDesde',
          'origen_lng',
          'lng_desde',
        ]);
        final latDestino = _readDouble(data, [
          'lat_hasta',
          'latHasta',
          'lat_destino',
          'destino_lat',
        ]);
        final lngDestino = _readDouble(data, [
          'lon_hasta',
          'lonHasta',
          'lng_destino',
          'lon_destino',
          'destino_lng',
        ]);

        // 3) Navegar a la pantalla de viaje asignado
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ViajeAsignadoScreen(
              idViaje: widget.idViaje,
              direccionOrigen: direccionOrigen,
              direccionDestino: direccionDestino,
              precioFinal: precioMostrado,
              latOrigen: latOrigen ?? 0.0,
              lngOrigen: lngOrigen ?? 0.0,
              latDestino: latDestino ?? 0.0,
              lngDestino: lngDestino ?? 0.0,
            ),
          ),
        );
      } catch (e) {
        debugPrint('❌ Error procesando viaje_asignado: $e');
      }
    });

    // ▶️ Evento: viaje en curso
    _socket.on('viaje_en_curso', (data) {
      debugPrint('▶️ Evento: viaje_en_curso -> $data');
      if (mounted) setState(() => _viajeEnCurso = true);
      _mostrarSnack('Tu viaje ha comenzado ▶️');
    });

    // 🏁 Evento: viaje finalizado
    _socket.on('viaje_finalizado', (data) {
      debugPrint('🏁 Evento: viaje_finalizado -> $data');
      if (mounted) {
        setState(() {
          _viajeEnCurso = false;
          _viajeAsignado = false;
        });
      }
      _mostrarSnack('El viaje ha finalizado. ¡Gracias por usar GoApp!');
    });

    // ❌ Evento: viaje cancelado
    _socket.on('viaje_cancelado', (data) {
      debugPrint('❌ Evento: viaje_cancelado -> $data');

      try {
        final rawId = data?['id_viajes'] ?? data?['id_viaje'] ?? data?['id'];
        if (rawId == null) return;

        final idSocket = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId.toString());

        if (idSocket == null || idSocket != widget.idViaje) {
          debugPrint(
            'ℹ️ viaje_cancelado de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
          );
          return;
        }

        if (mounted) {
          setState(() {
            _viajeCancelado = true;
            _cancelando = false;
          });
        }
        _mostrarSnack('Tu viaje fue cancelado.');

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        });
      } catch (e) {
        debugPrint('❌ Error procesando viaje_cancelado: $e');
      }
    });

    // 🔄 Evento: viaje vuelve a buscar conductor
    _socket.on('viaje_buscando_conductor', (data) {
      debugPrint('🔄 Evento: viaje_buscando_conductor -> $data');

      try {
        final rawId = data?['id_viajes'] ?? data?['id_viaje'] ?? data?['id'];
        if (rawId == null) return;

        final idSocket = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId.toString());

        if (idSocket == null || idSocket != widget.idViaje) return;

        if (mounted) {
          setState(() {
            _viajeAsignado = false;
            _viajeEnCurso = false;
          });
        }
        _mostrarSnack('El conductor canceló. Buscando otro conductor...');
      } catch (e) {
        debugPrint('❌ Error procesando viaje_buscando_conductor: $e');
      }
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
              if (idUsuario != null) {
                await prefs.setInt('id_usuario', idUsuario);
              }
            }
          } catch (e) {
            debugPrint('❌ Error parseando user_data: $e');
          }
        }
      }

      if (idUsuario == null) {
        debugPrint('❌ No se pudo obtener id_usuario de ninguna fuente');
        _mostrarSnack(
          'Error: No se encontró el ID de usuario. Por favor, cierra sesión y vuelve a iniciar.',
        );
        if (mounted) setState(() => _cancelando = false);
        return;
      }

      debugPrint('✅ ID usuario obtenido para cancelar: $idUsuario');

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

  @override
  void dispose() {
    _socket.off('viaje_asignado');
    _socket.off('viaje_en_curso');
    _socket.off('viaje_finalizado');
    _socket.off('viaje_cancelado');
    _socket.off('viaje_buscando_conductor');
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
