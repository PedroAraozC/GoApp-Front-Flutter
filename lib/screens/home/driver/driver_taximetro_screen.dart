import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../services/taximetro_service.dart';
import '../../../services/user_preferences.dart';
import '../../../services/earnings_service.dart';

class TaximetroScreen extends StatefulWidget {
  const TaximetroScreen({super.key});

  @override
  State<TaximetroScreen> createState() => _TaximetroScreenState();
}

class _TaximetroScreenState extends State<TaximetroScreen> {
  static const double bajadaDeBandera = 900.0;
  static const double valorFicha = 90.0;
  static const double metrosPorFicha = 100.0;

  final service = TaximetroService.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _timerPrueba;

  @override
  void initState() {
    super.initState();

    // Si el viaje sigue activo, reanudamos todo
    if (service.viajeActivo) {
      if (!service.cronometro.isRunning) {
        service.cronometro.start();
      }

      service.timer?.cancel();
      service.timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });

      // Reanudar seguimiento real
      service.iniciarSeguimientoDistancia();

      // Si estaba en modo prueba, reactivar también
      if (service.modoPrueba) {
        _timerPrueba = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return;
          if (!service.modoPrueba || !service.viajeActivo) {
            t.cancel();
            return;
          }

          service.distanciaTotal += Random().nextDouble() * 30;
          service.velocidadActual = 20 + Random().nextDouble() * 40;
          _calcularTarifa();
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    service.timer?.cancel();
    _timerPrueba?.cancel();
    super.dispose();
  }

  Future<void> _iniciarViaje() async {
    setState(() {
      service.viajeActivo = true;
      service.total = bajadaDeBandera;
      service.distanciaTotal = 0.0;
      service.velocidadActual = 0.0;
    });

    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      if (!mounted) return;
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

    service.cronometro.reset();
    service.cronometro.start();

    service.timer?.cancel();
    service.timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    service.iniciarSeguimientoDistancia();
  }

  void _detenerViaje() {
    service.detenerSeguimiento();

    final duracion = _formatearTiempo(service.cronometro.elapsed);
    final distanciaKm = (service.distanciaTotal / 1000).toStringAsFixed(2);
    final totalFinal = service.total.toStringAsFixed(0);

    if (!mounted) return;

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
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _datoFinal('⏱ Tiempo', duracion, Colors.white),
              _datoFinal('📏 Distancia', '$distanciaKm km', Colors.white),
              _datoFinal(
                '💰 Total',
                '\$$totalFinal',
                Colors.redAccent,
                big: true,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () async {
                  await HapticFeedback.mediumImpact();
                  SystemSound.play(SystemSoundType.alert);

                  // ✅ Guardar ingreso de viaje rápido
                  final idUsuario = await UserPreferences.getIdUsuario();
                  if (idUsuario != null) {
                    final monto = service.total; // total final del taxímetro
                    final uniqueId =
                        'rapido_${DateTime.now().millisecondsSinceEpoch}'; // ✅ único
                    await EarningsService.instance.addEarning(
                      idUsuario: idUsuario,
                      uniqueId: uniqueId,
                      idViaje: null, // no hay id de viaje en rápido (opcional)
                      monto: monto,
                      fecha: DateTime.now(),
                      tipo: EarningType.viajeRapido,
                    );
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  setState(() {
                    service.viajeActivo = false;
                    service.total = 0.0;
                    service.distanciaTotal = 0.0;
                    service.velocidadActual = 0.0;
                    service.cronometro.reset();
                  });
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Aceptar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _calcularTarifa() async {
    final fichas = (service.distanciaTotal ~/ metrosPorFicha);
    final nuevoTotal = bajadaDeBandera + (fichas * valorFicha);

    if (nuevoTotal > service.total) {
      await _audioPlayer.play(AssetSource('sounds/click.mp3'));
      await HapticFeedback.lightImpact();
    }

    if (!mounted) return;
    setState(() {
      service.total = nuevoTotal;
    });
  }

  void _toggleModoPrueba() {
    setState(() => service.modoPrueba = !service.modoPrueba);

    if (service.modoPrueba) {
      _timerPrueba?.cancel();
      _timerPrueba = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (!service.modoPrueba || !service.viajeActivo) {
          t.cancel();
          return;
        }

        service.distanciaTotal += Random().nextDouble() * 30;
        service.velocidadActual = 20 + Random().nextDouble() * 40;
        _calcularTarifa();
        if (mounted) setState(() {});
      });
    } else {
      _timerPrueba?.cancel();
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
          style: const TextStyle(color: Colors.white70, fontSize: 20),
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
    final tiempo = _formatearTiempo(service.cronometro.elapsed);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
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
            Text(
              service.modoPrueba ? '🧪 MODO PRUEBA ACTIVADO' : 'GPS ACTIVO',
              style: TextStyle(
                color: service.modoPrueba ? Colors.amber : Colors.greenAccent,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${service.velocidadActual.toStringAsFixed(1)} km/h',
                      style: GoogleFonts.orbitron(
                        textStyle: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Distancia: ${(service.distanciaTotal / 1000).toStringAsFixed(2)} km',
                      style: GoogleFonts.orbitron(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tiempo: $tiempo',
                      style: GoogleFonts.orbitron(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      '\$${service.total.toStringAsFixed(0)}',
                      style: GoogleFonts.orbitron(
                        textStyle: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleModoPrueba,
                    icon: const Icon(Icons.science_outlined, size: 30),
                    label: Text(
                      service.modoPrueba
                          ? 'Modo Prueba\nON'
                          : 'Modo Prueba\nOFF',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: service.modoPrueba
                          ? Colors.amber
                          : Colors.blueGrey[800],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 90),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: service.viajeActivo
                        ? _detenerViaje
                        : _iniciarViaje,
                    icon: Icon(
                      service.viajeActivo ? Icons.flag : Icons.play_arrow,
                      size: 36,
                    ),
                    label: Text(
                      service.viajeActivo
                          ? 'FINALIZAR\nVIAJE'
                          : 'INICIAR\nVIAJE',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: service.viajeActivo
                          ? Colors.greenAccent[700]
                          : Colors.redAccent[700],
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 90),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
