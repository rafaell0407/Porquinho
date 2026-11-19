import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/app/app.dart';
import 'package:porquinho/core/data_access.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/auth_providers.dart';
import 'package:porquinho/features/auth/auth_repository.dart';
import 'package:porquinho/features/auth/session_controller.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_providers.dart';
import 'package:porquinho/features/sync/sync_status.dart';
import 'package:porquinho/features/wipe_entries/wipe_entries_flow.dart';
import 'package:porquinho/features/wipe_entries/wipe_entries_gateway.dart';

import '../../support/period_gate_fake.dart';

const _user = AuthUser(id: 'u1', email: 'a@b.com');

class _Auth implements AuthRepository {
  final changes = StreamController<AuthUser?>.broadcast();
  @override
  Future<AuthUser?> restoreSession() async => _user;
  @override
  Stream<void> get passwordRecovery => const Stream.empty();
  @override
  Stream<AuthUser?> get userChanges => changes.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Pending implements PendingSyncCounter {
  _Pending(this.count);
  final int count;
  @override
  Future<int> countPending(String ownerId) async => count;
}

class _Probe implements ConnectivityProbe {
  _Probe(this.online);
  final bool online;
  @override
  Future<bool> isOnline() async => online;
}

const _preview = WipePreview(
  income: 2,
  expense: 3,
  investment: 1,
  templates: 1,
  openConflicts: 0,
  asOf: '2026-11-19T12:00:00Z',
);

class _Gateway implements WipeEntriesGateway {
  _Gateway({this.previewResult = _preview, List<WipeStep>? steps})
    : steps =
          steps ??
          [
            const WipeStep(status: 'running', templates: 1, income: 1),
            const WipeStep(
              status: 'done',
              income: 1,
              expense: 3,
              investment: 1,
            ),
          ];

  final WipePreview previewResult;
  final List<WipeStep> steps;
  int previews = 0;
  final runs = <String>[];
  bool fail = false;

  @override
  Future<WipePreview> preview() async {
    previews++;
    return previewResult;
  }

