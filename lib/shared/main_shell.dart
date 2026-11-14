import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/transactions/transactions_screen.dart';

/// Estrutura da navegação principal: barra inferior em pílula com Home,
/// Ferramentas, Adicionar (+), Lançamentos e Mais. Home, Ferramentas,
/// Lançamentos e Mais são abas (cada uma mantém o próprio estado); Adicionar
/// abre o menu de novo lançamento.
class MainShell extends ConsumerWidget {
  const MainShell({
    required this.navigationShell,
    this.banner = const SizedBox.shrink(),
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// Faixa de estado no topo (conexão/sincronização).
  final Widget banner;

  void _goTab(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = navigationShell.currentIndex;
    return Scaffold(
      body: Column(
        children: [
          banner,
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NorteNavBar(
        currentIndex: current,
        onTab: _goTab,
        onAdd: () => showNewEntryChooser(context, ref),
      ),
    );
  }
}

/// Barra em pílula, solta das bordas; o "+" fica elevado no centro. Usada no
/// shell principal e nas telas de ferramenta abertas por cima dele (ex.:
/// Relatórios, com Ferramentas selecionada).
class NorteNavBar extends StatelessWidget {
  const NorteNavBar({
    required this.onTab,
    required this.onAdd,
    this.currentIndex,
    super.key,
  });

  /// Rotas das abas, na ordem dos índices.
  static const tabRoutes = ['/', '/ferramentas', '/lancamentos', '/mais'];

  /// Aba selecionada (0 Home, 1 Ferramentas, 2 Lançamentos, 3 Mais); null se
  /// nenhuma.
  final int? currentIndex;
  final void Function(int index) onTab;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _NavItem(
                  itemKey: const Key('nav-home'),
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: () => onTab(0),
                ),
                _NavItem(
                  itemKey: const Key('nav-ferramentas'),
                  icon: Icons.home_repair_service_outlined,
                  selectedIcon: Icons.home_repair_service,
                  label: 'Ferramentas',
                  selected: currentIndex == 1,
                  onTap: () => onTab(1),
                ),
                _AddItem(onTap: () => onAdd()),
                _NavItem(
                  itemKey: const Key('nav-lancamentos'),
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: 'Lançamentos',
                  selected: currentIndex == 2,
                  onTap: () => onTab(2),
                ),
                _NavItem(
                  itemKey: const Key('nav-mais'),
                  icon: Icons.more_horiz,
                  selectedIcon: Icons.more_horiz,
                  label: 'Mais',
                  selected: currentIndex == 3,
                  onTap: () => onTab(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item comum da barra: ícone e rótulo; selecionado fica na cor primária.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.itemKey,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key itemKey;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: itemKey,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 24),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão central "Adicionar": círculo elevado acima da barra, sem estado de
/// seleção.
class _AddItem extends StatelessWidget {
  const _AddItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Adicionar',
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('nav-adicionar'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -22,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.add, color: scheme.onPrimary, size: 28),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Adicionar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
