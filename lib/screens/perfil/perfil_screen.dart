// lib/screens/perfil/perfil_screen.dart
import 'package:TaxiTuc/screens/passwordRecovery/password_recovey.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/home_screen.dart';
import 'datos_screen.dart';
import 'pagos_screen.dart';
import 'viajes_screen.dart';
import 'ayuda_screen.dart';

class PerfilScreen extends StatefulWidget {
  final int? userId;
  const PerfilScreen({super.key, this.userId});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    print('aaaaaaaaaaaaaaaaaaa ${prefs.getString('nombre_usuario')}');
    final nombre = prefs.getString('nombre_usuario') ?? 'Usuario';
    final apellido = prefs.getString('apellido_usuario') ?? '';
    final foto = prefs.getString('foto_perfil');
    setState(() {
      user = {'nombre': nombre, 'apellido': apellido, 'foto': foto};
      loading = false;
    });
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              // ======= Imagen + nombre =======
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    (user?['foto'] != null &&
                        (user?['foto'] as String).isNotEmpty)
                    ? NetworkImage(user!['foto_perfil'])
                    : const NetworkImage('https://i.pravatar.cc/150?img=5'),
              ),
              const SizedBox(height: 12),
              Text(
                '${user?['nombre_usuario']} ${user?['apellido_usuario']}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Divider(),

              // ======= Opciones del menú =======
              _buildMenuItem(
                icon: Icons.person_outline,
                text: 'Mis datos personales',
                onTap: () => _navigateTo(DatosScreen(userId: widget.userId)),
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
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
