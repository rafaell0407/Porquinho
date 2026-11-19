import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/domain/calendar_date.dart';
import '../../../core/domain/period_calendar.dart';
import '../../../core/domain/surplus.dart';
import '../data/import_batch.dart';
import '../data/import_repository.dart';
import '../data/picked_file.dart';
import '../domain/backfill_preview.dart';
import '../domain/category_resolution.dart';
import '../domain/column_mapping.dart';
import '../domain/csv_reader.dart';
import '../domain/date_parsing.dart';
import '../domain/duplicate_detection.dart';
import '../domain/existing_data.dart';
import '../domain/import_models.dart';
import '../domain/import_plan.dart';
import '../domain/norte_formats.dart';
import '../domain/row_validation.dart';
import '../domain/series_detection.dart';
import '../domain/text_decoding.dart';
import '../domain/value_parsing.dart';
import 'import_runner.dart';

/// Etapas do assistente (spec §6, 2–11). A etapa 1 é a tela inicial.
enum ImportStep {
  file('Arquivo'),
  columns('Colunas'),
  classification('Classificação'),
  categories('Categorias'),
  duplicates('Duplicidades'),
  series('Recorrências'),
  preview('Prévia e confirmação'),
  processing('Importando'),
  result('Resultado');

  const ImportStep(this.label);
  final String label;

  /// Etapas com "Voltar"/"Continuar".
  static const wizard = [
    file,
    columns,
    classification,
    categories,
    duplicates,
    series,
    preview,
  ];
}

/// Linha da prévia por período: dinheiro livre antes e depois (RN052).
class PeriodPreview {
  const PeriodPreview(this.effect, this.before);
  final PeriodEffect effect;

  /// Totais atuais do período no servidor (`null` = não carregados).
  final PeriodTotals? before;

  BigInt? get freeBefore => before?.surplus;
  BigInt? get freeAfter =>
      before == null ? null : before!.surplus + effect.delta;
}

/// Arquivo grande: aviso antes de confirmar (D24).
const largeFileRows = 2000;

