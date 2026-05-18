// lib/screens/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
// <- ya casi no se usa, puedes quitarlo si quieres
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_tuc/screens/perfil/viajes_screen.dart';

import '../../services/socket_service.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/perfil/perfil_screen.dart';
import '../../services/api_service.dart';
import '../../screens/home/widgets/completar_datos_screen.dart';
import '../../screens/home/iniciar_viaje_screen.dart';
import '../../screens/home/buscando_viaje_screen.dart';
import '../../screens/home/pasajero_viaje_en_curso_screen.dart';
import '../../screens/home/viaje_asignado_screen.dart';
import '../../services/user_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final apiKey = dotenv.env['GOOGLE_API_KEY'];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      verificarViajeActivo();
    });
    _connectSocket();
  }

  final ApiService _api = ApiService();
  Map<String, dynamic>? _tarifaVigente;

  bool _loadingTarifa = false;

  Future<Map<String, dynamic>?> _getTarifaVigente() async {
    if (_tarifaVigente != null) return _tarifaVigente;

    setState(() => _loadingTarifa = true);
    final t = await _api.obtenerTarifaVigente();
    if (!mounted) return null;

    setState(() {
      _tarifaVigente = t;
      _loadingTarifa = false;
    });

    return t;
  }

  void _connectSocket() async {
    try {
      await _socket.connect();
      debugPrint('🔌 Conectando socket desde HomeScreen...');

      Future.delayed(const Duration(seconds: 1), () async {
        final prefs = await SharedPreferences.getInstance();

        final dynamic rawId =
            prefs.getInt('id_usuario') ?? widget.user['id_usuario'];
        final int? idUsuario = (rawId is int) ? rawId : int.tryParse('$rawId');

        debugPrint('👤 [Home] idUsuario raw=$rawId -> int=$idUsuario');

        if (idUsuario != null) {
          try {
            await _socket.emitirConexionUsuario(idUsuario, 'pasajero');
            debugPrint('✅ [Home] Usuario $idUsuario registrado en socket.');
            _mostrarSnack('Conectado al servidor en tiempo real.');
          } catch (e) {
            debugPrint('❌ [Home] Error registrando usuario en socket: $e');
          }
        } else {
          debugPrint('⚠️ [Home] No hay id_usuario válido para registrar.');
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

  Future<void> verificarViajeActivo() async {
    try {
      final int? idUsuario = _toInt(widget.user['id_usuario']);

      if (idUsuario == null) {
        debugPrint("❌ No hay id_usuario");
        return;
      }

      debugPrint("🔎 Verificando viaje activo pasajero...");

      final viaje = await _api.obtenerViajeActivo(
        idUsuario: idUsuario,
        tipo: 'pasajero',
      );

      if (viaje == null) {
        debugPrint("✅ No hay viaje activo");
        return;
      }

      debugPrint("🚕 Viaje activo recuperado: $viaje");

      final estado = int.tryParse('${viaje['id_estado']}') ?? 0;

      final idViaje = int.tryParse('${viaje['id_viajes']}') ?? 0;

      final idConductor = int.tryParse('${viaje['id_conductor']}') ?? 0;

      final direccionOrigen = '${viaje['direccion_desde'] ?? ''}';

      final direccionDestino = '${viaje['direccion_hasta'] ?? ''}';

      final latDestino = double.tryParse('${viaje['lat_hasta'] ?? 0}') ?? 0;

      final lngDestino = double.tryParse('${viaje['lon_hasta'] ?? 0}') ?? 0;

      final latOrigen = double.tryParse('${viaje['lat_desde'] ?? 0}') ?? 0;

      final lngOrigen = double.tryParse('${viaje['lon_desde'] ?? 0}') ?? 0;

      final precioFinal = double.tryParse('${viaje['precio_final'] ?? 0}') ?? 0;

      // ✅ Re-unirse al room del viaje
      _socket.emit('join_viaje', {
        'id_viaje': idViaje,
        'user_id': idUsuario,
        'tipo': 'pasajero',
      });

      if (!mounted) return;

      // =========================
      // BUSCANDO CONDUCTOR
      // =========================
      if (estado == 5) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BuscandoViajeScreen(
              idViaje: idViaje,
              direccionOrigen: direccionOrigen,
              direccionDestino: direccionDestino,
            ),
          ),
        );
        return;
      }

      // =========================
      // ASIGNADO / EN CAMINO
      // =========================
      if (estado == 1 || estado == 6 || estado == 7) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ViajeAsignadoScreen(
              idViaje: idViaje,
              direccionOrigen: direccionOrigen,
              direccionDestino: direccionDestino,
              latOrigen: latOrigen,
              lngOrigen: lngOrigen,
              latDestino: latDestino,
              lngDestino: lngDestino,
              precioFinal: precioFinal,
            ),
          ),
        );
        return;
      }

      // =========================
      // VIAJE EN CURSO
      // =========================
      if (estado == 2) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PasajeroViajeEnCursoScreen(
              idViaje: idViaje,
              idConductor: idConductor,
              latDestino: latDestino,
              lngDestino: lngDestino,
              direccionOrigen: direccionOrigen,
              direccionDestino: direccionDestino,
            ),
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint("❌ verificarViajeActivo: $e");
    }
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

    // DNI puede venir con diferentes claves
    if (isEmptyVal(u['dni'] ?? u['dni_usuario'])) return true;

    // Fecha
    if (isEmptyVal(u['fecha_nacimiento'] ?? u['fechaNacimiento'])) return true;

    // Género
    int? genero = u['id_genero'] is int
        ? u['id_genero']
        : int.tryParse('${u['id_genero'] ?? ''}');
    if (genero == null || genero == 0) return true;

    // Teléfono – considerar ambas claves
    if (isEmptyVal(u['telefono'] ?? u['telefono_usuario'])) return true;

    // Email – considerar ambas claves
    if (isEmptyVal(u['email'] ?? u['email_usuario'])) return true;

    return false;
  }

  Future<void> _checkUserProfileAndNavigate(BuildContext context) async {
    final api = ApiService();

    // 1) Normalizamos lo que vino por parámetro en HomeScreen
    final localNormalized = _normalizeUser(widget.user);
    debugPrint('👤 [Home] user recibido (normalizado): $localNormalized');

    int? id = localNormalized['id_usuario'] is int
        ? localNormalized['id_usuario'] as int
        : int.tryParse('${localNormalized['id_usuario'] ?? ''}');

    // 2) Si no hay id_usuario en widget.user, intentamos sacar de SharedPreferences
    if (id == null) {
      final prefs = await SharedPreferences.getInstance();
      final idPrefs = prefs.getInt('id_usuario');
      if (idPrefs != null) {
        id = idPrefs;
        debugPrint(
          '📥 [Home] id_usuario tomado de SharedPreferences: $idPrefs',
        );
      }
    }
    final tarifa = await api.obtenerTarifaVigente();

    if (tarifa == null) {
      _mostrarSnack('No hay tarifa vigente. Contactá soporte.');
      return;
    }
    // 3) Si aun así no tenemos id → solo podemos trabajar con lo local
    if (id == null) {
      debugPrint('⚠️ [Home] No hay id_usuario. Uso solo datos locales.');
      if (_needsProfileCompletion(localNormalized)) {
        debugPrint('📌 [Home] Perfil incompleto (sin id). Abriendo modal...');
        await _openCompletarDatos(localNormalized, api);
        return;
      } else {
        debugPrint(
          '✅ [Home] Perfil OK (sin id pero con datos). Navegando a IniciarViaje...',
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IniciarViajeScreen(tarifaVigente: tarifa),
          ),
        );
        return;
      }
    }

    // 4) Ya tenemos id_usuario → traemos SIEMPRE lo más fresco del backend
    debugPrint(
      '🔄 [Home] Obteniendo usuario fresco del backend para id=$id...',
    );
    final freshFromApi = await api.obtenerUsuarioPorId(id);

    debugPrint('📡 [Home] Respuesta obtenerUsuarioPorId: $freshFromApi');

    // Mezclamos: primero local, luego lo del backend (lo del backend pisa a local)
    final merged = {...localNormalized, ...?freshFromApi};
    final userFresh = _normalizeUser(merged);

    debugPrint('✨ [Home] userFresh (normalizado tras merge): $userFresh');

    // Guardamos lo más actualizado en UserPreferences
    await UserPreferences.saveUser(userFresh);

    // 5) Verificamos si necesita completar perfil
    if (_needsProfileCompletion(userFresh)) {
      debugPrint('📌 [Home] Perfil incompleto. Abriendo CompletarDatos...');
      final updated = await _openCompletarDatos(userFresh, api);

      // Si el usuario guardó, volvemos a pedir al backend para asegurarnos
      if (updated == true) {
        debugPrint(
          '✅ [Home] Usuario guardó datos en modal. Re-cargando desde backend...',
        );
        final fresh2 = await api.obtenerUsuarioPorId(id);
        debugPrint('📡 [Home] obtenerUsuarioPorId (post-guardar): $fresh2');

        final merged2 = {...userFresh, ...?fresh2};
        final userFresh2 = _normalizeUser(merged2);

        await UserPreferences.saveUser(userFresh2);
        debugPrint('✨ [Home] userFresh2 final: $userFresh2');

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IniciarViajeScreen(tarifaVigente: tarifa),
          ),
        );
      }
      // Si canceló, simplemente no hacemos nada más
      return;
    }

    // 6) Perfil ya está completo → traigo tarifa vigente y voy a iniciar viaje
    debugPrint('✅ [Home] Perfil completo. Obteniendo tarifa vigente...');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IniciarViajeScreen(
          // 👇 si tu pantalla aún no recibe esto, te indico abajo cómo
          tarifaVigente: tarifa,
        ),
      ),
    );
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
