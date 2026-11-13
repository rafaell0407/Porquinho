import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:porquinho/features/transactions/transactions_screen.dart';

/// Tela de Lançamentos com um "+" de teste no lugar do botão central da barra
/// inferior (que fica no shell, fora da tela).
class TransactionsWithAdd extends ConsumerWidget {
  const TransactionsWithAdd({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const TransactionsScreen(),
        Positioned(
          right: 0,
          bottom: 0,
          child: IconButton(
            key: const Key('novo-lancamento'),
            icon: const Icon(Icons.add),
            onPressed: () => showNewEntryChooser(context, ref),
          ),
        ),
      ],
    );
  }
}
