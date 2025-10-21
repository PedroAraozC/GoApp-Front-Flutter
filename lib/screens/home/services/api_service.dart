// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String BASE_URL = 'http://192.168.1.30:3000'; // ⬅️ AJUSTAR


  /// 🔹 Obtiene un usuario por su ID desde el backend
  Future<Map<String, dynamic>?> obtenerUsuarioPorId(int id) async {
    try {
      final url = Uri.parse('$BASE_URL/usuarios/obtenerUsuarioId/$id');
      // obtenerUsuarioPorId
final response = await http
  .get(url, headers: {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  })
  .timeout(const Duration(seconds: 10), onTimeout: () {
    throw Exception('Tiempo de espera agotado. Verifica tu conexión.');
  });

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
      final url = Uri.parse('$BASE_URL/usuarios/actualizarUsuario/$idUsuario');
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

}