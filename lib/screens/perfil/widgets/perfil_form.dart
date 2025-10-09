import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'perfil_info_field.dart';

class PerfilForm extends StatelessWidget {
  final bool isEditing;
  final GlobalKey<FormState> formKey;

  // Controladores
  final TextEditingController dniController;
  final TextEditingController fechaController;
  final TextEditingController generoController;
  final TextEditingController telefonoController;
  final TextEditingController emailController;

  // FocusNodes (para scroll automático)
  final Map<String, FocusNode> focusNodes;

  // Callbacks
  final VoidCallback onGuardar;
  final VoidCallback onCancelar;
  final VoidCallback onEditar;

  const PerfilForm({
    super.key,
    required this.isEditing,
    required this.formKey,
    required this.dniController,
    required this.fechaController,
    required this.generoController,
    required this.telefonoController,
    required this.emailController,
    required this.focusNodes,
    required this.onGuardar,
    required this.onCancelar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 5,
            shadowColor: Colors.black26,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PerfilInfoField(
                    icon: Icons.badge_rounded,
                    label: "DNI",
                    controller: dniController,
                    isEditing: isEditing,
                    focusNode: focusNodes["DNI"],
                  ),
                  _divider(),
                  PerfilInfoField(
                    icon: Icons.cake_rounded,
                    label: "Fecha de Nacimiento",
                    controller: fechaController,
                    isEditing: isEditing,
                    onDateTap: () => _seleccionarFecha(context),
                  ),
                  _divider(),
                  PerfilInfoField(
                    icon: Icons.person_rounded,
                    label: "Género",
                    controller: generoController,
                    isEditing: isEditing,
                    onGeneroChanged: (value) => generoController.text = value,
                  ),
                  _divider(),
                  PerfilInfoField(
                    icon: Icons.phone_rounded,
                    label: "Teléfono",
                    controller: telefonoController,
                    isEditing: isEditing,
                    focusNode: focusNodes["Teléfono"],
                  ),
                  _divider(),
                  PerfilInfoField(
                    icon: Icons.email_rounded,
                    label: "Email",
                    controller: emailController,
                    isEditing: isEditing,
                    focusNode: focusNodes["Email"],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 Botones de acción
          isEditing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onCancelar,
                      icon: const Icon(
                        Icons.cancel_rounded,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "Cancelar",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (formKey.currentState!.validate()) onGuardar();
                      },
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text("Guardar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F51B5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 14,
                        ),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                    ),
                  ],
                )
              : ElevatedButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  label: const Text("Editar perfil"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F51B5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 14,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 🔹 Selector de fecha de nacimiento
  void _seleccionarFecha(BuildContext context) async {
    FocusScope.of(context).unfocus();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(_toDate(fechaController.text)) ??
          DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (pickedDate != null) {
      String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
      fechaController.text = formattedDate;
    }
  }

  String _toDate(String value) {
    try {
      final parts = value.split('/');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (_) {}
    return value;
  }

  Widget _divider() =>
      const Divider(color: Colors.black12, thickness: 1, height: 4);
}