  @override
  Future<WipeStep> run({
    required String operationId,
    required String asOf,
    required int limit,
  }) async {
    runs.add('$operationId|$asOf|$limit');
    if (fail) throw const SyncTransientError('sem rede');
    return steps.removeAt(0);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _Gateway gateway,
  int pending = 0,
  bool online = true,
  DataAccessMode mode = DataAccessMode.local,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _Auth();
  final session = SessionController(auth, _Pending(pending));
  await session.start();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionControllerProvider.overrideWithValue(session),
        wipeEntriesGatewayProvider.overrideWithValue(gateway),
        wipeEntriesLimitProvider.overrideWithValue(2),
        connectivityProbeProvider.overrideWithValue(_Probe(online)),
        remoteAttentionCountProvider.overrideWithValue(() async => 0),
        dataAccessModeProvider.overrideWithValue(mode),
        ...readyFinanceOverrides(),
      ],
      child: const PorquinhoApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mais'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('mais-apagar-todos')));
  await tester.tap(find.byKey(const Key('mais-apagar-todos')));
  await tester.pumpAndSettle();
}

Future<void> _confirmBoth(WidgetTester tester, {String word = 'apagar'}) async {
  await tester.tap(find.byKey(const Key('apagar-todos-continuar')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('apagar-todos-campo')), word);
  await tester.pump();
}

void main() {
  testWidgets('sem conexão nada é conferido nem apagado', (tester) async {
    final gateway = _Gateway();
    await _pump(tester, gateway: gateway, online: false);
    expect(find.text('Sem conexão'), findsOneWidget);
    expect(gateway.previews, 0);
    expect(gateway.runs, isEmpty);
  });

  testWidgets('com pendências no aparelho é recusado antes da prévia', (
    tester,
  ) async {
    final gateway = _Gateway();
    await _pump(tester, gateway: gateway, pending: 2);
    expect(find.text('Ainda há dados não enviados'), findsOneWidget);
    expect(find.textContaining('2 operação(ões)'), findsOneWidget);
    expect(gateway.previews, 0);
    expect(gateway.runs, isEmpty);
  });

  testWidgets('conflito aberto no servidor leva aos itens de atenção', (
    tester,
  ) async {
    final gateway = _Gateway(
      previewResult: const WipePreview(
        income: 1,
        expense: 0,
        investment: 0,
        templates: 0,
        openConflicts: 1,
        asOf: 'x',
      ),
    );
    await _pump(tester, gateway: gateway);
    expect(find.text('Há itens que precisam de atenção'), findsOneWidget);
    expect(find.text('Apagar todos os lançamentos?'), findsNothing);
    expect(gateway.runs, isEmpty);
  });

  testWidgets('sem lançamentos avisa que não há nada para apagar', (
    tester,
  ) async {
    final gateway = _Gateway(
      previewResult: const WipePreview(
        income: 0,
        expense: 0,
        investment: 0,
        templates: 0,
        openConflicts: 0,
        asOf: 'x',
      ),
    );
    await _pump(tester, gateway: gateway);
    expect(find.text('Nada para apagar'), findsOneWidget);
    expect(gateway.runs, isEmpty);
  });

  testWidgets('1ª confirmação mostra o resumo; cancelar não apaga', (
    tester,
  ) async {
    final gateway = _Gateway();
    await _pump(tester, gateway: gateway);
    expect(find.text('Apagar todos os lançamentos?'), findsOneWidget);
    expect(find.text('• 2 receitas'), findsOneWidget);
    expect(find.text('• 3 despesas'), findsOneWidget);
    expect(find.text('• 1 investimento'), findsOneWidget);
    expect(find.text('• 1 recorrência (será desativada)'), findsOneWidget);
    expect(find.textContaining('não pode ser desfeita'), findsOneWidget);
    expect(find.textContaining('Continuam: categorias'), findsOneWidget);
    // No celular não há exportação (só na Web).
    expect(find.byKey(const Key('apagar-todos-exportar')), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(gateway.runs, isEmpty);
  });

  testWidgets('2ª confirmação só libera com APAGAR; cancelar não apaga', (
    tester,
  ) async {
    final gateway = _Gateway();
    await _pump(tester, gateway: gateway);
    await _confirmBoth(tester, word: 'apaga');
    final confirm = find.byKey(const Key('apagar-todos-confirmar'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('apagar-todos-campo')), 'sim');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(gateway.runs, isEmpty);
  });

  testWidgets('confirmada: apaga em partes com o mesmo corte e avisa', (
    tester,
  ) async {
    final gateway = _Gateway();
    await _pump(tester, gateway: gateway);
    await _confirmBoth(tester);
    await tester.tap(find.byKey(const Key('apagar-todos-confirmar')));
    await tester.pumpAndSettle();

    expect(gateway.runs, hasLength(2));
    expect(gateway.runs.map((r) => r.split('|')[0]).toSet(), hasLength(1));
    expect(gateway.runs.map((r) => r.split('|').skip(1).join('|')).toSet(), {
      '2026-11-19T12:00:00Z|2',
    });
    expect(find.text('6 lançamentos apagados.'), findsOneWidget);
    expect(find.byKey(const Key('apagar-todos-progresso')), findsNothing);
  });

  testWidgets('falha no meio avisa que pode tentar de novo', (tester) async {
    final gateway = _Gateway()..fail = true;
    await _pump(tester, gateway: gateway);
    await _confirmBoth(tester);
    await tester.tap(find.byKey(const Key('apagar-todos-confirmar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('tente de novo para terminar'), findsOneWidget);
    expect(find.byKey(const Key('apagar-todos-progresso')), findsNothing);
  });

  testWidgets('na Web oferece exportar antes', (tester) async {
    final gateway = _Gateway();
    await _pump(tester, gateway: gateway, mode: DataAccessMode.remoteOnly);
    expect(find.byKey(const Key('apagar-todos-exportar')), findsOneWidget);
    expect(
      find.textContaining('exporte os dados em CSV antes'),
      findsOneWidget,
    );
  });
}
