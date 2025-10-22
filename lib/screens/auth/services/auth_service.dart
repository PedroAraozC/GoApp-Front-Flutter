import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl = 'http://186.123.85.22:3000';

  /// 🔹 Obtiene un usuario y contraseña del BackEnd
  Future<Map<String, dynamic>?> login(String mail, String password) async {
    try {
      final url = Uri.parse('$baseUrl/usuarios/login');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': mail, 'password': password}),
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
      } else if (response.statusCode == 401) {
        throw Exception('Credenciales incorrectas.');
      } else {
        throw Exception('Error ${response.statusCode} al iniciar sesión.');
      }
    } catch (e) {
      throw Exception('Error en login: $e');
    }

    return null;
  }

  /*

  /// 🔹 Actualiza los datos del usuario
  Future<bool> actualizarUsuario(int id, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/usuarios/actualizarUsuario/$id');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

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
*/
}
