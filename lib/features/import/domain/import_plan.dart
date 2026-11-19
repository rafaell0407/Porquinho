import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/domain/calendar_date.dart';
import 'backfill_preview.dart';
import 'category_resolution.dart';
import 'column_mapping.dart';
import 'csv_reader.dart';
import 'duplicate_detection.dart';
import 'existing_data.dart';
import 'import_models.dart';
import 'row_validation.dart';
import 'series_detection.dart';
import 'text_decoding.dart';

/// Metadados do arquivo guardados no histórico (D27): sem o conteúdo.
class ImportFileInfo {
  const ImportFileInfo({
    required this.name,
    required this.sha256,
    required this.sizeBytes,
    required this.rows,
  });

  final String name;
  final String sha256;
  final int sizeBytes;

  /// Linhas de dados (sem o cabeçalho e sem as vazias).
  final int rows;

  Map<String, Object?> toJson() => {
    'name': name,
    'sha256': sha256,
    'size_bytes': sizeBytes,
    'rows': rows,
  };
}

/// Todas as decisões do usuário (§11 `plan`): com o mesmo arquivo, elas
/// reproduzem exatamente os mesmos itens, ids e blocos (retomar, D26).
class ImportPlan {
  const ImportPlan({
    required this.batchId,
    required this.today,
    required this.encoding,
    required this.separator,
    required this.mapping,
    required this.categoryChoices,
    required this.duplicateDecisions,
    required this.ignoredRows,
    required this.confirmedSeries,
  });

  final String batchId;

  /// Data usada nas validações (faixa de datas, séries).
  final CalendarDate today;
  final ImportEncoding encoding;
  final CsvSeparator separator;
  final ImportMapping mapping;
  final Map<String, CategoryChoice> categoryChoices;
  final Map<String, DuplicateDecision> duplicateDecisions;

  /// Linhas ignoradas pelas decisões de duplicidade (guardadas, não
  /// recalculadas: ao retomar, o que já entrou não pode virar "duplicidade").
  final List<int> ignoredRows;
  final List<String> confirmedSeries;

  /// O usuário decidiu importar de novo um arquivo já importado.
  bool get allowDuplicateFile =>
      duplicateDecisions['file'] == DuplicateDecision.importAnyway;

  Map<String, Object?> toJson() => {
    'version': 1,
    'batch_id': batchId,
    'today': today.toIso(),
    'encoding': encoding.name,
    'separator': separator.name,
    'mapping': mapping.toJson(),
    'category_choices': {
      for (final k in (categoryChoices.keys.toList()..sort()))
        k: categoryChoices[k]!.toJson(),
    },
    'duplicate_decisions': {
      for (final k in (duplicateDecisions.keys.toList()..sort()))
        k: duplicateDecisions[k]!.name,
    },
    'ignored_rows': [...ignoredRows]..sort(),
    'confirmed_series': [...confirmedSeries]..sort(),
    'allow_duplicate_file': allowDuplicateFile,
  };

  factory ImportPlan.fromJson(Map<String, dynamic> json) => ImportPlan(
    batchId: json['batch_id'] as String,
    today: CalendarDate.parse(json['today'] as String),
    encoding: ImportEncoding.values.byName(json['encoding'] as String),
    separator: CsvSeparator.values.byName(json['separator'] as String),
    mapping: ImportMapping.fromJson(
      Map<String, dynamic>.from(json['mapping'] as Map),
    ),
    categoryChoices: {
      for (final e in (json['category_choices'] as Map).entries)
        e.key as String: CategoryChoice.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        ),
    },
    duplicateDecisions: {
      for (final e in (json['duplicate_decisions'] as Map).entries)
        e.key as String: DuplicateDecision.values.byName(e.value as String),
    },
    ignoredRows: [
      for (final r in json['ignored_rows'] as List) (r as num).toInt(),
    ],
    confirmedSeries: [for (final s in json['confirmed_series'] as List) '$s'],
  );

  /// Hash do plano (mesmas decisões = mesmo hash).
  String get hash =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();
}

