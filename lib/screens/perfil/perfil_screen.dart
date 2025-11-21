// lib/screens/perfil/perfil_screen.dart
import 'package:flutter/material.dart';

import '../../services/socket_service.dart';
import '../../services/perfil_services.dart';
import '../../services/user_preferences.dart';

import '../auth/auth_screen.dart';
import 'datos_screen.dart';
import 'pagos_screen.dart';
import 'viajes_screen.dart';
import 'ayuda_screen.dart';
import '../password/passwordRecovery/password_recovey.dart';

class PerfilScreen extends StatefulWidget {
  final int? userId;
  final Map<String, dynamic>? initialUser;

  const PerfilScreen({super.key, this.userId, this.initialUser});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _socket = SocketService.instance;
  final _perfilService = PerfilService();

  Map<String, dynamic>? _usuario;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _cargarPerfil() async {
    try {
      // 1) Leer usuario guardado localmente (UserPreferences)
      final storedUser = await UserPreferences.getUser();

      // 2) Determinar id_usuario a usar
      final int? idUsuario =
          widget.userId ??
          _parseId(storedUser?['id_usuario']) ??
          _parseId(widget.initialUser?['id_usuario']);

      if (idUsuario == null) {
        debugPrint(
          '⚠️ No se encontró id_usuario ni en widget ni en UserPreferences',
        );
        setState(() {
          _usuario = storedUser ?? widget.initialUser ?? {};
          _loading = false;
        });
        return;
      }

      // 3) Conectar socket si hace falta y registrar pasajero
      if (!_socket.isConnected) {
        await _socket.connect();
      }
      await _socket.emitirConexionUsuario(idUsuario, 'pasajero');
      debugPrint(
        '🧍 Usuario $idUsuario registrado en socket desde PerfilScreen',
      );

      // 4) Intentar obtener perfil desde el backend
      final perfilCrudo = await _perfilService.obtenerPerfil(idUsuario);
      Map<String, dynamic>? perfilNormalizado;

      if (perfilCrudo != null) {
        // Intentar desenrollar distintas formas: {result: {...}} o {result: [ {...} ]}
        if (perfilCrudo['result'] is List &&
            (perfilCrudo['result'] as List).isNotEmpty) {
          perfilNormalizado = Map<String, dynamic>.from(
            (perfilCrudo['result'] as List).first,
          );
        } else if (perfilCrudo['result'] is Map) {
          perfilNormalizado = Map<String, dynamic>.from(
            perfilCrudo['result'] as Map,
          );
        } else        perfilNormalizado = Map<String, dynamic>.from(perfilCrudo);
      
      }

      // 5) Merge de datos: primero los locales, luego los de backend pisan
      final Map<String, dynamic> combinado = {
        if (storedUser != null) ...storedUser,
        if (widget.initialUser != null) ...widget.initialUser!,
        if (perfilNormalizado != null) ...perfilNormalizado,
      };

      debugPrint('✅ Perfil combinado para mostrar en UI: $combinado');

      if (!mounted) return;
      setState(() {
        _usuario = combinado;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error al cargar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar perfil: $e')));
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try {
      final storedUser = await UserPreferences.getUser();
      final idUsuario = _parseId(storedUser?['id_usuario']);

      if (idUsuario != null) {
        await _socket.disconnectAndNotify(
          idUsuario: idUsuario,
          tipo: 'pasajero',
        );
        debugPrint('📤 usuario_desconectado enviado para $idUsuario');
      } else {
        _socket.disconnect();
      }

      await UserPreferences.fullLogout();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } catch (e) {
      debugPrint('❌ Error al cerrar sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final usuario = _usuario ?? {};

    final nombre = (usuario['nombre_usuario'] ?? usuario['nombre'] ?? '')
        .toString();
    final apellido = (usuario['apellido_usuario'] ?? usuario['apellido'] ?? '')
        .toString();
    final email = (usuario['email_usuario'] ?? usuario['email'] ?? '')
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 📸 Avatar con borde
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFCC00),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  backgroundImage: getUserImage(context, usuario),
                ),
              ),

              const SizedBox(height: 12),

              // 👤 Nombre completo
              Text(
                ('$apellido $nombre').trim().isEmpty
                    ? 'Usuario'
                    : '$apellido $nombre',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),

              if (email.isNotEmpty)
                Text(
                  email,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),

              const SizedBox(height: 15),
              const Divider(),

              // 🔸 Opciones del menú
              _buildMenuItem(
                context,
                icon: Icons.person_outline,
                text: 'Mis datos personales',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DatosScreen(
                      userId: _parseId(usuario['id_usuario']),
                      initialUser: usuario,
                    ),
                  ),
                ),
              ),
              _buildMenuItem(
                context,
                icon: Icons.history_rounded,
                text: 'Mis viajes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViajesScreen()),
                ),
              ),
              _buildMenuItem(
                context,
                icon: Icons.credit_card,
                text: 'Métodos de pago',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PagosScreen()),
                ),
              ),
              _buildMenuItem(
                context,
                icon: Icons.lock_outline,
                text: 'Cambiar contraseña',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecuperarPasswordScreen(),
                  ),
                ),
              ),
              _buildMenuItem(
                context,
                icon: Icons.help_outline,
                text: 'Ayuda',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AyudaScreen()),
                ),
              ),

              const SizedBox(height: 30),

              // 🔻 Botón de logout
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  ImageProvider getUserImage(
    BuildContext context,
    Map<String, dynamic> usuario,
  ) {
    final foto = usuario['foto_perfil'];
    final brightness = Theme.of(context).brightness;

    if (foto != null && foto.toString().isNotEmpty) {
      return NetworkImage(foto.toString());
    } else {
      return AssetImage(
        brightness == Brightness.dark
            ? 'assets/images/user_default.png'
            : 'assets/images/user_default_blanco.png',
      );
    }
  }
}
