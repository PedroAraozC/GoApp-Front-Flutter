// homescreen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:TaxiTuc/screens/perfil/perfil_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:TaxiTuc/screens/auth/auth_screen2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildActionCard({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color? bg,
      Color? fg,
      bool filled = false,
    }) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: bg ?? Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: filled ? (fg ?? cs.onPrimary) : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: filled ? (bg ?? cs.primary) : cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: fg ?? Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: (fg ?? Theme.of(context).colorScheme.onSurface)
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PerfilScreen(userId: user['id_usuario'] as int?),
                  ),
                );
              },
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      'Mi cuenta',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: NetworkImage(
                      user['foto_perfil'] ?? 'https://i.pravatar.cc/150?img=12',
                    ),
                    child: Container(),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;

            final content = <Widget>[
              Text(
                '¿Qué querés hacer hoy?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Podés iniciar un viaje nuevo o consultar tu historial.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              buildActionCard(
                icon: Icons.play_arrow_rounded,
                title: 'Iniciar viaje',
                subtitle: 'Configura origen, destino y comenzá',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IniciarViajeScreen()),
                ),
                bg: cs.primary,
                fg: cs.onPrimary,
                filled: true,
              ),

              buildActionCard(
                icon: Icons.history_rounded,
                title: 'Viajes realizados',
                subtitle: 'Mirá tu historial y detalles',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ViajesRealizadosScreen(),
                  ),
                ),
              ),
            ];

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: isWide
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...content.take(3),
                            Row(
                              children: [
                                Expanded(child: content[3]),
                                const SizedBox(width: 16),
                                Expanded(child: content[4]),
                              ],
                            ),
                          ],
                        )
                      : ListView.separated(
                          itemCount: content.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => content[i],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Limpia prefs (por si almacenás flags/tokens)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Desloguea Google si hubo sesión
      final g = GoogleSignIn(scopes: ['email', 'profile']);
      await g.signOut();
      await g.disconnect();
    } catch (_) {
      // Ignorar errores silenciosamente
    }

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen2()),
        (_) => false,
      );
    }
  }
}

/* =================== Iniciar Viaje (mapa + origen auto + autocomplete origen/destino + ruta + ETA + costo + conductor) =================== */
class IniciarViajeScreen extends StatefulWidget {
  const IniciarViajeScreen({super.key});
  @override
  State<IniciarViajeScreen> createState() => _IniciarViajeScreenState();
}

class _IniciarViajeScreenState extends State<IniciarViajeScreen> {
  // ⚠️ Habilitar: Maps SDK, Places API, Directions API, Distance Matrix API
  static const String kGoogleApiKey = 'AIzaSyAMP0ERTGQgCvTRknlbE7wA01WSvRtGHV4';

  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();

  final FocusNode _origenFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  GoogleMapController? _mapCtrl;
  LatLng? _miUbicacion;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  int _durationSeconds = 0;
  int _distanceMeters = 0;
  String _durationText = '';
  String _distanceText = '';
  bool get _routeReady => _durationSeconds > 0 && _distanceMeters > 0;

  // Costeo (simple)
  final double _baseFare = 300;
  final double _perKm = 150;
  final double _perMin = 20;
  double _surge = 1.0;

  double get _km => _distanceMeters / 1000.0;
  double get _mins => _durationSeconds / 60.0;
  double get _fare =>
      ((_baseFare + (_km * _perKm) + (_mins * _perMin)) * _surge);

  // Conductores (mock)
  final List<_Driver> _drivers = const [
    _Driver(
      name: 'Luis R.',
      rating: 4.9,
      car: 'Toyota Etios',
      etaMin: 3,
      multiplier: 1.0,
    ),
    _Driver(
      name: 'María S.',
      rating: 4.8,
      car: 'Chevrolet Onix',
      etaMin: 4,
      multiplier: 1.1,
    ),
    _Driver(
      name: 'Jorge A.',
      rating: 4.7,
      car: 'VW Gol',
      etaMin: 6,
      multiplier: 0.95,
    ),
  ];
  _Driver? _selectedDriver;

