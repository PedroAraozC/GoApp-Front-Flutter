// lib/screens/perfil/perfil_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/socket_service.dart';
import '../../services/perfil_services.dart';
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

  Future<void> _cargarPerfil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = widget.userId ?? prefs.getInt('id_usuario');

      if (idUsuario == null) {
        debugPrint('⚠️ No se encontró id_usuario');
        setState(() => _loading = false);
        return;
      }

      // Conectar socket si no está conectado
      if (!_socket.isConnected) {
        _socket.connect();
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // Registrar usuario en el socket
      _socket.emitirConexionUsuario(idUsuario, 'pasajero');
      debugPrint(
        '🧍 Usuario $idUsuario registrado en socket desde PerfilScreen',
      );

      // Obtener datos desde el backend
      final perfil = await _perfilService.obtenerPerfil(idUsuario);

      if (perfil != null && perfil.isNotEmpty) {
        debugPrint('✅ Perfil obtenido del backend: $perfil');
        setState(() {
          _usuario = perfil;
          _loading = false;
        });
      } else {
        debugPrint('⚠️ No se obtuvo perfil, cargando desde prefs');
        _usuario = {
          'nombre_usuario': prefs.getString('nombre_usuario') ?? '',
          'apellido_usuario': prefs.getString('apellido_usuario') ?? '',
          'dni': prefs.getString('dni') ?? '',
          'telefono_usuario': prefs.getString('telefono_usuario') ?? '',
          'email_usuario': prefs.getString('email_usuario') ?? '',
          'fecha_nacimiento': prefs.getString('fecha_nacimiento') ?? '',
          'foto_perfil': prefs.getString('foto_perfil'),
        };
        setState(() => _loading = false);
      }
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
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getInt('id_usuario');

      if (idUsuario != null) {
        _socket.emit('usuario_desconectado', {'id_usuario': idUsuario});
        debugPrint('📤 Emitido evento usuario_desconectado → $idUsuario');
      }

      await prefs.clear();
      _socket.disconnect();

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
    final ImageProvider fotoPerfil =
        (usuario['foto_perfil'] != null &&
            (usuario['foto_perfil'] as String).isNotEmpty)
        ? NetworkImage(usuario['foto_perfil'])
        : const AssetImage('assets/images/user_default.png');

    final nombre = usuario['nombre_usuario'] ?? 'Usuario';
    final apellido = usuario['apellido_usuario'] ?? '';
    final email = usuario['email_usuario'] ?? '';

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
              // 📸 Avatar
              Container(
                padding: const EdgeInsets.all(3), // espacio para el borde
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFCC00)
                        : const Color(0xFFFFCC00),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors
                            .white // fondo blanco para modo oscuro
                      : Colors.black, // fondo negro para modo claro
                  backgroundImage: getUserImage(context, usuario),
                ),
              ),

              const SizedBox(height: 12),

              // 👤 Nombre
              Text(
                '$apellido $nombre',
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

              // const SizedBox(height: 24),
              // const Divider(),

              // // 🔹 Datos principales (lectura rápida)
              // _buildInfoRow(Icons.badge, 'DNI', usuario['dni'] ?? '-'),
              // _buildInfoRow(
              //   Icons.phone,
              //   'Teléfono',
              //   usuario['telefono_usuario'] ?? usuario['telefono'] ?? '-',
              // ),
              // _buildInfoRow(
              //   Icons.cake,
              //   'Nacimiento',
              //   usuario['fecha_nacimiento'] ?? '-',
              // ),
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
                      userId: widget.userId,
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

  // // 🔹 Helpers visuales
  // Widget _buildInfoRow(IconData icon, String label, dynamic value) {
  //   // Convierte automáticamente cualquier valor a texto seguro
  //   final displayValue = (value == null || value.toString().trim().isEmpty)
  //       ? '-'
  //       : value.toString();

  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 6.0),
  //     child: Row(
  //       children: [
  //         Icon(icon, color: Colors.grey[700]),
  //         const SizedBox(width: 10),
  //         Expanded(
  //           child: Text(
  //             label,
  //             style: const TextStyle(fontWeight: FontWeight.bold),
  //           ),
  //         ),
  //         Flexible(
  //           child: Text(
  //             displayValue,
  //             overflow: TextOverflow.ellipsis,
  //             maxLines: 1,
  //             style: const TextStyle(fontSize: 15),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
      return NetworkImage(foto);
    } else {
      return AssetImage(
        brightness == Brightness.dark
            ? 'assets/images/user_default.png' // fondo blanco
            : 'assets/images/user_default_blanco.png', // fondo oscuro
      );
    }
  }
}
