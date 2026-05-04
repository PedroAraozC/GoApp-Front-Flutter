import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  /// ✅ Base URL segura (si API_URL no está seteada, no crashea)
  String get _baseUrl {
    final raw = (dotenv.env['API_URL'] ?? '').trim();
    if (raw.isEmpty) {
      // fallback típico emulador Android
      return 'http://10.0.2.2:3000';
    }
    return raw.replaceAll(RegExp(r'/$'), '');
  }

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
      final url = Uri.parse('$_baseUrl/usuarios/actualizarUsuario/$idUsuario');
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
  // 🔹 Obtener datos del usuario por ID
  // ==============================
  Future<Map<String, dynamic>?> obtenerUsuarioPorId(int idUsuario) async {
    try {
      final url = Uri.parse('$_baseUrl/usuarios/obtenerUsuarioId/$idUsuario');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = decoded['result'];

        debugPrint('📡 obtenerUsuarioPorId($idUsuario) → result: $result');

        if (result is List) {
          if (result.isEmpty) return null;
          if (result.first is Map<String, dynamic>) {
            return Map<String, dynamic>.from(result.first);
          }
          return Map<String, dynamic>.from(
            Map<String, dynamic>.from(result.first as Map),
          );
        }

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

    // ✅ precio fijo
    String modoCobro = 'PACTADO', // 'PACTADO' | 'TAXIMETRO'
    double? precioPactado,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/iniciarViaje');
      debugPrint('🌐 POST $_baseUrl/viajes/iniciarViaje');

      // ✅ Compat total con backend viejo y nuevo:
      // - backend viejo espera precio_estimado
      // - backend nuevo usa modo_cobro + precio_pactado
      final body = jsonEncode({
        'id_usuario': idUsuario,
        'origen_lat': origenLat,
        'origen_lng': origenLng,
        'destino_lat': destinoLat,
        'destino_lng': destinoLng,
        'direccion_origen': direccionOrigen,
        'direccion_destino': direccionDestino,

        // ✅ clave histórica
        'precio_estimado': precioPactado,

        // ✅ claves nuevas
        'modo_cobro': modoCobro,
        'precio_pactado': precioPactado,
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
  // 🔹 Recaudación de hoy
  // ==============================
  Future<double?> getTodayEarnings() async {
    final url = Uri.parse('$_baseUrl/recaudacion/today');
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return (data['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<void> addEarning(double amount) async {
    final url = Uri.parse('$_baseUrl/recaudacion/add');
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
    final url = Uri.parse('$_baseUrl/viajes/$idViaje/aceptar');
    final resp = await http.put(
      url,
      body: json.encode({'id_conductor': idConductor}),
      headers: {'Content-Type': 'application/json'},
    );
    return resp.statusCode == 200;
  }

  // ==============================
  // 🔹 Rechazar viaje (chofer)
  // ==============================
  Future<bool> rechazarViaje(int idViaje, int idConductor) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/$idViaje/rechazar');
      final resp = await http.put(
        url,
        body: json.encode({'id_conductor': idConductor}),
        headers: {'Content-Type': 'application/json'},
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error en rechazarViaje(): $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Actualizar ubicación en tiempo real
  // ==============================
  Future<bool> actualizarUbicacion({
    required int idViaje,
    required double lat,
    required double lng,
    required int idUsuario,
    required String tipo,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/$idViaje/actualizarUbicacion');
      final resp = await http.put(
        url,
        body: json.encode({
          'lat': lat,
          'lng': lng,
          'id_usuario': idUsuario,
          'tipo': tipo,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error en actualizarUbicacion(): $e');
      return false;
    }
  }

  // ==============================
  // ✅ NUEVO: Estado 6 "EN CAMINO AL ENCUENTRO"
  // Endpoint esperado: PUT /viajes/:id/enCamino  body: { id_conductor }
  // ==============================
  Future<bool> marcarEnCaminoEncuentro({
    required int idViaje,
    required int idConductor,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/$idViaje/enCamino');
      debugPrint('🚗 PUT $url');
      final resp = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_conductor': idConductor}),
      );

      debugPrint('📥 enCamino status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 200) {
        try {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map && decoded.containsKey('ok')) {
            return decoded['ok'] == true;
          }
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error en marcarEnCaminoEncuentro(): $e');
      return false;
    }
  }

  // ==============================
  // ✅ NUEVO: Obtener tarifa vigente (desde BD)
  // Endpoint esperado: GET /tarifas/vigente
  // Soporta respuesta {data:{...}} o directo {...}
  // ==============================
  Future<Map<String, dynamic>?> getTarifaVigente() async {
    try {
      final url = Uri.parse('$_baseUrl/tarifas/vigente');
      debugPrint('💲 GET $url');
      final resp = await http.get(url);

      if (resp.statusCode != 200) {
        debugPrint('⚠️ getTarifaVigente: ${resp.statusCode} ${resp.body}');
        return null;
      }

      final decoded = jsonDecode(resp.body);
      final raw = (decoded is Map && decoded['data'] != null)
          ? decoded['data']
          : decoded;

      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return raw.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('❌ Error en getTarifaVigente(): $e');
      return null;
    }
  }

  // ==============================
  // 🔹 Conductor llegó al punto de encuentro
  // ==============================
  Future<bool> llegarEncuentro({
    required int idViaje,
    required int idConductor,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/$idViaje/llegarEncuentro');
      debugPrint('🚦 PUT $url');
      debugPrint('📤 body: {"id_conductor": $idConductor}');

      final resp = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_conductor': idConductor}),
      );

      debugPrint('📥 llegarEncuentro status=${resp.statusCode}');
      debugPrint('📥 llegarEncuentro body=${resp.body}');

      if (resp.statusCode == 200) {
        try {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map && decoded.containsKey('ok')) {
            return decoded['ok'] == true;
          }
        } catch (_) {}
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error en llegarEncuentro(): $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Comenzar viaje (requiere id_conductor)
  // ==============================
  Future<bool> comenzarViaje(int idViaje, int idConductor) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/$idViaje/comenzar');
      debugPrint('PUT $url');

      final resp = await http.put(
        url,
        body: json.encode({'id_conductor': idConductor}),
        headers: {'Content-Type': 'application/json'},
      );

      if (resp.statusCode == 200) {
        debugPrint('✅ Viaje $idViaje marcado como EN CURSO');
        return true;
      } else {
        debugPrint(
          '⚠️ Error comenzarViaje($idViaje): ${resp.statusCode} → ${resp.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error en comenzarViaje(): $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Finalizar viaje (requiere id_conductor)
  // ==============================
  Future<bool> finalizarViaje({
    required int idViaje,
    required int idConductor,
    double? precioFinal,
    double? distanciaKm,
    double? duracionMin,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/$idViaje/finalizar');
      final body = jsonEncode({
        'id_conductor': idConductor,
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
  // ⭐ Calificar viaje
  // POST /calificaciones
  // tipo:
  //  - "CONDUCTOR_A_PASAJERO"
  //  - "PASAJERO_A_CONDUCTOR"
  // ==============================
  Future<Map<String, dynamic>> calificarViaje({
    required int idViaje,
    required int idCalificador,
    required String tipo,
    required int calificacion, // 1..5
    String? comentario,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/calificaciones');

      final body = {
        "id_viaje": idViaje,
        "id_calificador": idCalificador,
        "tipo": tipo,
        "calificacion": calificacion,
        "comentario": (comentario != null && comentario.trim().isNotEmpty)
            ? comentario.trim()
            : null,
      };

      final resp = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      // Intentamos parsear JSON siempre
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        data = {"ok": false, "message": resp.body};
      }

      // Normalizamos resultado
      if (resp.statusCode == 201) {
        return {"ok": true, ...data};
      }

      // Duplicado (ya calificó)
      if (resp.statusCode == 409) {
        return {
          "ok": false,
          "code": "DUPLICATE",
          "message":
              data["message"] ?? "Ya existe una calificación para este viaje",
        };
      }

      // Errores típicos 400/403/404
      return {
        "ok": false,
        "status": resp.statusCode,
        "message": data["message"] ?? "Error al calificar viaje",
        "data": data,
      };
    } catch (e) {
      return {"ok": false, "message": "Error de conexión: $e"};
    }
  }

  // ==============================
  // 🔹 Cancelar viaje
  // ==============================
  Future<bool> cancelarViaje({
    required int idViaje,
    required int idUsuario,
    required String tipo,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/$idViaje/cancelar');
      final resp = await http.put(
        url,
        body: json.encode({'id_usuario': idUsuario, 'tipo': tipo}),
        headers: {'Content-Type': 'application/json'},
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error en cancelarViaje(): $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Cambiar estado del conductor
  // ==============================
  Future<bool> cambiarEstadoConductor({
    required int idConductor,
    required bool conectado,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/conductores/cambiarEstado');
      debugPrint('🔁 Llamando a $url');

      final body = json.encode({
        'id_usuario': idConductor,
        'conectado': conectado ? 1 : 0,
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
          '⚠️ Error al cambiar estado del conductor: ${response.statusCode} → ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Excepción en cambiarEstadoConductor(): $e');
      return false;
    }
  }

  // ==============================
  // 🔹 Obtener tarifa vigente
  // ==============================
  Future<Map<String, dynamic>?> obtenerTarifaVigente() async {
    try {
      final url = Uri.parse('$_baseUrl/tarifas/vigente');
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final data = decoded['data'];
        if (data is Map) return Map<String, dynamic>.from(data);
        return null;
      }

      debugPrint(
        '⚠️ obtenerTarifaVigente HTTP ${resp.statusCode} → ${resp.body}',
      );
      return null;
    } catch (e) {
      debugPrint('❌ Error en obtenerTarifaVigente(): $e');
      return null;
    }
  }

  // ==============================
  // 🔹 Historial de viajes del usuario
  // ==============================
  Future<List<Map<String, dynamic>>> obtenerHistorialViajesUsuario(
    int idUsuario,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/historial/$idUsuario');
      final resp = await http.get(url);

      if (resp.statusCode != 200) {
        debugPrint('⚠️ Historial status=${resp.statusCode} body=${resp.body}');
        return [];
      }

      final decoded = jsonDecode(resp.body);

      final data = (decoded is Map<String, dynamic>)
          ? (decoded['data'] ?? [])
          : decoded;

      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ obtenerHistorialViajesUsuario(): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialViajesConductor(
    int idUsuario,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/historialConductor/$idUsuario');
      final resp = await http.get(url);

      if (resp.statusCode != 200) {
        debugPrint(
          '⚠️ Historial conductor status=${resp.statusCode} body=${resp.body}',
        );
        return [];
      }

      final decoded = jsonDecode(resp.body);
      final data = (decoded is Map<String, dynamic>)
          ? (decoded['data'] ?? [])
          : decoded;

      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ obtenerHistorialViajesConductor(): $e');
      return [];
    }
  }

  // ==============================
  // 📄 Detalle de viaje (conductor/pasajero)
  // GET /viajes/:id/detalle
  // ==============================
  Future<Map<String, dynamic>> getDetalleViaje(int idViaje) async {
    try {
      final url = Uri.parse('$_baseUrl/viajes/$idViaje/detalle');
      final resp = await http.get(url);

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        data = {"ok": false, "message": resp.body};
      }

      if (resp.statusCode == 200 && data["ok"] == true) {
        return {"ok": true, "data": data["data"]};
      }

      return {
        "ok": false,
        "status": resp.statusCode,
        "message": data["message"] ?? "Error obteniendo detalle del viaje",
        "data": data,
      };
    } catch (e) {
      return {"ok": false, "message": "Error de conexión: $e"};
    }
  }

  // ==============================
  // 🔹 Saldo Adeudado (Deuda Conductor)
  // ==============================
  Future<double?> obtenerSaldoAdeudado(int idConductor) async {
    try {
      final url = Uri.parse('$_baseUrl/deuda/$idConductor');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        return (decoded['saldo_adeudado'] as num).toDouble();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error en obtenerSaldoAdeudado(): $e');
      return null;
    }
  }

  Future<bool> pagarSaldoAdeudado(int idConductor) async {
    try {
      final url = Uri.parse('$_baseUrl/deuda/pagar');
      final body = jsonEncode({'id_conductor': idConductor});
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (resp.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error en pagarSaldoAdeudado(): $e');
      return false;
    }
  }
}
