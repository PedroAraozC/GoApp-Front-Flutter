import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/user_preferences.dart';
import '../../screens/home/buscando_viaje_screen.dart';

final apiKey = dotenv.env['GOOGLE_API_KEY'];

class IniciarViajeScreen extends StatefulWidget {
  const IniciarViajeScreen({super.key});

  @override
  State<IniciarViajeScreen> createState() => _IniciarViajeScreenState();
}

class _IniciarViajeScreenState extends State<IniciarViajeScreen> {
  final SocketService _socket = SocketService.instance;
  final ApiService _api = ApiService();

  GoogleMapController? _mapCtrl;
  LatLng? _miUbicacion;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  final TextEditingController _origenCtrl = TextEditingController();
  final TextEditingController _destinoCtrl = TextEditingController();
  final FocusNode _origenFocus = FocusNode();
  final FocusNode _destinoFocus = FocusNode();

  final _uuid = const Uuid();
  Timer? _debounce;
  String? _sessionTokenOrigen;
  String? _sessionTokenDestino;
  List<_Prediction> _predOrigen = [];
  List<_Prediction> _predDestino = [];

  int _distanceMeters = 0;
  int _durationSeconds = 0;

  final double _baseFare = 900;
  final double _perKm = 900;
  final double _perMin = 90;

