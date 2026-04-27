import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:taxi_tuc/screens/home/driver/driver_map_screen.dart';

import 'package:taxi_tuc/screens/password/passwordRecovery/password_recovey.dart';
import '../auth/services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/user_preferences.dart';
import '../home/home_screen.dart';

// ====== Colores de marca ======
const Color kTaxiYellow = Color.fromARGB(255, 235, 213, 18);
const Color kGoogleRed = Color(0xFFDB4437);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _selectedTab = 0;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  late final String? srvClientId;
  late GoogleSignIn _googleSignIn;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();

  final _authService = AuthService();
  final _authGoogleService = AuthGoogleService();
  final _socket = SocketService.instance; // ✅ Socket compartido

  @override
  void initState() {
    super.initState();
    srvClientId = dotenv.env['SERVER_CLIENT_ID'];
    _googleSignIn = GoogleSignIn(
      serverClientId: srvClientId,
      scopes: ['email', 'profile'],
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  // ======================
  // Iniciar sesión manual
  // ======================
  Future<void> _handleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Por favor completa todos los campos');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final user = await _authService.login(email, password);

      if (user == null) {
        _showSnackbar('Email o contraseña incorrectos');
        setState(() => _isLoading = false);
        return;
      }

      if (user['auth_provider'] != 'manual') {
        _showSnackbar('Debes iniciar sesión con Google.');
        setState(() => _isLoading = false);
        return;
      }

      // Obtenemos el rol (soportando String o int)
      final dynamic rawRole = user['id_rol'];
      final int roleId = rawRole is String
          ? int.tryParse(rawRole) ?? 0
          : (rawRole is int ? rawRole : 0);

      // Armamos el mapa a guardar en UserPreferences
      final userToSave = <String, dynamic>{
        'id_usuario': user['id_usuario'],
        'nombre_usuario': user['nombre_usuario'],
        'apellido_usuario': user['apellido_usuario'],
        'email_usuario': user['email_usuario'],
        'telefono_usuario': user['telefono_usuario'],
        'foto_perfil': user['foto_perfil'],
        'token': user['token'],
        'id_rol': roleId,
        'auth_provider': user['auth_provider'],
      };

      // ✅ Guardar usuario + flag isLoggedIn
      await UserPreferences.saveUser(userToSave);

      _showSnackbar('Bienvenido, ${user['nombre_usuario']}');

      // ✅ Conectamos al socket y registramos al usuario
      final tipoSocket = roleId == 3 ? 'conductor' : 'pasajero';
      await _socket.connect();
      await _socket.registrarUsuario(
        idUsuario: user['id_usuario'],
        tipo: tipoSocket, // 'pasajero' o 'conductor'
      );

      if (!mounted) return;

      // 👇 REDIRECCIÓN SEGÚN ROL
      if (roleId == 3) {
        // Chofer
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverMapScreen()),
        );
      } else if (roleId == 2) {
        // Pasajero
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: userToSave)),
        );
      } else {
        // Rol desconocido -> por seguridad al Home pasajero
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: userToSave)),
        );
      }
    } catch (e) {
      _showSnackbar('Error al iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======================
  // Iniciar sesión con Google (siempre mostrando selector de cuenta)
  // ======================
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 👇 Forzamos que SIEMPRE pregunte con qué cuenta entrar
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('No se pudo obtener el token.');

      final response = await _authGoogleService.loginWithGoogle(idToken);
      final user = response['result'];
      final token = response['token'];

      if (user['auth_provider'] != 'google') {
        _showSnackbar('Debes ingresar con tu contraseña habitual.');
        setState(() => _isLoading = false);
        return;
      }

      // Obtenemos el rol
      final dynamic rawRole = user['id_rol'];
      final int roleId = rawRole is String
          ? int.tryParse(rawRole) ?? 0
          : (rawRole is int ? rawRole : 0);

      // Armamos el mapa a guardar
      final userToSave = <String, dynamic>{
        'id_usuario': user['id_usuario'],
        'nombre_usuario': user['nombre_usuario'],
        'apellido_usuario': user['apellido_usuario'],
        'email_usuario': user['email_usuario'],
        'telefono_usuario': user['telefono_usuario'],
        'foto_perfil': user['foto_perfil'],
        'token': token, // el token viene separado en la respuesta
        'id_rol': roleId,
        'auth_provider': user['auth_provider'],
      };

      // ✅ Guardar usuario + flag isLoggedIn
      await UserPreferences.saveUser(userToSave);

      _showSnackbar('Bienvenido, ${user['nombre_usuario']}');

      // ✅ Conectamos y registramos el usuario según rol
      final tipoSocket = roleId == 3 ? 'conductor' : 'pasajero';
      await _socket.connect();
      _socket.emit('usuario_conectado', {
        'id_usuario': user['id_usuario'],
        'tipo': tipoSocket,
      });

      if (!mounted) return;

      // 👇 REDIRECCIÓN SEGÚN ROL
      if (roleId == 3) {
        // Chofer
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverMapScreen()),
        );
      } else if (roleId == 2) {
        // Pasajero
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: userToSave)),
        );
      } else {
        // Rol desconocido -> por seguridad al Home pasajero
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: userToSave)),
        );
      }
    } catch (e) {
      await _googleSignIn.signOut();
      debugPrint('❌ Error Google SignIn: $e');
      _showSnackbar('Error al iniciar sesión con Google: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======================
  // Registro normal
  // ======================
  Future<void> _handleRegister() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final apellido = _apellidoController.text.trim();
    final nombre = _nombreController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final passwordConfirm = _passwordConfirmController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        apellido.isEmpty ||
        nombre.isEmpty ||
        passwordConfirm.isEmpty) {
      _showSnackbar('Por favor completa todos los campos');
      setState(() => _isLoading = false);
      return;
    }

    if (password != passwordConfirm) {
      _showSnackbar('Las contraseñas no coinciden');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await _authService.register(
        apellido,
        nombre,
        email,
        password,
      );
      _showSnackbar(result['message']);

      if (result['status'] == 200) {
        _emailController.clear();
        _passwordController.clear();
        _passwordConfirmController.clear();
        _nombreController.clear();
        _apellidoController.clear();
        setState(() => _selectedTab = 0);
      }
    } catch (e) {
      _showSnackbar('Error al registrar usuario: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======================
  // Helpers
  // ======================
  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ======================
  // UI
  // ======================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final textColor = scheme.onSurface;
    final hintColor = scheme.onSurfaceVariant;
    final fieldFill = isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : scheme.surfaceContainerHighest;
    final dividerColor = scheme.outlineVariant;
    final linkColor = scheme.primary;
    final iconDefault = scheme.onSurface;
    final suffixIconCols = scheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: IconTheme.merge(
          data: IconThemeData(color: iconDefault),
          child: DefaultTextStyle(
            style: TextStyle(color: textColor),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 40.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_taxi, size: 80, color: kTaxiYellow),
                    const SizedBox(height: 40),
                    _buildTabSelector(textColor),
                    const SizedBox(height: 24),
                    Text(
                      _selectedTab == 1
                          ? "Crea tu cuenta completando los siguientes datos:"
                          : "¡Bienvenido! Por favor, ingresa tus datos:",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _selectedTab == 1
                          ? _buildRegisterForm(
                              textColor,
                              hintColor,
                              fieldFill,
                              suffixIconCols,
                            )
                          : _buildLoginForm(
                              textColor,
                              hintColor,
                              fieldFill,
                              suffixIconCols,
                              linkColor,
                            ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_selectedTab == 0
                                ? _handleLogin
                                : _handleRegister),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: kTaxiYellow,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              _selectedTab == 0
                                  ? 'Iniciar Sesión'
                                  : 'Registrarse',
                              style: const TextStyle(fontSize: 18),
                            ),
                    ),
                    const SizedBox(height: 24),
                    _buildDivider(dividerColor, textColor),
                    const SizedBox(height: 24),
                    _buildSocialButton(
                      icon: FontAwesomeIcons.google,
                      label: 'Continuar con Google',
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================
  // Widgets auxiliares
  // ==============================
  Widget _buildRegisterForm(
    Color textColor,
    Color hintColor,
    Color fillColor,
    Color suffixIconColor,
  ) {
    return Column(
      key: const ValueKey('register'),
      children: [
        _buildTextField(
          'Nombre',
          _nombreController,
          textColor,
          hintColor,
          fillColor,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Apellido',
          _apellidoController,
          textColor,
          hintColor,
          fillColor,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Email',
          _emailController,
          textColor,
          hintColor,
          fillColor,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          'Contraseña',
          _isPasswordVisible,
          () {
            setState(() => _isPasswordVisible = !_isPasswordVisible);
          },
          _passwordController,
          textColor,
          hintColor,
          fillColor,
          suffixIconColor,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          'Confirmar Contraseña',
          _isConfirmPasswordVisible,
          () {
            setState(
              () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
            );
          },
          _passwordConfirmController,
          textColor,
          hintColor,
          fillColor,
          suffixIconColor,
        ),
      ],
    );
  }

  Widget _buildLoginForm(
    Color textColor,
    Color hintColor,
    Color fillColor,
    Color suffixIconColor,
    Color linkColor,
  ) {
    return Column(
      key: const ValueKey('login'),
      children: [
        _buildTextField(
          'Email',
          _emailController,
          textColor,
          hintColor,
          fillColor,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          'Contraseña',
          _isPasswordVisible,
          () {
            setState(() => _isPasswordVisible = !_isPasswordVisible);
          },
          _passwordController,
          textColor,
          hintColor,
          fillColor,
          suffixIconColor,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecuperarPasswordScreen(),
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: linkColor),
              child: const Text('¿Olvidaste la Contraseña?'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSelector(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTabOption("Iniciar", 0, textColor),
        const SizedBox(width: 40),
        _buildTabOption("Registrarse", 1, textColor),
      ],
    );
  }

  Widget _buildTabOption(String text, int index, Color textColor) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (isSelected)
            Container(
              height: 3,
              width: 60,
              decoration: BoxDecoration(
                color: kTaxiYellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    Color textColor,
    Color hintColor,
    Color fillColor,
  ) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: hint.toLowerCase().contains('email')
          ? TextInputType.emailAddress
          : null,
    );
  }

  Widget _buildPasswordField(
    String hint,
    bool isVisible,
    VoidCallback onToggleVisibility,
    TextEditingController controller,
    Color textColor,
    Color hintColor,
    Color fillColor,
    Color suffixIconColor,
  ) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off : Icons.visibility,
            color: suffixIconColor,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }

  Widget _buildDivider(Color dividerColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: Divider(color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            _selectedTab == 1 ? 'O regístrate con:' : 'O iniciar Sesión con:',
            style: TextStyle(color: textColor),
          ),
        ),
        Expanded(child: Divider(color: dividerColor)),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: FaIcon(icon, color: kGoogleRed),
      label: Text(label, style: const TextStyle(color: kGoogleRed)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: kGoogleRed),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
