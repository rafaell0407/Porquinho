import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/money.dart';
import '../../../shared/main_shell.dart' show NorteNavBar;
import '../../transactions/transactions_screen.dart' show showNewEntryChooser;
import '../domain/simulation_math.dart';

/// Página das simulações: barra superior, barra inferior com Ferramentas
/// selecionada (como Relatórios) e conteúdo rolável com largura máxima.
class SimulationPage extends ConsumerWidget {
  const SimulationPage({
    required this.title,
    required this.children,
    this.actions = const [],
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      bottomNavigationBar: NorteNavBar(
        currentIndex: 1,
        onTab: (i) => context.go(NorteNavBar.tabRoutes[i]),
        onAdd: () => showNewEntryChooser(context, ref),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Leva a tela até a seção de resultado depois do cálculo.
void scrollToResult(GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  });
}

/// Valor para preencher um campo de dinheiro (sem o "R$", que é prefixo).
String moneyFieldText(BigInt cents) => formatBrl(cents).substring(3);

String monthsText(int months) => months == 1 ? '1 mês' : '$months meses';

/// "12% ao ano (≈ 0,9489% ao mês)", "0,85% ao mês".
String rateCaption(InterestRate rate) {
  if (rate.period == RatePeriod.monthly) {
    return '${formatRatePercent(rate)} ao mês';
  }
  final m = rate.monthlyPercentE4;
  final monthly = InterestRate(
    percentE4: m.percentE4,
    period: RatePeriod.monthly,
  );
  return '${formatRatePercent(rate)} ao ano '
      '(${m.exact ? '' : '≈ '}${formatRatePercent(monthly)} ao mês)';
}

/// Título de subseção dentro do resultado.
class SubsectionTitle extends StatelessWidget {
  const SubsectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Linha discreta abaixo do título do resultado (parâmetros usados).
class ResultCaption extends StatelessWidget {
  const ResultCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
