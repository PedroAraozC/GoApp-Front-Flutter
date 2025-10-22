import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthGoogleService {
  // Cambia esta URL por la de tu backend
  final String _baseUrl = 'http://localhost:3000';
  // Iniciar sesión/Registrarse con Google
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse(
        '$_baseUrl/usuarios/google_login',
      ), // Nuevo endpoint para Google
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'token': idToken}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['result'];
    } else {
      final error = json.decode(response.body);
      throw Exception(
        error['message'] ?? 'Error en la autenticación con Google.',
      );
    }
  }
}
