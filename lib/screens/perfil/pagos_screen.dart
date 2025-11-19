// lib/screens/perfil/perfil_pagos_screen.dart
import 'package:flutter/material.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  String? _metodoSeleccionado;

  final List<Map<String, dynamic>> _metodos = [
    {
      'id': 'efectivo',
      'tipo': 'Efectivo',
      'descripcion': 'Pagar directamente al conductor',
      'icono': Icons.payments_rounded,
    },
    {
      'id': 'visa',
      'tipo': 'Visa •••• 3456',
      'descripcion': 'Válida hasta 09/28',
      'icono': Icons.credit_card_rounded,
    },
    {
      'id': 'mastercard',
      'tipo': 'MasterCard •••• 1278',
      'descripcion': 'Válida hasta 04/27',
      'icono': Icons.credit_card,
    },
  ];

  void _confirmarSeleccion() {
    if (_metodoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccioná un método de pago.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Método seleccionado: $_metodoSeleccionado'),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context, _metodoSeleccionado);
  }

  void _abrirAgregarMetodo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const _AgregarTarjetaModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Métodos de pago')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Seleccioná tu método de pago preferido',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // Lista de métodos
              Expanded(
                child: ListView.builder(
                  itemCount: _metodos.length + 1,
                  itemBuilder: (context, index) {
                    // Último: botón para agregar método
                    if (index == _metodos.length) {
                      return Card(
                        color: isDark ? cs.surfaceVariant : cs.surface,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _abrirAgregarMetodo,
                          child: SizedBox(
                            height: 80,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: cs.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Agregar método de pago',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // Métodos existentes
                    final metodo = _metodos[index];
                    final seleccionado = _metodoSeleccionado == metodo['id'];

                    return Card(
                      color: seleccionado
                          ? cs.primaryContainer.withValues(alpha: 0.2)
                          : (isDark ? cs.surfaceVariant : cs.surface),
                      elevation: seleccionado ? 3 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: seleccionado
                              ? cs.primary
                              : Colors.grey.withValues(alpha: 0.3),
                          width: seleccionado ? 1.8 : 1,
                        ),
                      ),
                      child: RadioListTile<String>(
                        value: metodo['id'],
                        groupValue: _metodoSeleccionado,
                        onChanged: (value) {
                          setState(() => _metodoSeleccionado = value);
                        },
                        activeColor: cs.primary,
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  metodo['icono'],
                                  color: cs.primary,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    metodo['tipo'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    metodo['descripcion'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Botón confirmar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar método de pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _confirmarSeleccion,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget separado para el modal de agregar tarjeta
// Widget separado para el modal de agregar tarjeta
class _AgregarTarjetaModal extends StatefulWidget {
  const _AgregarTarjetaModal();

  @override
  State<_AgregarTarjetaModal> createState() => _AgregarTarjetaModalState();
}

class _AgregarTarjetaModalState extends State<_AgregarTarjetaModal> {
  final _formKey = GlobalKey<FormState>();
  final _numeroController = TextEditingController();
  final _nombreController = TextEditingController();
  final _vencimientoController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _numeroController.dispose();
    _nombreController.dispose();
    _vencimientoController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _guardarTarjeta() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarjeta agregada correctamente.')),
      );
    }
  }

  String _formatCardNumber(String input) {
    final clean = input.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      buffer.write(clean[i]);
      if ((i + 1) % 4 == 0 && i + 1 != clean.length) buffer.write(' ');
    }
    return buffer.toString();
  }

  String _formatExpiryDate(String input) {
    var clean = input.replaceAll(RegExp(r'\D'), '');
    if (clean.length > 4) clean = clean.substring(0, 4);
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Text(
                      'Agregar tarjeta',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🔹 Número de tarjeta
                    TextFormField(
                      controller: _numeroController,
                      decoration: const InputDecoration(
                        labelText: 'Número de tarjeta',
                        prefixIcon: Icon(Icons.credit_card),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 19, // 16 dígitos + 3 espacios
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final clean = v?.replaceAll(' ', '') ?? '';
                        if (clean.isEmpty)
                          return 'Ingresá el número de tarjeta';
                        if (clean.length != 16) return 'Número incompleto';
                        return null;
                      },
                      onChanged: (value) {
                        final newText = _formatCardNumber(value);
                        if (newText != value) {
                          _numeroController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: newText.length,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🔹 Nombre del titular
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del titular',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Ingresá el nombre del titular'
                          : null,
                      onChanged: (value) {
                        final upper = value.toUpperCase();
                        if (upper != value) {
                          _nombreController.value = TextEditingValue(
                            text: upper,
                            selection: TextSelection.collapsed(
                              offset: upper.length,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🔹 Vencimiento y CVV
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _vencimientoController,
                            decoration: const InputDecoration(
                              labelText: 'Vencimiento (MM/AA)',
                              prefixIcon: Icon(Icons.date_range_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            maxLength: 5,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresá el vencimiento';
                              }
                              if (!RegExp(
                                r'^(0[1-9]|1[0-2])\/\d{2}$',
                              ).hasMatch(v)) {
                                return 'Formato inválido (MM/AA)';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              final newText = _formatExpiryDate(value);
                              if (newText != value) {
                                _vencimientoController.value = TextEditingValue(
                                  text: newText,
                                  selection: TextSelection.collapsed(
                                    offset: newText.length,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              prefixIcon: Icon(Icons.lock_outline),
                              counterText: '',
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _guardarTarjeta(),
                            validator: (v) => v == null || v.length != 3
                                ? 'CVV inválido'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Guardar tarjeta'),
                        onPressed: _guardarTarjeta,
                      ),
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
}