// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final baseUrl = dotenv.env['API_URL'];

  /// 🔹 Obtiene un usuario por su ID desde el backend
  Future<Map<String, dynamic>?> obtenerUsuarioPorId(int id) async {
    try {
      final url = Uri.parse('$baseUrl/usuarios/obtenerUsuarioId/$id');
      // obtenerUsuarioPorId
      final response = await http
          .get(
            url,
            headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Tiempo de espera agotado. Verifica tu conexión.',
              );
            },
          );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final result = decoded['result'];

        if (result is List && result.isNotEmpty) {
          return Map<String, dynamic>.from(result[0]);
        } else if (result is Map) {
          return Map<String, dynamic>.from(result);
        }
      } else {
        throw Exception('Error ${response.statusCode} al obtener el usuario.');
      }
    } catch (e) {
      throw Exception('Error en obtenerUsuarioPorId: $e');
    }
    return null;
  }

  /// PUT /usuarios/:id
  ///
  /// El backend espera en body:
  /// { dni, fecha_nacimiento, id_genero, telefono_usuario, email }
  /// y hace UPDATE a email_usuario con "email".
  Future<bool> actualizarUsuario({
    required int idUsuario,
    required String dni,
    required String fechaNacimiento,
    required int? idGenero,
    required String telefonoUsuario,
    required String email,
  }) async {
    //final uri = Uri.parse('$BASE_URL/usuarios/actualizarUsuario/$idUsuario');
    final body = jsonEncode({
      'dni': dni,
      'fecha_nacimiento': fechaNacimiento,
      'id_genero': idGenero,
      'telefono_usuario': telefonoUsuario,
      'email': email, // backend lo mapea a email_usuario en el UPDATE
    });

    try {
      final url = Uri.parse('$baseUrl/usuarios/actualizarUsuario/$idUsuario');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error en actualizarUsuario: $e');
    }
  }

  /// POST /viajes/iniciar
  /// Devuelve el viaje creado (estado "buscando")
  Future<Map<String, dynamic>> iniciarViaje({
    required int idUsuario,
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
    String? direccionOrigen,
    String? direccionDestino,
    double? precioEstimado,
    String? notas,
  }) async {
    final uri = Uri.parse('$baseUrl/viajes/iniciar');
    final body = {
      "id_usuario": idUsuario,
      "origen_lat": origenLat,
      "origen_lng": origenLng,
      "destino_lat": destinoLat,
      "destino_lng": destinoLng,
      "direccion_origen": direccionOrigen,
      "direccion_destino": direccionDestino,
      "precio_estimado": precioEstimado,
      "notas": notas,
    };

    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception('No se pudo iniciar el viaje (${resp.statusCode})');
    }
    final decoded = json.decode(resp.body);
    final result = decoded['result'];
    if (result is Map<String, dynamic>) return result;
    throw Exception('Respuesta inesperada al iniciar el viaje');
  }

  /// GET /viajes/:id
  Future<Map<String, dynamic>?> obtenerViaje(int idViaje) async {
    final uri = Uri.parse('$baseUrl/viajes/$idViaje');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final decoded = json.decode(resp.body);
    final result = decoded['result'];
    if (result is Map<String, dynamic>) return result;
    return null;
  }

  /// GET /viajes/usuario/:id_usuario?estado=finalizado
  Future<List<Map<String, dynamic>>> listarViajesUsuario(
    int idUsuario, {
    String estado = 'finalizado',
  }) async {
    final uri = Uri.parse('$baseUrl/viajes/usuario/$idUsuario?estado=$estado');
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) return [];
    final decoded = json.decode(resp.body);
    final list = decoded['result'];
    if (list is List) {
      return list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  /// PUT /viajes/:id/cancelar
  Future<bool> cancelarViaje(int idViaje) async {
    final uri = Uri.parse('$baseUrl/viajes/$idViaje/cancelar');
    final resp = await http
        .put(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));
    return resp.statusCode == 200;
  }

  void dispose() {
    http.Client().close();
  }
}
