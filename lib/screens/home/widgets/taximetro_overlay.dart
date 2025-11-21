import 'dart:async';
import 'package:flutter/material.dart';
import '../../../main.dart'; // navigatorKey y routeObserver global
import '../../../services/taximetro_service.dart';
import '../driver/driver_taximetro_screen.dart';

class TaximetroOverlay extends StatefulWidget {
  const TaximetroOverlay({super.key});

  @override
  State<TaximetroOverlay> createState() => _TaximetroOverlayState();
}

class _TaximetroOverlayState extends State<TaximetroOverlay>
    with SingleTickerProviderStateMixin, RouteAware {
  final taximetro = TaximetroService.instance;
  Offset _position = const Offset(20, 600);
  bool _mostrar = false;
  AnimationController? _fadeCtrl;
  Animation<double>? _fadeAnim;
  String? _rutaActual;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl!, curve: Curves.easeInOut);

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkVisibility(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Obtenemos la ruta actual y nos suscribimos solo si es un PageRoute
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    routeObserver.unsubscribe(this);
    _fadeCtrl?.dispose();
    super.dispose();
  }

  // Se llama automáticamente cuando cambia la ruta
  @override
  void didPushNext() {
    _updateRuta();
  }

  @override
  void didPopNext() {
    _updateRuta();
  }

  void _updateRuta() {
    final route = ModalRoute.of(context);
    _rutaActual = route?.settings.name;
  }

  void _checkVisibility() {
    final currentRoute = ModalRoute.of(
      navigatorKey.currentContext ?? context,
    )?.settings.name;

    final enTaximetro = currentRoute == '/taximetro';
    final debeMostrar = taximetro.viajeActivo && !enTaximetro;

    if (mounted && debeMostrar != _mostrar) {
      setState(() => _mostrar = debeMostrar);
      if (debeMostrar) {
        _fadeCtrl?.forward();
      } else {
        _fadeCtrl?.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mostrar) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    const bubbleWidth = 150.0;
    const bubbleHeight = 60.0;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: FadeTransition(
        opacity: _fadeAnim!,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final newX = _position.dx + details.delta.dx;
              final newY = _position.dy + details.delta.dy;
              _position = Offset(
                newX.clamp(0.0, screenSize.width - bubbleWidth),
                newY.clamp(0.0, screenSize.height - bubbleHeight - 50),
              );
            });
          },
          onTap: () {
            if (_rutaActual == '/taximetro') return;
            navigatorKey.currentState?.pushNamed('/taximetro');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: bubbleWidth,
            height: bubbleHeight,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_taxi, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text(
                  '\$${taximetro.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
