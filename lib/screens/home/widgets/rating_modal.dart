import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/user_preferences.dart';

class RatingModal extends StatefulWidget {
  final int idViaje;
  final String tipo; // "CONDUCTOR_A_PASAJERO" | "PASAJERO_A_CONDUCTOR"
  final String titulo;
  final String subtitulo;

  const RatingModal({
    super.key,
    required this.idViaje,
    required this.tipo,
    required this.titulo,
    required this.subtitulo,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int idViaje,
    required String tipo,
    required String titulo,
    required String subtitulo,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingModal(
        idViaje: idViaje,
        tipo: tipo,
        titulo: titulo,
        subtitulo: subtitulo,
      ),
    );
  }

  @override
  State<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  int _stars = 5;
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final idCalificador = await UserPreferences.getIdUsuario();
    if (idCalificador == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el ID del usuario.')),
      );
      return;
    }

    setState(() => _loading = true);

    final resp = await ApiService().calificarViaje(
      idViaje: widget.idViaje,
      idCalificador: idCalificador,
      tipo: widget.tipo,
      calificacion: _stars,
      comentario: _commentCtrl.text,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (resp["ok"] == true) {
      Navigator.pop(context, true);
      return;
    }

    final code = resp["code"]?.toString();
    final msg = resp["message"]?.toString() ?? "Error al enviar calificación";

    // Duplicado: lo tratamos como ok UX (no bloquea al usuario)
    if (code == "DUPLICATE") {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 14),

              _StarsRow(
                value: _stars,
                onChanged: (v) => setState(() => _stars = v),
              ),

              const SizedBox(height: 12),
              TextField(
                controller: _commentCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Comentario (opcional)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text("Ahora no"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          34,
                          150,
                          243,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Enviar"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarsRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= value;
        return IconButton(
          onPressed: () => onChanged(star),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            size: 34,
            color: filled ? Colors.amber : Colors.black38,
          ),
        );
      }),
    );
  }
}
