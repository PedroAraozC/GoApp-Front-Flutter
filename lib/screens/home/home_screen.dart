// lib/screens/home/homescreen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../screens/perfil/perfil_screen.dart';
import '../../services/user_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../screens/auth/auth_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../screens/home/services/api_service.dart';
import 'widgets/completar_datos_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

// ⬇️ Usamos la pantalla separada
import 'package:taxi_tuc/screens/home/buscando_viaje_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

final apiKey = dotenv.env['GOOGLE_API_KEY'];
final _BASE_URL = dotenv.env['API_URL'];

class _HomeScreenState extends State<HomeScreen> {
  // ==============================
  // Normalización y validaciones
  // ==============================

  String? _clean(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return null;
      return s;
    }
    return '$v';
  }

  int? _toInt(dynamic v) => (v is int) ? v : int.tryParse('${v ?? ''}');

  Map<String, dynamic> _normalizeUser(Map<String, dynamic>? rawIn) {
    final raw = {...?rawIn};
    return {
      'id_usuario': raw['id_usuario'] ?? raw['id'] ?? raw['userId'],
      'dni': _clean(raw['dni'] ?? raw['dni_usuario'] ?? raw['documento']),
      'fecha_nacimiento': _clean(
        raw['fecha_nacimiento'] ??
            raw['fechaNacimiento'] ??
            raw['fecha_nac'] ??
            raw['fechaNacimiento_usuario'],
      ),
      'id_genero': _toInt(
        raw['id_genero'] ?? raw['genero_id'] ?? raw['idGenero'],
      ),
      'telefono': _clean(
        raw['telefono'] ?? raw['telefono_usuario'] ?? raw['tel'],
      ),
      'email': _clean(raw['email'] ?? raw['email_usuario']),
      'foto_perfil':
          raw['foto_perfil'] ?? raw['avatar'] ?? raw['imagen_perfil'],
      'nombre_usuario': raw['nombre_usuario'] ?? raw['nombre'],
      'apellido_usuario': raw['apellido_usuario'] ?? raw['apellido'],
      'token': raw['token'],
    };
  }

  bool _needsProfileCompletion(Map<String, dynamic> u) {
    bool isEmptyVal(v) {
      if (v == null) return true;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s.isEmpty || s == 'null';
      }
      return false;
    }

    if (isEmptyVal(u['dni'])) return true;
    if (isEmptyVal(u['fecha_nacimiento'])) return true;
    int? g = u['id_genero'] is int
        ? u['id_genero']
        : int.tryParse('${u['id_genero'] ?? ''}');
    if (g == null || g == 0) return true;
    if (isEmptyVal(u['telefono'])) return true;
    if (isEmptyVal(u['email'])) return true;
    return false;
  }

  Future<void> _checkUserProfileAndNavigate(BuildContext context) async {
    final api = ApiService();
    final local = _normalizeUser(widget.user);

    final id = local['id_usuario'];
    if (id == null) {
      if (_needsProfileCompletion(local)) {
        await _openCompletarDatos(local, api);
        return;
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IniciarViajeScreen()),
        );
      }
      return;
    }

    final fresh = await api.obtenerUsuarioPorId(id);
    final userFresh = _normalizeUser({...local, ...?fresh});
    await UserPreferences.saveUser(userFresh);

    if (_needsProfileCompletion(userFresh)) {
      final updated = await _openCompletarDatos(userFresh, api);
      if (updated == true && mounted) {
        final fresh2 = await api.obtenerUsuarioPorId(id);
        final userFresh2 = _normalizeUser({...?fresh2, ...userFresh});
        await UserPreferences.saveUser(userFresh2);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IniciarViajeScreen()),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IniciarViajeScreen()),
      );
    }
  }

  Future<bool?> _openCompletarDatos(Map<String, dynamic> user, ApiService api) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompletarDatosScreen(user: user, api: api),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await UserPreferences.clearUser();
      final g = GoogleSignIn(scopes: ['email', 'profile']);
      await g.signOut();
      await g.disconnect();
    } catch (_) {}
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    }
  }

  // ==============================
  // UI
  // ==============================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = _normalizeUser(widget.user);

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
                              .withValues(alpha: 0.7),
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
                    builder: (_) => PerfilScreen(
                      userId: user['id_usuario'] as int?,
                      initialUser: user,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  const Padding(padding: EdgeInsets.only(right: 8)),
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
                'Podés iniciar un viaje nuevo o revisar tus viajes anteriores.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              buildActionCard(
                icon: Icons.play_arrow_rounded,
                title: 'Iniciar viaje',
                subtitle: 'Configura origen, destino y comenzá',
                onTap: () => _checkUserProfileAndNavigate(context),
                bg: cs.primary,
                fg: cs.onPrimary,
                filled: true,
              ),
              buildActionCard(
                icon: Icons.history_rounded,
                title: 'Mis viajes',
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
}

