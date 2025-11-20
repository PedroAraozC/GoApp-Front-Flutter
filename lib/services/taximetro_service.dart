import 'dart:async';
import 'package:geolocator/geolocator.dart';

class TaximetroService {
  static final TaximetroService instance = TaximetroService._internal();
  TaximetroService._internal();

  bool viajeActivo = false;
  bool modoPrueba = false;

  double total = 0.0;
  double distanciaTotal = 0.0;
  double velocidadActual = 0.0;

  Stopwatch cronometro = Stopwatch();
  Timer? timer;
  Timer? pruebaTimer;
  StreamSubscription<Position>? posicionSub;
  Position? ultimaPosicion;

  // 🔹 Inicia el seguimiento de ubicación (global)
  void iniciarSeguimientoDistancia() {
    posicionSub?.cancel();

    posicionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((posicion) {
      if (ultimaPosicion != null && !modoPrueba) {
        final distancia = Geolocator.distanceBetween(
          ultimaPosicion!.latitude,
          ultimaPosicion!.longitude,
          posicion.latitude,
          posicion.longitude,
        );
        distanciaTotal += distancia;
        velocidadActual = posicion.speed * 3.6;
      }
      ultimaPosicion = posicion;
    });
  }

  // 🔹 Detiene todo
  void detenerSeguimiento() {
    posicionSub?.cancel();
    posicionSub = null;

    timer?.cancel();
    timer = null;

    pruebaTimer?.cancel();
    pruebaTimer = null;

    if (cronometro.isRunning) {
      cronometro.stop();
    }
  }
}
