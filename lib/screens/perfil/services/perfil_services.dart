import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PerfilService {
  final baseUrl = dotenv.env['API_URL'];

  /// 🔹 Obtiene un usuario por su ID desde el backend
  Future<Map<String, dynamic>?> obtenerUsuarioPorId(int id) async {
    try {
      final url = Uri.parse('$baseUrl/usuarios/obtenerUsuarioId/$id');
      final response = await http
          .get(url)
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

  /// 🔹 Actualiza los datos del usuario
  Future<bool> actualizarUsuario(int id, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/usuarios/actualizarUsuario/$id');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      print(data);
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error en actualizarUsuario: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerGeneros() async {
    try {
      final url = Uri.parse('$baseUrl/generos/obtenerGenero');
      final response = await http
          .get(url)
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

        if (result is List) {
          return List<Map<String, dynamic>>.from(result);
        }
      } else {
        throw Exception('Error ${response.statusCode} al obtener los Generos.');
      }
    } catch (e) {
      throw Exception('Error en obtenerGeneros: $e');
    }
    return [];
  }
}
