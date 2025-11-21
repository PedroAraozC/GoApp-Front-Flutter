import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/carnet_service.dart'; // 👈 Importamos el nuevo servicio

class CarnetDigitalScreen extends StatefulWidget {
  const CarnetDigitalScreen({super.key});

  @override
  State<CarnetDigitalScreen> createState() => _CarnetDigitalScreenState();
}

class _CarnetDigitalScreenState extends State<CarnetDigitalScreen> {
  // 👇 Usamos CarnetService en lugar de ApiService
  final CarnetService _carnetService = CarnetService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _carnetData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('id_usuario');

    if (idUsuario == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se encontró sesión de conductor.';
      });
      return;
    }

    // 👇 Llamada real al servicio nuevo (Descomentar cuando el back esté listo)
    // final datos = await _carnetService.obtenerDatosCarnet(idUsuario);

    // ⚠️ MOCK DATA: Para probar diseño
    await Future.delayed(const Duration(seconds: 1)); 
    final datos = {
      'nombre': 'Juan',
      'apellido': 'Pérez',
      'foto_url': 'https://i.pravatar.cc/300',
      'patente': 'AA 123 BB',
      'modelo_vehiculo': 'Fiat Cronos Drive 1.3',
      'color_vehiculo': 'Blanco',
      'rating': 4.8,
      'viajes_totales': 1240,
      'fecha_ingreso': '12/03/2023',
      'verificado': true,
    };

    if (mounted) {
      setState(() {
        _carnetData = datos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Carnet Digital'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      _buildCarnetCard(),
                      const SizedBox(height: 30),
                      const Text(
                        'Muestre este carnet a las autoridades\no al pasajero si es requerido.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Compartir Datos de Viaje'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(200, 45),
                        ),
                        onPressed: () {
                          // Lógica para compartir
                        },
                      )
                    ],
                  ),
                ),
    );
  }

  Widget _buildCarnetCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 10),
          )
        ],
        gradient: const LinearGradient(
          colors: [Color(0xFF2C2C2C), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decoración de fondo
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.local_taxi,
              size: 150,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Logo y Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_taxi, color: Colors.amber, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'TaxiTuc',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    if (_carnetData!['verificado'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'VERIFICADO',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // Foto y Rating
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundImage: NetworkImage(_carnetData!['foto_url']),
                        onBackgroundImageError: (_, __) => const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_carnetData!['nombre']} ${_carnetData!['apellido']}'.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${_carnetData!['rating']}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' (${_carnetData!['viajes_totales']} viajes)',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Miembro desde: ${_carnetData!['fecha_ingreso']}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),

                // Info Vehículo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn('VEHÍCULO', _carnetData!['modelo_vehiculo']),
                    _buildInfoColumn('PATENTE', _carnetData!['patente']),
                    _buildInfoColumn('COLOR', _carnetData!['color_vehiculo']),
                  ],
                ),

                const SizedBox(height: 24),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2, size: 100, color: Colors.black87),
                      const Text(
                        'Escanear para validar',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}