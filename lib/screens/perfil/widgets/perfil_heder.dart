import 'package:flutter/material.dart';

class PerfilHeader extends StatelessWidget {
  final String nombreCompleto;
  final String email;

  const PerfilHeader({
    super.key,
    required this.nombreCompleto,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(
                  255,
                  255,
                  255,
                  255,
                ).withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const CircleAvatar(
            radius: 70,
            backgroundImage: AssetImage("assets/images/woman_profile.png"),
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          nombreCompleto,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 255, 255, 255),
          ),
        ),
        const SizedBox(height: 4),
        Text(email, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const SizedBox(height: 24),
      ],
    );
  }
}
