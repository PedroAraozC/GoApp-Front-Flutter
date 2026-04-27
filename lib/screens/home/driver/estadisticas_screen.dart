import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/earnings_service.dart';

class EstadisticasScreen extends StatefulWidget {
  final int idUsuario;
  const EstadisticasScreen({super.key, required this.idUsuario});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final _service = EarningsService.instance;
  final _money = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  bool _loading = true;

  double _total = 0;
  double _hoy = 0;
  int _cant = 0;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Map<DateTime, double> _byDay = {}; // del mes
  List<double> _byHourToday = List.filled(24, 0);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    final total = await _service.getTotal(idUsuario: widget.idUsuario);
    final hoy = await _service.getTotalHoy(idUsuario: widget.idUsuario);
    final cant = await _service.getCantidadViajes(idUsuario: widget.idUsuario);

    final byDay = await _service.sumByDay(
      idUsuario: widget.idUsuario,
      month: _selectedMonth,
    );
    final byHour = await _service.sumByHourToday(idUsuario: widget.idUsuario);

    if (!mounted) return;
    setState(() {
      _total = total;
      _hoy = hoy;
      _cant = cant;
      _byDay = byDay;
      _byHourToday = byHour;
      _loading = false;
    });
  }

  Future<void> _pickMonth() async {
    // Selector simple: retroceder/avanzar mes sin paquetes
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final now = DateTime.now();
        final months = List.generate(12, (i) {
          final d = DateTime(now.year, now.month - i);
          return d;
        });

        return SafeArea(
          child: ListView(
            children: months.map((m) {
              final label = DateFormat('MMMM yyyy', 'es').format(m);
              return ListTile(
                title: Text(label),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _selectedMonth = DateTime(m.year, m.month));
                  await _loadAll();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _statTile(String title, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------- CHART: Por día (mes) -----------
  Widget _chartByDayMonth() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final bars = <BarChartGroupData>[];

    double maxY = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final v = _byDay[d] ?? 0;
      if (v > maxY) maxY = v;

      bars.add(
        BarChartGroupData(
          x: day,
          barRods: [
            BarChartRodData(
              toY: v,
              width: 8,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    if (maxY == 0) maxY = 1000;

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barGroups: bars,
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  final v = value.toInt();
                  if (v < 1 || v > daysInMonth) return const SizedBox.shrink();
                  return Text('$v', style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------- CHART: Por hora (hoy) -----------
  Widget _chartByHourToday() {
    final bars = <BarChartGroupData>[];
    double maxY = 0;

    for (int h = 0; h < 24; h++) {
      final v = _byHourToday[h];
      if (v > maxY) maxY = v;

      bars.add(
        BarChartGroupData(
          x: h,
          barRods: [
            BarChartRodData(
              toY: v,
              width: 8,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    if (maxY == 0) maxY = 1000;

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barGroups: bars,
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 3,
                getTitlesWidget: (value, meta) {
                  final h = value.toInt();
                  if (h % 3 != 0) return const SizedBox.shrink();
                  return Text('$h', style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statTile(
                  'Total acumulado',
                  _money.format(_total),
                  Icons.account_balance_wallet_rounded,
                ),
                const SizedBox(height: 12),
                _statTile(
                  'Ganado hoy',
                  _money.format(_hoy),
                  Icons.today_rounded,
                ),
                const SizedBox(height: 12),
                _statTile('Viajes registrados', '$_cant', Icons.route_rounded),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mensual: $monthLabel',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickMonth,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Cambiar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _chartByDayMonth(),

                const SizedBox(height: 24),
                Text(
                  'Hoy: ingresos por hora',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _chartByHourToday(),

                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
