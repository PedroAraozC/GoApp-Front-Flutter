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

    // ignore: avoid_print
    print('🔎 SharedPreferences keys: ${prefs.getKeys()}');
    return null;
  }

  Future<int?> _obtenerIdUsuarioConFallback() async {
    final id1 = await UserPreferences.getIdUsuario();
    if (id1 != null) return id1;

    final prefs = await SharedPreferences.getInstance();
    final id2 = _leerIdUsuario(prefs);
    if (id2 != null) return id2;

    return null;
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _carnetData = null;
    });

    try {
      final idUsuario = await _obtenerIdUsuarioConFallback();

      if (idUsuario == null) {
        final user = await UserPreferences.getUser();
        // ignore: avoid_print
        print('🔎 user_data guardado: $user');

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No se encontró sesión de conductor (sin id_usuario).';
        });
        return;
      }

      // ignore: avoid_print
      print('🪪 idUsuario: $idUsuario');

      // ✅ Puede venir plano o envuelto (ok/data). Lo arreglamos acá.
      final resp = await _carnetService.obtenerDatosCarnet(idUsuario);
      // ignore: avoid_print
      print('📦 datos carnet (service): $resp');

      final Map<String, dynamic> datos = (resp?['data'] is Map)
          ? Map<String, dynamic>.from(resp?['data'] as Map)
          : Map<String, dynamic>.from(resp!);

      // ignore: avoid_print
      print('✅ datos carnet (usado por UI): $datos');

      if (!mounted) return;
      setState(() {
        _carnetData = datos;
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
                      // TODO: compartir
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
    final data = _carnetData ?? {};

    String safeStr(dynamic v, {String fallback = '-'}) {
      final t = (v ?? '').toString().trim();
      return t.isEmpty ? fallback : t;
    }

    final nombre = safeStr(data['nombre'], fallback: 'CONDUCTOR');
    final apellido = safeStr(data['apellido'], fallback: '');
    final fullName = ('$nombre $apellido').trim().toUpperCase();

    final fotoUrl = safeStr(data['foto_url'], fallback: '');
    final tieneFoto = fotoUrl.isNotEmpty;

    final ratingRaw = data['rating'];
    final ratingNum = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse((ratingRaw ?? '0').toString()) ?? 0.0;
    final ratingText = ratingNum <= 0 ? '—' : ratingNum.toStringAsFixed(1);

    final viajesRaw = data['viajes_totales'];
    final viajes = viajesRaw is num
        ? viajesRaw.toInt()
        : int.tryParse((viajesRaw ?? '0').toString()) ?? 0;

    final fecha = safeStr(data['fecha_ingreso'], fallback: '-');

    final verificado = data['verificado'] == true;

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
                    if (verificado)
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
                                ratingText,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' ($viajes viajes)',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Miembro desde: $fecha',
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
                        safeStr(data['modelo_vehiculo'], fallback: '-'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoColumn(
                      'PATENTE',
                      safeStr(data['patente'], fallback: '-'),
                      compact: true,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoColumn(
                      'COLOR',
                      safeStr(data['color_vehiculo'], fallback: '-'),
                      compact: true,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // QR placeholder
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
    final v = value.trim();
    final safeValue = v.isEmpty ? '-' : v;

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
          safeValue,
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
