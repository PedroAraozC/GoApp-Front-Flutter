import 'package:flutter/material.dart';
import '/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BuscandoViajeScreen extends StatefulWidget {
  const BuscandoViajeScreen({super.key});

  @override
  State<BuscandoViajeScreen> createState() => _BuscandoViajeScreenState();
}

class _BuscandoViajeScreenState extends State<BuscandoViajeScreen> {
  final SocketService _socket = SocketService();
  bool _viajeAsignado = false;
  bool _viajeCancelado = false;
  bool _viajeEnCurso = false;

  @override
  void initState() {
    super.initState();
    _inicializarSocketListeners();
  }

  void _inicializarSocketListeners() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario');

    // Solo para confirmar que el socket está conectado
    if (!_socket.isConnected) {
      _socket.connect();
      if (idUsuario != null) {
        _socket.emitirConexionUsuario(idUsuario, 'pasajero');
      }
    }

    // 🆕 Viaje creado (por el mismo pasajero o backend)
    _socket.socket.on('viaje_creado', (data) {
      debugPrint('🆕 Evento: viaje_creado -> $data');
      _mostrarSnack('Tu solicitud fue enviada');
    });

    // 🚕 Conductor asignado
    _socket.socket.on('viaje_asignado', (data) {
      debugPrint('🚕 Evento: viaje_asignado -> $data');
      if (mounted) {
        setState(() => _viajeAsignado = true);
      }
      _mostrarSnack('¡Un conductor fue asignado a tu viaje!');
      // 🔜 Acá más adelante podrías navegar a la pantalla de viaje en curso
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ViajeEnCursoScreen(data)));
    });

    // ▶️ Viaje comenzó
    _socket.socket.on('viaje_en_curso', (data) {
      debugPrint('▶️ Evento: viaje_en_curso -> $data');
      if (mounted) {
        setState(() => _viajeEnCurso = true);
      }
      _mostrarSnack('Tu viaje ha comenzado');
    });

    // 🏁 Viaje finalizado
    _socket.socket.on('viaje_finalizado', (data) {
      debugPrint('🏁 Evento: viaje_finalizado -> $data');
      _mostrarSnack('Tu viaje ha finalizado. ¡Gracias por usar GoApp!');
      if (mounted) {
        setState(() {
          _viajeEnCurso = false;
          _viajeAsignado = false;
        });
      }
    });

    // ❌ Viaje cancelado
    _socket.socket.on('viaje_cancelado', (data) {
      debugPrint('❌ Evento: viaje_cancelado -> $data');
      if (mounted) {
        setState(() => _viajeCancelado = true);
      }
      _mostrarSnack('Tu viaje fue cancelado');
      // 🔜 Más adelante podrías volver automáticamente al mapa
      // Navigator.pop(context);
    });
  }

  void _mostrarSnack(String mensaje) {
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
    // ⚠️ No desconectamos el socket aquí para mantener la conexión global viva
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String estadoActual = 'Buscando conductor...';
    if (_viajeAsignado) estadoActual = 'Conductor asignado 🚕';
    if (_viajeEnCurso) estadoActual = 'Viaje en curso ▶️';
    if (_viajeCancelado) estadoActual = 'Viaje cancelado ❌';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Buscando viaje'),
        backgroundColor: Colors.amber[700],
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 20),
            Text(
              estadoActual,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                _socket.send('viaje_cancelado', {
                  'motivo': 'cancelado_por_usuario',
                });
                _mostrarSnack('Cancelando viaje...');
              },
              icon: const Icon(Icons.cancel),
              label: const Text('Cancelar viaje'),
            ),
          ],
        ),
      ),
    );
  }
}
