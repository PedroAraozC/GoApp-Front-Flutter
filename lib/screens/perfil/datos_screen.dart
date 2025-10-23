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
  bool _isEditing = false;

  Map<String, dynamic>? _userData;

  final _dniController = TextEditingController();
  final _fechaController = TextEditingController();
  final _generoController =
      TextEditingController(); // Guardará el NOMBRE del género
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  final Map<String, FocusNode> _focusNodes = {
    'dni': FocusNode(),
    'fecha': FocusNode(),
    'genero': FocusNode(),
    'telefono': FocusNode(),
    'email': FocusNode(),
  };

  /// Lista de géneros: [{id_genero: int, nombre_genero: String}, ...]
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
    // Una vez que tenemos user y generos, sincronizamos el nombre del género
    _sincronizarNombreGenero();
    setState(() {
      _loading = false;
    });
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
        _dniController.text = (user['dni'] ?? '').toString();
        _telefonoController.text =
            (user['telefono_usuario'] ?? user['telefono'] ?? '').toString();
        _emailController.text = user['email_usuario'] ?? user['email'] ?? '';
        _fechaController.text = user['fecha_nacimiento'] ?? '';
        // temporalmente guardo el ID como texto; luego lo convertiré a nombre
        _generoController.text = (user['id_genero'] ?? '').toString();
      }
    } catch (e) {
      debugPrint('❌ Error al cargar usuario en DatosScreen: $e');
    }
  }

  Future<void> _fetchGeneros() async {
    try {
      final service = PerfilService();
      final lista = await service
          .obtenerGeneros(); // <-- ajusta si tu método se llama distinto
      if (lista is List) {
        _generos = List<Map<String, dynamic>>.from(lista);
      }
    } catch (e) {
      debugPrint('❌ Error al cargar géneros: $e');
    }
  }

  /// Convierte el id_genero actual (si está en el controller) al nombre correspondiente
  void _sincronizarNombreGenero() {
    final text = _generoController.text.trim();
    // Si ya es un nombre (no un número), no hacemos nada
    final idAsInt = int.tryParse(text);
    if (idAsInt == null) return;

    final nombre = _nombreGeneroFromId(idAsInt);
    if (nombre != null) {
      _generoController.text = nombre;
    } else {
      // Si no lo encuentra, deja el campo vacío para evitar mostrar un id
      _generoController.text = '';
    }
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

      // Limpia claves con null para no sobreescribir en backend si no corresponde
      payload.removeWhere((key, value) => value == null);

      final service = PerfilService();
      final ok = await service.actualizarUsuario(id, payload);

      if (ok) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados correctamente.')),
        );
        // Refrescar desde backend para mostrar lo último
        await _fetchUser();
        _sincronizarNombreGenero();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron actualizar los datos.')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al guardar cambios: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  void _cancelarEdicion() {
    // Restauro valores desde _userData
    if (_userData != null) {
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
          dniController: _dniController,
          fechaController: _fechaController,
          generos: _generos, // ✅ Ahora enviamos la lista de géneros
          generoController:
              _generoController, // ✅ Contiene el NOMBRE del género
          telefonoController: _telefonoController,
          emailController: _emailController,
          onGuardar: _guardarCambios,
          onCancelar: _cancelarEdicion,
          onEditar: () => setState(() => _isEditing = true),
        ),
      ),
      // Si no usas botones dentro del PerfilForm, puedes agregar actions abajo:
      bottomNavigationBar: !_isEditing
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelarEdicion,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _guardarCambios,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _loadFromInitialUser(Map<String, dynamic> user) {
    _userData = user;
    _dniController.text = (user['dni'] ?? '').toString();
    _telefonoController.text =
        (user['telefono_usuario'] ?? user['telefono'] ?? '').toString();
    _emailController.text = user['email_usuario'] ?? user['email'] ?? '';
    _fechaController.text = user['fecha_nacimiento'] ?? '';

    // Si initialUser trae id_genero, lo dejamos temporalmente. Luego, cuando
    // carguen los géneros, lo convertimos a nombre en _sincronizarNombreGenero().
    _generoController.text = (user['id_genero'] ?? '').toString();

    _loading = false;
  }

  @override
  void dispose() {
    for (final fn in _focusNodes.values) {
      fn.dispose();
    }
    _dniController.dispose();
    _fechaController.dispose();
    _generoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
