import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Estrutura da navegação principal: somente Dashboard, Lançamentos e Mais
/// (`CLAUDE.md` §4.1). Cada aba mantém o próprio estado de navegação.
class MainShell extends StatelessWidget {
  const MainShell({
    required this.navigationShell,
    this.banner = const SizedBox.shrink(),
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// Faixa de estado no topo (conexão/sincronização).
  final Widget banner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          banner,
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Lançamentos',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}
