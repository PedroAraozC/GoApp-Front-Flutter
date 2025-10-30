import 'package:flutter/material.dart';

class PerfilForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Map<String, FocusNode> focusNodes;
  final bool isEditing;

  final TextEditingController nombreController;
  final TextEditingController apellidoController;
  final TextEditingController dniController;
  final TextEditingController fechaController;
  final TextEditingController generoController;
  final TextEditingController telefonoController;
  final TextEditingController emailController;

  final List<Map<String, dynamic>> generos;

  final VoidCallback onGuardar;
  final VoidCallback onCancelar;
  final VoidCallback onEditar;

  const PerfilForm({
    super.key,
    required this.formKey,
    required this.focusNodes,
    required this.isEditing,
    required this.nombreController,
    required this.apellidoController,
    required this.dniController,
    required this.fechaController,
    required this.generos,
    required this.generoController,
    required this.telefonoController,
    required this.emailController,
    required this.onGuardar,
    required this.onCancelar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(
              label: 'Nombre',
              controller: nombreController,
              focusNode: focusNodes['nombre'],
              enabled: isEditing,
            ),
            const SizedBox(height: 12),
            _buildField(
              label: 'Apellido',
              controller: apellidoController,
              focusNode: focusNodes['apellido'],
              enabled: isEditing,
            ),
            const SizedBox(height: 12),
            _buildField(
              label: 'DNI',
              controller: dniController,
              focusNode: focusNodes['dni'],
              keyboardType: TextInputType.number,
              enabled: isEditing,
            ),
            const SizedBox(height: 12),
            _buildDateField(context),
            const SizedBox(height: 12),
            _buildGeneroDropdown(),
            const SizedBox(height: 12),
            _buildField(
              label: 'Teléfono',
              controller: telefonoController,
              focusNode: focusNodes['telefono'],
              keyboardType: TextInputType.phone,
              enabled: isEditing,
            ),
            const SizedBox(height: 12),
            _buildField(
              label: 'Email',
              controller: emailController,
              focusNode: focusNodes['email'],
              keyboardType: TextInputType.emailAddress,
              enabled: isEditing,
            ),
            const SizedBox(height: 24),
            if (isEditing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancelar,
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onGuardar,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (!enabled) return null;
        if (v == null || v.trim().isEmpty) {
          return 'Campo requerido';
        }
        return null;
      },
    );
  }

  Widget _buildDateField(BuildContext context) {
    return TextFormField(
      controller: fechaController,
      focusNode: focusNodes['fecha'],
      readOnly: true,
      enabled: isEditing,
      decoration: const InputDecoration(
        labelText: 'Fecha de nacimiento',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.calendar_today),
      ),
      onTap: isEditing
          ? () async {
              FocusScope.of(context).unfocus();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'ES'),
              );
              if (picked != null) {
                final formatted =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                fechaController.text = formatted;
              }
            }
          : null,
      validator: (v) {
        if (!isEditing) return null;
        if (v == null || v.isEmpty) return 'Campo requerido';
        return null;
      },
    );
  }

  Widget _buildGeneroDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _getGeneroIdActual(),
      items: generos
          .map(
            (g) => DropdownMenuItem<int>(
              value: g['id_genero'] as int,
              child: Text(g['nombre_genero']),
            ),
          )
          .toList(),
      decoration: const InputDecoration(
        labelText: 'Género',
        border: OutlineInputBorder(),
      ),
      onChanged: isEditing
          ? (v) {
              if (v != null) {
                generoController.text = generos
                    .firstWhere((g) => g['id_genero'] == v)['nombre_genero']
                    .toString();
              }
            }
          : null,
    );
  }

  int? _getGeneroIdActual() {
    try {
      final text = generoController.text.trim();
      if (text.isEmpty) return null;
      final id = int.tryParse(text);
      if (id != null) return id;

      final found = generos.firstWhere(
        (g) => g['nombre_genero'] == text,
        orElse: () => {},
      );
      return found['id_genero'] as int?;
    } catch (_) {
      return null;
    }
  }
}
