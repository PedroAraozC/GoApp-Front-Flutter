// lib/screens/perfil/perfil_viajes_screen.dart
import 'package:flutter/material.dart';
import '../../screens/home/home_screen.dart';

class ViajesScreen extends StatelessWidget {
  const ViajesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Viajes')),
      body: const Center(
        child: Text(
          'Aquí podrás ver tus viajes.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