/// =================================================================================
///  Iniciar Viaje (sin elegir conductor ni demanda; guarda en backend y muestra "Buscando")
/// =================================================================================
class IniciarViajeScreen extends StatefulWidget {
  const IniciarViajeScreen({super.key});
  @override
  State<IniciarViajeScreen> createState() => _IniciarViajeScreenState();
}

class _IniciarViajeScreenState extends State<IniciarViajeScreen> {
  static String kGoogleApiKey = '$apiKey';

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
  final double _baseFare = 900;
  final double _perKm = 900;
  final double _perMin = 90;

  double get _km => _distanceMeters / 1000.0;
  double get _mins => _durationSeconds / 60.0;
  double get _fare => (_baseFare + (_km * _perKm) + (_mins * _perMin));

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

  Future<BitmapDescriptor> _crearIconoNegro() async {
    final ByteData data = await rootBundle.load('assets/images/pin_origen.png');
    return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
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

    // Obtener la posición actual del usuario
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Guardar la ubicación exacta del usuario
    _miUbicacion = LatLng(pos.latitude, pos.longitude);

    // Crear el icono personalizado
    final iconoNegro = await _crearIconoNegro();

    String direccion = '';
    try {
      final placemarks = await placemarkFromCoordinates(
        _miUbicacion!.latitude,
        _miUbicacion!.longitude,
        localeIdentifier: "es_AR",
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        direccion = _formatDireccion(p);
      }
    } catch (e) {
      direccion =
          '${_miUbicacion!.latitude.toStringAsFixed(5)}, ${_miUbicacion!.longitude.toStringAsFixed(5)}';
      debugPrint('Error obteniendo dirección: $e');
    }

    // Crear el marcador en la ubicación exacta del usuario
    final origen = Marker(
      markerId: const MarkerId('origen'),
      position: _miUbicacion!,
      infoWindow: InfoWindow(
        title: 'Origen',
        snippet: direccion.isEmpty ? 'Mi ubicación' : direccion,
      ),
      icon: iconoNegro,
      anchor: const Offset(0.5, 0.5), // Centrar el pin en la ubicación exacta
      draggable: true, // Permitir arrastrar el pin
      onDragEnd: (newPos) async {
        try {
          final placemarks = await placemarkFromCoordinates(
            newPos.latitude,
            newPos.longitude,
            localeIdentifier: "es_AR",
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final nuevaDir = _formatDireccion(p);
            setState(() {
              _origenCtrl.text = nuevaDir;
            });
            _msg('Origen actualizado a: $nuevaDir');
          }
        } catch (e) {
          _msg('Error al actualizar dirección: $e');
        }

        // Actualizar el marcador con la nueva posición
        final iconoNegroActualizado = await _crearIconoNegro();
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'origen');
          _markers.add(
            Marker(
              markerId: const MarkerId('origen'),
              position: newPos,
              draggable: true,
              icon: iconoNegroActualizado,
              anchor: const Offset(0.5, 0.5),
              infoWindow: const InfoWindow(title: 'Origen'),
              onDragEnd: (nextPos) async {
                // Recursivamente manejar futuros arrastres
                try {
                  final placemarks = await placemarkFromCoordinates(
                    nextPos.latitude,
                    nextPos.longitude,
                    localeIdentifier: "es_AR",
                  );
                  if (placemarks.isNotEmpty) {
                    final p = placemarks.first;
                    final nuevaDir = _formatDireccion(p);
                    setState(() {
                      _origenCtrl.text = nuevaDir;
                    });
                    _msg('Origen actualizado a: $nuevaDir');
                  }
                } catch (e) {
                  _msg('Error al actualizar dirección: $e');
                }

                final iconoNegroFinal = await _crearIconoNegro();
                setState(() {
                  _markers.removeWhere((m) => m.markerId.value == 'origen');
                  _markers.add(
                    Marker(
                      markerId: const MarkerId('origen'),
                      position: nextPos,
                      draggable: true,
                      icon: iconoNegroFinal,
                      anchor: const Offset(0.5, 0.5),
                      infoWindow: const InfoWindow(title: 'Origen'),
                    ),
                  );
                });

                // Reconstruir ruta si hay destino
                if (_destinoMarker != null) await _construirRutaSiPosible();
              },
            ),
          );
        });