  // ======= Autocomplete REST (dos campos) =======
  final _uuid = const Uuid();
  Timer? _debounce;

  String? _sessionTokenOrigin;
  String? _sessionTokenDest;

  List<_Prediction> _predOrigen = [];
  List<_Prediction> _predDestino = [];

  bool get _hasBothMarkers => _origenMarker != null && _destinoMarker != null;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _mapCtrl?.dispose();
    _debounce?.cancel();
    _origenFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  // ======= GPS: fija ORIGEN automáticamente =======
  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _msg('Activá los servicios de ubicación.');
      return;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      _msg('Permiso de ubicación denegado.');
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _miUbicacion = LatLng(pos.latitude, pos.longitude);

    String direccion = '';
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
        localeIdentifier: "es_AR",
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        direccion =
            "${p.street ?? ''} ${p.subThoroughfare ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
      }
    } catch (e) {
      direccion =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      debugPrint('Error obteniendo dirección: $e');
    }

    final origen = Marker(
      markerId: const MarkerId('origen'),
      position: _miUbicacion!,
      infoWindow: const InfoWindow(title: 'Origen', snippet: 'Mi ubicación'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'origen');
      _markers.add(origen);
      _origenCtrl.text = direccion;
      _polylines.clear();
      _durationSeconds = 0;
      _distanceMeters = 0;
      _durationText = '';
      _distanceText = '';
      _selectedDriver = null;

      _predOrigen = [];
      _predDestino = [];
      _sessionTokenOrigin = null;
      _sessionTokenDest = null;
    });

    await Future.delayed(const Duration(milliseconds: 150));
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_miUbicacion!, 15));
  }

  // ======= Util =======
  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _dialog(String t, String c) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t),
        content: Text(c),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Marker? _getMarker(String id) {
    try {
      return _markers.firstWhere((m) => m.markerId.value == id);
    } catch (_) {
      return null;
    }
  }

  Marker? get _origenMarker => _getMarker('origen');
  Marker? get _destinoMarker => _getMarker('destino');

  // ======= Buscar por texto (fallback, usa geocoding) =======
  Future<void> _buscarYMarcar({
    required String texto,
    required bool esOrigen,
  }) async {
    if (texto.trim().isEmpty) {
      _dialog('Aviso', 'Debes ingresar una dirección');
      return;
    }
    try {
      final r = await locationFromAddress(texto);
      if (r.isEmpty) {
        _msg('No se encontró la dirección.');
        return;
      }
      final ll = LatLng(r.first.latitude, r.first.longitude);
      if (esOrigen) {
        _setOrigen(ll, texto);
        if (_destinoMarker != null) await _construirRutaSiPosible();
      } else {
        _setDestino(ll, texto);
        await _construirRutaSiPosible();
      }
    } catch (e) {
      _msg('Error buscando la dirección: $e');
    }
  }

  void _setOrigen(LatLng pos, String etiqueta) {
    final origen = Marker(
      markerId: const MarkerId('origen'),
      position: pos,
      infoWindow: InfoWindow(title: 'Origen', snippet: etiqueta),
      draggable: true, // 🟢 Permitir arrastrar
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      onDragEnd: (newPos) async {
        // Cuando se suelta el pin, actualizar dirección
        try {
          final placemarks = await placemarkFromCoordinates(
            newPos.latitude,
            newPos.longitude,
            localeIdentifier: "es_AR",
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final nuevaDir =
                "${p.street ?? ''} ${p.subThoroughfare ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
            setState(() {
              _origenCtrl.text = nuevaDir;
            });
            _msg('Origen actualizado a: $nuevaDir');
          }
        } catch (e) {
          _msg('Error al actualizar dirección: $e');
        }

        // Actualizar posición del marcador en el mapa
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'origen');
          _markers.add(
            Marker(
              markerId: const MarkerId('origen'),
              position: newPos,
              draggable: true,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueCyan,
              ),
              infoWindow: const InfoWindow(title: 'Origen'),
            ),
          );
        });
      },
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'origen');
      _markers.add(origen);
      _origenCtrl.text = etiqueta;
      _polylines.clear();
      _durationSeconds = 0;
      _distanceMeters = 0;
      _durationText = '';
      _distanceText = '';
      _selectedDriver = null;
    });

    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
  }

  void _setDestino(LatLng pos, String etiqueta) {
    final destino = Marker(
      markerId: const MarkerId('destino'),
      position: pos,
      infoWindow: InfoWindow(title: 'Destino', snippet: etiqueta),
      draggable: true, // 🟢 Ahora también se puede mover
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      onDragEnd: (newPos) async {
        final placemarks = await placemarkFromCoordinates(
          newPos.latitude,
          newPos.longitude,
          localeIdentifier: "es_AR",
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final nuevaDir =
              "${p.street ?? ''} ${p.subThoroughfare ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
          setState(() {
            _destinoCtrl.text = nuevaDir;
          });
          await _construirRutaSiPosible();
        }
      },
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'destino');
      _markers.add(destino);
      _destinoCtrl.text = etiqueta;
    });
  }

  // ======= Ruta + ETA =======
  Future<void> _construirRutaSiPosible() async {
    final origen = _origenMarker;
    final destino = _destinoMarker;
    if (origen == null || destino == null) return;

    try {
      final polylinePoints = PolylinePoints();
      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: kGoogleApiKey,
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

      if (result.errorMessage?.isNotEmpty == true) {
        _msg('Directions error: ${result.errorMessage}');
      }
      if (result.points.isEmpty) {
        _msg('No se pudo obtener la ruta');
        return;
      }

      final pts = result.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      final polyline = Polyline(
        polylineId: const PolylineId('ruta'),
        points: pts,
        width: 6,
        color: Theme.of(context).colorScheme.primary,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      );

      await _fetchDistanceMatrix(
        origin: origen.position,
        destination: destino.position,
      );

      setState(() {
        _polylines
          ..clear()
          ..add(polyline);
      });

      await _ajustarCamaraAOrigenDestino(origen.position, destino.position);
    } catch (e) {
      _msg('Error solicitando ruta: $e');
    }
  }

  Future<void> _fetchDistanceMatrix({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=${origin.latitude},${origin.longitude}'
      '&destinations=${destination.latitude},${destination.longitude}'
      '&mode=driving&units=metric&key=$kGoogleApiKey',
    );
    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      _msg('Error Distance Matrix: ${resp.statusCode}');
      return;
    }
    final data = json.decode(resp.body);
    final rows = data['rows'] as List?;
    if (rows == null || rows.isEmpty) return;
    final elements = rows.first['elements'] as List?;
    if (elements == null || elements.isEmpty) return;

    final el = elements.first;
    if (el['status'] != 'OK') {
      _msg('Distance Matrix no disponible (status: ${el['status']}).');
      return;
    }

    setState(() {
      _distanceMeters = (el['distance']?['value'] ?? 0) as int;
      _durationSeconds = (el['duration']?['value'] ?? 0) as int;
      _distanceText = (el['distance']?['text'] ?? '') as String;
      _durationText = (el['duration']?['text'] ?? '') as String;
      _surge = _distanceMeters > 10000 ? 1.2 : 1.0;
      _selectedDriver ??= _drivers.first;
    });
  }

  Future<void> _ajustarCamaraAOrigenDestino(LatLng o, LatLng d) async {
    if (_mapCtrl == null) return;
    final sw = LatLng(
      min(o.latitude, d.latitude),
      min(o.longitude, d.longitude),
    );
    final ne = LatLng(
      max(o.latitude, d.latitude),
      max(o.longitude, d.longitude),
    );
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  // ======= AUTOCOMPLETE REST (reutilizable) =======
  void _onChangedAutocomplete({required String value, required bool esOrigen}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().length < 3) {
        setState(() {
          if (esOrigen) {
            _predOrigen = [];
          } else {
            _predDestino = [];
          }
        });
        return;
      }

      // token de session por campo
      if (esOrigen) {
        _sessionTokenOrigin ??= _uuid.v4();
      } else {
        _sessionTokenDest ??= _uuid.v4();
      }

      try {
        final lat = _miUbicacion?.latitude;
        final lng = _miUbicacion?.longitude;

        final token = esOrigen ? _sessionTokenOrigin : _sessionTokenDest;

        final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(value)}'
          '&language=es'
          '&key=$kGoogleApiKey'
          '&sessiontoken=$token'
          // Sesgo por país (ajustá si querés)
          '&components=country:ar'
          // Bias por ubicación del usuario (opcional)
          '${lat != null && lng != null ? '&location=$lat,$lng&radius=30000' : ''}',
        );

        final resp = await http.get(uri);
        if (resp.statusCode != 200) {
          _msg('Autocomplete error: ${resp.statusCode}');
          return;
        }
        final data = json.decode(resp.body);
        if ((data['status'] ?? '') == 'REQUEST_DENIED') {
          _msg('Autocomplete denegado: revisá tu API Key y habilitaciones.');
          return;
        }
        final preds =
            (data['predictions'] as List?)
                ?.map((p) => _Prediction.fromJson(p))
                .toList() ??
            [];

        setState(() {
          if (esOrigen) {
            _predOrigen = preds;
          } else {
            _predDestino = preds;
          }
        });
      } catch (e) {
        _msg('Autocomplete error: $e');
      }
    });
  }

  Future<void> _selectPrediction(
    _Prediction p, {
    required bool esOrigen,
  }) async {
    try {
      if (p.placeId == null) return;
      final token = esOrigen ? _sessionTokenOrigin : _sessionTokenDest;

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${Uri.encodeComponent(p.placeId!)}'
        '&fields=geometry/location'
        '&language=es'
        '&key=$kGoogleApiKey'
        '${token != null ? '&sessiontoken=$token' : ''}',
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        _msg('Place Details error: ${resp.statusCode}');
        return;
      }
      final data = json.decode(resp.body);
      final loc = data['result']?['geometry']?['location'];
      if (loc == null) {
        _msg('No se pudo obtener ubicación del lugar');
        return;
      }
      final ll = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );

      setState(() {
        if (esOrigen) {
          _predOrigen = [];
          _sessionTokenOrigin = null;
          _origenFocus.unfocus();
        } else {
          _predDestino = [];
          _sessionTokenDest = null;
          _destFocus.unfocus();
        }
      });

      if (esOrigen) {
        _setOrigen(ll, p.description ?? '${ll.latitude}, ${ll.longitude}');
        if (_destinoMarker != null) await _construirRutaSiPosible();
      } else {
        _setDestino(ll, p.description ?? '${ll.latitude}, ${ll.longitude}');
        await _construirRutaSiPosible();
      }
    } catch (e) {
      _msg('Error al seleccionar lugar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar viaje'),
        actions: [
          IconButton(
            tooltip: 'Limpiar',
            onPressed: () {
              setState(() {
                _markers.clear();
                _polylines.clear();
                _origenCtrl.clear();
                _destinoCtrl.clear();
                _durationSeconds = 0;
                _distanceMeters = 0;
                _durationText = '';
                _distanceText = '';
                _selectedDriver = null;
                _surge = 1.0;

                _predOrigen = [];
                _predDestino = [];
                _sessionTokenOrigin = null;
                _sessionTokenDest = null;
              });
              _initLocation();
            },
            icon: const Icon(Icons.layers_clear),
          ),
        ],
      ),
      backgroundColor: cs.surface,
      body: _miUbicacion == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  key: const ValueKey('mapa_unico'),
                  initialCameraPosition: CameraPosition(
                    target: _miUbicacion!,
                    zoom: 15,
                  ),
                  onMapCreated: (c) => _mapCtrl ??= c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  markers: _markers,
                  polylines: _polylines,
                  onTap: (latLng) async {
                    // Si hay listas abiertas, las cierro; si no, seteo destino por tap.
                    if (_predOrigen.isNotEmpty || _predDestino.isNotEmpty) {
                      setState(() {
                        _predOrigen = [];
                        _predDestino = [];
                      });
                    } else {
                      _setDestino(
                        latLng,
                        '${latLng.latitude}, ${latLng.longitude}',
                      );
                      await _construirRutaSiPosible();
                    }
                  },
                ),

                // ======= Controles de búsqueda + listas =======
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      // ORIGEN
                      _SearchField(
                        hint: 'Origen (por defecto: mi ubicación)',
                        controller: _origenCtrl,
                        onSearch: () => _buscarYMarcar(
                          texto: _origenCtrl.text,
                          esOrigen: true,
                        ),
                        prefix: Icons.my_location,
                        onChanged: (v) =>
                            _onChangedAutocomplete(value: v, esOrigen: true),
                        focusNode: _origenFocus,
                      ),
                      if (_predOrigen.isNotEmpty)
                        _PredictionsList(
                          predictions: _predOrigen,
                          onTap: (p) => _selectPrediction(p, esOrigen: true),
                        ),
                      const SizedBox(height: 8),

                      // DESTINO
                      _SearchField(
                        hint: 'Buscar Destino',
                        controller: _destinoCtrl,
                        onSearch: () => _buscarYMarcar(
                          texto: _destinoCtrl.text,
                          esOrigen: false,
                        ),
                        prefix: Icons.place,
                        onChanged: (v) =>
                            _onChangedAutocomplete(value: v, esOrigen: false),
                        focusNode: _destFocus,
                      ),
                      if (_predDestino.isNotEmpty)
                        _PredictionsList(
                          predictions: _predDestino,
                          onTap: (p) => _selectPrediction(p, esOrigen: false),
                        ),
                    ],
                  ),
                ),

                // ======= Panel inferior (ETA + costo + conductor) =======
                if (_hasBothMarkers)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _RideBottomSheet(
                        distanceText: _routeReady ? _distanceText : '—',
                        durationText: _routeReady ? _durationText : '—',
                        baseFare: _baseFare,
                        perKm: _perKm,
                        perMin: _perMin,
                        km: _routeReady ? _km : 0,
                        minutes: _routeReady ? _mins : 0,
                        surge: _surge,
                        drivers: _drivers,
                        selected: _selectedDriver,
                        onSurgeChanged: (v) => setState(() => _surge = v),
                        onSelectDriver: (d) =>
                            setState(() => _selectedDriver = d),
                        onConfirm: () {
                          final total =
                              _fare * (_selectedDriver?.multiplier ?? 1.0);
                          _msg(
                            '¡Viaje solicitado! Conductor: ${_selectedDriver?.name ?? "—"}  •  Estimado: \$${total.toStringAsFixed(0)}',
                          );
                        },
                        estimate: _routeReady
                            ? _fare * (_selectedDriver?.multiplier ?? 1.0)
                            : _baseFare,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/* =================== Viajes realizados =================== */
class ViajesRealizadosScreen extends StatelessWidget {
  const ViajesRealizadosScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viajes realizados')),
      body: const Center(
        child: Text('Lista de viajes realizados (historial).'),
      ),
    );
  }
}

