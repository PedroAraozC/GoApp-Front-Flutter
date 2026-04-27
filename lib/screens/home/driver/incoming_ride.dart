import 'dart:convert';

/// Modelo de viaje que llega por socket / REST.
///
/// Es tolerante a distintas claves, para evitar pantallas rojas por `null`.
class IncomingRide {
  final int idViajes;
  final int idPasajero;
  final int? idConductor;
  final String direccionDesde;
  final double latDesde;
  final double lonDesde;
  final String direccionHasta;
  final double latHasta;
  final double lonHasta;
  final DateTime? horaInicio;
  final DateTime? horaFin;
  final double valor;
  final int idEstado;

  IncomingRide({
    required this.idViajes,
    required this.idPasajero,
    required this.idConductor,
    required this.direccionDesde,
    required this.latDesde,
    required this.lonDesde,
    required this.direccionHasta,
    required this.latHasta,
    required this.lonHasta,
    required this.horaInicio,
    required this.horaFin,
    required this.valor,
    required this.idEstado,
  });

  static int _parseInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? fallback;
  }

  static double _parseDouble(dynamic v, {double fallback = 0.0}) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? fallback;
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();

  factory IncomingRide.fromSocket(dynamic json) {
    final parsed = (json is String) ? jsonDecode(json) : json;

    final int idViaje = _parseInt(
      parsed['id_viajes'] ?? parsed['id_viaje'] ?? parsed['id'],
      fallback: -1,
    );

    final int idPasajero = _parseInt(
      parsed['id_pasajero'] ?? parsed['idUsuario'] ?? parsed['id_usuario'],
      fallback: -1,
    );

    final double latDesde = _parseDouble(
      parsed['lat_desde'] ??
          parsed['latDesde'] ??
          parsed['lat_origen'] ??
          parsed['latOrigen'],
    );
    final double lonDesde = _parseDouble(
      parsed['lon_desde'] ??
          parsed['lonDesde'] ??
          parsed['lng_desde'] ??
          parsed['lngDesde'] ??
          parsed['lon_origen'] ??
          parsed['lng_origen'] ??
          parsed['lngOrigen'],
    );

    final double latHasta = _parseDouble(
      parsed['lat_hasta'] ??
          parsed['latHasta'] ??
          parsed['lat_destino'] ??
          parsed['latDestino'],
      fallback: latDesde,
    );
    final double lonHasta = _parseDouble(
      parsed['lon_hasta'] ??
          parsed['lonHasta'] ??
          parsed['lng_hasta'] ??
          parsed['lngHasta'] ??
          parsed['lon_destino'] ??
          parsed['lng_destino'] ??
          parsed['lngDestino'],
      fallback: lonDesde,
    );

    final int estado = _parseInt(
      parsed['id_estado'] ?? parsed['estado'],
      fallback: 1,
    );

    if (idViaje <= 0 || idPasajero <= 0) {
      throw Exception(
        'Payload inválido: idViaje=$idViaje idPasajero=$idPasajero parsed=$parsed',
      );
    }

    return IncomingRide(
      idViajes: idViaje,
      idPasajero: idPasajero,
      idConductor: (parsed['id_conductor'] == null)
          ? null
          : _parseInt(parsed['id_conductor']),
      direccionDesde: _str(
        parsed['direccion_desde'] ??
            parsed['direccionDesde'] ??
            parsed['origen'],
      ),
      latDesde: latDesde,
      lonDesde: lonDesde,
      direccionHasta: _str(
        parsed['direccion_hasta'] ??
            parsed['direccionHasta'] ??
            parsed['destino'],
      ),
      latHasta: latHasta,
      lonHasta: lonHasta,
      horaInicio: (parsed['hora_inicio'] != null)
          ? DateTime.tryParse('${parsed['hora_inicio']}')
          : null,
      horaFin: (parsed['hora_fin'] != null)
          ? DateTime.tryParse('${parsed['hora_fin']}')
          : null,
      valor: _parseDouble(parsed['valor'], fallback: 0.0),
      idEstado: estado,
    );
  }
}