        // Reconstruir ruta si hay destino
        if (_destinoMarker != null) await _construirRutaSiPosible();
      },
    );

    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'origen');
      _markers.add(origen);
      _origenCtrl.text = direccion.isEmpty ? 'Mi ubicación' : direccion;
      _polylines.clear();
      _durationSeconds = 0;
      _distanceMeters = 0;
      _durationText = '';
      _distanceText = '';

      _predOrigen = [];
      _predDestino = [];
      _sessionTokenOrigin = null;
      _sessionTokenDest = null;
    });

    // Centrar el mapa en la ubicación del usuario
    await Future.delayed(const Duration(milliseconds: 200));
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_miUbicacion!, 16));
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
      draggable: true,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      onDragEnd: (newPos) async {
        try {
          final placemarks = await placemarkFromCoordinates(
            newPos.latitude,
            newPos.longitude,
            localeIdentifier: "es_AR",
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final nuevaDir = _formatDireccion(p);
            setState(() {
              _origenCtrl.text = nuevaDir;
            });
            _msg('Origen actualizado a: $nuevaDir');
          }
        } catch (e) {
          _msg('Error al actualizar dirección: $e');
        }

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
    });

    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
  }

  void _setDestino(LatLng pos, String etiqueta) {
    final destino = Marker(
      markerId: const MarkerId('destino'),
      position: pos,
      infoWindow: InfoWindow(title: 'Destino', snippet: etiqueta),
      draggable: true,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      onDragEnd: (newPos) async {
        final placemarks = await placemarkFromCoordinates(
          newPos.latitude,
          newPos.longitude,
          localeIdentifier: "es_AR",
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final nuevaDir = _formatDireccion(p);
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
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 280));
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
          '&components=country:ar'
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

  Future<void> _confirmarViaje() async {
    final _api = ApiService();

    if (!_hasBothMarkers) {
      _msg('Seleccioná origen y destino.');
      return;
    }

    try {
      final user = await UserPreferences.getUser();
      final int? idUsuario = user?['id_usuario'];
      if (idUsuario == null) {
        _msg('No se encontró el usuario. Iniciá sesión nuevamente.');
        return;
      }

      final o = _origenMarker!.position;
      final d = _destinoMarker!.position;
      final precioEstimado = _fare;

      final result = await _api.iniciarViaje(
        idUsuario: idUsuario,
        origenLat: o.latitude,
        origenLng: o.longitude,
        destinoLat: d.latitude,
        destinoLng: d.longitude,
        direccionOrigen: _origenCtrl.text.trim(),
        direccionDestino: _destinoCtrl.text.trim(),
        precioEstimado: double.parse(precioEstimado.toStringAsFixed(2)),
        notas: null,
      );

      final int idViaje = (result['id_viajes'] as num).toInt();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BuscandoViajeScreen(idViaje: idViaje),
        ),
      );
    } catch (e) {
      print("$e");
      _msg('Error al confirmar viaje: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar viaje')),
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
                    // cerrar predicciones si están abiertas
                    if (_predOrigen.isNotEmpty || _predDestino.isNotEmpty) {
                      setState(() {
                        _predOrigen = [];
                        _predDestino = [];
                      });
                    } else {
                      try {
                        final placemarks = await placemarkFromCoordinates(
                          latLng.latitude,
                          latLng.longitude,
                          localeIdentifier: "es_AR",
                        );

                        String direccion;
                        if (placemarks.isNotEmpty) {
                          final p = placemarks.first;
                          direccion = _formatDireccion(p);
                        } else {
                          direccion =
                              "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
                        }

                        _setDestino(latLng, direccion);
                        await _construirRutaSiPosible();
                      } catch (e) {
                        _msg("No se pudo obtener la dirección del punto: $e");
                      }
                    }
                  },
                ),

                Positioned(
                  bottom: 20,
                  left: 20,
                  child: FloatingActionButton.small(
                    heroTag: 'btn_mi_ubicacion',
                    backgroundColor: Colors.white,
                    onPressed: () async {
                      final pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                      );
                      final current = LatLng(pos.latitude, pos.longitude);
                      _mapCtrl?.animateCamera(
                        CameraUpdate.newLatLngZoom(current, 16),
                      );
                    },
                    child: const Icon(Icons.my_location, color: Colors.black87),
                  ),
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

                // ======= Panel inferior (ETA + costo + confirmar) =======
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
                        estimate: _routeReady ? _fare : _baseFare,
                        onConfirm: _confirmarViaje,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/* =================== Viajes realizados (historial) =================== */
