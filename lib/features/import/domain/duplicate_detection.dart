import 'existing_data.dart';
import 'import_models.dart';

/// Etapa "Duplicidades" (RN053): só aviso, nunca decisão automática. Cada
/// grupo exige "Importar mesmo assim" ou "Ignorar"; nada vem marcado.
enum DuplicateKind {
  withinFile('Repetidas dentro do arquivo'),
  againstExisting('Parecidas com lançamentos que já existem'),
  fileAlreadyImported('Arquivo já importado');

  const DuplicateKind(this.label);
  final String label;
}

enum DuplicateDecision { importAnyway, ignore }

class DuplicateGroup {
  const DuplicateGroup({
    required this.id,
    required this.kind,
    required this.rows,
    required this.rowsIgnoredOnIgnore,
    this.matches = const [],
    this.strong = false,
    this.sameDescription = false,
  });

  /// Identificador estável (vai no plano com a decisão).
  final String id;
  final DuplicateKind kind;

  /// Linhas do arquivo envolvidas.
  final List<int> rows;

  /// Linhas que deixam de entrar se o usuário escolher "Ignorar" (dentro do
  /// arquivo: todas menos a primeira).
  final List<int> rowsIgnoredOnIgnore;

  /// Lançamentos existentes parecidos (contra o banco).
  final List<ExistingEntry> matches;

  /// Sinal forte: mesmo `id` do Norte.
  final bool strong;

  /// Descrição também igual (critério secundário).
  final bool sameDescription;
}

String _money(BigInt? v) => v?.toString() ?? '-';

/// Grupos de possíveis duplicidades. [fileSha256] confere importações
/// anteriores não desfeitas do mesmo arquivo.
List<DuplicateGroup> detectDuplicates(
  List<ImportRow> rows,
  ExistingData existing, {
  required String fileSha256,
}) {
  final groups = <DuplicateGroup>[];

  // Arquivo já importado.
  final previous = existing.imports
      .where((i) => i.fileSha256 == fileSha256)
      .toList();
  if (previous.isNotEmpty && rows.isNotEmpty) {
    final all = [for (final r in rows) r.sourceRow];
    groups.add(
      DuplicateGroup(
        id: 'file',
        kind: DuplicateKind.fileAlreadyImported,
        rows: all,
        rowsIgnoredOnIgnore: all,
        strong: true,
      ),
    );
  }

  // Dentro do arquivo: mesmos tipo, data, valor, descrição e categoria; ou
  // mesmo id do Norte.
  final byValues = <String, List<ImportRow>>{};
  final byId = <String, List<ImportRow>>{};
  for (final r in rows) {
    final key = [
      r.kind.key,
      r.date.toIso(),
      _money(r.amount),
      normalizeKey(r.description),
      normalizeKey(r.categoryName),
    ].join('|');
    byValues.putIfAbsent(key, () => []).add(r);
    if (r.norteId != null && r.norteId!.isNotEmpty) {
      byId.putIfAbsent('${r.kind.key}|${r.norteId}', () => []).add(r);
    }
  }
  for (final e in byId.entries.where((e) => e.value.length > 1)) {
    final list = [for (final r in e.value) r.sourceRow];
    groups.add(
      DuplicateGroup(
        id: 'id:${e.key}',
        kind: DuplicateKind.withinFile,
        rows: list,
        rowsIgnoredOnIgnore: list.sublist(1),
        strong: true,
        sameDescription: true,
      ),
    );
  }
  for (final e in byValues.entries.where((e) => e.value.length > 1)) {
    final list = [for (final r in e.value) r.sourceRow];
    groups.add(
      DuplicateGroup(
        id: 'file-values:${list.first}',
        kind: DuplicateKind.withinFile,
        rows: list,
        rowsIgnoredOnIgnore: list.sublist(1),
        sameDescription: true,
      ),
    );
  }

  // Contra o banco: mesmo tipo, data e valor (lançamentos não cancelados);
  // mesmo id do Norte já existente é sinal forte.
  final existingByValues = <String, List<ExistingEntry>>{};
  final existingById = <String, ExistingEntry>{};
  for (final e in existing.entries) {
    existingById['${e.kind.key}|${e.id}'] = e;
    if (e.cancelled) continue;
    existingByValues
        .putIfAbsent(
          '${e.kind.key}|${e.date.toIso()}|${_money(e.amount)}',
          () => [],
        )
        .add(e);
  }
  for (final r in rows) {
    final matches = <ExistingEntry>[
      ...?existingByValues['${r.kind.key}|${r.date.toIso()}|${_money(r.amount)}'],
    ];
    var strong = false;
    if (r.norteId != null) {
      final byIdMatch = existingById['${r.kind.key}|${r.norteId}'];
      if (byIdMatch != null) {
        strong = true;
        if (!matches.any((m) => m.id == byIdMatch.id)) {
          matches.insert(0, byIdMatch);
        }
      }
    }
    if (matches.isEmpty) continue;
    final sameDescription = matches.any(
      (m) => normalizeKey(m.description) == normalizeKey(r.description),
    );
    groups.add(
      DuplicateGroup(
        id: 'db:${r.sourceRow}',
        kind: DuplicateKind.againstExisting,
        rows: [r.sourceRow],
        rowsIgnoredOnIgnore: [r.sourceRow],
        matches: matches,
        strong: strong,
        sameDescription: sameDescription,
      ),
    );
  }
  return groups;
}

/// Linhas ignoradas pelas decisões tomadas.
Set<int> ignoredRows(
  List<DuplicateGroup> groups,
  Map<String, DuplicateDecision> decisions,
) => {
  for (final g in groups)
    if (decisions[g.id] == DuplicateDecision.ignore) ...g.rowsIgnoredOnIgnore,
};

/// Quantos grupos ainda não têm decisão (só avança com zero).
int undecidedGroups(
  List<DuplicateGroup> groups,
  Map<String, DuplicateDecision> decisions,
) => groups.where((g) => !decisions.containsKey(g.id)).length;