  double get _km => _distanceMeters / 1000;
  double get _mins => _durationSeconds / 60;
  double get _fare => _baseFare + (_km * _perKm) + (_mins * _perMin);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // ================== GEOLOCALIZACIÓN ==================
  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _msg('Activá los servicios de ubicación.');
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.deniedForever) {
        _msg('Permiso de ubicación denegado permanentemente.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _miUbicacion = LatLng(pos.latitude, pos.longitude);

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
        localeIdentifier: "es_AR",
      );
      final direccion = placemarks.isNotEmpty
          ? _formatDireccion(placemarks.first)
          : '${pos.latitude}, ${pos.longitude}';

      setState(() {
        _origenCtrl.text = direccion;
        _setOrigen(_miUbicacion!, direccion);
      });

      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_miUbicacion!, 15));
      debugPrint('📍 Ubicación actual establecida: $direccion');
    } catch (e) {
      debugPrint('❌ Error obteniendo ubicación: $e');
    }
  }

  // ================== MARCADORES ==================
  Marker? _getMarker(String id) {
    try {
      return _markers.firstWhere((m) => m.markerId.value == id);
    } catch (_) {
      return null;
    }
  }

  Marker? get _origenMarker => _getMarker('origen');
  Marker? get _destinoMarker => _getMarker('destino');

  void _setOrigen(LatLng pos, String etiqueta) {
    final marker = Marker(
      markerId: const MarkerId('origen'),
      position: pos,
      draggable: false,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      infoWindow: InfoWindow(title: 'Origen', snippet: etiqueta),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'origen');
      _markers.add(marker);
    });
  }

  void _setDestino(LatLng pos, String etiqueta) {
    final marker = Marker(
      markerId: const MarkerId('destino'),
      position: pos,
      draggable: false,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: 'Destino', snippet: etiqueta),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'destino');
      _markers.add(marker);
    });
  }

  // ================== AUTOCOMPLETE ==================
  void _onChangedAutocomplete({
    required String value,
    required bool esOrigen,
  }) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().length < 3) return;
      final token = esOrigen
          ? (_sessionTokenOrigen ??= _uuid.v4())
          : (_sessionTokenDestino ??= _uuid.v4());
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(value)}'
        '&language=es&key=$apiKey&sessiontoken=$token&components=country:ar',
      );
      final resp = await http.get(url);
      final data = json.decode(resp.body);
      if (data['status'] != 'OK') return;
      final preds = (data['predictions'] as List)
          .map((p) => _Prediction.fromJson(p))
          .toList();

      setState(() {
        if (esOrigen) {
          _predOrigen = preds;
        } else {
          _predDestino = preds;
        }
      });
    });
  }

  Future<void> _selectPrediction(_Prediction p, {required bool esOrigen}) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${p.placeId}&fields=geometry/location&key=$apiKey',
    );
    final resp = await http.get(url);
    final data = json.decode(resp.body);
    final loc = data['result']?['geometry']?['location'];
    if (loc == null) return;
    final ll = LatLng(loc['lat'], loc['lng']);
    final desc = p.description ?? '${ll.latitude}, ${ll.longitude}';

    if (esOrigen) {
      _setOrigen(ll, desc);
      _origenCtrl.text = desc;
      _predOrigen.clear();
    } else {
      _setDestino(ll, desc);
      _destinoCtrl.text = desc;
      _predDestino.clear();
    }

    await _construirRutaSiPosible();
  }

  // ================== RUTA ==================
  Future<void> _construirRutaSiPosible() async {
    final origen = _origenMarker;
    final destino = _destinoMarker;
    if (origen == null || destino == null) return;

    final polyPoints = PolylinePoints();
    final result = await polyPoints.getRouteBetweenCoordinates(
      googleApiKey: apiKey!,
      request: PolylineRequest(
        origin: PointLatLng(
          origen.position.latitude,
          origen.position.longitude,
        ),
        destination: PointLatLng(
          destino.position.latitude,
          destino.position.longitude,
        ),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isEmpty) return;
    final pts = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final polyline = Polyline(
      polylineId: const PolylineId('ruta'),
      color: Colors.blue,
      width: 5,
      points: pts,
    );

    await _fetchDistanceMatrix(origen.position, destino.position);
    setState(() => _polylines..clear()..add(polyline));
  }

  Future<void> _fetchDistanceMatrix(LatLng o, LatLng d) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=${o.latitude},${o.longitude}'
      '&destinations=${d.latitude},${d.longitude}'
      '&mode=driving&key=$apiKey',
    );
    final resp = await http.get(url);
    if (resp.statusCode != 200) return;
    final data = json.decode(resp.body);
    final el = data['rows'][0]['elements'][0];
    setState(() {
      _distanceMeters = el['distance']['value'];
      _durationSeconds = el['duration']['value'];
    });
  }

  // ================== CONFIRMAR VIAJE ==================
  Future<void> _confirmarViaje() async {
    try {
      final user = await UserPreferences.getUser();
      final idUsuario = user?['id_usuario'];
      if (idUsuario == null) {
        _msg('Usuario no encontrado.');
        return;
      }

      final origen = _origenMarker!.position;
      final destino = _destinoMarker!.position;
      final result = await _api.iniciarViaje(
        idUsuario: idUsuario,
        origenLat: origen.latitude,
        origenLng: origen.longitude,
        destinoLat: destino.latitude,
        destinoLng: destino.longitude,
        direccionOrigen: _origenCtrl.text.trim(),
        direccionDestino: _destinoCtrl.text.trim(),
        precioEstimado: double.parse(_fare.toStringAsFixed(2)),
        // notas: null,
      );

      final idViaje = (result?['id_viajes'] as num).toInt();
      debugPrint('🟢 Viaje iniciado con ID: $idViaje');

      _socket.emit('viaje_creado', {'id_viaje': idViaje, 'id_usuario': idUsuario});
      _mostrarSnack('Tu solicitud fue enviada.');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BuscandoViajeScreen(id_viaje: idViaje),
        ),
      );
    } catch (e) {
      _msg('Error al confirmar viaje: $e');
      debugPrint('❌ Error al confirmar viaje: $e');
    }
  }

  // ================== UTILIDADES ==================
  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  void _mostrarSnack(String mensaje) => _msg(mensaje);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar viaje')),
      body: _miUbicacion == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (ctrl) => _mapCtrl = ctrl,
                  initialCameraPosition: CameraPosition(
                    target: _miUbicacion!,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  markers: _markers,
                  polylines: _polylines,
                  onTap: (pos) async {
                    final placemarks = await placemarkFromCoordinates(
                      pos.latitude,
                      pos.longitude,
                      localeIdentifier: "es_AR",
                    );
                    final direccion = placemarks.isNotEmpty
                        ? _formatDireccion(placemarks.first)
                        : '${pos.latitude}, ${pos.longitude}';
                    _setDestino(pos, direccion);
                    _destinoCtrl.text = direccion;
                    await _construirRutaSiPosible();
                  },
                ),

                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      _SearchField(
                        hint: 'Origen',
                        controller: _origenCtrl,
                        onChanged: (v) => _onChangedAutocomplete(value: v, esOrigen: true),
                        onSearch: () {},
                        prefix: Icons.my_location,
                      ),
                      if (_predOrigen.isNotEmpty)
                        _PredictionsList(predictions: _predOrigen, onTap: (p) => _selectPrediction(p, esOrigen: true)),
                      const SizedBox(height: 8),
                      _SearchField(
                        hint: 'Destino',
                        controller: _destinoCtrl,
                        onChanged: (v) => _onChangedAutocomplete(value: v, esOrigen: false),
                        onSearch: () {},
                        prefix: Icons.place,
                      ),
                      if (_predDestino.isNotEmpty)
                        _PredictionsList(predictions: _predDestino, onTap: (p) => _selectPrediction(p, esOrigen: false)),
                    ],
                  ),
                ),

                if (_origenMarker != null && _destinoMarker != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _RideBottomSheet(
                        distanceText: '${(_km).toStringAsFixed(2)} km',
                        durationText: '${(_mins).toStringAsFixed(0)} min',
                        estimate: _fare,
                        onConfirm: _confirmarViaje,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ================== WIDGETS AUXILIARES ==================
class _SearchField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback onSearch;
  final IconData prefix;

  const _SearchField({
    required this.hint,
    required this.controller,
    required this.onSearch,
    required this.prefix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefix),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _Prediction {
  final String? description;
  final String? placeId;
  _Prediction({this.description, this.placeId});
  factory _Prediction.fromJson(Map<String, dynamic> json) => _Prediction(
        description: json['description'],
        placeId: json['place_id'],
      );
}

class _PredictionsList extends StatelessWidget {
  final List<_Prediction> predictions;
  final ValueChanged<_Prediction> onTap;
  const _PredictionsList({required this.predictions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: predictions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(predictions[i].description ?? ''),
          onTap: () => onTap(predictions[i]),
        ),
      ),
    );
  }
}

class _RideBottomSheet extends StatelessWidget {
  final String distanceText;
  final String durationText;
  final double estimate;
  final VoidCallback onConfirm;

  const _RideBottomSheet({
    required this.distanceText,
    required this.durationText,
    required this.estimate,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Duración: $durationText  •  Distancia: $distanceText'),
            const SizedBox(height: 8),
            Text(
              '\$${estimate.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.local_taxi),
              label: const Text('Confirmar viaje'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDireccion(Placemark p) {
  final calle = p.street ?? '';
  final localidad = p.locality ?? '';
  final provincia = p.administrativeArea ?? '';
  return '$calle, $localidad, $provincia';
}
