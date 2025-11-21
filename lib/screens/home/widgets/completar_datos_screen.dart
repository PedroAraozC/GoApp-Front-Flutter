// lib/screens/home/completar_datos_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../../../services/perfil_services.dart';

class CompletarDatosScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService api;

  const CompletarDatosScreen({
    super.key,
    required this.user,
    required this.api,
  });

  @override
  State<CompletarDatosScreen> createState() => _CompletarDatosScreenState();
}

class _CompletarDatosScreenState extends State<CompletarDatosScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _dniController;
  late final TextEditingController _fechaController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _emailController;

  // Dropdown género
  List<Map<String, dynamic>> _generos = [];
  int? _idGeneroSeleccionado;

  bool _saving = false;

  String _clean(dynamic v) {
    if (v == null) return '';
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return '';
      if (s.toLowerCase() == 'null') return '';
      return s;
    }
    return '$v';
  }

  @override
  void initState() {
    super.initState();

    final u = widget.user;
    debugPrint('🧾 [CompletarDatosScreen] user recibido: $u');

    _dniController = TextEditingController(
      text: _clean(u['dni'] ?? u['dni_usuario']),
    );
    _fechaController = TextEditingController(
      text: _clean(u['fecha_nacimiento'] ?? u['fechaNacimiento']),
    );
    _telefonoController = TextEditingController(
      text: _clean(u['telefono'] ?? u['telefono_usuario']),
    );
    _emailController = TextEditingController(
      text: _clean(u['email'] ?? u['email_usuario']),
    );

    final gRaw = u['id_genero'] ?? u['idGenero'];
    _idGeneroSeleccionado = (gRaw is int)
        ? gRaw
        : int.tryParse('${gRaw ?? ''}');

    debugPrint(
      '📌 Valores iniciales -> DNI: ${_dniController.text}, '
      'Fecha: ${_fechaController.text}, '
      'Teléfono: ${_telefonoController.text}, '
      'Email: ${_emailController.text}, '
      'id_genero: $_idGeneroSeleccionado',
    );

    _fetchGeneros();
  }

  @override
  void dispose() {
    _dniController.dispose();
    _fechaController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchGeneros() async {
    final service = PerfilService();
    try {
      final lista = await service.obtenerGeneros();
      debugPrint('📥 Géneros recibidos: $lista');

      setState(() {
        _generos = lista;
      });

      // Si no hay género seleccionado pero el user traía uno compatible, lo dejamos
      if (_idGeneroSeleccionado != null) {
        final existe = _generos.any(
          (g) => (g['id_genero'] as int?) == _idGeneroSeleccionado,
        );
        if (!existe) {
          debugPrint(
            '⚠️ El id_genero=$_idGeneroSeleccionado no está en la lista de géneros.',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error al obtener géneros: $e');
    }
  }

  Future<void> _onGuardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final idUsuario = widget.user['id_usuario'];
    if (idUsuario == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró id_usuario.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      debugPrint('📤 Enviando actualización de usuario:');
      debugPrint('   id_usuario: $idUsuario');
      debugPrint('   dni: ${_dniController.text.trim()}');
      debugPrint('   fecha_nacimiento: ${_fechaController.text.trim()}');
      debugPrint('   id_genero: $_idGeneroSeleccionado');
      debugPrint('   telefono_usuario: ${_telefonoController.text.trim()}');
      debugPrint('   email_usuario: ${_emailController.text.trim()}');

      final ok = await widget.api.actualizarUsuario(
        idUsuario: idUsuario,
        dni: _dniController.text.trim(),
        fechaNacimiento: _fechaController.text.trim(),
        idGenero: _idGeneroSeleccionado,
        telefonoUsuario: _telefonoController.text.trim(),
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      if (ok) {
        // ✅ Guardamos los datos actualizados localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('id_usuario', idUsuario);
        await prefs.setString('dni', _dniController.text.trim());
        await prefs.setString('fecha_nacimiento', _fechaController.text.trim());
        await prefs.setInt('id_genero', _idGeneroSeleccionado ?? 0);
        await prefs.setString(
          'telefono_usuario',
          _telefonoController.text.trim(),
        );
        await prefs.setString('email_usuario', _emailController.text.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados correctamente ✅')),
        );

        Navigator.pop(context, true); // Éxito → devolvemos true
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar los cambios.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onCancelar() => Navigator.pop(context, false);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final insets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Completa tu perfil',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: _onCancelar,
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Necesitamos algunos datos más para que puedas iniciar un viaje.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                // DNI
                TextFormField(
                  controller: _dniController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'DNI'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresá tu DNI';
                    }
                    final dni = v.trim();
                    if (!RegExp(r'^\d+$').hasMatch(dni)) {
                      return 'El DNI solo puede contener números';
                    }
                    if (dni.length < 6 || dni.length > 8) {
                      return 'El DNI debe tener entre 6 y 8 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Fecha de nacimiento
                TextFormField(
                  controller: _fechaController,
                  readOnly: true, // 🔒 evita escribir manualmente
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                  ),
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());

                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().subtract(
                        const Duration(days: 365 * 20),
                      ),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: const Locale('es', 'ES'),
                      builder: (context, child) {
                        return Theme(data: Theme.of(context), child: child!);
                      },
                    );

                    if (pickedDate != null) {
                      final formattedDate =
                          "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                      setState(() {
                        _fechaController.text = formattedDate;
                      });
                    }
                  },
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresá tu fecha de nacimiento';
                    }
                    try {
                      final parts = v.split('-');
                      if (parts.length != 3) return 'Fecha inválida';

                      final year = int.parse(parts[0]);
                      final month = int.parse(parts[1]);
                      final day = int.parse(parts[2]);

                      final birthDate = DateTime(year, month, day);
                      final today = DateTime.now();
                      final age =
                          today.year -
                          birthDate.year -
                          ((today.month < birthDate.month ||
                                  (today.month == birthDate.month &&
                                      today.day < birthDate.day))
                              ? 1
                              : 0);

                      if (age > 110) {
                        return 'La edad no puede superar los 110 años';
                      }
                      if (age < 0) {
                        return 'La fecha no puede ser futura';
                      }
                    } catch (e) {
                      return 'Fecha inválida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Género
                DropdownButtonFormField<int>(
                  initialValue: _idGeneroSeleccionado,
                  items: _generos
                      .map(
                        (g) => DropdownMenuItem<int>(
                          value: g['id_genero'] as int,
                          child: Text(g['nombre_genero'] as String),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Género'),
                  onChanged: (v) => setState(() => _idGeneroSeleccionado = v),
                  validator: (v) => (v == null) ? 'Elegí un género' : null,
                ),
                const SizedBox(height: 12),

                // Teléfono
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresá un teléfono';
                    }
                    final telefono = v.trim().replaceAll(
                      RegExp(r'[\s\-\(\)]'),
                      '',
                    );
                    if (!RegExp(r'^\d+$').hasMatch(telefono)) {
                      return 'El teléfono solo puede contener números';
                    }
                    if (telefono.length < 10 || telefono.length > 15) {
                      return 'El teléfono debe tener entre 10 y 15 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresá un email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _onCancelar,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _onGuardar,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
