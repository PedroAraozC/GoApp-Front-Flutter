// lib/screens/perfil/viajes_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/user_preferences.dart';

class ViajesScreen extends StatefulWidget {
  const ViajesScreen({super.key});

  @override
  State<ViajesScreen> createState() => _ViajesScreenState();
}

class _ViajesScreenState extends State<ViajesScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _viajes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final idUsuario = await UserPreferences.getIdUsuario();
      if (idUsuario == null) {
        setState(() {
          _loading = false;
          _error = 'No se encontró el usuario logueado.';
        });
        return;
      }

      final list = await _api.obtenerHistorialViajesUsuario(idUsuario);

      setState(() {
        _viajes = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error cargando historial: $e';
      });
    }
  }

  // ---------- Helpers ----------
  String _clean(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.toLowerCase() == 'null') return '';
    return s;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;

    // Intenta ISO (2026-02-13T21:00:00.000Z)
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.toLocal();

    // Intenta formatos comunes
    for (final f in ['yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd']) {
      try {
        return DateFormat(f).parse(s, true).toLocal();
      } catch (_) {}
    }
    return null;
  }

  Color _statusColor(ColorScheme cs, String estado) {
    final e = estado.toLowerCase();
    if (e.contains('final') || e.contains('complet')) return Colors.green;
    if (e.contains('cancel')) return Colors.red;
    if (e.contains('en curso') ||
        e.contains('iniciado') ||
        e.contains('activo')) {
      return Colors.orange;
    }
    if (e.contains('asign') || e.contains('acept')) return Colors.blue;
    return cs.primary;
  }

  String _statusLabel(String estado) {
    final e = estado.trim();
    if (e.isEmpty) return 'Desconocido';
    return e[0].toUpperCase() + e.substring(1);
  }

  String _money(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return '-';
    // ARS, sin símbolo raro (podés cambiarlo)
    return NumberFormat.currency(locale: 'es_AR', symbol: '\$').format(d);
  }

  ImageProvider? _driverPhotoProvider(Map<String, dynamic> v) {
    final url = _clean(v['foto_conductor'] ?? v['foto_perfil_conductor']);
    if (url.isEmpty) return null;
    return NetworkImage(url);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis viajes')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: () => _load())
            : _viajes.isEmpty
            ? _EmptyState(onRefresh: () => _load(showLoading: true))
            : RefreshIndicator(
                onRefresh: () => _load(showLoading: false),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _viajes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final v = _viajes[i];

                    final estado = _clean(v['estado'] ?? v['estado_viaje']);
                    final color = _statusColor(cs, estado);

                    final fecha = _parseDate(
                      v['fecha'] ??
                          v['created_at'] ??
                          v['fecha_viaje'] ??
                          v['inicio'],
                    );
                    final fechaTxt = (fecha != null)
                        ? DateFormat('dd/MM/yyyy HH:mm').format(fecha)
                        : '';

                    final origen = _clean(
                      v['direccion_origen'] ?? v['origen'] ?? v['origen_texto'],
                    );
                    final destino = _clean(
                      v['direccion_destino'] ??
                          v['destino'] ??
                          v['destino_texto'],
                    );

                    final nombreConductor = _clean(
                      v['conductor_nombre'] ??
                          v['nombre_conductor'] ??
                          v['nombre'],
                    );
                    final apellidoConductor = _clean(
                      v['conductor_apellido'] ??
                          v['apellido_conductor'] ??
                          v['apellido'],
                    );
                    final conductor = ('$nombreConductor $apellidoConductor')
                        .trim();

                    final patente = _clean(
                      v['patente'] ?? v['patente_vehiculo'],
                    );
                    final modelo = _clean(v['modelo_vehiculo'] ?? v['modelo']);
                    final colorVeh = _clean(v['color_vehiculo'] ?? v['color']);

                    final precio = v['precio_final'] ?? v['precio_estimado'];

                    final rating = _toDouble(
                      v['rating_conductor'] ?? v['rating'],
                    );

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openDetalle(context, v),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: cs.surfaceContainerHighest,
                                    backgroundImage: _driverPhotoProvider(v),
                                    child: _driverPhotoProvider(v) == null
                                        ? Icon(
                                            Icons.person,
                                            color: cs.onSurfaceVariant,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          conductor.isEmpty
                                              ? 'Conductor'
                                              : conductor,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (patente.isNotEmpty) patente,
                                            if (modelo.isNotEmpty) modelo,
                                            if (colorVeh.isNotEmpty) colorVeh,
                                          ].join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      _statusLabel(estado),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              if (origen.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.my_location,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        origen,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (destino.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      size: 16,
                                      color: cs.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        destino,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],

                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      fechaTxt.isEmpty ? '—' : fechaTxt,
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  if (rating != null) ...[
                                    Icon(
                                      Icons.star,
                                      size: 18,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Text(
                                    _money(precio),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _openDetalle(BuildContext context, Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DetalleViajeSheet(viaje: v),
    );
  }
}

// ---------------- UI states ----------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text(
              'Todavía no tenés viajes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuando realices un viaje, te va a aparecer acá.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: cs.error),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalleViajeSheet extends StatelessWidget {
  const _DetalleViajeSheet({required this.viaje});
  final Map<String, dynamic> viaje;

  String _c(dynamic v) =>
      (v == null || v.toString().trim().toLowerCase() == 'null')
      ? ''
      : v.toString().trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final idViaje = _c(viaje['id_viaje'] ?? viaje['id'] ?? viaje['viaje_id']);
    final estado = _c(viaje['estado'] ?? viaje['estado_viaje']);
    final origen = _c(
      viaje['direccion_origen'] ?? viaje['origen'] ?? viaje['origen_texto'],
    );
    final destino = _c(
      viaje['direccion_destino'] ?? viaje['destino'] ?? viaje['destino_texto'],
    );

    final conductorNombre = _c(
      viaje['conductor_nombre'] ?? viaje['nombre_conductor'] ?? viaje['nombre'],
    );
    final conductorApellido = _c(
      viaje['conductor_apellido'] ??
          viaje['apellido_conductor'] ??
          viaje['apellido'],
    );
    final conductor = ('$conductorNombre $conductorApellido').trim();

    final patente = _c(viaje['patente'] ?? viaje['patente_vehiculo']);
    final modelo = _c(viaje['modelo_vehiculo'] ?? viaje['modelo']);
    final colorVeh = _c(viaje['color_vehiculo'] ?? viaje['color']);
    final tel = _c(viaje['telefono_conductor'] ?? viaje['telefono']);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detalle del viaje',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              _kv('ID', idViaje.isEmpty ? '—' : idViaje, cs),
              _kv('Estado', estado.isEmpty ? '—' : estado, cs),
              const Divider(height: 22),

              _kv('Conductor', conductor.isEmpty ? '—' : conductor, cs),
              _kv(
                'Vehículo',
                [
                  patente,
                  modelo,
                  colorVeh,
                ].where((e) => e.isNotEmpty).join(' • ').ifEmpty('—'),
                cs,
              ),
              if (tel.isNotEmpty) _kv('Teléfono', tel, cs),

              const Divider(height: 22),

              _kv('Origen', origen.isEmpty ? '—' : origen, cs),
              _kv('Destino', destino.isEmpty ? '—' : destino, cs),

              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

extension _StrX on String {
  String ifEmpty(String other) => trim().isEmpty ? other : this;
}
