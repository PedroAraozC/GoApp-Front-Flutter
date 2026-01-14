import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/carnet_service.dart';
import '/services/user_preferences.dart';

class CarnetDigitalScreen extends StatefulWidget {
  const CarnetDigitalScreen({super.key});

  @override
  State<CarnetDigitalScreen> createState() => _CarnetDigitalScreenState();
}

class _CarnetDigitalScreenState extends State<CarnetDigitalScreen> {
  final CarnetService _carnetService = CarnetService();

  bool _isLoading = true;
  Map<String, dynamic>? _carnetData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  int? _leerIdUsuario(SharedPreferences prefs) {
    // Probamos varias keys comunes (por si en tu login guardaste otro nombre)
    const keys = [
      'id_usuario',
      'idUsuario',
      'id_user',
      'user_id',
      'id_conductor_usuario',
    ];

    for (final k in keys) {
      final vInt = prefs.getInt(k);
      if (vInt != null) return vInt;

      final vStr = prefs.getString(k);
      if (vStr != null) {
        final parsed = int.tryParse(vStr);
        if (parsed != null) return parsed;
      }
    }

    // Debug útil: ver qué keys hay guardadas
    // (esto te sirve para encontrar la key real)
    // ignore: avoid_print
    print('🔎 SharedPreferences keys: ${prefs.getKeys()}');

    return null;
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _carnetData = null;
    });

    try {
      final idUsuario = await UserPreferences.getIdUsuario();

      if (idUsuario == null) {
        // Debug para ver qué se está guardando realmente
        final user = await UserPreferences.getUser();
        print('🔎 user_data guardado: $user');

        setState(() {
          _isLoading = false;
          _errorMessage =
              'No se encontró sesión de conductor (user_data sin id_usuario).';
        });
        return;
      }

      Map<String, dynamic>? datos;
      try {
        datos = await _carnetService.obtenerDatosCarnet(idUsuario);
      } catch (_) {
        datos = null; // fallback
      }

      datos ??= {
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

      final normalizado = _normalizarCarnet(datos);

      if (!mounted) return;
      setState(() {
        _carnetData = normalizado;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar carnet: $e';
      });
    }
  }

  Map<String, dynamic> _normalizarCarnet(Map<String, dynamic> raw) {
    String s(dynamic v, {String fallback = '-'}) {
      final txt = (v ?? '').toString().trim();
      return txt.isEmpty ? fallback : txt;
    }

    double d(dynamic v, {double fallback = 0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    int i(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    bool b(dynamic v, {bool fallback = false}) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v == 1;
      final t = v.toString().toLowerCase();
      return (t == '1' || t == 'true' || t == 'si' || t == 'sí');
    }

    return {
      'nombre': s(raw['nombre'], fallback: 'CONDUCTOR'),
      'apellido': s(raw['apellido'], fallback: ''),
      'foto_url': s(raw['foto_url'], fallback: ''),
      'patente': s(raw['patente'], fallback: '-'),
      'modelo_vehiculo': s(raw['modelo_vehiculo'], fallback: '-'),
      'color_vehiculo': s(raw['color_vehiculo'], fallback: '-'),
      'rating': d(raw['rating'], fallback: 0),
      'viajes_totales': i(raw['viajes_totales'], fallback: 0),
      'fecha_ingreso': s(raw['fecha_ingreso'], fallback: '-'),
      'verificado': b(raw['verificado'], fallback: false),
    };
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
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _errorMessage != null
          ? _buildError()
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
                      // TODO: Lógica para compartir
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarnetCard() {
    final data = _carnetData!;
    final fullName = ('${data['nombre']} ${data['apellido']}')
        .trim()
        .toUpperCase();
    final fotoUrl = (data['foto_url'] ?? '').toString().trim();
    final tieneFoto = fotoUrl.isNotEmpty;

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
          ),
        ],
        gradient: const LinearGradient(
          colors: [Color(0xFF2C2C2C), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
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
                // Header
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
                    if (data['verificado'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 14,
                            ),
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
                        backgroundColor: Colors.white10,
                        backgroundImage: tieneFoto
                            ? NetworkImage(fotoUrl)
                            : null,
                        onBackgroundImageError: tieneFoto ? (_, __) {} : null,
                        child: !tieneFoto
                            ? const Icon(Icons.person, color: Colors.white70)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${data['rating']}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' (${data['viajes_totales']} viajes)',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Miembro desde: ${data['fecha_ingreso']}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
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
                    Expanded(
                      child: _buildInfoColumn(
                        'VEHÍCULO',
                        data['modelo_vehiculo'],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoColumn('PATENTE', data['patente'], compact: true),
                    const SizedBox(width: 12),
                    _buildInfoColumn(
                      'COLOR',
                      data['color_vehiculo'],
                      compact: true,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // QR
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.qr_code_2, size: 100, color: Colors.black87),
                      Text(
                        'Escanear para validar',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
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

  Widget _buildInfoColumn(String label, String value, {bool compact = false}) {
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
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
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
