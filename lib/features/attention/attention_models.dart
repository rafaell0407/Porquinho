import 'dart:convert';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/money.dart';

enum AttentionKind { conflict, rejected }

/// Item que precisa de decisão do usuário (Entrega 22): conflito entre a
/// versão do aparelho e a do servidor, ou alteração recusada pelo servidor.
class AttentionItem {
  const AttentionItem({
    required this.kind,
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.request,
    this.remote = const {},
    this.reason,
  });

  final AttentionKind kind;

  /// Id do conflito (servidor) ou chave idempotente da operação recusada.
  final String id;
  final String entityType;
  final String entityId;

  /// Alteração do usuário, com as chaves sem o prefixo `p_`
  /// (`action`, `name`, `payload`…).
  final Map<String, dynamic> request;

  /// Registro como está no servidor (conflitos).
  final Map<String, dynamic> remote;

  /// Motivo da recusa, quando [kind] é `rejected`.
  final String? reason;

  /// Ação pedida. A configuração de período não envia `action`: é criação
  /// quando a versão esperada é 0 e troca nos demais casos.
  String? get action =>
      request['action'] as String? ??
      (entityType == 'period_settings'
          ? (request['expected_version'] == 0 ? 'create' : 'update')
          : null);

  /// Conflitos de criação, de período e de configuração só aceitam a versão
  /// do servidor (o servidor recusa reaplicar uma criação).
  bool get canKeepLocal =>
      kind == AttentionKind.conflict &&
      _reapplicable.contains(entityType) &&
      action != null &&
      action != 'create';

  bool get canEdit =>
      canKeepLocal &&
      (((entityType == 'category' || entityType == 'subcategory') &&
              action == 'rename') ||
          ((entityType == 'income_entry' || entityType == 'expense_entry') &&
              action == 'update') ||
          (isInvestment && action == 'update'));

  bool get isInvestment => entityType == 'investment_allocation';

  bool get isEntry =>
      entityType == 'income_entry' || entityType == 'expense_entry';

  String get title => entityLabel(entityType);

  /// Texto da alteração feita neste aparelho.
  String get mineSummary => describeRequest(entityType, request);

  /// Texto do registro no servidor.
  String get serverSummary => describeRecord(entityType, remote);

  static const _reapplicable = {
    'category',
    'subcategory',
    'income_entry',
    'expense_entry',
    'investment_allocation',
    'income_recurrence_template',
    'expense_recurrence_template',
    'investment_recurrence_template',
    'period_settings',
  };
}

String entityLabel(String entityType) => switch (entityType) {
  'category' => 'Categoria',
  'subcategory' => 'Subcategoria',
  'period_settings' => 'Configuração de período',
  'income_entry' => 'Receita',
  'expense_entry' => 'Despesa',
  'investment_allocation' => 'Investimento',
  'income_recurrence_template' => 'Receita recorrente',
  'expense_recurrence_template' => 'Despesa recorrente',
  'investment_recurrence_template' => 'Investimento recorrente',
  'user_preferences' => 'Preferência da conta',
  _ => 'Item',
};

/// Remove o prefixo `p_` dos parâmetros de RPC guardados na fila local, para
/// comparar com o formato do conflito no servidor.
Map<String, dynamic> normalizeRequest(Map<String, dynamic> raw) => {
  for (final e in raw.entries)
    (e.key.startsWith('p_') ? e.key.substring(2) : e.key): e.value,
};

String _amount(Object? value) {
  if (value == null) return 'sem valor';
  try {
    return formatBrl(BigInt.parse(value.toString()));
  } on FormatException {
    return value.toString();
  }
}

String _date(Object? value) {
  if (value == null) return '';
  try {
    return CalendarDate.parse(value.toString()).toBr();
  } on Object {
    return value.toString();
  }
}

/// Resumo, em português, da alteração pedida pelo usuário.
String describeRequest(String entityType, Map<String, dynamic> request) {
  final action = request['action'];
  switch (entityType) {
    case 'category':
    case 'subcategory':
      return switch (action) {
        'create' => 'Criar "${request['name']}"',
        'rename' => 'Renomear para "${request['name']}"',
        'restyle' => 'Mudar ícone e cor',
        'deactivate' => 'Desativar',
        _ => 'Alterar',
      };
    case 'income_entry':
    case 'expense_entry':
      if (action == 'cancel') return 'Cancelar o lançamento';
      if (action == 'pay') return 'Marcar como paga';
      final payload = Map<String, dynamic>.from(
        (request['payload'] as Map?) ?? const {},
      );
      final parts = <String>[
        if (payload.containsKey('amount_centavos'))
          _amount(payload['amount_centavos']),
        if (payload['description'] != null) '${payload['description']}',
        if (payload['received_on'] != null) _date(payload['received_on']),
        if (payload['competence_on'] != null) _date(payload['competence_on']),
      ];
      final verb = action == 'create' ? 'Criar' : 'Alterar';
      return parts.isEmpty ? verb : '$verb: ${parts.join(' · ')}';
    case 'investment_allocation':
      if (action == 'cancel') return 'Cancelar o investimento';
      final parts = <String>[
        if (request['amount_centavos'] != null)
          _amount(request['amount_centavos']),
        if (request['allocated_on'] != null) _date(request['allocated_on']),
      ];
      final verb = action == 'create' ? 'Criar' : 'Alterar';
      return parts.isEmpty ? verb : '$verb: ${parts.join(' · ')}';
    case 'period_settings':
      return 'Mudar para ${_periodConfig(request)}';
    default:
      return switch (action) {
        'create' => 'Criar',
        'cancel' => 'Cancelar',
        _ => 'Alterar',
      };
  }
}

/// Resumo do registro como está no servidor.
String describeRecord(String entityType, Map<String, dynamic> record) {
  if (record.isEmpty) return 'Sem dados do servidor';
  switch (entityType) {
    case 'category':
    case 'subcategory':
      final inactive = record['is_active'] == false ? ' (desativada)' : '';
      return '"${record['name']}"$inactive';
    case 'income_entry':
    case 'expense_entry':
      final cancelled = record['status'] == 'cancelled' ? ' (cancelado)' : '';
      final date = record['received_on'] ?? record['competence_on'];
      final parts = <String>[
        _amount(record['amount_centavos']),
        if (record['description'] != null) '${record['description']}',
        if (date != null) _date(date),
      ];
      return '${parts.join(' · ')}$cancelled';
    case 'investment_allocation':
      final cancelled = record['cancelled_at'] != null ? ' (cancelado)' : '';
      return '${_amount(record['amount_centavos'])} · '
          '${_date(record['allocated_on'])}$cancelled';
    case 'period_settings':
      return _periodConfig(record);
    default:
      return 'Versão ${record['version']}';
  }
}

/// Converte um JSON vindo do servidor (objeto ou texto) em mapa.
Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }
  return {};
}

/// "Mês-calendário" ou "Ciclo personalizado (dia N)".
String _periodConfig(Map<String, dynamic> m) => m['mode'] == 'custom_cycle'
    ? 'Ciclo personalizado (dia ${m['custom_start_day']})'
    : 'Mês-calendário';
