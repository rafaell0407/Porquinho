import 'package:flutter/material.dart';

/// Marcador até a Fase 4/5 (sobra do período). O texto é o marcador de
/// "sessão ativa" usado pelos testes.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(child: Text('Você está conectado.')),
    );
  }
}
