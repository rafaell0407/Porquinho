import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/surplus.dart';
import 'package:porquinho/features/import/application/import_providers.dart';
import 'package:porquinho/features/import/data/import_batch.dart';
import 'package:porquinho/features/import/data/picked_file.dart';
import 'package:porquinho/features/import/domain/import_template.dart';
import 'package:porquinho/features/import/domain/norte_formats.dart';
import 'package:porquinho/features/import/screens/import_batch_screen.dart';
import 'package:porquinho/features/import/screens/import_guide_screen.dart';
import 'package:porquinho/features/import/screens/import_home_screen.dart';
import 'package:porquinho/features/import/screens/import_wizard_screen.dart';
import 'package:porquinho/features/periods/period_providers.dart';

import '../fake_import_repository.dart';

Finder _key(String k) => find.byKey(Key(k));

/// Downloads do modelo entregues durante o teste (nome, conteúdo).
final _downloads = <(String, String)>[];

PickedFile _file(String text, {String name = 'norte_despesas.csv'}) =>
    PickedFile(name, Uint8List.fromList(utf8.encode(text)));

final _norteExpenses =
    '${NorteFileKind.expenses.header.join(',')}\r\n'
    'a1,Luz,12345,paid,2026-10-05,2026-10-10,2026-10-09,Casa,,nao,,x,y\r\n'
    'a2,Água,8000,pending,2026-11-05,,,Casa,,nao,,x,y\r\n'
    'a3,Velha,100,cancelled,2026-01-05,,,,,nao,,x,y\r\n';

