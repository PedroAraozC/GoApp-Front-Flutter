import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../perfil/services/perfil_services.dart';
import 'datos_screen.dart';
import 'pagos_screen.dart';
import 'viajes_screen.dart';
import 'ayuda_screen.dart';
import '../passwordRecovery/password_recovey.dart';

class PerfilScreen extends StatefulWidget {
  final int? userId;
  final Map<String, dynamic>? initialUser;
  const PerfilScreen({super.key, this.userId, this.initialUser});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    user = widget.initialUser; //
    _fetchUserFromBackend();
  }

  Future<void> _fetchUserFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getInt('id_usuario');
      final token = prefs.getString('token');

      if (idUsuario == null || token == null) {
        debugPrint('❌ No hay datos guardados en SharedPreferences');
        setState(() => loading = false);
        return;
      }

      final service = PerfilService();
      final data = await service.obtenerUsuarioPorId(idUsuario);

      debugPrint('📦 Usuario obtenido del backend: $data');

      if (data != null) {
        setState(() {
          user = data;
          loading = false;
        });
      } else {
        debugPrint('⚠️ Usuario no encontrado en backend');
        setState(() => loading = false);
      }
    } catch (e) {
      debugPrint('❌ Error al cargar usuario: $e');
      setState(() => loading = false);
    }
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final foto =
        (user?['foto_perfil'] != null &&
            (user?['foto_perfil'] as String).isNotEmpty)
        ? NetworkImage(user!['foto_perfil'])
        : const NetworkImage('https://i.pravatar.cc/150?img=5');

    final nombre = user?['nombre_usuario'] ?? 'Usuario';
    final apellido = user?['apellido_usuario'] ?? 'Apellido';
    final email = user?['email_usuario'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(radius: 50, backgroundImage: foto),
              const SizedBox(height: 12),
              Text(
                '$apellido $nombre',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (email.isNotEmpty)
                Text(email, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              const Divider(),

              _buildMenuItem(
                icon: Icons.person_outline,
                text: 'Mis datos personales',
                onTap: () => _navigateTo(
                  DatosScreen(userId: user?['id_usuario'], initialUser: user),
                ),
              ),
              _buildMenuItem(
                icon: Icons.history_rounded,
                text: 'Mis viajes',
                onTap: () => _navigateTo(const ViajesScreen()),
              ),
              _buildMenuItem(
                icon: Icons.credit_card,
                text: 'Métodos de pago',
                onTap: () => _navigateTo(const PagosScreen()),
              ),
              _buildMenuItem(
                icon: Icons.lock_outline,
                text: 'Cambiar contraseña',
                onTap: () => _navigateTo(const RecuperarPasswordScreen()),
              ),
              _buildMenuItem(
                icon: Icons.help_outline,
                text: 'Ayuda',
                onTap: () => _navigateTo(const AyudaScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
