import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'perfil_info_field.dart';

class PerfilForm extends StatelessWidget {
  final bool isEditing;
  final GlobalKey<FormState> formKey;

  // Controladores
  // final TextEditingController nombreController;
  // final TextEditingController apellidoController;
  final TextEditingController dniController;
  final TextEditingController fechaController;
  final TextEditingController generoController;
  final TextEditingController telefonoController;
  final TextEditingController emailController;

  final Map<String, FocusNode> focusNodes;
  final List<Map<String, dynamic>> generos;

  // Callbacks
  final VoidCallback onGuardar;
  final VoidCallback onCancelar;
  final VoidCallback onEditar;

  const PerfilForm({
    super.key,
    required this.isEditing,
    required this.formKey,
    // required this.nombreController,
    // required this.apellidoController,
    required this.dniController,
    required this.fechaController,
    required this.generos,
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
    final cs = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      child: Column(
        children: [
          // 🧩 Tarjeta principal
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 5,
            shadowColor: const Color.fromARGB(80, 0, 0, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // _buildInfoField(
                  //   icon: Icons.person_outline,
                  //   label: "Nombre",
                  //   controller: nombreController,
                  //   isEditing: isEditing,
                  //   focusNode: focusNodes["nombre"],
                  // ),
                  // _divider(),
                  // _buildInfoField(
                  //   icon: Icons.person,
                  //   label: "Apellido",
                  //   controller: apellidoController,
                  //   isEditing: isEditing,
                  //   focusNode: focusNodes["apellido"],
                  // ),
                  _divider(),
                  _buildInfoField(
                    icon: Icons.badge_rounded,
                    label: "DNI",
                    controller: dniController,
                    isEditing: isEditing,
                    focusNode: focusNodes["dni"],
                    keyboardType: TextInputType.number,
                  ),
                  _divider(),
                  _buildInfoField(
                    icon: Icons.cake_rounded,
                    label: "Fecha de Nacimiento",
                    controller: fechaController,
                    isEditing: isEditing,
                    onDateTap: () => _seleccionarFecha(context),
                  ),
                  _divider(),
                  _buildInfoField(
                    icon: Icons.person_rounded,
                    label: "Género",
                    controller: generoController,
                    generos: generos,
                    isEditing: isEditing,
                    onGeneroChanged: (value) =>
                        generoController.text = value,
                  ),
                  _divider(),
                  _buildInfoField(
                    icon: Icons.phone_rounded,
                    label: "Teléfono",
                    controller: telefonoController,
                    isEditing: isEditing,
                    keyboardType: TextInputType.phone,
                    focusNode: focusNodes["telefono"],
                  ),
                  _divider(),
                  _buildInfoField(
                    icon: Icons.email_rounded,
                    label: "Email",
                    controller: emailController,
                    isEditing: isEditing,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: focusNodes["email"],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),

          // 🔘 Botones inferiores
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
                            horizontal: 35, vertical: 18),
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
                      icon:
                          const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text("Guardar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 18),
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
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 18),
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

  /// 🔹 Construye campo con ícono y comportamiento dinámico
  Widget _buildInfoField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    bool isEditing = false,
    List<Map<String, dynamic>>? generos,
    Function(String)? onGeneroChanged,
    VoidCallback? onDateTap,
  }) {
    return PerfilInfoField(
      icon: icon,
      label: label,
      controller: controller,
      isEditing: isEditing,
      focusNode: focusNode,
      keyboardType: keyboardType,
      generos: generos,
      onGeneroChanged: onGeneroChanged,
      onDateTap: onDateTap,
    );
  }

  /// 📅 Selector de fecha de nacimiento
  void _seleccionarFecha(BuildContext context) async {
    FocusScope.of(context).unfocus();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_toDate(fechaController.text)) ??
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
