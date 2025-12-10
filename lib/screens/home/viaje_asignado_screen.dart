import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../services/socket_service.dart';
import '../../services/api_service.dart';

class ViajeAsignadoScreen extends StatefulWidget {
  final int idViaje;
  final String direccionOrigen;
  final String direccionDestino;
  final double? precioEstimado;

  final double latOrigen;
  final double lngOrigen;

  const ViajeAsignadoScreen({
    super.key,
    required this.idViaje,
    required this.direccionOrigen,
    required this.direccionDestino,
    this.precioEstimado,
    required this.latOrigen,
    required this.lngOrigen,
  });

  @override
  State<ViajeAsignadoScreen> createState() => _ViajeAsignadoScreenState();
}

class _ViajeAsignadoScreenState extends State<ViajeAsignadoScreen> {
  final SocketService _socket = SocketService.instance;
  final ApiService _api = ApiService();

  GoogleMapController? _mapController;

  LatLng? _posPasajero;
  LatLng? _posConductor;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _viajeCancelado = false;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();

    // 🟦 POSICIÓN DEL PASAJERO DESDE EL VIAJE
    _posPasajero = LatLng(widget.latOrigen, widget.lngOrigen);

    _actualizarMarkers();

    _inicializarSocketListeners();
  }

  // ===============================================================
  // 🔌 SOCKET LISTENERS
  // ===============================================================
  Future<void> _inicializarSocketListeners() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario');

    if (idUsuario == null) {
      debugPrint("⚠️ id_usuario es null. No se puede registrar en socket.");
      return;
    }

    await _socket.emitirConexionUsuario(idUsuario, 'pasajero');
    
    // Unirse al room del viaje para recibir actualizaciones
    await _socket.unirseAViaje(
      idViaje: widget.idViaje,
      userId: idUsuario,
      tipo: 'pasajero',
    );

    // 🔊 UBICACIÓN DEL CONDUCTOR (nuevo sistema)
    _socket.onUbicacionEnTiempoReal((data) async {
      debugPrint("📍 LLEGA UBICACIÓN EN TIEMPO REAL → $data");
      try {
        // Solo procesar si es del conductor
        if (data['tipo'] != 'conductor') return;
        
        final lat = double.tryParse(data["lat"].toString());
        final lng = double.tryParse(data["lng"].toString());
        if (lat == null || lng == null) return;

        _posConductor = LatLng(lat, lng);

        _actualizarMarkers();
        await _drawRoute(); // 👈 siempre actualizar ruta
        if (_posConductor != null) {
          _moverCamara(_posConductor!);
        }
      } catch (e) {
        debugPrint("❌ Error procesando ubicación del conductor: $e");
      }
    });

    // 🔊 CONDUCTOR LLEGÓ AL ENCUENTRO
    _socket.onConductorLlegoEncuentro((data) {
      debugPrint("🚕 Conductor llegó al punto de encuentro → $data");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚕 El conductor llegó al punto de encuentro'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // ▶️ VIAJE EN CURSO
    _socket.onViajeEnCurso((data) {
      debugPrint("▶️ Viaje en curso → $data");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('▶️ El viaje ha comenzado'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        // Aquí podrías navegar a una pantalla de viaje en curso si la tienes
      }
    });

    // 🏁 VIAJE FINALIZADO
    _socket.onViajeFinalizado((data) {
      debugPrint("🏁 Viaje finalizado → $data");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏁 Viaje finalizado. ¡Gracias por usar GoApp!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        // Navegar a pantalla de calificación o home
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          }
        });
      }
    });

    // ❌ VIAJE CANCELADO
    _socket.onViajeCancelado((data) {
      debugPrint("❌ Viaje cancelado → $data");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ El viaje fue cancelado'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          }
        });
      }
    });
  }

  // ===============================================================
  // 🗺️ MAPA
  // ===============================================================
  void _actualizarMarkers() {
    _markers.clear();

    if (_posPasajero != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("pasajero"),
          position: _posPasajero!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    if (_posConductor != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("conductor"),
          position: _posConductor!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
        ),
      );
    }

    setState(() {});
  }

  void _moverCamara(LatLng pos) {
    if (_mapController == null) return;

    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
  }

  // ===============================================================
  // 🟦 ROUTE (DIRECTIONS API)
  // ===============================================================
  Future<void> _drawRoute() async {
    if (_posConductor == null || _posPasajero == null) return;

    final apiKey =
        dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${_posConductor!.latitude},${_posConductor!.longitude}'
      '&destination=${_posPasajero!.latitude},${_posPasajero!.longitude}'
      '&mode=driving&key=$apiKey',
    );

    try {
      final resp = await http.get(url);
      final data = jsonDecode(resp.body);

      if (data['status'] != 'OK') {
        debugPrint('❌ Directions API error: ${data['status']}');
        return;
      }

      final polyline = data['routes'][0]['overview_polyline']['points'];
      final points = _decodePolyline(polyline);

      setState(() {
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('conductor_pasajero'),
              points: points,
              width: 6,
              color: Colors.blue,
            ),
          );
      });

      _fitPolyline(points);
    } catch (e) {
      debugPrint("❌ Error obteniendo ruta: $e");
    }
  }

  // POLYLINE DECODER
  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < polyline.length) {
      int b, shift = 0, result = 0;

      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  Future<void> _fitPolyline(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  // ===============================================================
  // UI
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tu viaje")),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _posPasajero ?? const LatLng(-26.8241, -65.2226),
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) => _mapController = controller,
            ),
          ),

          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    "El conductor está en camino 🚕",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(Icons.my_location),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.direccionOrigen)),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.location_on),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.direccionDestino)),
                    ],
                  ),

                  const Spacer(),

                  FutureBuilder(
                    future: SharedPreferences.getInstance(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final prefs = snapshot.data!;
                      final idUsuario = prefs.getInt('id_usuario');
                      
                      return ElevatedButton(
                        onPressed: _cancelando || idUsuario == null
                            ? null
                            : () async {
                                setState(() => _cancelando = true);
                                try {
                                  final ok = await _api.cancelarViaje(
                                    idViaje: widget.idViaje,
                                    idUsuario: idUsuario!,
                                    tipo: 'pasajero',
                                  );
                                  if (!ok) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Error al cancelar el viaje'),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('Error al cancelar: $e');
                                } finally {
                                  if (mounted) setState(() => _cancelando = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _cancelando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Cancelar viaje"),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _socket.off('ubicacion_en_tiempo_real');
    _socket.off('conductor_llego_encuentro');
    _socket.off('viaje_en_curso');
    _socket.off('viaje_finalizado');
    _socket.off('viaje_cancelado');
    super.dispose();
  }
}
