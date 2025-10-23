import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../auth/services/auth_service.dart';
import '../auth/services/google_auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen2 extends StatefulWidget {
  const AuthScreen2({super.key});

  @override
  State<AuthScreen2> createState() => _AuthScreen2State();
}

// ====== Colores de marca (no cambian con el tema) ======
const Color kTaxiYellow = Color.fromARGB(255, 235, 213, 18); // Amarillo Taxi
const Color kGoogleRed = Color(0xFFDB4437); // Rojo Google

class _AuthScreen2State extends State<AuthScreen2> {
  int _selectedTab = 0; // 0 = Iniciar, 1 = Registrarse
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Controladores
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Servicios
  final _authService = AuthService();
  final _authGoogleService = AuthGoogleService();
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '125703789007-m6785nj61t63qvdjkok8qokrd9tsdoog.apps.googleusercontent.com',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ======================
  // Lógica de autenticación
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
          SnackBar(
            content: Text('Bienvenido, ${user['nombre_usuario'] ?? 'usuario'}'),
          ),
        );
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
        SnackBar(content: Text('Error al iniciar sesión: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('No se pudo obtener el token de Google.');
      }

      final user = await _authGoogleService.loginWithGoogle(idToken);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bienvenido, ${user['nombre_usuario'] ?? 'usuario'}'),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      await _googleSignIn.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión con Google: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleRegister() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de registro no implementada aún')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Colores dinámicos según tema
    final Color textColor =
        scheme.onSurface; // blanco en oscuro, negro en claro
    final Color hintColor = scheme.onSurfaceVariant; // sutil según tema
    final Color fieldFill = isDark
        ? scheme.surfaceVariant.withOpacity(0.35)
        : scheme.surfaceVariant; // relleno inputs
    final Color dividerColor = scheme.outlineVariant;
    final Color linkColor = scheme.primary; // links en color primario del tema
    final Color iconDefault = scheme.onSurface; // íconos (excepto marca)
    final Color suffixIconCols =
        scheme.onSurfaceVariant; // visibilidad/ojito más sutil

    return Scaffold(
      // No seteamos backgroundColor: sigue al tema del sistema
      body: SafeArea(
        child: IconTheme.merge(
          // Íconos por defecto se adaptan al tema
          data: IconThemeData(color: iconDefault),
          child: DefaultTextStyle(
            // Texto por defecto se adapta al tema
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
                    // Ícono principal SIEMPRE amarillo (marca)
                    const Icon(Icons.local_taxi, size: 80, color: kTaxiYellow),
                    const SizedBox(height: 40),

                    _buildTabSelector(textColor),
                    const SizedBox(height: 24),

                    Text(
                      _selectedTab == 1
                          ? "Crea tu cuenta completando los siguientes"
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

                    // Botón principal (amarillo de marca)
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
                          : const Text(
                              'Iniciar Sesión',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                    const SizedBox(height: 24),

                    _buildDivider(dividerColor, textColor),
                    const SizedBox(height: 24),

                    // Botón Google SIEMPRE rojo (marca)
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
  // Formularios y Widgets
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
          hint: 'Email',
          textColor: textColor,
          hintColor: hintColor,
          fillColor: fillColor,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          hint: 'Contraseña',
          isVisible: _isPasswordVisible,
          onToggleVisibility: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
          textColor: textColor,
          hintColor: hintColor,
          fillColor: fillColor,
          suffixIconColor: suffixIconColor,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          hint: 'Confirmar Contraseña',
          isVisible: _isConfirmPasswordVisible,
          onToggleVisibility: () => setState(
            () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
          ),
          textColor: textColor,
          hintColor: hintColor,
          fillColor: fillColor,
          suffixIconColor: suffixIconColor,
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
          hint: 'Email',
          controller: _emailController,
          textColor: textColor,
          hintColor: hintColor,
          fillColor: fillColor,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          hint: 'Contraseña',
          isVisible: _isPasswordVisible,
          controller: _passwordController,
          onToggleVisibility: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
          textColor: textColor,
          hintColor: hintColor,
          fillColor: fillColor,
          suffixIconColor: suffixIconColor,
        ),
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
              color: textColor, // negro en claro / blanco en oscuro
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
                color: kTaxiYellow, // subrayado de marca
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    TextEditingController? controller,
    required Color textColor,
    required Color hintColor,
    required Color fillColor,
  }) {
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

  Widget _buildPasswordField({
    required String hint,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    TextEditingController? controller,
    required Color textColor,
    required Color hintColor,
    required Color fillColor,
    required Color suffixIconColor,
  }) {
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
