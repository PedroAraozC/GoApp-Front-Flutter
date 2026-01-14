import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CarnetService {
  final baseUrl = dotenv.env['API_URL'];

  // ==============================\r
  // 🔹 OBTENER DATOS CARNET DIGITAL\r
  // ==============================\r
  /// Retorna un mapa con datos: {nombre, apellido, foto, patente, modelo, color, rating, verificado}
  Future<Map<String, dynamic>?> obtenerDatosCarnet(int idConductor) async {
    try {
      final url = Uri.parse('$baseUrl/conductores/$idConductor/carnet');
      debugPrint('🪪 Obteniendo carnet desde CarnetService: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Asumiendo que el backend devuelve { ok: true, carnet: {...} }
        return decoded['carnet'] ?? decoded; 
      } else {
        debugPrint('⚠️ Error al obtener carnet: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error en obtenerDatosCarnet: $e');
      return null;
    }
  }
}