Future<void> _pump(
  WidgetTester tester,
  FakeImportRepository repo, {
  bool available = true,
  PickedFile? pick,
  String initial = ImportHomeScreen.route,
  ThemeData? theme,
  Size size = const Size(900, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: ImportHomeScreen.route,
        builder: (_, _) => const ImportHomeScreen(),
        routes: [
          GoRoute(
            path: 'como-importar',
            builder: (_, _) => const ImportGuideScreen(),
          ),
          GoRoute(
            path: 'nova',
            builder: (_, state) =>
                ImportWizardScreen(resume: state.extra as ImportResumeRequest?),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ImportBatchScreen(batchId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/lancamentos',
        builder: (_, _) => const Scaffold(body: Text('Lançamentos')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        importRepositoryProvider.overrideWithValue(repo),
        importTemplateDownloadProvider.overrideWithValue(
          (name, content) => _downloads.add((name, content)),
        ),
        importAvailableProvider.overrideWithValue(available),
        csvFilePickerProvider.overrideWithValue(() async => pick),
        todayProvider.overrideWithValue(CalendarDate(2026, 11, 18)),
        importPeriodConfigProvider.overrideWithValue(
          () async => PeriodConfig.calendarMonth(),
        ),
        importPeriodTotalsProvider.overrideWithValue(
          (ranges) async => {for (final r in ranges) r: PeriodTotals.zero},
        ),
      ],
      child: MaterialApp.router(
        theme: theme ?? NorteTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

ImportBatch _batch(String id, ImportBatchStatus status) => ImportBatch(
  id: id,
  status: status,
  fileName: 'extrato.csv',
  fileSha256: 'a' * 64,
  fileSizeBytes: 10,
  fileRows: 3,
  planHash: 'b' * 64,
  totalChunks: 1,
  itemCount: 3,
  createdAt: DateTime.utc(2026, 11, 18, 12),
  result: const {'incomes': 1, 'expenses': 2, 'investments': 0},
  summary: const {'rejected': 1, 'cancelled': 0, 'ignored_duplicates': 0},
  lastError: status == ImportBatchStatus.interrupted
      ? const {'row': 7, 'message': 'Valor obrigatório.'}
      : null,
);

void main() {
  testWidgets('no celular: orientação para usar a Web', (tester) async {
    await _pump(tester, FakeImportRepository(), available: false);
    expect(_key('importar-so-web'), findsOneWidget);
    expect(_key('importar-nova'), findsNothing);
  });

  testWidgets('modelo para baixar e passo a passo', (tester) async {
    _downloads.clear();
    await _pump(tester, FakeImportRepository());
    expect(_key('importar-ajuda'), findsOneWidget);

    await _tap(tester, 'importar-baixar-modelo');
    expect(_downloads.single.$1, ImportTemplate.fileName);
    expect(_downloads.single.$2, ImportTemplate.content());
    expect(find.textContaining('Modelo baixado'), findsOneWidget);

    await _tap(tester, 'importar-tutorial');
    expect(_key('importar-tutorial-tela'), findsOneWidget);
    expect(find.text('Preencha uma linha por lançamento'), findsOneWidget);
    await _tap(tester, 'importar-tutorial-baixar-modelo');
    expect(_downloads, hasLength(2));
  });

  testWidgets('passo a passo cabe no celular, claro e escuro', (tester) async {
    for (final theme in [NorteTheme.light(), NorteTheme.dark()]) {
      await _pump(
        tester,
        FakeImportRepository(),
        initial: ImportGuideScreen.route,
        theme: theme,
        size: const Size(360, 780),
      );
      expect(_key('importar-tutorial-tela'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Se algo der errado'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('arquivo do Norte: do início ao resultado', (tester) async {
    final repo = FakeImportRepository();
    await _pump(tester, repo, pick: _file(_norteExpenses));
    expect(find.text('Nenhuma importação ainda.'), findsOneWidget);
    await _tap(tester, 'importar-nova');

    // Etapa 2: arquivo.
    expect(_key('importar-etapa-file'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('importar-continuar')).onPressed,
      isNull,
    );
    await _tap(tester, 'importar-escolher-arquivo');
    expect(_key('importar-arquivo-norte'), findsOneWidget);
    expect(find.textContaining('3 linha(s) de dados'), findsOneWidget);

    await _tap(tester, 'importar-continuar'); // colunas (já associadas)
    expect(find.textContaining('Arquivo do Norte'), findsWidgets);
    await _tap(tester, 'importar-continuar'); // classificação
    await _tap(tester, 'importar-continuar'); // categorias
    expect(find.text('Despesa · Casa'), findsOneWidget);
    await _tap(tester, 'importar-continuar'); // duplicidades
    expect(
      find.text('Nenhuma possível duplicidade encontrada.'),
      findsOneWidget,
    );
    await _tap(tester, 'importar-continuar'); // recorrências
    await _tap(tester, 'importar-continuar'); // prévia
    expect(_key('importar-etapa-preview'), findsOneWidget);
    expect(find.textContaining('2 despesas · R\$ 203,45'), findsOneWidget);
    expect(find.textContaining('1 cancelada(s) no arquivo'), findsOneWidget);
    expect(_key('importar-periodos'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(
      find.text(
        'Importar 2 lançamento(s), criar 1 categoria(s) e 0 '
        'recorrência(s)',
      ),
      findsOneWidget,
    );

    await _tap(tester, 'importar-confirmar');
    expect(_key('importar-concluida'), findsOneWidget);
    expect(repo.calls, ['begin', 'chunk:0', 'finish']);
    final items = repo.allItems(repo.batches.keys.single);
    final paid = items.firstWhere((i) => i['description'] == 'Luz');
    expect(paid['amount_centavos'], 12345);
    expect(paid['paid_on'], '2026-10-09');
    expect(paid['due_on'], '2026-10-10');
  });

  testWidgets('arquivo comum: tipo, duplicidades e bloqueios', (tester) async {
    final repo = FakeImportRepository();
    await _pump(
      tester,
      repo,
      pick: _file(
        'Data;Histórico;Valor\n'
        '20/10/2026;Mercado;10,00\n'
        '20/10/2026;Mercado;10,00\n',
        name: 'banco.csv',
      ),
      initial: '${ImportHomeScreen.route}/nova',
      theme: NorteTheme.dark(),
    );
    await _tap(tester, 'importar-escolher-arquivo');
    await _tap(tester, 'importar-continuar');
    await _tap(tester, 'importar-continuar');
    // Classificação: falta o tipo do arquivo.
    expect(_key('importar-bloqueio'), findsOneWidget);
    await _tap(tester, 'importar-tipo-arquivo');
    await tester.tap(find.text('Despesa').last);
    await tester.pumpAndSettle();
    expect(_key('importar-bloqueio'), findsNothing);
    await _tap(tester, 'importar-continuar'); // categorias
    await _tap(tester, 'importar-continuar'); // duplicidades
    expect(find.text('Repetidas dentro do arquivo'), findsOneWidget);
    expect(_key('importar-bloqueio'), findsOneWidget);
    await _tap(tester, 'importar-dup-todos-ignorar');
    await _tap(tester, 'importar-continuar'); // recorrências
    await _tap(tester, 'importar-continuar'); // prévia
    expect(
      find.textContaining('1 ignorada(s) por duplicidade'),
      findsOneWidget,
    );
    await _tap(tester, 'importar-voltar');
    expect(_key('importar-etapa-series'), findsOneWidget);
  });

  testWidgets('importação interrompida: retomar e desfazer na tela inicial', (
    tester,
  ) async {
    final repo = FakeImportRepository();
    repo.batches['b1'] = _batch('b1', ImportBatchStatus.interrupted);
    repo.batches['b2'] = _batch('b2', ImportBatchStatus.completed);
    await _pump(tester, repo);
    expect(_key('importar-interrompida'), findsOneWidget);
    expect(find.textContaining('linha 7'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('importar-nova')).onPressed,
      isNull,
    );
    expect(_key('importar-retomar'), findsOneWidget);
    expect(_key('importacao-b2'), findsOneWidget);
  });

  testWidgets('detalhe: prévia do desfazer, confirmação e resultado', (
    tester,
  ) async {
    final repo = FakeImportRepository()
      ..undoParts = 2
      ..undoResult = const UndoReport(
        remaining: false,
        counts: {'cancelled': 2, 'deactivated': 1, 'preserved_changed': 1},
        preserved: [
          PreservedItem(
            entityType: 'expense_entry',
            role: 'created',
            outcome: 'preserved_changed',
            row: 4,
            reason: 'Alterado, pago ou recebido depois da importação.',
          ),
        ],
      );
    repo.batches['b2'] = _batch('b2', ImportBatchStatus.completed);
    await _pump(tester, repo, initial: '${ImportHomeScreen.route}/b2');
    expect(find.textContaining('1 receita(s), 2 despesa(s)'), findsOneWidget);
    await _tap(tester, 'importar-desfazer');
    expect(_key('importar-previa-desfazer'), findsOneWidget);
    expect(
      find.textContaining('2 lançamento(s) serão cancelados'),
      findsOneWidget,
    );
    expect(find.textContaining('Despesa (linha 4)'), findsOneWidget);
    await _tap(tester, 'importar-confirmar-desfazer');
    expect(repo.calls.where((c) => c == 'undo'), hasLength(2));
    expect(_key('importar-resultado-desfazer'), findsOneWidget);
    expect(find.textContaining('2 lançamento(s) cancelados'), findsOneWidget);
    expect(_key('importar-desfazer'), findsNothing);
  });
}
