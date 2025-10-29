import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthGoogleService {
  final _baseUrl = dotenv.env['API_URL'];

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/usuarios/google_login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'token': idToken}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      print('✅ Autenticación con Google exitosa: $data');
      return data; // devolvemos todo: {result, token, message}
    } else {
      final error = json.decode(response.body);
      throw Exception(
          error['message'] ?? 'Error en la autenticación con Google.');
    }
  }
}
