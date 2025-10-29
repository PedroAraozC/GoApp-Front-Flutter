import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../perfil/perfil_screen.dart';
import '../../services/perfil_services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '/screens/auth/auth_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/socket_service.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GoogleMapController mapController;
  final Completer<GoogleMapController> _controller = Completer();
  final SocketService _socket = SocketService();
  late LatLng _currentPosition;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _inicializarSocket();
    _obtenerUbicacionActual();
  }

  Future<void> _inicializarSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario') ?? widget.user['id_usuario'];
    final tipoUsuario =
        'pasajero'; // Podés hacerlo dinámico luego (conductor/pasajero)

    _socket.connect();
    _socket.emitirConexionUsuario(idUsuario, tipoUsuario);

    // Escuchar todos los eventos de viaje para debug
    _socket.socket.on('viaje_creado', (data) {
      debugPrint('🆕 viaje_creado: $data');
      _mostrarSnackBar('Nuevo viaje creado');
    });

    _socket.socket.on('viaje_asignado', (data) {
      debugPrint('🚕 viaje_asignado: $data');
      _mostrarSnackBar('Viaje asignado a un conductor');
    });

    _socket.socket.on('viaje_en_curso', (data) {
      debugPrint('▶️ viaje_en_curso: $data');
      _mostrarSnackBar('Tu viaje está en curso');
    });

    _socket.socket.on('viaje_finalizado', (data) {
      debugPrint('🏁 viaje_finalizado: $data');
      _mostrarSnackBar('Tu viaje ha finalizado');
    });

    _socket.socket.on('viaje_cancelado', (data) {
      debugPrint('❌ viaje_cancelado: $data');
      _mostrarSnackBar('Tu viaje fue cancelado');
    });
  }

  Future<void> _obtenerUbicacionActual() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _isMapReady = true;
    });
  }

  void _mostrarSnackBar(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    // No desconectamos el socket aquí porque debe mantenerse activo
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GoApp Taxi'),
        backgroundColor: cs.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
            },
          ),
        ],
      ),
      body: _isMapReady
          ? GoogleMap(
              onMapCreated: (controller) {
                _controller.complete(controller);
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        backgroundColor: cs.primary,
        onPressed: _centrarEnUbicacion,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Future<void> _centrarEnUbicacion() async {
    if (!_isMapReady) return;
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition, zoom: 16),
      ),
    );
  }
}
