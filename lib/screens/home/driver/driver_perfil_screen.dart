import 'package:flutter/material.dart';
import 'package:taxi_tuc/services/api_service.dart';
import 'package:taxi_tuc/services/user_preferences.dart';
import 'package:taxi_tuc/screens/auth/auth_screen.dart';
import 'package:taxi_tuc/services/socket_service.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService.instance;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  Future<void> _loadPerfil() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final idUsuario = await UserPreferences.getIdUsuario();
      if (idUsuario == null) {
        throw Exception("No hay sesión iniciada (id_usuario no encontrado).");
      }

      final data = await _api.obtenerUsuarioPorId(idUsuario);
      if (!mounted) return;

      setState(() {
        _user = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? "—" : value)),
        ],
      ),
    );
  }

  String _get(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return "";
  }

  int? _getInt(Map<String, dynamic> m, List<String> keys) {
    final s = _get(m, keys);
    if (s.trim().isEmpty) return null;
    return int.tryParse(s.trim());
  }

  Future<void> _openEdit() async {
    final user = _user;
    if (user == null) return;

    final idUsuarioStr = _get(user, ["id_usuario"]);
    final idUsuario = int.tryParse(idUsuarioStr);
    if (idUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo obtener el id_usuario.")),
      );
      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverEditProfileScreen(
          idUsuario: idUsuario,
          nombre: _get(user, ["nombres", "nombre_usuario"]),
          apellido: _get(user, ["apellido_usuario"]),
          email: _get(user, ["email_usuario", "email"]),
          telefono: _get(user, ["telefono_usuario", "telefono"]),
          dni: _get(user, ["dni"]),
          fechaNacimiento: _get(user, ["fecha_nacimiento"]),
          idGenero: _getInt(user, ["id_genero"]),
        ),
      ),
    );

    if (saved == true) {
      await _loadPerfil();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Datos actualizados")));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Convertir ID de género a texto
  String _generoTexto(int? idGenero) {
    switch (idGenero) {
      case 1:
        return "Femenino";
      case 2:
        return "Masculino";
      default:
        return "—";
    }
  }

  //Cerrar Sesion
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que querés cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // notificar desconexión por socket antes de borrar prefs
      final user = await UserPreferences.getUser();
      final idUsuario = user?['id_usuario'];
      if (idUsuario != null) {
        await _socket.disconnectAndNotify(
          idUsuario: idUsuario,
          tipo: 'conductor',
        );
      }

      await UserPreferences.fullLogout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      if (!mounted) return;
      _showSnack('Error al cerrar sesión');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil (Conductor)"),
        actions: [
          IconButton(
            tooltip: "Editar",
            onPressed: (_loading || _user == null) ? null : _openEdit,
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: "Actualizar",
            onPressed: _loadPerfil,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPerfil,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) ...[
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 10),
              const Center(child: Text("Cargando perfil...")),
            ] else if (_error != null) ...[
              Text(
                "❌ Error:\n\n$_error",
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadPerfil,
                icon: const Icon(Icons.refresh),
                label: const Text("Reintentar"),
              ),
            ] else if (user == null) ...[
              const Text("No se encontraron datos del usuario."),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadPerfil,
                icon: const Icon(Icons.refresh),
                label: const Text("Reintentar"),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _item(
                        "Nombre",
                        _get(user, ["nombres", "nombre_usuario"]),
                      ),
                      _item("Apellido", _get(user, ["apellido_usuario"])),
                      _item("Email", _get(user, ["email_usuario", "email"])),
                      _item(
                        "Teléfono",
                        _get(user, ["telefono_usuario", "telefono"]),
                      ),
                      _item("DNI", _get(user, ["dni"])),
                      _item("Fecha nac.", _get(user, ["fecha_nacimiento"])),
                      _item(
                        "Género",
                        _generoTexto(_getInt(user, ["id_genero"])),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _openEdit,
                icon: const Icon(Icons.edit),
                label: const Text("Editar datos"),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("Cerrar sesión"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DriverEditProfileScreen extends StatefulWidget {
  final int idUsuario;

  // Solo lectura (por backend actual)
  final String nombre;
  final String apellido;

  // Editables (por backend actual)
  final String email;
  final String telefono;
  final String dni;
  final String fechaNacimiento; // "YYYY-MM-DD" ideal
  final int? idGenero;

  const DriverEditProfileScreen({
    super.key,
    required this.idUsuario,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.telefono,
    required this.dni,
    required this.fechaNacimiento,
    required this.idGenero,
  });

  @override
  State<DriverEditProfileScreen> createState() =>
      _DriverEditProfileScreenState();
}

class _DriverEditProfileScreenState extends State<DriverEditProfileScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _dniCtrl;
  late final TextEditingController _fechaCtrl;
  int? _idGenero;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.email);
    _telCtrl = TextEditingController(text: widget.telefono);
    _dniCtrl = TextEditingController(text: widget.dni);
    _fechaCtrl = TextEditingController(text: widget.fechaNacimiento);
    _idGenero = widget.idGenero;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _dniCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 18));
    try {
      final parts = _fechaCtrl.text.trim().split("-");
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          initial = DateTime(y, m, d);
        }
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    final y = picked.year.toString().padLeft(4, "0");
    final m = picked.month.toString().padLeft(2, "0");
    final d = picked.day.toString().padLeft(2, "0");
    setState(() => _fechaCtrl.text = "$y-$m-$d");
  }

  String? _validateEmail(String? v) {
    final s = (v ?? "").trim();
    if (s.isEmpty) return "Email requerido";
    if (!s.contains("@") || !s.contains(".")) return "Email inválido";
    return null;
  }

  String? _validateTel(String? v) {
    final s = (v ?? "").trim();
    if (s.isEmpty) return "Teléfono requerido";
    // simple: al menos 6 dígitos
    final digits = s.replaceAll(RegExp(r"\D"), "");
    if (digits.length < 6) return "Teléfono inválido";
    return null;
  }

  String? _validateDni(String? v) {
    final s = (v ?? "").trim();
    if (s.isEmpty) return null; // opcional si querés
    final digits = s.replaceAll(RegExp(r"\D"), "");
    if (digits.length < 7) return "DNI inválido";
    return null;
  }

  String? _validateFecha(String? v) {
    final s = (v ?? "").trim();
    if (s.isEmpty) return null; // opcional si querés
    // formato YYYY-MM-DD
    if (!RegExp(r"^\d{4}-\d{2}-\d{2}$").hasMatch(s)) {
      return "Usá formato YYYY-MM-DD";
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final ok = await _api.actualizarUsuario(
      idUsuario: widget.idUsuario,
      dni: _dniCtrl.text.trim(),
      fechaNacimiento: _fechaCtrl.text.trim(),
      idGenero: _idGenero,
      telefonoUsuario: _telCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ No se pudo actualizar. Revisá el servidor."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editar Perfil")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Datos (solo lectura)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Nombre: ${widget.nombre.isEmpty ? "—" : widget.nombre}",
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Apellido: ${widget.apellido.isEmpty ? "—" : widget.apellido}",
                  ),
                  const SizedBox(height: 6),
                  Text("DNI: ${widget.dni.isEmpty ? "—" : widget.dni}"),
                  const SizedBox(height: 6),
                  Text("Email: ${widget.email.isEmpty ? "—" : widget.email}"),
                  const SizedBox(height: 4),
                  const Divider(),
                  const SizedBox(height: 4),
                  const Text(
                    "Datos editables",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telCtrl,
                          decoration: const InputDecoration(
                            labelText: "Teléfono",
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: _validateTel,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fechaCtrl,
                          readOnly: true,
                          onTap: _pickFecha,
                          decoration: const InputDecoration(
                            labelText: "Fecha nacimiento (opcional)",
                            prefixIcon: Icon(Icons.cake),
                            hintText: "YYYY-MM-DD",
                          ),
                          validator: _validateFecha,
                        ),
                        const SizedBox(height: 12),

                        // Género: lo dejamos como ID numérico por simplicidad
                        DropdownButtonFormField<int?>(
                          value: _idGenero,
                          decoration: const InputDecoration(
                            labelText: "Género",
                            prefixIcon: Icon(Icons.wc),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text("— Seleccionar —"),
                            ),
                            DropdownMenuItem(value: 1, child: Text("Femenino")),
                            DropdownMenuItem(
                              value: 2,
                              child: Text("Masculino"),
                            ),
                          ],
                          onChanged: (v) => setState(() => _idGenero = v),
                        ),

                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _saving ? "Guardando..." : "Guardar cambios",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
