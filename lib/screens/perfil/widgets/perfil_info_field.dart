import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PerfilInfoField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final FocusNode? focusNode;
  final Function()? onDateTap;
  final Function(String)? onGeneroChanged;

  /// 🔹 Lista dinámica de géneros (traída del backend)
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
    this.generos, // 🔹 nuevo parámetro opcional
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay géneros cargados, se usa una lista vacía temporal
    final List<Map<String, dynamic>> generosList = generos ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blueGrey[700]),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: isEditing
                ? _buildEditableField(context, generosList)
                : Text(
                    controller.text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Construye el campo editable según el tipo
  Widget _buildEditableField(
    BuildContext context,
    List<Map<String, dynamic>> generosList,
  ) {
    switch (label) {
      case "Fecha de Nacimiento":
        return GestureDetector(
          onTap: onDateTap,
          child: AbsorbPointer(
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.right,
              readOnly: true,
              style: const TextStyle(fontSize: 12),
              decoration: _inputDecoration().copyWith(
                suffixIcon: const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.indigo,
                  size: 20,
                ),
              ),
            ),
          ),
        );

      case "Género":
        // 🔹 Usa los géneros dinámicos si están disponibles
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

        // 🔹 Validar valor inicial (evita crash)
        final currentValue = controller.text.trim();
        final validValues = items.map((e) => e.value).toList();
        final safeValue = validValues.contains(currentValue)
            ? currentValue
            : null;

        return DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: safeValue,
          onChanged: (value) {
            if (value != null && onGeneroChanged != null) {
              onGeneroChanged!(value);
            }
          },
          items: items,
          decoration: _inputDecoration(),
          hint: const Text(
            "Seleccionar género",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.indigo),
        );

      default:
        return TextFormField(
          focusNode: focusNode,
          controller: controller,
          textAlign: TextAlign.right,
          keyboardType: label == "Email"
              ? TextInputType.emailAddress
              : TextInputType.number,
          style: const TextStyle(fontSize: 12),
          decoration: _inputDecoration(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Campo obligatorio";
            }
            if (label == "Email") {
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
              if (!emailRegex.hasMatch(value)) {
                return "Ingrese un email válido";
              }
            }
            return null;
          },
        );
    }
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueGrey, width: 0.6),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.indigoAccent, width: 1.2),
      ),
    );
  }
}
