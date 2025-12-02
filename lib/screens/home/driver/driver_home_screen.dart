import 'package:flutter/material.dart';
import 'package:taxi_tuc/screens/carnet_conductor/carnet_digital_screen.dart';
import 'driver_map_screen.dart'; // Importa tu antigua pantalla (ahora mapa)
//import '../carnet_conductor/carnet_digital_screen.dart'; // Asegúrate de tener esta ruta correcta
//import 'package:taxi_tuc/screens/carnet_conductor/carnet_digital_screen.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos los colores base para mantener consistencia
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Conductor'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Sección de Resumen Rápido (Opcional, pero útil)
          _buildHeaderSummary(context),
          
          const SizedBox(height: 20),
          
          // Grilla de Opciones
          Expanded(
            child: GridView.count(
              crossAxisCount: 2, // 2 columnas
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _DashboardCard(
                  icon: Icons.history,
                  title: 'Historial Viajes',
                  onTap: () {
                    // Navigator.push(context, ... ir a historial);
                  },
                ),
                _DashboardCard(
                  icon: Icons.monetization_on_outlined,
                  title: 'Ingresos',
                  onTap: () {
                    // Navigator.push(context, ... ir a ingresos);
                  },
                ),
                _DashboardCard(
                  icon: Icons.bar_chart,
                  title: 'Estadísticas',
                  onTap: () {
                    // Navigator.push(context, ... ir a estadísticas);
                  },
                ),
                _DashboardCard(
                  icon: Icons.person,
                  title: 'Mi Perfil',
                  onTap: () {
                    // Navigator.push(context, ... ir a perfil);
                  },
                ),
                _DashboardCard(
                  icon: Icons.badge_outlined,
                  title: 'Carnet Digital',
                  onTap: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CarnetDigitalScreen()),
                    );
                  },
                ),
                _DashboardCard(
                  icon: Icons.settings,
                  title: 'Configuración',
                  onTap: () {
                    // Navigator.push(context, ... ir a configuración);
                  },
                ),
              ],
            ),
          ),
          
          // Botón para "Ponerse Activo"
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                )
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                // Navegar a la pantalla del mapa (Tu antiguo DriverHomeScreen)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverMapScreen()),
                );
              },
              icon: const Icon(Icons.power_settings_new),
              label: const Text(
                'CONECTARSE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600], // Color de "Activo"
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSummary(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '¡Bienvenido!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Widget auxiliar para las tarjetas del menú
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}