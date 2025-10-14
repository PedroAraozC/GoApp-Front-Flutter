import 'package:flutter/material.dart';

class PerfilSnackBar {
  /// Muestra un snackbar animado en la parte superior de la pantalla.
  ///
  /// [message] → texto del mensaje.
  /// [color] → color del fondo. (Por defecto: verde)
  /// [icon] → ícono opcional (por defecto, check o close según color).
  static void show(
    BuildContext context, {
    required String message,
    Color color = Colors.green,
    IconData? icon,
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(begin: const Offset(-1, 0), end: const Offset(0, 0)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutExpo,
          builder: (context, offset, child) {
            return SlideTransition(
              position: AlwaysStoppedAnimation(offset),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon ??
                            (color == Colors.grey
                                ? Icons.close_rounded
                                : Icons.check_circle),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }
}