/* =================== Cuenta =================== */
// class CuentaScreen extends StatelessWidget {
//   const CuentaScreen({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Scaffold(
//       appBar: AppBar(title: const Text('Información de cuenta')),
//       body: Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 520),
//           child: Card(
//             elevation: 1,
//             color: cs.surface,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: const Padding(
//               padding: EdgeInsets.all(20),
//               child: Row(
//                 children: [
//                   CircleAvatar(
//                     radius: 36,
//                     backgroundImage: NetworkImage(
//                       'https://i.pravatar.cc/150?img=12',
//                     ),
//                   ),
//                   SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Braian Barrionuevo',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                         SizedBox(height: 4),
//                         Text('braian@example.com'),
//                         SizedBox(height: 12),
//                         Text('Estado: Verificado ✅'),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

/* =================== Widgets auxiliares =================== */
class _SearchField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final VoidCallback onSearch;
  final IconData? prefix;

  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  const _SearchField({
    required this.hint,
    required this.controller,
    required this.onSearch,
    this.prefix,
    this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            focusNode: focusNode,
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: prefix != null ? Icon(prefix) : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: cs.surface,
            ),
            onSubmitted: (_) => onSearch(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          width: 44,
          child: IconButton.filled(
            onPressed: onSearch,
            icon: const Icon(Icons.search),
          ),
        ),
      ],
    );
  }
}

