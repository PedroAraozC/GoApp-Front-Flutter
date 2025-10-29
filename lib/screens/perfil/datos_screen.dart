import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/perfil_services.dart';
import '../perfil/widgets/perfil_form.dart';

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
  bool _isEditing = false;

  Map<String, dynamic>? _userData;

  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _dniController = TextEditingController();
  final _fechaController = TextEditingController();
  final _generoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  final Map<String, FocusNode> _focusNodes = {
    'nombre': FocusNode(),
    'apellido': FocusNode(),
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
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_fetchUser(), _fetchGeneros()]);
    _sincronizarNombreGenero();
    setState(() => _loading = false);
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
        _userData = user;
        _nombreController.text =
            user['nombre_usuario'] ?? user['nombre'] ?? '';
        _apellidoController.text =
            user['apellido_usuario'] ?? user['apellido'] ?? '';
        _dniController.text = (user['dni'] ?? '').toString();
        _telefonoController.text =
            (user['telefono_usuario'] ?? user['telefono'] ?? '').toString();
        _emailController.text = user['email_usuario'] ?? user['email'] ?? '';
        _fechaController.text = user['fecha_nacimiento'] ?? '';
        _generoController.text = (user['id_genero'] ?? '').toString();
      }
    } catch (e) {
      debugPrint('❌ Error al cargar usuario en DatosScreen: $e');
    }
  }

  Future<void> _fetchGeneros() async {
    try {
      final service = PerfilService();
      final lista = await service.obtenerGeneros();
      _generos = List<Map<String, dynamic>>.from(lista);
    } catch (e) {
      debugPrint('❌ Error al cargar géneros: $e');
    }
  }

  void _sincronizarNombreGenero() {
    final text = _generoController.text.trim();
    final idAsInt = int.tryParse(text);
    if (idAsInt == null) return;
    final nombre = _nombreGeneroFromId(idAsInt);
    _generoController.text = nombre ?? '';
  }

  String? _nombreGeneroFromId(int idGenero) {
    try {
      final found = _generos.firstWhere(
        (g) => (g['id_genero'] == idGenero),
        orElse: () => {},
      );
      final nombre = found['nombre_genero'];
      if (nombre is String && nombre.isNotEmpty) return nombre;
      return null;
    } catch (_) {
      return null;
    }
  }

  int? _idGeneroFromNombre(String nombre) {
    try {
      final found = _generos.firstWhere(
        (g) =>
            (g['nombre_genero']?.toString().toLowerCase() ?? '') ==
            nombre.toLowerCase(),
        orElse: () => {},
      );
      final id = found['id_genero'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final id = widget.userId ?? prefs.getInt('id_usuario');
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo identificar al usuario.')),
        );
        return;
      }

      final idGenero = _idGeneroFromNombre(_generoController.text.trim());

      final payload = <String, dynamic>{
        'nombre_usuario': _nombreController.text.trim().isEmpty
            ? null
            : _nombreController.text.trim(),
        'apellido_usuario': _apellidoController.text.trim().isEmpty
            ? null
            : _apellidoController.text.trim(),
        'dni': _dniController.text.trim().isEmpty
            ? null
            : _dniController.text.trim(),
        'fecha_nacimiento': _fechaController.text.trim().isEmpty
            ? null
            : _fechaController.text.trim(),
        'id_genero': idGenero,
        'telefono_usuario': _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        'email_usuario': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      };

      payload.removeWhere((key, value) => value == null);

      final service = PerfilService();
      final ok = await service.actualizarUsuario(id, payload);

      if (ok) {
        // ✅ Guardar datos en SharedPreferences
        await prefs.setString('nombre_usuario', _nombreController.text.trim());
        await prefs.setString('apellido_usuario', _apellidoController.text.trim());
        await prefs.setString('dni', _dniController.text.trim());
        await prefs.setString('fecha_nacimiento', _fechaController.text.trim());
        if (idGenero != null) await prefs.setInt('id_genero', idGenero);
        await prefs.setString(
            'telefono_usuario', _telefonoController.text.trim());
        await prefs.setString('email_usuario', _emailController.text.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados correctamente ✅')),
        );

        await _fetchUser();
        _sincronizarNombreGenero();
        setState(() => _isEditing = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudieron actualizar los datos.')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al guardar cambios: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  void _cancelarEdicion() {
    if (_userData != null) {
      _nombreController.text = _userData!['nombre_usuario'] ?? '';
      _apellidoController.text = _userData!['apellido_usuario'] ?? '';
      _dniController.text = (_userData!['dni'] ?? '').toString();
      _telefonoController.text =
          (_userData!['telefono_usuario'] ?? _userData!['telefono'] ?? '')
              .toString();
      _emailController.text =
          _userData!['email_usuario'] ?? _userData!['email'] ?? '';
      _fechaController.text = _userData!['fecha_nacimiento'] ?? '';

      final idGenero = _userData!['id_genero'];
      if (idGenero != null) {
        final nombre = _nombreGeneroFromId(
          idGenero is String ? int.tryParse(idGenero) ?? -1 : idGenero as int,
        );
        _generoController.text = nombre ?? '';
      } else {
        _generoController.text = '';
      }
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis datos personales'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PerfilForm(
          formKey: _formKey,
          focusNodes: _focusNodes,
          isEditing: _isEditing,
          nombreController: _nombreController,
          apellidoController: _apellidoController,
          dniController: _dniController,
          fechaController: _fechaController,
          generos: _generos,
          generoController: _generoController,
          telefonoController: _telefonoController,
          emailController: _emailController,
          onGuardar: _guardarCambios,
          onCancelar: _cancelarEdicion,
          onEditar: () => setState(() => _isEditing = true),
        ),
      ),
    );
  }

  void _loadFromInitialUser(Map<String, dynamic> user) {
    _userData = user;
    _nombreController.text = user['nombre_usuario'] ?? user['nombre'] ?? '';
    _apellidoController.text = user['apellido_usuario'] ?? user['apellido'] ?? '';
    _dniController.text = (user['dni'] ?? '').toString();
    _telefonoController.text =
        (user['telefono_usuario'] ?? user['telefono'] ?? '').toString();
    _emailController.text = user['email_usuario'] ?? user['email'] ?? '';
    _fechaController.text = user['fecha_nacimiento'] ?? '';
    _generoController.text = (user['id_genero'] ?? '').toString();
    _loading = false;
  }

  @override
  void dispose() {
    for (final fn in _focusNodes.values) {
      fn.dispose();
    }
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    _fechaController.dispose();
    _generoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