String randomUuid([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Estado e regras do assistente de importação. Nada é gravado antes de
/// [confirm] (RN046).
class ImportWizardController extends ChangeNotifier {
  ImportWizardController({
    required ImportRepository repository,
    required CalendarDate today,
    required Future<PeriodConfig> Function() periodConfig,
    required Future<Map<PeriodRange, PeriodTotals>> Function(List<PeriodRange>)
    periodTotals,
    String Function()? newBatchId,
  }) : _repo = repository,
       _today = today,
       _periodConfig = periodConfig,
       _periodTotals = periodTotals,
       _newBatchId = newBatchId ?? randomUuid;

  final ImportRepository _repo;
  final CalendarDate _today;
  final Future<PeriodConfig> Function() _periodConfig;
  final Future<Map<PeriodRange, PeriodTotals>> Function(List<PeriodRange>)
  _periodTotals;
  final String Function() _newBatchId;

  CalendarDate get today => _today;

  ImportStep step = ImportStep.file;
  bool busy = false;
  String? error;

  // Arquivo.
  PickedFile? file;
  ImportEncoding encoding = ImportEncoding.utf8;
  String? decodeFailure;
  String? _text;
  CsvSeparator separator = CsvSeparator.comma;
  CsvTable? table;
  String? sha256;
  NorteFileKind? norteKind;
  ExistingData existing = const ExistingData();

  // Decisões.
  ImportMapping mapping = const ImportMapping();
  ValidationResult? validation;
  List<CategoryNeed> needs = const [];
  Map<String, CategoryChoice> categoryChoices = {};
  List<DuplicateGroup> duplicateGroups = const [];
  Map<String, DuplicateDecision> duplicateDecisions = {};
  List<SeriesCandidate> series = const [];
  Set<String> confirmedSeries = {};

  // Prévia e envio.
  String? _batchId;
  ImportPlan? plan;
  AssembledImport? assembled;
  List<PeriodPreview> periods = const [];
  BackfillCounts? pendingCounts;
  int progressDone = 0;
  int progressTotal = 0;
  RunResult? runResult;

  /// Retomada: importação interrompida cujo arquivo o usuário escolhe de novo.
  ImportBatch? resuming;

  PreviousImport? get previousImport => sha256 == null
      ? null
      : existing.imports.where((i) => i.fileSha256 == sha256).firstOrNull;

  int get dataRows => table?.records.length ?? 0;

  void _set(void Function() change) {
    change();
    notifyListeners();
  }

  Future<T?> _work<T>(Future<T> Function() run) async {
    _set(() {
      busy = true;
      error = null;
    });
    try {
      return await run();
    } on Object catch (e) {
      error =
          'Não foi possível concluir agora. Verifique a conexão e tente '
          'de novo. ($e)';
      return null;
    } finally {
      _set(() => busy = false);
    }
  }

  // ---------------------------------------------------------------- Arquivo

  /// Lê o arquivo escolhido (só no navegador) e o que já existe no servidor.
  Future<void> loadFile(PickedFile picked) => _work(() async {
    file = picked;
    sha256 = fileSha256(picked.bytes);
    encoding = ImportEncoding.utf8;
    _decode();
    existing = await _repo.loadExisting();
    notifyListeners();
  });

  /// Windows-1252 por escolha explícita quando o UTF-8 falhar (D23).
  void useEncoding(ImportEncoding value) => _set(() {
    encoding = value;
    _decode();
  });

  void _decode() {
    final decoded = decodeImportBytes(file!.bytes, encoding);
    decodeFailure = decoded.failure;
    _text = decoded.text;
    table = null;
    norteKind = null;
    if (_text == null) return;
    separator = detectSeparator(_text!);
    _parse();
  }

  void setSeparator(CsvSeparator value) => _set(() {
    separator = value;
    _parse();
  });

  void _parse() {
    table = parseCsv(_text!, separator);
    norteKind = recognizeNorteFile(table!.header);
    if (norteKind != null) {
      mapping = norteMapping(norteKind!);
    } else {
      mapping = ImportMapping(columns: suggestColumns(table!.header));
      _suggestFormats();
    }
    _resetFrom(ImportStep.columns);
  }

  /// Arquivo pronto para associar colunas.
  String? get fileProblem {
    if (file == null) return 'Escolha um arquivo.';
    if (decodeFailure != null) return decodeFailure;
    if (table == null || table!.isEmpty) return 'O arquivo está vazio.';
    if (table!.records.isEmpty) return 'O arquivo só tem o cabeçalho.';
    return null;
  }

  // ---------------------------------------------------------------- Colunas

  void setColumn(ImportField field, int? column) => _set(() {
    final columns = {...mapping.columns};
    columns.removeWhere((f, c) => c == column);
    if (column == null) {
      columns.remove(field);
    } else {
      columns[field] = column;
    }
    mapping = mapping.copyWith(columns: columns);
    if (field == ImportField.amount || ImportField.dateFields.contains(field)) {
      _suggestFormats();
    }
    _resetFrom(ImportStep.classification);
  });

  void _suggestFormats() {
    final t = table;
    if (t == null || norteKind != null) return;
    final amount = mapping.column(ImportField.amount);
    final valueFormat = amount == null
        ? null
        : suggestValueFormat(columnSample(t, amount));
    final dateSamples = [
      for (final f in ImportField.dateFields)
        if (mapping.column(f) != null) ...columnSample(t, mapping.column(f)!),
    ];
    final dateFormat = dateSamples.isEmpty
        ? null
        : suggestDateFormat(dateSamples);
    mapping = mapping.copyWith(
      valueFormat: valueFormat,
      clearValueFormat: valueFormat == null,
      dateFormat: dateFormat,
      clearDateFormat: dateFormat == null,
    );
  }

  void setValueFormat(ValueFormat? value) => _set(() {
    mapping = mapping.copyWith(
      valueFormat: value,
      clearValueFormat: value == null,
    );
    _resetFrom(ImportStep.classification);
  });

  void setDateFormat(DateFormatKind? value) => _set(() {
    mapping = mapping.copyWith(
      dateFormat: value,
      clearDateFormat: value == null,
    );
    _resetFrom(ImportStep.classification);
  });

  // --------------------------------------------------------- Classificação

  void setTypeSource(TypeSource value) => _set(() {
    mapping = mapping.copyWith(typeSource: value);
    _resetFrom(ImportStep.categories);
  });

  void setFixedKind(RowKind? value) => _set(() {
    mapping = mapping.copyWith(fixedKind: value, clearFixedKind: value == null);
    _resetFrom(ImportStep.categories);
  });

  void setKindValue(String raw, RowKind? kind) => _set(() {
    mapping = mapping.copyWith(kindValues: {...mapping.kindValues, raw: kind});
    _resetFrom(ImportStep.categories);
  });

  void setStatusValue(String raw, StatusMeaning meaning) => _set(() {
    mapping = mapping.copyWith(
      statusValues: {...mapping.statusValues, raw: meaning},
    );
    _resetFrom(ImportStep.categories);
  });

  void setMarkExpensesPaid(bool value) => _set(() {
    mapping = mapping.copyWith(markExpensesPaid: value);
    _resetFrom(ImportStep.categories);
  });

  void setPaidDateSource(PaidDateSource value) => _set(() {
    mapping = mapping.copyWith(paidDateSource: value);
    _resetFrom(ImportStep.categories);
  });

  List<String> get columnProblems {
    final t = table;
    if (t == null) return const ['Escolha um arquivo.'];
    return mappingProblems(
      mapping,
      t,
    ).where((p) => !_isClassificationProblem(p)).toList();
  }

  List<String> get classificationProblems {
    final t = table;
    if (t == null) return const ['Escolha um arquivo.'];
    return mappingProblems(mapping, t);
  }

  static bool _isClassificationProblem(String p) =>
      p.contains('tipo do arquivo') ||
      p.contains('coluna de tipo') ||
      p.contains('cada situação') ||
      p.contains('data de pagamento');

  /// Valores distintos da coluna (tipo ou situação), normalizados.
  List<String> distinctValues(ImportField field) {
    final c = mapping.column(field);
    if (c == null || table == null) return const [];
    return distinctColumnValues(table!, c);
  }

  // ------------------------------------------------------------ Categorias

  void _validate() {
    validation = validateRows(table!, mapping, _today);
    needs = collectCategoryNeeds(validation!.rows, validation!.categoryRows);
    final suggested = suggestCategoryChoices(needs, existing);
    categoryChoices = {
      for (final e in suggested.entries)
        e.key: categoryChoices[e.key] ?? e.value,
    };
  }

  void setCategoryChoice(String key, CategoryChoice choice) => _set(() {
    categoryChoices = {...categoryChoices, key: choice};
    final need = needs.where((n) => n.key == key).firstOrNull;
    if (need != null) {
      for (final sub in need.subs.values) {
        categoryChoices[sub.key] = suggestSubcategoryChoice(
          choice,
          sub,
          existing,
        );
      }
    }
    _resetFrom(ImportStep.duplicates);
  });

  List<String> get categoryProblemsList =>
      categoryProblems(needs, categoryChoices, existing);

  // ---------------------------------------------------------- Duplicidades

  void decide(String groupId, DuplicateDecision decision) => _set(() {
    duplicateDecisions = {...duplicateDecisions, groupId: decision};
    _resetFrom(ImportStep.series);
  });

  /// Ação em massa, só por clique explícito (RN053).
  void decideAll(DuplicateKind? kind, DuplicateDecision decision) => _set(() {
    duplicateDecisions = {
      ...duplicateDecisions,
      for (final g in duplicateGroups)
        if (kind == null || g.kind == kind) g.id: decision,
    };
    _resetFrom(ImportStep.series);
  });

  int get undecided => undecidedGroups(duplicateGroups, duplicateDecisions);

  Set<int> get ignored => ignoredRows(duplicateGroups, duplicateDecisions);

  // ----------------------------------------------------------- Recorrências

  void toggleSeries(String id, bool confirmed) => _set(() {
    confirmedSeries = {...confirmedSeries};
    confirmed ? confirmedSeries.add(id) : confirmedSeries.remove(id);
    _resetFrom(ImportStep.preview);
  });

  /// Prévia das atrasadas de uma série (RN052).
  List<BackfillOccurrence> backfillOf(SeriesCandidate s) =>
      backfillFor(s, _today);

  // -------------------------------------------------------------- Navegação

  /// O que impede sair da etapa atual.
  List<String> get blockers => switch (step) {
    ImportStep.file => [?fileProblem],
    ImportStep.columns => columnProblems,
    ImportStep.classification => classificationProblems,
    ImportStep.categories => categoryProblemsList,
    ImportStep.duplicates => [
      if (undecided > 0)
        'Decida os $undecided grupo(s) de possíveis duplicidades.',
    ],
    ImportStep.series => const [],
    ImportStep.preview => [
      if ((assembled?.items.isEmpty ?? true)) 'Não há nada para importar.',
    ],
    _ => const [],
  };

  bool get canContinue => !busy && blockers.isEmpty;

  /// Ao mudar uma decisão, as etapas seguintes são refeitas.
  void _resetFrom(ImportStep from) {
    final index = ImportStep.values.indexOf(from);
    if (index <= ImportStep.values.indexOf(ImportStep.categories)) {
      validation = null;
    }
    if (index <= ImportStep.values.indexOf(ImportStep.duplicates)) {
      duplicateGroups = const [];
    }
    if (index <= ImportStep.values.indexOf(ImportStep.series)) {
      series = const [];
    }
    plan = null;
    assembled = null;
    periods = const [];
  }

  Future<void> next() async {
    if (!canContinue) return;
    switch (step) {
      case ImportStep.file:
        _set(() => step = ImportStep.columns);
      case ImportStep.columns:
        _set(() => step = ImportStep.classification);
      case ImportStep.classification:
        _set(() {
          _validate();
          step = ImportStep.categories;
        });
      case ImportStep.categories:
        _set(() {
          duplicateGroups = detectDuplicates(
            validation!.rows,
            existing,
            fileSha256: sha256!,
          );
          duplicateDecisions = {
            for (final e in duplicateDecisions.entries)
              if (duplicateGroups.any((g) => g.id == e.key)) e.key: e.value,
          };
          step = ImportStep.duplicates;
        });
      case ImportStep.duplicates:
        _set(() {
          final skip = ignored;
          series = detectSeries(
            [
              for (final r in validation!.rows)
                if (!skip.contains(r.sourceRow)) r,
            ],
            categoryChoices,
            _today,
            existing,
          );
          confirmedSeries = {
            for (final id in confirmedSeries)
              if (series.any(
                (s) => s.id == id && s.status == SeriesStatus.suggested,
              ))
                id,
          };
          step = ImportStep.series;
        });
      case ImportStep.series:
        await _buildPreview();
      case ImportStep.preview:
        await confirm();
      default:
        break;
    }
  }

  void back() {
    final i = ImportStep.wizard.indexOf(step);
    if (i > 0 && !busy) _set(() => step = ImportStep.wizard[i - 1]);
  }

  Future<void> _buildPreview() => _work(() async {
    _batchId ??= _newBatchId();
    plan = ImportPlan(
      batchId: _batchId!,
      today: _today,
      encoding: encoding,
      separator: separator,
      mapping: mapping,
      categoryChoices: categoryChoices,
      duplicateDecisions: duplicateDecisions,
      ignoredRows: ignored.toList(),
      confirmedSeries: confirmedSeries.toList(),
    );
    assembled = assembleImport(table!, plan!);
    final config = await _periodConfig();
    final effects = effectByPeriod(
      assembled!.rows,
      assembled!.backfill,
      config,
    );
    Map<PeriodRange, PeriodTotals> before = const {};
    if (effects.isNotEmpty) {
      before = await _periodTotals([for (final e in effects) e.range]);
    }
    periods = [for (final e in effects) PeriodPreview(e, before[e.range])];
    pendingCounts = countPending(
      assembled!.rows,
      assembled!.anchors,
      assembled!.backfill,
      _today,
    );
    step = ImportStep.preview;
  });

  bool get isLargeFile => dataRows > largeFileRows;

  /// Estimativa (cerca de 1 segundo por bloco).
  Duration get estimatedDuration =>
      Duration(seconds: (assembled?.chunks.length ?? 0) + 2);

  Map<String, Object?> get _summary {
    final a = assembled!;
    final v = a.validation;
    return {
      'rejected': a.rejected.length,
      'cancelled': v.cancelled,
      'ignored_duplicates': a.ignoredByDuplicates,
      'ignored_by_kind': v.ignoredByKind,
      'inactive_categories': v.inactiveCategories,
      'empty_lines': v.emptyLines,
      'warnings': v.warningCount,
      'entries': a.entryCount,
      'series': a.series.length,
      'backfill': a.backfill.length,
    };
  }

  ImportFileInfo get _fileInfo => ImportFileInfo(
    name: file!.name.length > 255 ? file!.name.substring(0, 255) : file!.name,
    sha256: sha256!,
    sizeBytes: file!.bytes.length,
    rows: dataRows,
  );

  /// Grava (etapa 10). Até aqui nada foi enviado.
  Future<void> confirm() async {
    if (plan == null || assembled == null) return;
    _set(() {
      step = ImportStep.processing;
      progressDone = 0;
      progressTotal = assembled!.chunks.length;
      runResult = null;
      error = null;
    });
    await _run(resume: false);
  }

  Future<void> _run({required bool resume}) async {
    final result = await ImportRunner(_repo).run(
      plan: plan!,
      file: _fileInfo,
      assembled: assembled!,
      summary: _summary,
      resume: resume,
      onProgress: (done, total) => _set(() {
        progressDone = done;
        progressTotal = total;
      }),
    );
    _set(() {
      runResult = result;
      step = ImportStep.result;
    });
  }

  // ---------------------------------------------------------------- Retomar

  /// Retomar (D26): o usuário escolhe de novo o mesmo arquivo. Mesmo hash e
  /// mesmo plano → continua do primeiro bloco não aplicado; diferente → só
  /// desfazer.
  Future<String?> resumeWith(ImportBatch batch, PickedFile picked) async {
    final full = await _repo.batch(batch.id);
    if (full?.plan == null) return 'Importação não encontrada.';
    if (fileSha256(picked.bytes) != full!.fileSha256) {
      return 'Este não é o mesmo arquivo da importação. Escolha o arquivo '
          'original ou desfaça o que entrou.';
    }
    final restored = ImportPlan.fromJson(full.plan!);
    final decoded = decodeImportBytes(picked.bytes, restored.encoding);
    if (!decoded.ok) return decoded.failure;
    final t = parseCsv(decoded.text!, restored.separator);
    final a = assembleImport(t, restored);
    if (restored.hash != full.planHash ||
        a.chunks.length != full.totalChunks ||
        a.items.length != full.itemCount) {
      return 'O arquivo ou as decisões mudaram: não dá para continuar. '
          'Desfaça o que entrou e importe de novo.';
    }
    file = picked;
    sha256 = full.fileSha256;
    encoding = restored.encoding;
    separator = restored.separator;
    table = t;
    mapping = restored.mapping;
    plan = restored;
    assembled = a;
    resuming = full;
    _set(() {
      step = ImportStep.processing;
      progressTotal = a.chunks.length;
    });
    await _run(resume: true);
    return null;
  }
}
