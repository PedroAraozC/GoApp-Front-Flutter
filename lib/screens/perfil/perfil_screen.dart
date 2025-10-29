import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_tuc/screens/auth/auth_screen.dart';
import 'package:taxi_tuc/services/socket_service.dart';
import '../../services/perfil_services.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _perfilService = PerfilService();
  final _socket = SocketService();
  Map<String, dynamic>? _usuario;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario');
    if (idUsuario != null) {
      final perfil = await _perfilService.obtenerPerfil(idUsuario);
      setState(() {
        _usuario = perfil;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getInt('id_usuario');
      if (idUsuario != null) {
        _socket.emitirDesconexionUsuario(); // 🔴 Avisamos al backend
      }

      await prefs.clear(); // 🧹 Limpiar datos guardados
      _socket.disconnect(); // 🔌 Desconectar socket

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _usuario?['foto_perfil'] != null &&
                              _usuario!['foto_perfil'].toString().isNotEmpty
                          ? NetworkImage(_usuario!['foto_perfil'])
                          : const AssetImage('assets/images/default_avatar.png')
                              as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '${_usuario?['nombre_usuario'] ?? ''} ${_usuario?['apellido_usuario'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _usuario?['email_usuario'] ?? '',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const Divider(height: 32),
                  _buildInfoRow(Icons.badge, 'DNI', _usuario?['dni'] ?? '-'),
                  _buildInfoRow(Icons.phone, 'Teléfono', _usuario?['telefono_usuario'] ?? '-'),
                  _buildInfoRow(Icons.calendar_today, 'Nacimiento',
                      _usuario?['fecha_nacimiento'] ?? '-'),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
