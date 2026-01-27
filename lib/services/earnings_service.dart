import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum EarningType { viajeApp, viajeRapido }

class EarningEntry {
  final String id; // unique
  final int? idViaje; // null para viaje rapido si querés
  final double monto;
  final DateTime fecha;
  final EarningType tipo;

  EarningEntry({
    required this.id,
    required this.idViaje,
    required this.monto,
    required this.fecha,
    required this.tipo,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'id_viaje': idViaje,
    'monto': monto,
    'fecha': fecha.toIso8601String(),
    'tipo': tipo.name, // viajeApp | viajeRapido
  };

  factory EarningEntry.fromMap(Map<String, dynamic> map) {
    final tipoStr = (map['tipo'] ?? 'viajeApp').toString();
    final tipo = tipoStr == 'viajeRapido'
        ? EarningType.viajeRapido
        : EarningType.viajeApp;

    return EarningEntry(
      id: map['id'].toString(),
      idViaje: map['id_viaje'] == null
          ? null
          : (map['id_viaje'] as num).toInt(),
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'].toString()),
      tipo: tipo,
    );
  }
}

class EarningsService {
  EarningsService._();
  static final EarningsService instance = EarningsService._();

  String _key(int idUsuario) => 'earnings_$idUsuario';
  String _keyIds(int idUsuario) => 'earnings_ids_$idUsuario';

  // -------------------------
  // CRUD
  // -------------------------
  Future<List<EarningEntry>> getAll({required int idUsuario}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(idUsuario));
    if (raw == null || raw.trim().isEmpty) return [];

    final list = (jsonDecode(raw) as List)
        .map((e) => EarningEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    list.sort((a, b) => b.fecha.compareTo(a.fecha));
    return list;
  }

  Future<double> getTotal({required int idUsuario}) async {
    final items = await getAll(idUsuario: idUsuario);
    double total = 0;
    for (final e in items) {
      total += e.monto;
    }
    return total;
  }

  Future<bool> addEarning({
    required int idUsuario,
    required String uniqueId,
    int? idViaje,
    required double monto,
    DateTime? fecha,
    required EarningType tipo,
  }) async {
    final sp = await SharedPreferences.getInstance();

    // Anti duplicados por uniqueId
    final idsRaw = sp.getString(_keyIds(idUsuario)) ?? '[]';
    final ids = (jsonDecode(idsRaw) as List).map((e) => e.toString()).toSet();

    if (ids.contains(uniqueId)) return false;

    final current = await getAll(idUsuario: idUsuario);
    final entry = EarningEntry(
      id: uniqueId,
      idViaje: idViaje,
      monto: monto,
      fecha: fecha ?? DateTime.now(),
      tipo: tipo,
    );

    current.add(entry);

    await sp.setString(
      _key(idUsuario),
      jsonEncode(current.map((e) => e.toMap()).toList()),
    );

    ids.add(uniqueId);
    await sp.setString(_keyIds(idUsuario), jsonEncode(ids.toList()));
    return true;
  }

  Future<void> clearAll({required int idUsuario}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key(idUsuario));
    await sp.remove(_keyIds(idUsuario));
  }

  // -------------------------
  // Agrupaciones (día/mes/hora)
  // -------------------------
  DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _onlyMonth(DateTime d) => DateTime(d.year, d.month);

  Future<Map<DateTime, double>> sumByDay({
    required int idUsuario,
    required DateTime month,
  }) async {
    final items = await getAll(idUsuario: idUsuario);
    final m = _onlyMonth(month);
    final Map<DateTime, double> out = {};

    for (final e in items) {
      if (e.fecha.year == m.year && e.fecha.month == m.month) {
        final day = _onlyDay(e.fecha);
        out[day] = (out[day] ?? 0) + e.monto;
      }
    }
    return out;
  }

  Future<Map<DateTime, double>> sumByMonth({required int idUsuario}) async {
    final items = await getAll(idUsuario: idUsuario);
    final Map<DateTime, double> out = {};

    for (final e in items) {
      final key = _onlyMonth(e.fecha);
      out[key] = (out[key] ?? 0) + e.monto;
    }
    return out;
  }

  Future<List<double>> sumByHourToday({required int idUsuario}) async {
    final items = await getAll(idUsuario: idUsuario);
    final now = DateTime.now();
    final List<double> hours = List.filled(24, 0);

    for (final e in items) {
      final f = e.fecha;
      final sameDay =
          f.year == now.year && f.month == now.month && f.day == now.day;
      if (sameDay) {
        hours[f.hour] += e.monto;
      }
    }
    return hours;
  }

  Future<double> getTotalHoy({required int idUsuario}) async {
    final hours = await sumByHourToday(idUsuario: idUsuario);
    double t = 0;
    for (final v in hours) t += v;
    return t;
  }

  Future<int> getCantidadViajes({required int idUsuario}) async {
    final items = await getAll(idUsuario: idUsuario);
    return items.length;
  }
}
