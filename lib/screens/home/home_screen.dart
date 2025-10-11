// homescreen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                  MaterialPageRoute(builder: (_) => const CuentaScreen()),
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
                    backgroundImage: const NetworkImage(
                      'https://i.pravatar.cc/150?img=12',
                    ),
                    child: Container(),
                  ),
                ],
              ),
            ),
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

              // Iniciar viaje -> abre la pantalla con origen auto + ruta a destino
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
}

/* =================== Iniciar Viaje (UN mapa + origen automático + ruta a destino) =================== */
class IniciarViajeScreen extends StatefulWidget {
  const IniciarViajeScreen({super.key});
  @override
  State<IniciarViajeScreen> createState() => _IniciarViajeScreenState();
}

class _IniciarViajeScreenState extends State<IniciarViajeScreen> {
  // ⚠️ PONÉ TU API KEY DE GOOGLE AQUÍ (con Directions API habilitado)
  static const String kGoogleApiKey = 'AIzaSyAMP0ERTGQgCvTRknlbE7wA01WSvRtGHV4';

  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();

  GoogleMapController? _mapCtrl; // sin Completer
  LatLng? _miUbicacion;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

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
    super.dispose();
  }

  // ---------- Ubicación actual + seteo automático de ORIGEN ----------
  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _msg('Activá los servicios de ubicación.');
      return;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied)
      p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      _msg('Permiso de ubicación denegado.');
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _miUbicacion = LatLng(pos.latitude, pos.longitude);

    // Origen automático en mi ubicación
    final origen = Marker(
      markerId: const MarkerId('origen'),
      position: _miUbicacion!,
      infoWindow: const InfoWindow(title: 'Origen', snippet: 'Mi ubicación'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'origen');
      _markers.add(origen);
      _origenCtrl.text =
          '${_miUbicacion!.latitude}, ${_miUbicacion!.longitude}';
      _polylines.clear();
    });

    await Future.delayed(const Duration(milliseconds: 150));
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_miUbicacion!, 15));
  }

  // ---------- Utilidades ----------
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

  Marker? get _origenMarker => _markers.cast<Marker?>().firstWhere(
    (m) => m?.markerId.value == 'origen',
    orElse: () => null,
  );
  Marker? get _destinoMarker => _markers.cast<Marker?>().firstWhere(
    (m) => m?.markerId.value == 'destino',
    orElse: () => null,
  );

  // ---------- Buscar y marcar (origen/destino). Si es destino, dibuja ruta ----------
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
        // Si ya hay destino, reconstruir ruta
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
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'origen');
      _markers.add(origen);
      _origenCtrl.text = etiqueta;
      _polylines.clear();
    });
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
  }

  void _setDestino(LatLng pos, String etiqueta) {
    final destino = Marker(
      markerId: const MarkerId('destino'),
      position: pos,
      infoWindow: InfoWindow(title: 'Destino', snippet: etiqueta),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'destino');
      _markers.add(destino);
      _destinoCtrl.text = etiqueta;
    });
  }

  // ---------- Construir polyline con Directions API ----------
  Future<void> _construirRutaSiPosible() async {
    final origen = _origenMarker;
    final destino = _destinoMarker;
    if (origen == null || destino == null) return;

    final polylinePoints = PolylinePoints();
    final result = await polylinePoints.getRouteBetweenCoordinates(
      kGoogleApiKey,
      PointLatLng(origen.position.latitude, origen.position.longitude),
      PointLatLng(destino.position.latitude, destino.position.longitude),
      travelMode: TravelMode.driving,
    );

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

    setState(() {
      _polylines
        ..clear()
        ..add(polyline);
    });

    await _ajustarCamaraAOrigenDestino(origen.position, destino.position);
  }

  Future<void> _ajustarCamaraAOrigenDestino(LatLng o, LatLng d) async {
    if (_mapCtrl == null) return;
    final sw = LatLng(
      _min(o.latitude, d.latitude),
      _min(o.longitude, d.longitude),
    );
    final ne = LatLng(
      _max(o.latitude, d.latitude),
      _max(o.longitude, d.longitude),
    );
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  double _min(double a, double b) => a < b ? a : b;
  double _max(double a, double b) => a > b ? a : b;

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
              });
              _initLocation(); // vuelve a setear origen automático
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
                    // Tap rápido: setea DESTINO (origen ya es automático)
                    _setDestino(
                      latLng,
                      '${latLng.latitude}, ${latLng.longitude}',
                    );
                    await _construirRutaSiPosible();
                  },
                ),

                // Controles: origen (editable) + destino
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _SearchField(
                        hint: 'Origen (por defecto: mi ubicación)',
                        controller: _origenCtrl,
                        onSearch: () => _buscarYMarcar(
                          texto: _origenCtrl.text,
                          esOrigen: true,
                        ),
                        prefix: Icons.my_location,
                      ),
                      const SizedBox(height: 8),
                      _SearchField(
                        hint: 'Buscar Destino',
                        controller: _destinoCtrl,
                        onSearch: () => _buscarYMarcar(
                          texto: _destinoCtrl.text,
                          esOrigen: false,
                        ),
                        prefix: Icons.place,
                      ),
                    ],
                  ),
                ),

                // Confirmar
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_origenMarker == null || _destinoMarker == null) {
                        _msg('Seleccioná destino para continuar.');
                        return;
                      }
                      _msg('Ruta lista ✅');
                      // Aquí podrías navegar a confirmación o calcular precio/tiempo con Distance Matrix.
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar viaje'),
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
class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Información de cuenta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: NetworkImage(
                      'https://i.pravatar.cc/150?img=12',
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Braian Barrionuevo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('braian@example.com'),
                        SizedBox(height: 12),
                        Text('Estado: Verificado ✅'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
  const _SearchField({
    required this.hint,
    required this.controller,
    required this.onSearch,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
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
