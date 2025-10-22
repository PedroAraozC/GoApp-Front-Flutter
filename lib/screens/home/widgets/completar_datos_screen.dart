// lib/screens/home/completar_datos_screen.dart
import 'package:flutter/material.dart';
import 'package:go_app_flutter/screens/home/services/api_service.dart';
import '../../perfil/services/perfil_services.dart';

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
  late final TextEditingController generoController;

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
    _fetchGeneros();

    final u = widget.user;

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

    print(_dniController.text);
    print(_fechaController.text);
    final gRaw = u['id_genero'];
    _idGeneroSeleccionado = (gRaw is int)
        ? gRaw
        : int.tryParse('${gRaw ?? ''}');
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
      setState(() {
        _generos = lista;
      });
    } catch (e) {
      debugPrint('Error al obtener géneros: $e');
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
      final ok = await widget.api.actualizarUsuario(
        idUsuario: idUsuario,
        dni: _dniController.text.trim(),
        fechaNacimiento: _fechaController.text.trim(),
        idGenero: _idGeneroSeleccionado,
        telefonoUsuario: _telefonoController.text.trim(),
        email: _emailController.text.trim(), // backend mapea a email_usuario
      );

      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true); // ✔️ éxito
        print("Correctou");
        print(_dniController.text);
        print(_fechaController.text);
        print(_idGeneroSeleccionado);
        print(_telefonoController.text);
        print(_emailController.text);
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
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresá tu DNI' : null,
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
                    FocusScope.of(
                      context,
                    ).requestFocus(FocusNode()); // cierra el teclado

                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().subtract(
                        const Duration(days: 365 * 20),
                      ), // fecha inicial
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: const Locale(
                        'es',
                        'ES',
                      ), // 🇪🇸 calendario en español
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(
                                0xFF5A4FF1,
                              ), // color principal (morado)
                              onPrimary: Colors.white,
                              onSurface: Colors.black87,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF5A4FF1),
                              ),
                            ),
                          ),
                          child: child!,
                        );
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresá tu fecha de nacimiento'
                      : null,
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresá un teléfono'
                      : null,
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
