import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CarnetService {
  // Podés definir en tu .env algo como:
  // API_URL=http://192.168.0.10:3000
  //
  // Si no usás dotenv, dejá la constante.
  final _baseUrl = dotenv.env['API_URL'];

  // Endpoint sugerido:
  // GET /conductores/:idUsuario/carnet
  //
  // Si tu backend lo hace distinto, cambiá esta función.
  Future<Map<String, dynamic>> obtenerDatosCarnet(int idUsuario) async {
    final uri = Uri.parse('$_baseUrl/conductores/$idUsuario/carnet');

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

      // Permitimos que el backend responda:
      // - { ...datos }
      // - { ok: true, data: { ...datos } }
      // - { data: { ...datos } }
      Map<String, dynamic> raw;
      if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is Map<String, dynamic>) {
          raw = Map<String, dynamic>.from(decoded['data']);
        } else {
          raw = Map<String, dynamic>.from(decoded);
        }
      } else {
        throw Exception('Respuesta inesperada (no es JSON objeto).');
      }

      // Mapeo a las keys que espera CarnetDigitalScreen:
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

  // ------------------------------
  // Helpers
  // ------------------------------

  String _safeBody(String body) {
    final t = body.trim();
    if (t.isEmpty) return '(sin cuerpo)';
    return t.length > 200 ? '${t.substring(0, 200)}...' : t;
  }

  /// Convierte un JSON "cualquiera" a las claves estándar del carnet:
  /// nombre, apellido, foto_url, patente, modelo_vehiculo, color_vehiculo,
  /// rating, viajes_totales, fecha_ingreso, verificado
  Map<String, dynamic> _mapToCarnetKeys(Map<String, dynamic> raw) {
    dynamic pick(List<String> keys) {
      for (final k in keys) {
        if (raw.containsKey(k) && raw[k] != null) return raw[k];
      }
      return null;
    }

    // Datos conductor
    final nombre = pick(['nombre', 'nombres', 'name', 'nombre_usuario']);
    final apellido = pick([
      'apellido',
      'apellidos',
      'last_name',
      'apellido_usuario',
    ]);
    final fotoUrl = pick([
      'foto_url',
      'foto',
      'fotoPerfil',
      'foto_perfil',
      'avatar',
      'image',
      'url_foto',
    ]);

    // Datos vehículo
    final patente = pick(['patente', 'dominio', 'matricula', 'placa']);
    final modelo = pick([
      'modelo_vehiculo',
      'modelo',
      'vehiculo_modelo',
      'auto_modelo',
      'marca_modelo',
    ]);
    final color = pick([
      'color_vehiculo',
      'color',
      'vehiculo_color',
      'auto_color',
    ]);

    // Stats
    final rating = pick(['rating', 'calificacion', 'score', 'promedio_rating']);
    final viajesTotales = pick([
      'viajes_totales',
      'total_viajes',
      'viajes',
      'cant_viajes',
    ]);
    final fechaIngreso = pick([
      'fecha_ingreso',
      'member_since',
      'fecha_alta',
      'created_at',
      'fechaRegistro',
    ]);

    // Verificación
    final verificado = pick([
      'verificado',
      'verified',
      'is_verified',
      'estado_verificacion',
    ]);

    return {
      'nombre': (nombre ?? '').toString(),
      'apellido': (apellido ?? '').toString(),
      'foto_url': (fotoUrl ?? '').toString(),
      'patente': (patente ?? '').toString(),
      'modelo_vehiculo': (modelo ?? '').toString(),
      'color_vehiculo': (color ?? '').toString(),
      'rating': rating ?? 0,
      'viajes_totales': viajesTotales ?? 0,
      'fecha_ingreso': (fechaIngreso ?? '').toString(),
      'verificado': verificado ?? false,
    };
  }
}
