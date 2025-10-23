import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final generosList = generos ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
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
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Campo editable con altura uniforme
  Widget _buildEditableField(
    BuildContext context,
    List<Map<String, dynamic>> generosList,
  ) {
    final scheme = Theme.of(context).colorScheme;

    switch (label) {
      case "Fecha de Nacimiento":
        return SizedBox(
          height: kInputHeight,
          child: GestureDetector(
            onTap: onDateTap,
            child: AbsorbPointer(
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.right,
                readOnly: true,
                style: TextStyle(fontSize: 12, color: scheme.onSurface),
                decoration: _inputDecoration(context).copyWith(
                  suffixIcon: Icon(
                    Icons.calendar_today_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        );

      case "Género":
        final items = generosList.isNotEmpty
            ? generosList
                .map(
                  (g) => DropdownMenuItem<String>(
                    value: g['nombre_genero']?.toString().trim() ?? '',
                    child: Text(
                      g['nombre_genero']?.toString().trim() ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList()
            : [
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(
                    "Cargando...",
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ),
              ];

        final currentValue = controller.text.trim();
        final validValues = items.map((e) => e.value).toList();
        final safeValue =
            validValues.contains(currentValue) ? currentValue : null;

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
            decoration: _inputDecoration(context),
            hint: Text(
              "Seleccionar género",
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            icon: Icon(Icons.arrow_drop_down_rounded, color: scheme.primary),
          ),
        );

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
            style: TextStyle(fontSize: 12, color: scheme.onSurface),
            decoration: _inputDecoration(context),
            validator: (value) {
              if (value == null || value.isEmpty) return "Campo obligatorio";
              if (label == "Email") {
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                if (!emailRegex.hasMatch(value)) {
                  return "Ingrese un email válido";
                }
              }
              return null;
            },
          ),
        );
    }
  }

  /// 🔹 Decoración común adaptada al tema del sistema
  InputDecoration _inputDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 0.6),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.2),
      ),
    );
  }
}
