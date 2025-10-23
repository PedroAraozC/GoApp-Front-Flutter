// lib/screens/perfil/perfil_pagos_screen.dart
import 'package:flutter/material.dart';

class PagosScreen extends StatelessWidget {
  const PagosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Métodos de pago')),
      body: const Center(
        child: Text(
          'Aquí podrás gestionar tus medios de pago.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
