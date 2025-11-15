// lib/screens/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart'; // <- ya casi no se usa, puedes quitarlo si quieres
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_tuc/screens/perfil/viajes_screen.dart';

import '../../services/socket_service.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/perfil/perfil_screen.dart';
import '../../services/api_service.dart';
import '../../screens/home/widgets/completar_datos_screen.dart';
import '../../screens/home/iniciar_viaje_screen.dart';
import '../../services/user_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final apiKey = dotenv.env['GOOGLE_API_KEY'];
final _BASE_URL = dotenv.env['API_URL'];

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SocketService _socket = SocketService.instance;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() async {
    try {
      await _socket.connect();
      debugPrint('🔌 Conectando socket desde HomeScreen...');

      Future.delayed(const Duration(seconds: 1), () async {
        // Podrías usar también UserPreferences.getUser()
        final prefs = await SharedPreferences.getInstance();
        final idUsuario =
            prefs.getInt('id_usuario') ?? widget.user['id_usuario'];
        if (idUsuario != null) {
          _socket.emitirConexionUsuario(idUsuario, 'pasajero');
          debugPrint('✅ Usuario $idUsuario registrado en socket.');
          _mostrarSnack('Conectado al servidor en tiempo real.');
        }
      });

      // Escuchar eventos globales
      _socket.on('viaje_actualizado', (data) {
        debugPrint('🟡 Evento: viaje_actualizado → $data');
        _mostrarSnack('Un viaje fue actualizado.');
      });

      _socket.on('viaje_cancelado', (data) {
        debugPrint('🔴 Evento: viaje_cancelado → $data');
        _mostrarSnack('Un viaje fue cancelado.');
      });

      _socket.on('viaje_asignado', (data) {
        debugPrint('🟢 Evento: viaje_asignado → $data');
        _mostrarSnack('Se asignó un viaje a un conductor.');
      });

      _socket.on('viaje_finalizado', (data) {
        debugPrint('🏁 Evento: viaje_finalizado → $data');
        _mostrarSnack('Un viaje fue finalizado.');
      });
    } catch (e) {
      debugPrint('❌ Error al conectar socket: $e');
      _mostrarSnack('Error al conectar al servidor.');
    }
  }

  void _mostrarSnack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    // No desconectamos el socket aquí para mantenerlo global si lo usas en más pantallas
    super.dispose();
  }

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

    debugPrint('👤 Verificando perfil del usuario...');

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

  // 🔹 LOGOUT usando UserPreferences.fullLogout()
  Future<void> _logout(BuildContext context) async {
    await UserPreferences.fullLogout();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  ImageProvider getUserImage(
    BuildContext context,
    Map<String, dynamic> usuario,
  ) {
    final foto = usuario['foto_perfil'];
    final brightness = Theme.of(context).brightness;

    if (foto != null && foto.toString().isNotEmpty) {
      return NetworkImage(foto);
    } else {
      return AssetImage(
        brightness == Brightness.dark
            ? 'assets/images/user_default.png'
            : 'assets/images/user_default_blanco.png',
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
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFCC00),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      backgroundImage: getUserImage(context, user),
                    ),
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
                  MaterialPageRoute(builder: (_) => const ViajesScreen()),
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
