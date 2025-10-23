import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../auth/services/auth_service.dart';
import '../auth/services/google_auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ====== Colores de marca ======
const Color kTaxiYellow = Color.fromARGB(255, 235, 213, 18);
const Color kGoogleRed = Color(0xFFDB4437);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _selectedTab = 0; // 0 = Iniciar, 1 = Registrarse
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  late final String? srvClientId;
  late GoogleSignIn _googleSignIn;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _authService = AuthService();
  final _authGoogleService = AuthGoogleService();

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ======================
  // Iniciar sesión normal
  // ======================
  Future<void> _handleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final user = await _authService.login(email, password);
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bienvenido, ${user['nombre_usuario']}')),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setInt('id_usuario', user['id_usuario']);
        await prefs.setString('token', user['token'] ?? '');
        await prefs.setString('nombre_usuario', user['nombre_usuario']);
        await prefs.setString('email_usuario', user['email_usuario']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email o contraseña incorrectos')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======================
  // Iniciar sesión con Google
  // ======================
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('No se pudo obtener el token.');

      // Llamada al backend
      final response = await _authGoogleService.loginWithGoogle(idToken);
      final user = response['result'];
      final token = response['token'];

      debugPrint('✅ Usuario desde backend: $user');
      debugPrint('🔑 Token JWT: $token');

      // Guardamos datos
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setInt('id_usuario', user['id_usuario'] ?? 0);
      await prefs.setString('nombre_usuario', user['nombre_usuario'] ?? '');
      await prefs.setString('apellido_usuario', user['apellido_usuario'] ?? '');
      await prefs.setString('email_usuario', user['email_usuario'] ?? '');
      await prefs.setString('telefono_usuario', user['telefono_usuario'] ?? '');
      await prefs.setString('foto_perfil', user['foto_perfil'] ?? '');
      await prefs.setString('token', token ?? '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenido, ${user['nombre_usuario']}')),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      await _googleSignIn.signOut();
      debugPrint('❌ Error Google SignIn: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión con Google: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======================
  // Registro (aún no implementado)
  // ======================
  void _handleRegister() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de registro no implementada aún')),
    );
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
        ? scheme.surfaceVariant.withOpacity(0.35)
        : scheme.surfaceVariant;
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
                              textColor, hintColor, fieldFill, suffixIconCols)
                          : _buildLoginForm(
                              textColor,
                              hintColor,
                              fieldFill,
                              suffixIconCols,
                              linkColor),
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
                    const SizedBox(height: 16),
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
      Color textColor, Color hintColor, Color fillColor, Color suffixIconColor) {
    return Column(
      key: const ValueKey('register'),
      children: [
        _buildTextField('Email', null, textColor, hintColor, fillColor),
        const SizedBox(height: 16),
        _buildPasswordField('Contraseña', _isPasswordVisible, () {
          setState(() => _isPasswordVisible = !_isPasswordVisible);
        }, null, textColor, hintColor, fillColor, suffixIconColor),
        const SizedBox(height: 16),
        _buildPasswordField('Confirmar Contraseña', _isConfirmPasswordVisible,
            () {
          setState(() =>
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
        }, null, textColor, hintColor, fillColor, suffixIconColor),
      ],
    );
  }

  Widget _buildLoginForm(Color textColor, Color hintColor, Color fillColor,
      Color suffixIconColor, Color linkColor) {
    return Column(
      key: const ValueKey('login'),
      children: [
        _buildTextField('Email', _emailController, textColor, hintColor, fillColor),
        const SizedBox(height: 16),
        _buildPasswordField('Contraseña', _isPasswordVisible, () {
          setState(() => _isPasswordVisible = !_isPasswordVisible);
        }, _passwordController, textColor, hintColor, fillColor, suffixIconColor),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {},
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

  Widget _buildTextField(String hint, TextEditingController? controller,
      Color textColor, Color hintColor, Color fillColor) {
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
      keyboardType:
          hint.toLowerCase().contains('email') ? TextInputType.emailAddress : null,
    );
  }

  Widget _buildPasswordField(
      String hint,
      bool isVisible,
      VoidCallback onToggleVisibility,
      TextEditingController? controller,
      Color textColor,
      Color hintColor,
      Color fillColor,
      Color suffixIconColor) {
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
      icon: const FaIcon(FontAwesomeIcons.google, color: kGoogleRed),
      label: const Text(
        'Continuar con Google',
        style: TextStyle(color: kGoogleRed),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: kGoogleRed),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
