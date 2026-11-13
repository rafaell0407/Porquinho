import 'package:flutter/material.dart';

/// Visual das categorias: conjunto fixo de ícones (Material, licença Apache
/// 2.0) e de cores. O banco guarda só a chave, então a cor se adapta ao tema
/// claro/escuro e novos ícones podem entrar sem mudar o banco.
const defaultCategoryIconKey = 'category';
const defaultCategoryColorKey = 'gray';

/// Ícones oferecidos ao usuário, na ordem de exibição.
const categoryIcons = <String, IconData>{
  'shopping_cart': Icons.shopping_cart_outlined,
  'restaurant': Icons.restaurant_outlined,
  'coffee': Icons.local_cafe_outlined,
  'delivery': Icons.delivery_dining_outlined,
  'home': Icons.home_outlined,
  'bolt': Icons.bolt_outlined,
  'water': Icons.water_drop_outlined,
  'wifi': Icons.wifi,
  'phone': Icons.smartphone_outlined,
  'car': Icons.directions_car_outlined,
  'bus': Icons.directions_bus_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'health': Icons.favorite_border,
  'pharmacy': Icons.medication_outlined,
  'school': Icons.school_outlined,
  'book': Icons.menu_book_outlined,
  'leisure': Icons.theaters_outlined,
  'music': Icons.music_note_outlined,
  'travel': Icons.flight_outlined,
  'gift': Icons.card_giftcard_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'clothes': Icons.checkroom_outlined,
  'pets': Icons.pets_outlined,
  'fitness': Icons.fitness_center_outlined,
  'subscriptions': Icons.subscriptions_outlined,
  'card': Icons.credit_card_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'work': Icons.work_outline,
  'savings': Icons.savings_outlined,
  'trending_up': Icons.trending_up,
  'category': Icons.label_outline,
};

/// Ícone da chave; chave desconhecida (por exemplo, de uma versão mais nova do
/// app) cai no ícone padrão em vez de quebrar a tela.
IconData categoryIconFor(String key) =>
    categoryIcons[key] ?? categoryIcons[defaultCategoryIconKey]!;

/// Cores das categorias. Evitam o vermelho/coral (despesa) e o verde
/// (receita), que têm significado fixo no app.
const categoryColorKeys = [
  'yellow',
  'blue',
  'sand',
  'cyan',
  'pink',
  'orange',
  'lime',
  'gray',
];

const _darkColors = <String, Color>{
  'yellow': Color(0xFFE9C46A),
  'blue': Color(0xFF7FB8E8),
  'sand': Color(0xFFD2A679),
  'cyan': Color(0xFF6FD3D8),
  'pink': Color(0xFFF29BC0),
  'orange': Color(0xFFF2A65A),
  'lime': Color(0xFFA9D86E),
  'gray': Color(0xFF9AA7B8),
};

const _lightColors = <String, Color>{
  'yellow': Color(0xFF8F6508),
  'blue': Color(0xFF2D6FA8),
  'sand': Color(0xFF8A5A2B),
  'cyan': Color(0xFF0E7C8A),
  'pink': Color(0xFFB03A75),
  'orange': Color(0xFFB8601A),
  'lime': Color(0xFF4D7A12),
  'gray': Color(0xFF5A6678),
};

const categoryColorNames = <String, String>{
  'yellow': 'Amarelo',
  'blue': 'Azul',
  'sand': 'Areia',
  'cyan': 'Ciano',
  'pink': 'Rosa',
  'orange': 'Laranja',
  'lime': 'Lima',
  'gray': 'Cinza',
};

/// Cor da chave no brilho dado; chave desconhecida usa o cinza.
Color categoryColorFor(String key, Brightness brightness) {
  final table = brightness == Brightness.dark ? _darkColors : _lightColors;
  return table[key] ?? table[defaultCategoryColorKey]!;
}

/// Visual sugerido para as categorias do primeiro acesso.
const suggestedCategoryAppearance = <String, (String, String)>{
  'Salário': ('work', 'lime'),
  'Renda extra': ('wallet', 'cyan'),
  'Rendimentos': ('trending_up', 'yellow'),
  'Moradia': ('home', 'blue'),
  'Alimentação': ('restaurant', 'yellow'),
  'Mercado': ('shopping_cart', 'orange'),
  'Transporte': ('car', 'cyan'),
  'Saúde': ('health', 'pink'),
  'Educação': ('school', 'sand'),
  'Lazer': ('leisure', 'orange'),
  'Contas da casa': ('bolt', 'blue'),
  'Assinaturas': ('subscriptions', 'sand'),
  'Fatura do cartão': ('card', 'gray'),
};

/// Círculo com o ícone da categoria: cor cheia (cabeçalho) ou suave.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.iconKey,
    required this.colorKey,
    this.size = 40,
    this.filled = false,
  });

  final String iconKey;
  final String colorKey;
  final double size;

  /// `true`: fundo na cor da categoria e ícone no fundo da tela.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = categoryColorFor(colorKey, theme.brightness);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : theme.colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        categoryIconFor(iconKey),
        size: size * 0.5,
        color: filled ? theme.colorScheme.surface : color,
      ),
    );
  }
}