class ViajesRealizadosScreen extends StatefulWidget {
  const ViajesRealizadosScreen({super.key});

  @override
  State<ViajesRealizadosScreen> createState() => _ViajesRealizadosScreenState();
}

class _ViajesRealizadosScreenState extends State<ViajesRealizadosScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final u = await UserPreferences.getUser();
    final int? idUsuario = u?['id_usuario'];
    if (idUsuario == null) return [];

    final api = ApiService();
    // Por defecto trae estado=finalizado; podés ajustar si querés
    final items = await api.listarViajesUsuario(
      idUsuario,
      estado: 'finalizado',
    );
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Viajes realizados')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No tenés viajes finalizados aún.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final v = items[i];
              final origen = (v['direccion_origen'] ?? '') as String;
              final destino = (v['direccion_destino'] ?? '') as String;
              final precio = (v['precio_final'] ?? v['precio_estimado'] ?? 0)
                  .toString();
              final fecha =
                  (v['fecha_fin'] ?? v['fecha_creacion'] ?? '') as String;
              final distancia = (v['distancia_km'] ?? 0).toString();
              final duracion = (v['duracion_min'] ?? 0).toString();

              return Card(
                color: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: const Icon(Icons.local_taxi),
                  ),
                  title: Text(
                    '$origen → $destino',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Fecha: $fecha\nDist: ${distancia}km  •  Dur: ${duracion}min',
                  ),
                  trailing: Text(
                    '\$$precio',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

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
            color: Colors.black.withValues(alpha: 0.08),
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

/* =================== Panel con costo y confirmar =================== */
class _RideBottomSheet extends StatelessWidget {
  final String distanceText;
  final String durationText;
  final double baseFare;
  final double perKm;
  final double perMin;
  final double km;
  final double minutes;
  final double estimate;
  final VoidCallback onConfirm;

  const _RideBottomSheet({
    required this.distanceText,
    required this.durationText,
    required this.baseFare,
    required this.perKm,
    required this.perMin,
    required this.km,
    required this.minutes,
    required this.estimate,
    required this.onConfirm,
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
            const SizedBox(height: 12),
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

String _formatDireccion(Placemark p) {
  final calle = p.street?.trim() ?? '';
  final numero = p.subThoroughfare?.trim() ?? '';

  final contieneNumero = numero.isNotEmpty && calle.contains(numero);
  final direccionBase = contieneNumero ? calle : '$calle $numero';

  final localidad = p.locality?.trim() ?? '';
  final provincia = p.administrativeArea?.trim() ?? '';

  return [
    direccionBase,
    localidad,
    provincia,
  ].where((s) => s.isNotEmpty).join(', ');
}
