import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 🔹 Altura estándar para todos los campos de entrada
const double kInputHeight = 44;

class PerfilInfoField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final FocusNode? focusNode;
  final Function()? onDateTap;
  final Function(String)? onGeneroChanged;
  final List<Map<String, dynamic>>? generos;

  const PerfilInfoField({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    required this.isEditing,
    this.focusNode,
    this.onDateTap,
    this.onGeneroChanged,
    this.generos,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final generosList = generos ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: isEditing
                ? _buildEditableField(context, generosList)
                : Tooltip(
                    message: controller.text,
                    child: Text(
                      controller.text,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Campo editable con validaciones y snackbars
  Widget _buildEditableField(
    BuildContext context,
    List<Map<String, dynamic>> generosList,
  ) {
    switch (label) {
      // 📅 FECHA DE NACIMIENTO
      case "Fecha de Nacimiento":
        return SizedBox(
          height: kInputHeight,
          child: TextFormField(
            controller: controller,
            readOnly: true,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
            decoration: _inputDecoration(context).copyWith(
              suffixIcon: Icon(
                Icons.calendar_today_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
            onTap: () async {
              FocusScope.of(context).unfocus();
              final theme = Theme.of(context);

              DateTime initialDate = DateTime.now().subtract(
                const Duration(days: 365 * 20),
              );
              try {
                if (controller.text.isNotEmpty) {
                  initialDate = DateFormat('dd/MM/yyyy').parse(controller.text);
                }
              } catch (_) {}

              final pickedDate = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'ES'),
                builder: (context, child) {
                  return Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: theme.colorScheme.primary,
                        onPrimary: theme.colorScheme.onPrimary,
                        surface: theme.colorScheme.surface,
                        onSurface: theme.colorScheme.onSurface,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (pickedDate != null) {
                final formatted = DateFormat('dd/MM/yyyy').format(pickedDate);
                controller.text = formatted;
              }
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                _showSnackBar(context, "La fecha de nacimiento es obligatoria");
                return '';
              }
              try {
                final parsedDate = DateFormat('dd/MM/yyyy').parse(value);
                final today = DateTime.now();
                final age = today.year - parsedDate.year;
                if (age > 110) {
                  _showSnackBar(context, "No puede tener más de 110 años");
                  return '';
                }
                if (parsedDate.isAfter(today)) {
                  _showSnackBar(context, "La fecha no puede ser futura");
                  return '';
                }
              } catch (_) {
                _showSnackBar(context, "Fecha inválida");
                return '';
              }
              return null;
            },
          ),
        );

      // ⚧ GÉNERO
      case "Género":
        final items = generosList.isNotEmpty
            ? generosList
                  .map(
                    (g) => DropdownMenuItem<String>(
                      value: g['nombre_genero']?.toString().trim() ?? '',
                      child: Text(
                        g['nombre_genero']?.toString().trim() ?? '',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList()
            : [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text(
                    "Cargando...",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ];

        final currentValue = controller.text.trim();
        final validValues = items.map((e) => e.value).toList();
        final safeValue = validValues.contains(currentValue)
            ? currentValue
            : null;

        return SizedBox(
          height: kInputHeight,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: safeValue,
            onChanged: (value) {
              if (value != null && onGeneroChanged != null) {
                onGeneroChanged!(value);
              }
            },
            items: items,
            decoration: _inputDecoration(
              context,
            ).copyWith(errorStyle: const TextStyle(height: 0, fontSize: 0)),
            hint: const Text(
              "Seleccionar género",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                _showSnackBar(context, "Debe seleccionar un género");
                return '';
              }
              return null;
            },
          ),
        );

      // 🧍 DNI / TELÉFONO / EMAIL
      default:
        return SizedBox(
          height: kInputHeight,
          child: TextFormField(
            focusNode: focusNode,
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType: label == "Email"
                ? TextInputType.emailAddress
                : TextInputType.number,
            style: const TextStyle(fontSize: 12),
            decoration: _inputDecoration(
              context,
            ).copyWith(errorStyle: const TextStyle(height: 0, fontSize: 0)),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                _showSnackBar(context, "$label es obligatorio");
                return '';
              }

              if (label == "DNI") {
                if (value.length < 6 || value.length > 8) {
                  _showSnackBar(
                    context,
                    "El DNI debe tener entre 6 y 8 dígitos",
                  );
                  return '';
                }
              }

              if (label == "Teléfono") {
                if (value.length < 10 || value.length > 15) {
                  _showSnackBar(
                    context,
                    "El teléfono debe tener entre 10 y 15 números",
                  );
                  return '';
                }
              }

              if (label == "Email") {
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!emailRegex.hasMatch(value)) {
                  _showSnackBar(context, "Ingrese un email válido");
                  return '';
                }
              }

              return null;
            },
          ),
        );
    }
  }

  /// 🔹 Mostrar snackbar en la parte inferior
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  /// 🔹 Decoración común de los inputs
  InputDecoration _inputDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: cs.outline.withValues(alpha: 0.5),
          width: 0.6,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.2),
      ),
    );
  }
}