/// UUID determinístico a partir de um nome: `md5` com versão 5 e variante 8,
/// como `recurrence_occurrence_id` no servidor.
String importUuid(String name) {
  final chars = md5.convert(utf8.encode(name)).toString().split('');
  chars[12] = '5';
  chars[16] = '8';
  final h = chars.join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

abstract final class ImportIds {
  static String entry(String batch, int row) => importUuid('$batch|row|$row');
  static String category(String batch, String key) =>
      importUuid('$batch|category|$key');
  static String subcategory(String batch, String key) =>
      importUuid('$batch|subcategory|$key');
  static String template(String batch, String seriesId) =>
      importUuid('$batch|series|$seriesId');
}

/// Itens por bloco (§12): cada bloco é uma transação no servidor.
const importChunkSize = 250;

/// Resultado da montagem: o que será gravado e o que a prévia mostra.
class AssembledImport {
  const AssembledImport({
    required this.items,
    required this.validation,
    required this.rows,
    required this.series,
    required this.backfill,
    required this.lateRejected,
    required this.newCategories,
    required this.newSubcategories,
    required this.ignoredByDuplicates,
  });

  /// Itens na ordem de gravação: categorias, subcategorias, lançamentos e
  /// séries.
  final List<Map<String, Object?>> items;
  final ValidationResult validation;

  /// Lançamentos que entram (avulsos e âncoras), sem os ignorados.
  final List<ImportRow> rows;

  /// Séries confirmadas.
  final List<SeriesCandidate> series;
  final List<BackfillOccurrence> backfill;

  /// Rejeitadas na validação final (só âncora de série confirmada, D18).
  final List<RejectedRow> lateRejected;
  final int newCategories;
  final int newSubcategories;
  final int ignoredByDuplicates;

  List<RejectedRow> get rejected =>
      [...validation.rejected, ...lateRejected]
        ..sort((a, b) => a.sourceRow.compareTo(b.sourceRow));

  int get entryCount => rows.length;

  List<List<Map<String, Object?>>> get chunks => [
    for (var i = 0; i < items.length; i += importChunkSize)
      items.sublist(
        i,
        i + importChunkSize > items.length ? items.length : i + importChunkSize,
      ),
  ];

  Set<ImportRow> get anchors => {for (final s in series) s.anchor};
}

String? _date(CalendarDate? d) => d?.toIso();
int? _cents(BigInt? v) => v?.toInt();

/// Monta a importação a partir do arquivo lido e das decisões do [plan].
/// Determinística: mesmo arquivo + mesmo plano = mesmos itens.
AssembledImport assembleImport(CsvTable table, ImportPlan plan) {
  final batch = plan.batchId;
  final validation = validateRows(table, plan.mapping, plan.today);
  final needs = collectCategoryNeeds(validation.rows, validation.categoryRows);
  final choices = plan.categoryChoices;
  final ignored = plan.ignoredRows.toSet();
  final kept = [
    for (final r in validation.rows)
      if (!ignored.contains(r.sourceRow)) r,
  ];

  // Séries confirmadas (a trava de colisão foi aplicada ao confirmar).
  final confirmed = plan.confirmedSeries.toSet();
  final series = [
    for (final s in detectSeries(
      kept,
      choices,
      plan.today,
      const ExistingData(),
    ))
      if (confirmed.contains(s.id) && s.status == SeriesStatus.suggested) s,
  ];
  final anchors = {for (final s in series) s.anchor};

  final lateRejected = <RejectedRow>[];
  final rows = <ImportRow>[];
  for (final r in kept) {
    if (r.anchorOnly && !anchors.contains(r)) {
      lateRejected.add(
        RejectedRow(
          r.sourceRow,
          r.amount == null
              ? 'Lançamento sem valor só entra como início de uma '
                    'recorrência confirmada.'
              : 'Receita a receber só entra como início de uma recorrência '
                    'confirmada.',
        ),
      );
    } else {
      rows.add(r);
    }
  }

  final items = <Map<String, Object?>>[];
  final categoryIds = <String, String>{};
  var newSubs = 0;
  for (final need in needs) {
    final choice = choices[need.key];
    String? parentId;
    if (choice?.type == CategoryChoiceType.create) {
      parentId = ImportIds.category(batch, need.key);
      categoryIds[need.key] = parentId;
      items.add({
        'type': 'category',
        'id': parentId,
        'kind': need.kind.key,
        'name': need.name,
      });
    } else if (choice?.type == CategoryChoiceType.existing) {
      parentId = choice!.existingId;
    }
    if (parentId == null) continue;
    for (final sub in need.subs.values) {
      if (choices[sub.key]?.type != CategoryChoiceType.create) continue;
      categoryIds[sub.key] = ImportIds.subcategory(batch, sub.key);
      newSubs++;
    }
  }
  // Subcategorias depois de todas as categorias.
  for (final need in needs) {
    final choice = choices[need.key];
    final parentId = choice?.type == CategoryChoiceType.existing
        ? choice!.existingId
        : categoryIds[need.key];
    if (parentId == null) continue;
    for (final sub in need.subs.values) {
      final id = categoryIds[sub.key];
      if (id == null) continue;
      items.add({
        'type': 'subcategory',
        'id': id,
        'category_id': parentId,
        'name': sub.name,
      });
    }
  }

  Map<String, Object?> categoryFields(ImportRow r) {
    final ref = resolveCategory(r, choices);
    return {
      'category_id': ref.categoryId ?? categoryIds[ref.newCategoryKey],
      'subcategory_id': ref.subId ?? categoryIds[ref.newSubKey],
    };
  }

  Map<String, Object?> entryFields(ImportRow r) => switch (r.kind) {
    RowKind.income => {
      'description': r.description,
      'amount_centavos': _cents(r.amount),
      'received_on': r.date.toIso(),
      ...categoryFields(r),
    },
    RowKind.expense => {
      'description': r.description,
      'amount_centavos': _cents(r.amount),
      'competence_on': r.date.toIso(),
      'due_on': _date(r.dueOn),
      'paid_on': _date(r.paidOn),
      ...categoryFields(r),
    },
    RowKind.investment => {
      'amount_centavos': _cents(r.amount),
      'allocated_on': r.date.toIso(),
    },
    RowKind.category => const {},
  };

  final anchorSeries = {for (final s in series) s.anchor: s};
  final seriesItems = <Map<String, Object?>>[];
  for (final r in rows) {
    final id = ImportIds.entry(batch, r.sourceRow);
    final s = anchorSeries[r];
    if (s == null) {
      items.add({
        'type': r.kind.key,
        'id': id,
        'row': r.sourceRow,
        ...entryFields(r),
      });
      continue;
    }
    final category = categoryFields(r);
    seriesItems.add({
      'type': 'series',
      'kind': r.kind.key,
      'template_id': ImportIds.template(batch, s.id),
      'id': id,
      'row': r.sourceRow,
      'state': r.state.name,
      'entry': entryFields(r),
      'template': {
        if (r.kind != RowKind.investment) 'description': r.description,
        'frequency': 'monthly',
        'starts_on': r.date.toIso(),
        'monthly_reference_day': r.date.day,
        'value_mode': s.fixed ? 'fixed' : 'variable',
        'default_amount_centavos': _cents(s.defaultAmount),
        if (r.kind != RowKind.investment) ...category,
      },
    });
  }
  items.addAll(seriesItems);

  return AssembledImport(
    items: items,
    validation: validation,
    rows: rows,
    series: series,
    backfill: [for (final s in series) ...backfillFor(s, plan.today)],
    lateRejected: lateRejected,
    newCategories: items.where((i) => i['type'] == 'category').length,
    newSubcategories: newSubs,
    ignoredByDuplicates: validation.rows
        .where((r) => ignored.contains(r.sourceRow))
        .length,
  );
}
