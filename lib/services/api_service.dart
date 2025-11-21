import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final baseUrl = dotenv.env['API_URL'];

  // ==============================
  // 🔹 Actualizar datos del usuario
  // ==============================
  Future<bool> actualizarUsuario({
    required int idUsuario,
    required String dni,
    required String fechaNacimiento,
    required int? idGenero,
    required String telefonoUsuario,
    required String email,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/usuarios/actualizarUsuario/$idUsuario');
      debugPrint('URL de actualización: $url');
      final body = jsonEncode({
        'dni': dni,
        'fecha_nacimiento': fechaNacimiento,
        'id_genero': idGenero,
        'telefono_usuario': telefonoUsuario,
        'email_usuario': email,
      });

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Usuario actualizado correctamente');
        return true;
      } else {
        debugPrint('⚠️ Error al actualizar usuario: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error en actualizarUsuario(): $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Marcar viaje como "en curso" (chofer llegó al pasajero)
  // ==============================
  Future<bool> comenzarViaje(int idViaje) async {
    try {
      final url = Uri.parse('$baseUrl/viajes/$idViaje/comenzar');
      debugPrint('PUT $url');

      final resp = await http.put(url);

      if (resp.statusCode == 200) {
        debugPrint('✅ Viaje $idViaje marcado como EN CURSO');
        return true;
      } else {
        debugPrint(
          '⚠️ Error comenzarViaje($idViaje): '
          '${resp.statusCode} → ${resp.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error en comenzarViaje(): $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Obtener datos del usuario por ID
  // ==============================
  Future<Map<String, dynamic>?> obtenerUsuarioPorId(int idUsuario) async {
    try {
      final url = Uri.parse('$baseUrl/usuarios/obtenerUsuarioId/$idUsuario');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = decoded['result'];

        debugPrint('📡 obtenerUsuarioPorId($idUsuario) → result: $result');

        // Puede venir como LISTA [ { ... } ]
        if (result is List) {
          if (result.isEmpty) {
            debugPrint('⚠️ result es una lista vacía');
            return null;
          }
          if (result.first is Map<String, dynamic>) {
            return Map<String, dynamic>.from(result.first);
          }
          // Si el primer elemento no es Map, lo intentamos castear igual
          return Map<String, dynamic>.from(
            Map<String, dynamic>.from(result.first as Map),
          );
        }

        // O puede venir como OBJETO { ... }
        if (result is Map) {
          return Map<String, dynamic>.from(result);
        }

        debugPrint('⚠️ Formato inesperado en result: ${result.runtimeType}');
        return null;
      }

      debugPrint(
        '⚠️ Error HTTP ${response.statusCode} al obtener usuario: ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('❌ Error en obtenerUsuarioPorId(): $e');
      return null;
    }
  }

  // ==============================
  // 🔹 Iniciar viaje (pasajero)
  // ==============================
  Future<Map<String, dynamic>?> iniciarViaje({
    required int idUsuario,
    required double origenLat,
    required double origenLng,
    double? destinoLat,
    double? destinoLng,
    String? direccionOrigen,
    String? direccionDestino,
    double? precioEstimado,
  }) async {
    try {
      // 🔧 RUTA CORRECTA
      final url = Uri.parse('$baseUrl/viajes/iniciarViaje');
      debugPrint('🌐 POST $baseUrl/viajes/iniciarViaje');

      final body = jsonEncode({
        'id_usuario': idUsuario,
        'origen_lat': origenLat,
        'origen_lng': origenLng,
        'destino_lat': destinoLat,
        'destino_lng': destinoLng,
        'direccion_origen': direccionOrigen,
        'direccion_destino': direccionDestino,
        'precio_estimado': precioEstimado,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      debugPrint('📥 Status iniciarViaje: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('🆕 Viaje iniciado correctamente');
        return data['result'];
      } else {
        debugPrint('⚠️ Error al iniciar viaje: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error en iniciarViaje(): $e');
      return null;
    }
  }

  // ==============================
  // 🔹 Cancelar viaje
  // ==============================
  Future<void> cancelarViaje(int idViaje) async {
    final url = Uri.parse('$baseUrl/viajes/$idViaje/cancelar');
    final response = await http.put(url);

    if (response.statusCode != 200) {
      throw Exception('Error al cancelar viaje: ${response.body}');
    }
  }

  // ==============================
  // 🔹 Finalizar viaje
  // ==============================
  Future<bool> finalizarViaje({
    required int idViaje,
    double? precioFinal,
    double? distanciaKm,
    double? duracionMin,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/viajes/$idViaje/finalizar');
      final body = jsonEncode({
        'precio_final': precioFinal,
        'distancia_km': distanciaKm,
        'duracion_min': duracionMin,
      });

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('🏁 Viaje finalizado correctamente');
        return true;
      } else {
        debugPrint('⚠️ Error al finalizar viaje: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error en finalizarViaje(): $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Recaudación de hoy
  // ==============================
  Future<double?> getTodayEarnings() async {
    final url = Uri.parse('$baseUrl/recaudacion/today');
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return (data['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<void> addEarning(double amount) async {
    final url = Uri.parse('$baseUrl/recaudacion/add');
    await http.post(
      url,
      body: json.encode({'amount': amount}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ==============================
  // 🔹 Aceptar viaje (chofer)
  // ==============================
  Future<bool> acceptRide(int idViaje, int idConductor) async {
    final url = Uri.parse('$baseUrl/viajes/$idViaje/aceptar');
    final resp = await http.put(
      url,
      body: json.encode({'id_usuario': idConductor}),
      headers: {'Content-Type': 'application/json'},
    );
    return resp.statusCode == 200;
  }

  // ==============================
  // 🔹 Cambiar estado del conductor
  // ==============================
  Future<bool> cambiarEstadoConductor({
    required int idConductor,
    required bool conectado,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/conductores/cambiarEstado');
      debugPrint('🔁 Llamando a $url');

      final body = json.encode({
        'id_usuario': idConductor, // 👈 nombre que usa tu back
        'conectado': conectado ? 1 : 0, // 1 = conectado, 0 = desconectado
      });

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint(
          '✅ Estado de conductor actualizado a ${conectado ? "conectado" : "desconectado"}',
        );
        return true;
      } else {
        debugPrint(
          '⚠️ Error al cambiar estado del conductor: '
          '${response.statusCode} → ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Excepción en cambiarEstadoConductor(): $e');
      return false;
    }
  }
}
