// lib/screens/perfil/perfil_datos_screen.dart
import 'package:flutter/material.dart';
import 'widgets/perfil_form.dart'; // ajustá el import si hace falta

class DatosScreen extends StatefulWidget {
  final int? userId;
  const DatosScreen({super.key, this.userId});

  @override
  State<DatosScreen> createState() => _DatosScreenState();
}

class _DatosScreenState extends State<DatosScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _dniController = TextEditingController();
  final _fechaController = TextEditingController();
  final _generoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  // FocusNodes (uno por campo)
  final Map<String, FocusNode> _focusNodes = {
    'dni': FocusNode(),
    'fecha': FocusNode(),
    'genero': FocusNode(),
    'telefono': FocusNode(),
    'email': FocusNode(),
  };

  List<Map<String, dynamic>> _generos = [];

  void _handleGuardar() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Datos guardados correctamente')),
      );
    }
  }

  void _handleCancelar() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('❌ Edición cancelada')));
    Navigator.pop(context);
  }

  void _handleEditar() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✏️ Modo edición activado')));
  }

  @override
  void dispose() {
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    _dniController.dispose();
    _fechaController.dispose();
    _generoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis datos personales')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PerfilForm(
          formKey: _formKey,
          focusNodes: _focusNodes,
          isEditing: true,
          dniController: _dniController,
          fechaController: _fechaController,
          generos: _generos,
          generoController: _generoController,
          telefonoController: _telefonoController,
          emailController: _emailController,

          // 🔹 Callbacks obligatorios
          onGuardar: _handleGuardar,
          onCancelar: _handleCancelar,
          onEditar: _handleEditar,
        ),
      ),
    );
  }
}
