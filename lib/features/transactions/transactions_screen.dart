import 'package:flutter/material.dart';

/// Marcador até a Fase 4 (receitas, despesas e investimentos).
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos')),
      body: const Center(child: Text('Nenhum lançamento ainda.')),
    );
  }
}
