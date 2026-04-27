import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CarnetService {
  final String? _baseUrl = dotenv.env['API_URL'];

  Future<Map<String, dynamic>> obtenerDatosCarnet(int idUsuario) async {
    if (_baseUrl == null || _baseUrl.trim().isEmpty) {
      throw Exception('API_URL no está configurado en .env');
    }

    final uri = Uri.parse('${_baseUrl.trim()}/conductores/$idUsuario/carnet');

    try {
      final resp = await http
          .get(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Error ${resp.statusCode}: ${_safeBody(resp.body)}');
      }

      final decoded = jsonDecode(resp.body);

      // ✅ 1) Extraemos el "raw" real aunque venga {ok:true,data:{...}}
      Map<String, dynamic> raw;
      if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is Map) {
          raw = Map<String, dynamic>.from(decoded['data'] as Map);
        } else {
          raw = Map<String, dynamic>.from(decoded);
        }
      } else {
        throw Exception('Respuesta inesperada (no es JSON objeto).');
      }

      // ✅ 2) Devolvemos SIEMPRE el mapa plano normalizado
      return _mapToCarnetKeys(raw);
    } on SocketException {
      throw Exception('Sin conexión a internet / servidor no disponible.');
    } on HttpException {
      throw Exception('Error HTTP.');
    } on FormatException {
      throw Exception('Respuesta inválida (JSON mal formado).');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado.');
    }
  }

  String _safeBody(String body) {
    final t = body.trim();
    if (t.isEmpty) return '(sin cuerpo)';
    return t.length > 200 ? '${t.substring(0, 200)}...' : t;
  }

  Map<String, dynamic> _mapToCarnetKeys(Map<String, dynamic> raw) {
    dynamic pick(List<String> keys) {
      for (final k in keys) {
        if (raw.containsKey(k) && raw[k] != null) return raw[k];
      }
      return null;
    }

    String s(dynamic v, {String fallback = ''}) {
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

    final nombre = pick(['nombre', 'nombres', 'name', 'nombre_usuario']);
    final apellido = pick([
      'apellido',
      'apellidos',
      'last_name',
      'apellido_usuario',
    ]);
    final fotoUrl = pick([
      'foto_url',
      'foto_perfil',
      'fotoPerfil',
      'foto',
      'avatar',
      'image',
      'url_foto',
    ]);

    final patente = pick(['patente', 'dominio', 'matricula', 'placa']);
    final modelo = pick([
      'modelo_vehiculo',
      'modelo',
      'auto_modelo',
      'vehiculo_modelo',
      'marca_vehiculo',
    ]);
    final color = pick([
      'color_vehiculo',
      'color',
      'auto_color',
      'vehiculo_color',
    ]);

    final rating = pick(['rating', 'calificacion', 'score', 'promedio_rating']);
    final viajesTotales = pick([
      'viajes_totales',
      'total_viajes',
      'viajes',
      'cant_viajes',
    ]);

    // tu DB usa fecha_carga; backend puede enviar created_at también
    final fechaIngreso = pick([
      'fecha_ingreso',
      'fecha_carga',
      'created_at',
      'member_since',
      'fecha_alta',
      'fechaRegistro',
    ]);

    final verificado = pick([
      'verificado',
      'verified',
      'is_verified',
      'estado_verificacion',
    ]);

    return {
      'nombre': s(nombre, fallback: ''),
      'apellido': s(apellido, fallback: ''),
      'foto_url': s(fotoUrl, fallback: ''),
      'patente': s(patente, fallback: ''),
      'modelo_vehiculo': s(modelo, fallback: ''),
      'color_vehiculo': s(color, fallback: ''),
      'rating': d(rating, fallback: 0),
      'viajes_totales': i(viajesTotales, fallback: 0),
      'fecha_ingreso': s(fechaIngreso, fallback: ''),
      'verificado': b(verificado, fallback: false),
    };
  }
}
