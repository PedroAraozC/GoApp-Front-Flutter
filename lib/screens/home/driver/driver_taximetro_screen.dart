import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart'; // Para tono del sistema
import 'package:flutter_vibrate/flutter_vibrate.dart';

class TaximetroScreen extends StatefulWidget {
  const TaximetroScreen({super.key});

  @override
  State<TaximetroScreen> createState() => _TaximetroScreenState();
}

class _TaximetroScreenState extends State<TaximetroScreen> {
  static const double bajadaDeBandera = 900.0;
  static const double valorFicha = 90.0;
  static const double metrosPorFicha = 100.0;

  bool modoPrueba = false;
  bool viajeActivo = false;

  double total = 0.0;
  double distanciaTotal = 0.0;
  double velocidadActual = 0.0;

  Stopwatch cronometro = Stopwatch();
  Timer? timer;
  StreamSubscription<Position>? posicionSub;
  Position? ultimaPosicion;

  @override
  void dispose() {
    posicionSub?.cancel();
    timer?.cancel();
    super.dispose();
  }

  Future<void> _iniciarViaje() async {
    setState(() {
      viajeActivo = true;
      total = bajadaDeBandera;
      distanciaTotal = 0.0;
      velocidadActual = 0.0;
    });

    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Por favor activá el GPS')));
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) return;
    }

    cronometro.reset();
    cronometro.start();

    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

    posicionSub =
        Geolocator.getPositionStream(
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
            _calcularTarifa();
          }
          ultimaPosicion = posicion;
          setState(() {});
        });
  }

  void _detenerViaje() {
    cronometro.stop();
    posicionSub?.cancel();
    timer?.cancel();

    final duracion = _formatearTiempo(cronometro.elapsed);
    final distanciaKm = (distanciaTotal / 1000).toStringAsFixed(2);
    final totalFinal = total.toStringAsFixed(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.local_taxi, color: Colors.redAccent, size: 60),
              const SizedBox(height: 10),
              Text(
                'VIAJE FINALIZADO',
                style: GoogleFonts.orbitron(
                  textStyle: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _datoFinal('⏱ Tiempo', duracion, Colors.white),
              const SizedBox(height: 10),
              _datoFinal('📏 Distancia', '$distanciaKm km', Colors.white),
              const SizedBox(height: 10),
              _datoFinal(
                '💰 Total',
                '\$$totalFinal',
                Colors.redAccent,
                big: true,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () async {
                  // Vibración + sonido del sistema
                  if (await Vibrate.canVibrate) {
                    Vibrate.feedback(FeedbackType.success);
                  }
                  SystemSound.play(SystemSoundType.alert);

                  Navigator.pop(context);

                  // Reiniciar valores
                  setState(() {
                    viajeActivo = false;
                    total = 0.0;
                    distanciaTotal = 0.0;
                    velocidadActual = 0.0;
                    cronometro.reset();
                  });
                },

                icon: const Icon(Icons.check_circle_outline, size: 26),
                label: const Text('Aceptar', style: TextStyle(fontSize: 20)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _calcularTarifa() {
    final fichas = (distanciaTotal ~/ metrosPorFicha);
    total = bajadaDeBandera + (fichas * valorFicha);
  }

  void _toggleModoPrueba() {
    setState(() => modoPrueba = !modoPrueba);

    if (modoPrueba) {
      Timer.periodic(const Duration(seconds: 1), (t) {
        if (!modoPrueba || !viajeActivo) {
          t.cancel();
          return;
        }
        distanciaTotal += Random().nextDouble() * 30;
        velocidadActual = 20 + Random().nextDouble() * 40;
        _calcularTarifa();
        setState(() {});
      });
    }
  }

  String _formatearTiempo(Duration d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return "${dos(d.inHours)}:${dos(d.inMinutes % 60)}:${dos(d.inSeconds % 60)}";
  }

  Widget _datoFinal(
    String label,
    String valor,
    Color color, {
    bool big = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: color,
            fontSize: big ? 32 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanciaKm = distanciaTotal / 1000;
    final tiempo = _formatearTiempo(cronometro.elapsed);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    'TAXÍMETRO',
                    style: GoogleFonts.orbitron(
                      textStyle: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    modoPrueba ? '🧪 MODO PRUEBA ACTIVADO' : 'GPS ACTIVO',
                    style: TextStyle(
                      color: modoPrueba ? Colors.amber : Colors.greenAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${velocidadActual.toStringAsFixed(1)} km/h',
                    style: GoogleFonts.orbitron(
                      textStyle: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Distancia: ${distanciaKm.toStringAsFixed(2)} km',
                    style: GoogleFonts.orbitron(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tiempo: $tiempo',
                    style: GoogleFonts.orbitron(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '\$${total.toStringAsFixed(0)}',
                    style: GoogleFonts.orbitron(
                      textStyle: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleModoPrueba,
                    icon: const Icon(Icons.science_outlined),
                    label: Text(
                      modoPrueba
                          ? 'Desactivar Modo Prueba'
                          : 'Activar Modo Prueba',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: modoPrueba
                          ? Colors.amber
                          : Colors.blueGrey[800],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: viajeActivo ? _detenerViaje : _iniciarViaje,
                    icon: Icon(viajeActivo ? Icons.flag : Icons.play_arrow),
                    label: Text(
                      viajeActivo ? 'Finalizar viaje' : 'Iniciar viaje',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: viajeActivo
                          ? Colors.greenAccent[700]
                          : Colors.redAccent[700],
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
