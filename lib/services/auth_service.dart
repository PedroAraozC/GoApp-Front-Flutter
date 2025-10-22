import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String baseUrl = "http://192.168.100.10:3000";

  static Future<Map<String, dynamic>> recuperarPassword(String dni, String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/recoveryPassword'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"dni": dni, "email": email}),
    );

    /* DEBUG:
    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");
    */
    
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verificarCodigo(String email, String codigo) async {
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/verificarCodigo'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "codigo": codigo}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> cambiarPassword({
    required String dni,
    required String email,
    required String actual,
    required String nueva,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/changePassword'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'dni': dni,
          'email': email,
          'actual': actual,
          'nueva': nueva,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión con el servidor'};
    }
  }
}
