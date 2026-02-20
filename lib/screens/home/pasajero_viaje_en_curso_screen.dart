import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/user_preferences.dart';

class PasajeroViajeEnCursoScreen extends StatefulWidget {
  final int idViaje;

  final double latDestino;
  final double lngDestino;

  final String direccionOrigen;
  final String direccionDestino;

  final double? latConductorInicial;
  final double? lngConductorInicial;

  const PasajeroViajeEnCursoScreen({
    super.key,
    required this.idViaje,
    required this.latDestino,
    required this.lngDestino,
    required this.direccionOrigen,
    required this.direccionDestino,
    this.latConductorInicial,
    this.lngConductorInicial,
  });

  @override
  State<PasajeroViajeEnCursoScreen> createState() =>
      _PasajeroViajeEnCursoScreenState();
}

class _PasajeroViajeEnCursoScreenState
    extends State<PasajeroViajeEnCursoScreen> {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService.instance;

  GoogleMapController? _mapCtrl;

  LatLng? _posConductor;
  late final LatLng _posDestino;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool _loading = true;
  bool _cancelando = false;

  String _distanceText = '--';
  String _durationText = '--';

  Timer? _routeDebounce;
  bool _pendingRouteUpdate = false;

  bool _endingHandled = false;

  // ✅ handlers para remover SOLO lo de esta pantalla
  Function(dynamic)? _hUbicacion;
  Function(dynamic)? _hFinalizadoWrapper;
  Function(dynamic)? _hFinalizadoDirect;
  Function(dynamic)? _hCompletadoPasajero;
  Function(dynamic)? _hCompletado; // por compat
  Function(dynamic)? _hCanceladoWrapper;
  Function(dynamic)? _hCanceladoDirect;

  @override
  void initState() {
    super.initState();

    _posDestino = LatLng(widget.latDestino, widget.lngDestino);

    if (widget.latConductorInicial != null &&
        widget.lngConductorInicial != null) {
      _posConductor = LatLng(
        widget.latConductorInicial!,
        widget.lngConductorInicial!,
      );
    }

    _actualizarMarkers();
    _initSocket();
  }

  int? _readViajeId(dynamic data) {
    try {
      if (data is! Map) return null;
      final raw = data['id_viaje'] ?? data['id_viajes'] ?? data['id'];
      if (raw == null) return null;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  double? _parseMoney(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  Future<void> _showFinalPriceDialog(double total) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Viaje finalizado'),
        content: Text(
          'Total a pagar: \$${total.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleViajeFinalizado(
    dynamic data, {
    String source = 'socket',
  }) async {
    debugPrint("🏁 [$source] viaje_finalizado -> $data");
    if (!mounted) return;
    if (_endingHandled) return;

    final idSocket = _readViajeId(data);
    if (idSocket != null && idSocket != widget.idViaje) {
      debugPrint(
        'ℹ️ [$source] finalizado de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
      );
      return;
    }

    _endingHandled = true;

    final m = (data is Map) ? data : const <String, dynamic>{};

    final total =
        (_parseMoney(m['precio_final']) ??
                _parseMoney(m['precio_pactado']) ??
                _parseMoney(m['precio_estimado']) ??
                _parseMoney(m['valor']) ??
                0.0)
            .toDouble();

    await _showFinalPriceDialog(total);

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _handleViajeCancelado(dynamic data, {String source = 'socket'}) {
    debugPrint("❌ [$source] viaje_cancelado -> $data");
    if (!mounted) return;
    if (_endingHandled) return;

    final idSocket = _readViajeId(data);
    if (idSocket != null && idSocket != widget.idViaje) {
      debugPrint(
        'ℹ️ [$source] cancelado de otro viaje (idSocket=$idSocket, actual=${widget.idViaje})',
      );
      return;
    }

    _endingHandled = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ El viaje fue cancelado'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Future<void> _initSocket() async {
    try {
      final idUsuario = await UserPreferences.getIdUsuario();
      if (idUsuario == null) {
        debugPrint("⚠️ id_usuario null (pasajero).");
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (!_socket.isConnected) {
        await _socket.connect();
      }

      await _socket.emitirConexionUsuario(idUsuario, 'pasajero');

      await _socket.unirseAViaje(
        idViaje: widget.idViaje,
        userId: idUsuario,
        tipo: 'pasajero',
      );

      // -------------------------
      // ✅ Ubicación conductor
      // -------------------------
      _hUbicacion = _socket.onUbicacionEnTiempoReal((data) async {
        try {
          if (!mounted) return;
          if (data == null) return;
          if (data is! Map) return;
          if (data['tipo'] != 'conductor') return;

          final lat = double.tryParse(data['lat'].toString());
          final lng = double.tryParse(data['lng'].toString());
          if (lat == null || lng == null) return;

          _posConductor = LatLng(lat, lng);

          _actualizarMarkers();
          _scheduleRouteUpdate();
        } catch (e) {
          debugPrint("❌ Error ubicacion conductor: $e");
        }
      });

      // -------------------------
      // ✅ FINALIZADO (wrapper + directos/alias)
      // -------------------------
      _hFinalizadoWrapper = _socket.onViajeFinalizado(
        (data) =>
            _handleViajeFinalizado(data, source: 'wrapper:onViajeFinalizado'),
      );

      _hFinalizadoDirect = _socket.on(
        'viaje_finalizado',
        (data) =>
            _handleViajeFinalizado(data, source: 'socket:viaje_finalizado'),
      );

      // si alguna vez lo emitís así
      _hCompletadoPasajero = _socket.on(
        'viaje_completado_pasajero',
        (data) => _handleViajeFinalizado(
          data,
          source: 'socket:viaje_completado_pasajero',
        ),
      );

      // compat extra (por si tu server manda "viaje_completado")
      _hCompletado = _socket.on(
        'viaje_completado',
        (data) =>
            _handleViajeFinalizado(data, source: 'socket:viaje_completado'),
      );

      // -------------------------
      // ✅ CANCELADO (wrapper + directo)
      // -------------------------
      _hCanceladoWrapper = _socket.onViajeCancelado(
        (data) =>
            _handleViajeCancelado(data, source: 'wrapper:onViajeCancelado'),
      );

      _hCanceladoDirect = _socket.on(
        'viaje_cancelado',
        (data) => _handleViajeCancelado(data, source: 'socket:viaje_cancelado'),
      );

      if (_posConductor != null) {
        await _drawRoute();
        _fitToBounds();
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('❌ _initSocket error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleRouteUpdate() {
    _pendingRouteUpdate = true;
    _routeDebounce ??= Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!_pendingRouteUpdate) return;
      _pendingRouteUpdate = false;
      await _drawRoute();
      _fitToBounds();
    });
  }

  void _actualizarMarkers() {
    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('destino'),
        position: _posDestino,
        infoWindow: const InfoWindow(title: 'Destino'),
      ),
    );

    if (_posConductor != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: _posConductor!,
          infoWindow: const InfoWindow(title: 'Conductor'),
        ),
      );
    }

    if (!mounted) return;
    setState(() => _markers = markers);
  }

  Future<void> _drawRoute() async {
    if (_posConductor == null) return;

    try {
      final apiKey = dotenv.env['GOOGLE_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) return;

      final origin = '${_posConductor!.latitude},${_posConductor!.longitude}';
      final dest = '${_posDestino.latitude},${_posDestino.longitude}';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin&destination=$dest&key=$apiKey',
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) return;

      final jsonData = json.decode(resp.body);
      final routes = jsonData['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final leg = routes[0]['legs'][0];
      final distance = leg['distance']?['text']?.toString() ?? '--';
      final duration = leg['duration']?['text']?.toString() ?? '--';

      final points = routes[0]['overview_polyline']?['points'];
      if (points == null) return;

      final decoded = _decodePolyline(points.toString());

      if (!mounted) return;
      setState(() {
        _distanceText = distance;
        _durationText = duration;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: decoded,
            width: 6,
          ),
        };
      });
    } catch (e) {
      debugPrint('❌ Error _drawRoute(): $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  void _fitToBounds() {
    if (_mapCtrl == null) return;
    if (_posConductor == null) return;

    final a = _posConductor!;
    final b = _posDestino;

    final sw = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final ne = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );

    _mapCtrl!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        80,
      ),
    );
  }

  Future<void> _cancelarViaje() async {
    if (_cancelando) return;
    setState(() => _cancelando = true);

    try {
      final idUsuario = await UserPreferences.getIdUsuario();
      if (idUsuario == null) return;

      final ok = await _api.cancelarViaje(
        idViaje: widget.idViaje,
        idUsuario: idUsuario,
        tipo: 'pasajero',
      );

      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cancelar el viaje')),
        );
      }
    } catch (e) {
      debugPrint('❌ Cancelar viaje error: $e');
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  void dispose() {
    _routeDebounce?.cancel();

    // ✅ remover SOLO listeners de esta pantalla
    _socket.off('ubicacion_en_tiempo_real', _hUbicacion);

    _socket.off('viaje_finalizado', _hFinalizadoWrapper);
    _socket.off('viaje_finalizado', _hFinalizadoDirect);
    _socket.off('viaje_completado_pasajero', _hCompletadoPasajero);
    _socket.off('viaje_completado', _hCompletado);

    _socket.off('viaje_cancelado', _hCanceladoWrapper);
    _socket.off('viaje_cancelado', _hCanceladoDirect);

    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viaje en curso')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _posConductor ?? _posDestino,
                      zoom: 15,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: (c) {
                      _mapCtrl = c;
                      _fitToBounds();
                    },
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place_outlined),
                              const SizedBox(width: 8),
                              Expanded(child: Text(widget.direccionOrigen)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.flag_outlined),
                              const SizedBox(width: 8),
                              Expanded(child: Text(widget.direccionDestino)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.route_outlined),
                              const SizedBox(width: 8),
                              Text('Distancia: $_distanceText'),
                              const SizedBox(width: 14),
                              Text('Tiempo: $_durationText'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _cancelando ? null : _cancelarViaje,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _cancelando
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("Cancelar viaje"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
