import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/earnings_service.dart';

class IngresosScreen extends StatefulWidget {
  final int idUsuario;
  const IngresosScreen({super.key, required this.idUsuario});

  @override
  State<IngresosScreen> createState() => _IngresosScreenState();
}

class _IngresosScreenState extends State<IngresosScreen> {
  final _service = EarningsService.instance;

  bool _loading = true;
  String? _error;
  double _total = 0;
  List<EarningEntry> _items = [];

  final _money = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.getAll(idUsuario: widget.idUsuario);
      final total = await _service.getTotal(idUsuario: widget.idUsuario);
      if (!mounted) return;

      setState(() {
        _items = items;
        _total = total;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando ingresos: $e';
        _loading = false;
      });
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar ingresos'),
        content: const Text(
          '¿Seguro que querés borrar el historial de ingresos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _service.clearAll(idUsuario: widget.idUsuario);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Borrar',
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // “Billetera”
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Billetera',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _money.format(_total),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('${_items.length} viaje(s) registrados'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Historial',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text('Todavía no hay ingresos registrados.'),
                      ),
                    )
                  else
                    ..._items.map((e) {
                      final fecha = DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(e.fecha);
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_taxi),
                          title: Text('Viaje #${e.idViaje}'),
                          subtitle: Text(fecha),
                          trailing: Text(
                            _money.format(e.monto),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
