import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  //Map<String, dynamic>? _userData;
  bool _isEditing = false;
  bool _isLoading = true; // 🔹 Indicador de carga
  String? _errorMessage; // 🔹 Mensaje de error
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Controladores
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _generoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Copia de valores originales
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

  // 🔹 TRAER DATOS DEL BACKEND
Future<void> _fetchUserData() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final url = Uri.parse('http://192.168.1.13:3000/usuarios/obtenerUsuarioId/2');
    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Tiempo de espera agotado. Verifica tu conexión.');
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      // ✅ El backend devuelve { "result": [ { usuario } ] }
      final userList = decoded['result'] as List?;
      final user = (userList != null && userList.isNotEmpty) ? userList[0] : null;

      if (user != null && user is Map<String, dynamic>) {
        // 🔹 Parsear fecha
        String fechaNacimiento = '';
        try {
          if (user['fecha_nacimiento'] != null) {
            fechaNacimiento = DateFormat('dd/MM/yyyy').format(
              DateTime.parse(user['fecha_nacimiento']),
            );
          }
        } catch (_) {
          fechaNacimiento = '';
        }

        // 🔹 Mapear id_genero a texto
        String generoTexto = '';
        switch (user['id_genero']) {
          case 1:
            generoTexto = 'Masculino';
            break;
          case 2:
            generoTexto = 'Femenino';
            break;
          case 3:
            generoTexto = 'No binario';
            break;
          default:
            generoTexto = 'Prefiero no decirlo';
        }

        setState(() {
          _dniController.text = user['dni']?.toString() ?? '';
          _fechaController.text = fechaNacimiento;
          _generoController.text = generoTexto;
          _telefonoController.text = user['telefono_usuario'] ?? '';
          _emailController.text = user['email_usuario'] ?? '';
          _isLoading = false;
        });

        _saveOriginalValues();
      } else {
        setState(() {
          _errorMessage = 'No se encontraron datos del usuario.';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Error al cargar datos: ${response.statusCode}';
        _isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Error de conexión: ${e.toString()}';
      _isLoading = false;
    });
    debugPrint('Error al obtener datos: $e');
  }
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
    _showAnimatedSnackBar("Cambios cancelados", color: Colors.grey);
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
    if (!_isEditing) {
      _showAnimatedSnackBar(
        "Perfil actualizado con éxito",
        color: Colors.green,
      );
      _saveOriginalValues();
    }
  }

  void _showAnimatedSnackBar(String message, {Color color = Colors.green}) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(begin: const Offset(-1, 0), end: const Offset(0, 0)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutExpo,
          builder: (context, offset, child) {
            return SlideTransition(
              position: AlwaysStoppedAnimation(offset),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        color == Colors.grey
                            ? Icons.close_rounded
                            : Icons.check_circle,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
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
                      CircularProgressIndicator(
                        color: Color(0xFF3F51B5),
                      ),
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
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF1E1E1E),
                                fontSize: 16,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const CircleAvatar(
                              radius: 70,
                              backgroundImage: AssetImage(
                                "assets/images/woman_profile.png",
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Perfil del Usuario",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _emailController.text,
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 24),

                          // FORM
                          Form(
                            key: _formKey,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 5,
                              shadowColor: Colors.black26,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _infoField(
                                      Icons.badge_rounded,
                                      "DNI",
                                      _dniController,
                                    ),
                                    _divider(),
                                    _infoField(
                                      Icons.cake_rounded,
                                      "Fecha de Nacimiento",
                                      _fechaController,
                                    ),
                                    _divider(),
                                    _infoField(
                                      Icons.person_rounded,
                                      "Género",
                                      _generoController,
                                    ),
                                    _divider(),
                                    _infoField(
                                      Icons.phone_rounded,
                                      "Teléfono",
                                      _telefonoController,
                                    ),
                                    _divider(),
                                    _infoField(
                                      Icons.email_rounded,
                                      "Email",
                                      _emailController,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          if (_isEditing)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _restoreOriginalValues,
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  label: const Text(
                                    "Cancelar",
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      _toggleEdit();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.save_rounded,
                                    color: Colors.white,
                                  ),
                                  label: const Text("Guardar"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3F51B5),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 14,
                                    ),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 6,
                                  ),
                                ),
                              ],
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _toggleEdit,
                              icon: const Icon(Icons.edit_rounded, color: Colors.white),
                              label: const Text("Editar perfil"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3F51B5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 14,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 6,
                              ),
                            ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _infoField(
    IconData icon,
    String label,
    TextEditingController controller,
  ) {
    final List<String> generos = [
      "Masculino",
      "Femenino",
      "No binario",
      "Prefiero no decirlo",
      "Otro",
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blueGrey[700]),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: _isEditing
                ? (label == "Fecha de Nacimiento"
                      ? GestureDetector(
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.tryParse(_toDate(controller.text)) ??
                                  DateTime(1990, 1, 1),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              locale: const Locale('es', 'ES'),
                            );
                            if (pickedDate != null) {
                              String formattedDate = DateFormat(
                                'dd/MM/yyyy',
                              ).format(pickedDate);
                              setState(() => controller.text = formattedDate);
                            }
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: controller,
                              textAlign: TextAlign.right,
                              readOnly: true,
                              style: const TextStyle(fontSize: 12),
                              decoration: _inputDecoration().copyWith(
                                suffixIcon: const Icon(
                                  Icons.calendar_today_rounded,
                                  color: Colors.indigo,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        )
                      : label == "Género"
                      ? DropdownButtonFormField<String>(
                          initialValue: controller.text.isNotEmpty
                              ? controller.text
                              : generos.first,
                          onChanged: (value) =>
                              setState(() => controller.text = value!),
                          items: generos
                              .map(
                                (g) => DropdownMenuItem<String>(
                                  value: g,
                                  child: Text(
                                    g,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          decoration: _inputDecoration(),
                          icon: const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Colors.indigo,
                          ),
                        )
                      : TextFormField(
                          focusNode: _focusNodes[label],
                          controller: controller,
                          textAlign: TextAlign.right,
                          keyboardType: label == "Email"
                              ? TextInputType.emailAddress
                              : TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: _inputDecoration(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Campo obligatorio";
                            }
                            if (label == "Email") {
                              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                              if (!emailRegex.hasMatch(value)) {
                                return "Ingrese un email válido";
                              }
                            }
                            return null;
                          },
                        ))
                : Text(
                    controller.text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueGrey, width: 0.6),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.indigoAccent, width: 1.2),
      ),
    );
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

  Widget _divider() =>
      const Divider(color: Colors.black12, thickness: 1, height: 4);

  @override
  void dispose() {
    _scrollController.dispose();
    _dniController.dispose();
    _fechaController.dispose();
    _generoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}