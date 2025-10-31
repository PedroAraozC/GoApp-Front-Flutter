import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PerfilService {
  final baseUrl = dotenv.env['API_URL'];

  // ==============================
  // 📦 Obtener perfil de usuario
  // ==============================
  Future<Map<String, dynamic>?> obtenerPerfil(int idUsuario) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/obtenerUsuarioId/$idUsuario'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null) {
          return Map<String, dynamic>.from(data['result']);
        }
      }
      print('⚠️ No se pudo obtener el perfil: ${response.body}');
      return null;
    } catch (e) {
      print('❌ Error en obtenerPerfil: $e');
      return null;
    }
  }

  // ==============================
  // 📜 Obtener lista de géneros
  // ==============================
  Future<List<Map<String, dynamic>>> obtenerGeneros() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/generos/obtenerGenero'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] is List) {
          return List<Map<String, dynamic>>.from(data['result']);
        }
      }

      print('⚠️ Error al obtener géneros: ${response.body}');
      return [];
    } catch (e) {
      print('❌ Error en obtenerGeneros: $e');
      return [];
    }
  }

  // ==============================
  // ✏️ Actualizar datos de perfil
  // ==============================
  Future<bool> actualizarPerfil({
    required int idUsuario,
    String? telefono,
    String? email,
    String? fechaNacimiento,
    int? idGenero,
  }) async {
    try {
      final body = {
        'telefono_usuario': telefono,
        'email_usuario': email,
        'fecha_nacimiento': fechaNacimiento,
        'id_genero': idGenero,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/usuarios/$idUsuario'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print('✅ Perfil actualizado correctamente');
        return true;
      } else {
        print('⚠️ Error al actualizar perfil: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error en actualizarPerfil: $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Obtener usuario por ID
  // ==============================
  Future<Map<String, dynamic>?> obtenerUsuarioPorId(int idUsuario) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/$idUsuario'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null) {
          return Map<String, dynamic>.from(data['result']);
        }
      }

      print('⚠️ No se pudo obtener el usuario: ${response.body}');
      return null;
    } catch (e) {
      print('❌ Error en obtenerUsuarioPorId: $e');
      return null;
    }
  }

  // ==============================
  // ✏️ Actualizar usuario
  // ==============================
  Future<bool> actualizarUsuario(
    int idUsuario,
    Map<String, dynamic> data,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/usuarios/$idUsuario');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        print('✅ Usuario actualizado correctamente');
        return true;
      } else {
        print('⚠️ Error al actualizar usuario: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error en actualizarUsuario: $e');
      return false;
    }
  }
}