class _PredictionsList extends StatelessWidget {
  final List<_Prediction> predictions;
  final ValueChanged<_Prediction> onTap;
  const _PredictionsList({required this.predictions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: predictions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final p = predictions[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined),
            title: Text(p.mainText ?? p.description ?? ''),
            subtitle: Text(p.secondaryText ?? ''),
            onTap: () => onTap(p),
          );
        },
      ),
    );
  }
}

/* =================== Panel con costo y conductor =================== */
class _RideBottomSheet extends StatelessWidget {
  final String distanceText;
  final String durationText;
  final double baseFare;
  final double perKm;
  final double perMin;
  final double km;
  final double minutes;
  final double surge;
  final List<_Driver> drivers;
  final _Driver? selected;
  final ValueChanged<double> onSurgeChanged;
  final ValueChanged<_Driver> onSelectDriver;
  final VoidCallback onConfirm;
  final double estimate;

  const _RideBottomSheet({
    required this.distanceText,
    required this.durationText,
    required this.baseFare,
    required this.perKm,
    required this.perMin,
    required this.km,
    required this.minutes,
    required this.surge,
    required this.drivers,
    required this.selected,
    required this.onSurgeChanged,
    required this.onSelectDriver,
    required this.onConfirm,
    required this.estimate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  durationText.isEmpty ? '—' : durationText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.route, color: cs.primary),
                const SizedBox(width: 6),
                Text(distanceText.isEmpty ? '—' : distanceText),
                const Spacer(),
                Text(
                  '\$${estimate.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Base \$${baseFare.toStringAsFixed(0)}  •  '
                    '${km.toStringAsFixed(2)} km x \$${perKm.toStringAsFixed(0)}  •  '
                    '${minutes.toStringAsFixed(0)} min x \$${perMin.toStringAsFixed(0)}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Demanda (x):'),
                const SizedBox(width: 8),
                DropdownButton<double>(
                  value: surge,
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('1.0')),
                    DropdownMenuItem(value: 1.1, child: Text('1.1')),
                    DropdownMenuItem(value: 1.2, child: Text('1.2')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5')),
                  ],
                  onChanged: (v) {
                    if (v != null) onSurgeChanged(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Conductor:'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<_Driver>(
                    isExpanded: true,
                    value: selected,
                    hint: const Text('Elegí un conductor'),
                    items: drivers
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Row(
                              children: [
                                const Icon(Icons.person),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${d.name}  •  ${d.car}  •  ⭐ ${d.rating}  •  ${d.etaMin} min',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (d) {
                      if (d != null) onSelectDriver(d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.local_taxi),
                label: const Text('Confirmar viaje'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =================== Modelos =================== */
class _Driver {
  final String name;
  final double rating;
  final String car;
  final int etaMin;
  final double multiplier;
  const _Driver({
    required this.name,
    required this.rating,
    required this.car,
    required this.etaMin,
    required this.multiplier,
  });
}

class _Prediction {
  final String? description;
  final String? placeId;
  final String? mainText;
  final String? secondaryText;

  _Prediction({
    this.description,
    this.placeId,
    this.mainText,
    this.secondaryText,
  });

  factory _Prediction.fromJson(Map<String, dynamic> json) {
    final sf = json['structured_formatting'] as Map<String, dynamic>?;
    return _Prediction(
      description: json['description'] as String?,
      placeId: json['place_id'] as String?,
      mainText: sf?['main_text'] as String?,
      secondaryText: sf?['secondary_text'] as String?,
    );
  }
}
