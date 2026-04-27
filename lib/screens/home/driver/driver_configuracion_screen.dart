import 'package:flutter/material.dart';
import 'package:taxi_tuc/main.dart';
import 'package:taxi_tuc/services/user_preferences.dart';

/// Pantalla de Configuración (conductor)
/// - Tema: Claro / Oscuro / Sistema
/// - Métodos de pago: Efectivo (opcional) / Débito (siempre habilitado)
class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  bool _loading = true;

  // Tema
  ThemeMode _themeMode = ThemeMode.system;

  // Pagos
  bool _cashEnabled = true;
  final bool _debitEnabled = true; // 🔒 siempre habilitado
  String _preferred = 'debit'; // cash|debit

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final themeStr = await UserPreferences.getThemeMode();
    final cashEnabled = await UserPreferences.getCashEnabled();
    final preferred = await UserPreferences.getPreferredPayment();

    if (!mounted) return;
    setState(() {
      _themeMode = _fromThemeString(themeStr);
      _cashEnabled = cashEnabled;
      _preferred = preferred;
      _loading = false;
    });
  }

  ThemeMode _fromThemeString(String v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeLabel(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      default:
        return 'Sistema';
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await AppThemeController.instance.setMode(mode);
  }

  Future<void> _setCashEnabled(bool enabled) async {
    setState(() {
      _cashEnabled = enabled;
      if (!enabled && _preferred == 'cash') {
        _preferred = 'debit';
      }
    });
    await UserPreferences.setCashEnabled(enabled);
  }

  Future<void> _setPreferred(String method) async {
    if (method == 'cash' && !_cashEnabled) return;
    setState(() => _preferred = method);
    await UserPreferences.setPreferredPayment(method);
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // ✅ Si el sistema no pudo hacer pop por algún motivo, lo forzamos.
        if (!didPop && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuración'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack, // ✅ vuelve sin cerrar la app
          ),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.yellow,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // =========================
                  // TEMA
                  // =========================
                  Text(
                    'Apariencia',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.color_lens_outlined),
                          title: const Text('Tema'),
                          subtitle: Text('Actual: ${_themeLabel(_themeMode)}'),
                        ),
                        const Divider(height: 1),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          groupValue: _themeMode,
                          onChanged: (v) => _setTheme(v!),
                          title: const Text('Sistema'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          groupValue: _themeMode,
                          onChanged: (v) => _setTheme(v!),
                          title: const Text('Claro'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          groupValue: _themeMode,
                          onChanged: (v) => _setTheme(v!),
                          title: const Text('Oscuro'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =========================
                  // MÉTODOS DE PAGO
                  // =========================
                  Text(
                    'Métodos de pago',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Aceptar efectivo'),
                          subtitle: const Text(
                            'Podés habilitar o deshabilitar el cobro en efectivo.',
                          ),
                          value: _cashEnabled,
                          onChanged: (v) => _setCashEnabled(v),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Aceptar débito'),
                          subtitle: const Text(
                            'Siempre habilitado (no se puede desactivar).',
                          ),
                          value: _debitEnabled,
                          onChanged: null, // 🔒 no deshabilitable
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
                            children: [
                              Icon(Icons.star_outline, color: cs.primary),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Método preferido',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        RadioListTile<String>(
                          value: 'debit',
                          groupValue: _preferred,
                          onChanged: (v) => _setPreferred(v!),
                          title: const Text('Débito'),
                        ),
                        RadioListTile<String>(
                          value: 'cash',
                          groupValue: _preferred,
                          onChanged: _cashEnabled
                              ? (v) => _setPreferred(v!)
                              : null,
                          title: const Text('Efectivo'),
                          subtitle: _cashEnabled
                              ? null
                              : const Text(
                                  'Deshabilitado (habilitá “Aceptar efectivo” para elegirlo).',
                                ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
