import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../perfil/services/perfil_services.dart';
import 'widgets/perfil_form.dart';

class DatosScreen extends StatefulWidget {
  final int? userId;
  final Map<String, dynamic>? initialUser;
  const DatosScreen({super.key, this.userId, this.initialUser});

  @override
  State<DatosScreen> createState() => _DatosScreenState();
}

class _DatosScreenState extends State<DatosScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  Map<String, dynamic>? _userData;

  final _dniController = TextEditingController();
  final _fechaController = TextEditingController();
  final _generoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  final Map<String, FocusNode> _focusNodes = {
    'dni': FocusNode(),
    'fecha': FocusNode(),
    'genero': FocusNode(),
    'telefono': FocusNode(),
    'email': FocusNode(),
  };

  List<Map<String, dynamic>> _generos = [];

  @override
  void initState() {
    super.initState();

    if (widget.initialUser != null) {
      _loadFromInitialUser(widget.initialUser!);
    }
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = widget.userId ?? prefs.getInt('id_usuario');
      if (id == null) return;

      final service = PerfilService();
      final user = await service.obtenerUsuarioPorId(id);

      debugPrint('🧾 Usuario cargado en DatosScreen: $user');

      if (user != null) {
        setState(() {
          _userData = user;
          _dniController.text = user['dni']?.toString() ?? '';
          _telefonoController.text = user['telefono_usuario']?.toString() ?? '';
          _emailController.text = user['email_usuario'] ?? '';
          _fechaController.text = user['fecha_nacimiento'] ?? '';
          _generoController.text = user['id_genero']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error al cargar DatosScreen: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis datos personales')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PerfilForm(
          formKey: _formKey,
          focusNodes: _focusNodes,
          isEditing: false,
          dniController: _dniController,
          fechaController: _fechaController,
          generos: _generos,
          generoController: _generoController,
          telefonoController: _telefonoController,
          emailController: _emailController,
          onGuardar: () {},
          onCancelar: () {},
          onEditar: () {},
        ),
      ),
    );
  }

  void _loadFromInitialUser(Map<String, dynamic> user) {
    setState(() {
      _userData = user;
      _dniController.text = user['dni']?.toString() ?? '';
      _telefonoController.text = user['telefono']?.toString() ?? '';
      _emailController.text = user['email'] ?? '';
      _fechaController.text = user['fecha_nacimiento'] ?? '';
      _generoController.text = user['id_genero']?.toString() ?? '';
      _loading = false;
    });
  }
}
