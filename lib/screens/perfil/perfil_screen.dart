import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../perfil/services/perfil_services.dart';
import '../perfil/widgets/perfil_heder.dart';
import '../perfil/widgets/perfil_form.dart';
import '../perfil/widgets/perfil_snackbar.dart';

class PerfilScreen extends StatefulWidget {
  final int? userId;
  const PerfilScreen({super.key, this.userId});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isEditing = false;
  String? _errorMessage;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _generos = [];

  // Controladores
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _generoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  late Map<String, String> _originalValues;

  final Map<String, FocusNode> _focusNodes = {
    "DNI": FocusNode(),
    "Teléfono": FocusNode(),
    "Email": FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchGeneros();

    // Scroll automático al editar campos
    for (var node in _focusNodes.entries) {
      node.value.addListener(() {
        if (node.value.hasFocus) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _scrollController.animateTo(
              _scrollController.offset + 150,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          });
        }
      });
    }
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

  // 🔹 Obtener datos del usuario
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final int id = widget.userId ?? 2;
    final service = PerfilService();

    try {
      final user = await service.obtenerUsuarioPorId(id);
      if (user == null) {
        setState(() {
          _errorMessage = "No se encontraron datos del usuario.";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _userData = user;
        _mapUserToControllers(user);
        _isLoading = false;
      });

      _saveOriginalValues();
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }

  void _mapUserToControllers(Map<String, dynamic> user) {
    String fechaNacimiento = '';
    try {
      if (user['fecha_nacimiento'] != null &&
          (user['fecha_nacimiento'] as String).isNotEmpty) {
        fechaNacimiento = DateFormat(
          'dd/MM/yyyy',
        ).format(DateTime.parse(user['fecha_nacimiento']));
      }
    } catch (_) {
      fechaNacimiento = '';
    }

    String generoTexto = '';
    if (_generos.isNotEmpty && user['id_genero'] != null) {
      final generoEncontrado = _generos.firstWhere(
        (g) => g['id_genero'] == user['id_genero'],
        orElse: () => {'nombre_genero': 'Sin especificar'},
      );
      generoTexto = generoEncontrado['nombre_genero'] ?? 'Sin especificar';
    } else {
      generoTexto = 'Sin especificar';
    }

    _dniController.text = user['dni']?.toString() ?? '';
    _fechaController.text = fechaNacimiento;
    _generoController.text = generoTexto;
    _telefonoController.text = user['telefono_usuario'] ?? '';
    _emailController.text = user['email_usuario'] ?? '';
  }

  void _saveOriginalValues() {
    _originalValues = {
      "DNI": _dniController.text,
      "Fecha": _fechaController.text,
      "Género": _generoController.text,
      "Teléfono": _telefonoController.text,
      "Email": _emailController.text,
    };
  }

  void _restoreOriginalValues() {
    setState(() {
      _dniController.text = _originalValues["DNI"]!;
      _fechaController.text = _originalValues["Fecha"]!;
      _generoController.text = _originalValues["Género"]!;
      _telefonoController.text = _originalValues["Teléfono"]!;
      _emailController.text = _originalValues["Email"]!;
      _isEditing = false;
    });

    PerfilSnackBar.show(
      context,
      message: "Cambios cancelados",
      color: Colors.grey,
    );
  }

  Future<void> _guardarDatos() async {
    final int id = widget.userId ?? 2;
    final service = PerfilService();

    setState(() => _isLoading = true);

    final body = {
      "dni": _dniController.text,
      "fecha_nacimiento": _toDate(_fechaController.text),
      "id_genero": _mapGeneroToId(_generoController.text),
      "telefono_usuario": _telefonoController.text,
      "email": _emailController.text,
    };

    final success = await service.actualizarUsuario(id, body);

    setState(() {
      _isLoading = false;
      if (success) {
        _isEditing = false;
        _fetchUserData();
        PerfilSnackBar.show(
          context,
          message: "Perfil actualizado correctamente",
          color: Colors.green,
        );
      } else {
        _errorMessage = "Error al actualizar el perfil.";
      }
    });
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
    if (!_isEditing) {
      PerfilSnackBar.show(
        context,
        message: "Perfil actualizado con éxito",
        color: Colors.green,
      );
      _saveOriginalValues();
    }
  }

  int _mapGeneroToId(String genero) {
    final encontrado = _generos.firstWhere(
      (g) =>
          g['nombre_genero']?.toString().trim().toLowerCase() ==
          genero.trim().toLowerCase(),
      orElse: () => {'id_genero': 4},
    );
    return encontrado['id_genero'] ?? 4;
  }

  String _toDate(String value) {
    try {
      final parts = value.split('/');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (_) {}
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final nombreCompleto = _userData != null
        ? "${_userData!['nombre_usuario']} ${_userData!['apellido_usuario']}"
        : "Cargando perfil...";

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF2F3), Color(0xFFDDE1E7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF3F51B5)),
                      SizedBox(height: 16),
                      Text(
                        "Cargando datos del perfil...",
                        style: TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      PerfilHeader(
                        nombreCompleto: nombreCompleto,
                        email: _emailController.text,
                      ),
                      PerfilForm(
                        isEditing: _isEditing,
                        formKey: _formKey,
                        dniController: _dniController,
                        fechaController: _fechaController,
                        generoController: _generoController,
                        telefonoController: _telefonoController,
                        emailController: _emailController,
                        focusNodes: _focusNodes,
                        onGuardar: _guardarDatos,
                        generos: _generos,
                        onCancelar: _restoreOriginalValues,
                        onEditar: _toggleEdit,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? "Error desconocido",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF1E1E1E), fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchUserData,
            icon: const Icon(Icons.refresh),
            label: const Text("Reintentar"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var c in [
      _dniController,
      _fechaController,
      _generoController,
      _telefonoController,
      _emailController,
    ]) {
      c.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}
