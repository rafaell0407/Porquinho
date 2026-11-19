import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/wipe_entries/wipe_entries_gateway.dart';
import 'package:porquinho/features/wipe_entries/wipe_entries_runner.dart';

class _Gateway implements WipeEntriesGateway {
  _Gateway(this.steps);

  final List<WipeStep> steps;
  final calls = <({String op, String asOf, int limit})>[];

  @override
  Future<WipePreview> preview() => throw UnimplementedError();

  @override
  Future<WipeStep> run({
    required String operationId,
    required String asOf,
    required int limit,
  }) async {
    calls.add((op: operationId, asOf: asOf, limit: limit));
    return steps.removeAt(0);
  }
}

void main() {
  test(
    'soma as partes até terminar, sempre com a mesma operação e corte',
    () async {
      final gateway = _Gateway([
        const WipeStep(status: 'running', templates: 2),
        const WipeStep(status: 'running', income: 1, expense: 1),
        const WipeStep(status: 'done', expense: 3, investment: 2),
      ]);
      final progress = <int>[];
      final outcome = await WipeEntriesRunner(gateway, limit: 2).run(
        operationId: 'op',
        asOf: '2026-11-19T12:00:00Z',
        onProgress: progress.add,
      );
      expect(outcome, isA<WipeDone>());
      final done = outcome as WipeDone;
      expect(
        (done.income, done.expense, done.investment, done.templates),
        (1, 4, 2, 2),
      );
      expect(done.entries, 7);
      expect(progress, [0, 2, 7]);
      expect(gateway.calls.map((c) => c.op).toSet(), {'op'});
      expect(gateway.calls.map((c) => c.asOf).toSet(), {
        '2026-11-19T12:00:00Z',
      });
      expect(gateway.calls.map((c) => c.limit).toSet(), {2});
    },
  );

  test('conflito aberto no servidor devolve bloqueado', () async {
    final outcome = await WipeEntriesRunner(
      _Gateway([const WipeStep(status: 'blocked', openConflicts: 2)]),
    ).run(operationId: 'op', asOf: 'x');
    expect(outcome, isA<WipeBlocked>());
    expect((outcome as WipeBlocked).openConflicts, 2);
  });

  test('resposta desconhecida ou que nunca termina vira erro', () async {
    await expectLater(
      WipeEntriesRunner(
        _Gateway([const WipeStep(status: 'estranho')]),
      ).run(operationId: 'op', asOf: 'x'),
      throwsA(isA<SyncTransientError>()),
    );
    await expectLater(
      WipeEntriesRunner(
        _Gateway(
          List.filled(3, const WipeStep(status: 'running'), growable: true),
        ),
        maxSteps: 3,
      ).run(operationId: 'op', asOf: 'x'),
      throwsA(isA<SyncTransientError>()),
    );
  });

  test(
    'lê a prévia e as partes do servidor (números como texto ou número)',
    () {
      final preview = WipePreview.fromJson({
        'income': 2,
        'expense': '3',
        'investment': 1,
        'templates': 4,
        'open_conflicts': 0,
        'as_of': '2026-11-19T12:00:00.123+00:00',
      });
      expect(preview.entries, 6);
      expect(preview.isEmpty, isFalse);
      expect(preview.asOf, '2026-11-19T12:00:00.123+00:00');
      expect(
        WipePreview.fromJson({
          'income': 0,
          'expense': 0,
          'investment': 0,
          'templates': 0,
          'open_conflicts': 0,
          'as_of': 'x',
        }).isEmpty,
        isTrue,
      );

      final step = WipeStep.fromJson({
        'status': 'running',
        'cancelled': {'income': 1, 'expense': 2, 'investment': 3},
        'deactivated_templates': 1,
      });
      expect(
        (
          step.status,
          step.income,
          step.expense,
          step.investment,
          step.templates,
        ),
        ('running', 1, 2, 3, 1),
      );
      final blocked = WipeStep.fromJson({
        'status': 'blocked',
        'reason': 'open_conflicts',
        'open_conflicts': 1,
      });
      expect((blocked.status, blocked.openConflicts), ('blocked', 1));
    },
  );
}
