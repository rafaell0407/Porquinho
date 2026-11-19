@TestOn('vm')
library;

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/attention/attention_models.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_retention.dart';

/// Servidor falso: devolve as linhas do dono por (coluna de ordem, id).
class _Reader implements SyncRemoteReader {
  final tables = <String, List<Map<String, dynamic>>>{};
  final requests = <String>[];

  @override
  Future<Map<String, dynamic>?> fetchPreferences(String ownerId) async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required String ownerId,
    required String orderColumn,
    String? afterOrder,
    String? afterId,
    required int limit,
  }) async {
    requests.add('$table|$afterOrder');
    int cmp(Map<String, dynamic> r) => DateTime.parse(
      r[orderColumn] as String,
    ).compareTo(DateTime.parse(afterOrder!));
    final rows =
        (tables[table] ?? []).where((r) {
          if (r['owner_id'] != ownerId) return false;
          if (afterOrder == null) return true;
          if (afterId == null) return cmp(r) >= 0;
          final c = cmp(r);
          return c > 0 ||
              (c == 0 && (r['id'] as String).compareTo(afterId) > 0);
        }).toList()..sort((a, b) {
          final c = DateTime.parse(
            a[orderColumn] as String,
          ).compareTo(DateTime.parse(b[orderColumn] as String));
          return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
        });
    return rows.take(limit).toList();
  }
}

/// Formato do servidor (microssegundos e `+00:00`).
String _server(DateTime t) =>
    '${t.toUtc().toIso8601String().replaceFirst('Z', '')}000+00:00';

Map<String, dynamic> _income(
  String id,
  DateTime updated, {
  String status = 'received',
  String? template,
  int version = 1,
}) => {
  'owner_id': 'u1',
  'id': id,
  'version': version,
  'created_at': _server(updated),
  'updated_at': _server(updated),
  'description': id,
  'amount_centavos': 1000,
  'status': status,
  'received_on': status == 'pending' ? null : '2025-01-10',
  'category_id': null,
  'subcategory_id': null,
  'recurrence_template_id': template,
  'scheduled_for_date': template == null ? null : '2025-01-10',
};

Map<String, dynamic> _investment(
  String id,
  DateTime updated, {
  bool cancelled = true,
}) => {
  'owner_id': 'u1',
  'id': id,
  'version': cancelled ? 2 : 1,
  'created_at': _server(updated),
  'updated_at': _server(updated),
  'amount_centavos': 5000,
  'allocated_on': '2025-01-10',
  'cancelled_at': cancelled ? _server(updated) : null,
  'recurrence_template_id': null,
  'scheduled_for_date': null,
};

void main() {
  late PorquinhoDatabase db;
  late _Reader reader;
  final now = DateTime.utc(2026, 11, 18, 12);
  final old = DateTime.utc(2025, 10, 1); // mais de 12 meses
  final recent = DateTime.utc(2026, 10, 1); // menos de 12 meses

  setUp(() {
    db = PorquinhoDatabase(NativeDatabase.memory());
    reader = _Reader();
  });
  tearDown(() => db.close());

  Future<Set<String>> ids(String table) async =>
      (await db
              .customSelect(
                'SELECT id FROM $table WHERE owner_id = ?',
                variables: [Variable.withString('u1')],
              )
              .get())
          .map((r) => r.read<String>('id'))
          .toSet();

  Future<void> enqueue(String entityType, String id) => db.customStatement(
    'INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, '
    "entity_id, expected_version, payload_json, state, attempts) "
    "VALUES ('u1', ?, ?, ?, 1, '{}', 'pending', 0)",
    ['op-$id', entityType, id],
  );

  Future<void> conflict(
    String id,
    String entityType,
    String state,
    DateTime at,
  ) => db.customStatement(
    'INSERT INTO sync_conflicts (id, owner_id, version, created_at, '
    'updated_at, entity_type, entity_id, expected_version, remote_version, '
    'local_snapshot_json, remote_snapshot_json, state) '
    "VALUES (?, 'u1', 1, ?, ?, ?, ?, 1, 2, '{}', '{}', ?)",
    ['c-$id', _server(at), _server(at), entityType, id, state],
  );

  Future<void> audit(String id, DateTime at) => db.customStatement(
    'INSERT INTO audit_events (id, owner_id, version, created_at, updated_at, '
    'entity_type, entity_id, operation, actor_id, occurred_at, '
    "operation_id) VALUES (?, 'u1', 1, ?, ?, 'income_entry', 'x', "
    "'update', 'u1', ?, ?)",
    [id, _server(at), _server(at), _server(at), 'op-$id'],
  );

  group('limpeza no aparelho (LocalRetention)', () {
    test('apaga só o avulso cancelado parado há 12 meses, sem pendência '
        'nem conflito aberto; recorrência fica', () async {
      reader.tables['income_entries'] = [
        _income('velha-cancelada', old, status: 'cancelled'),
        _income('recente-cancelada', recent, status: 'cancelled'),
        _income('velha-ativa', old),
        _income(
          'ocorrencia-cancelada',
          old,
          status: 'cancelled',
          template: 't1',
        ),
        _income('pendente-na-fila', old, status: 'cancelled'),
        _income('com-conflito', old, status: 'cancelled'),
        _income('conflito-resolvido', old, status: 'cancelled'),
      ];
      reader.tables['income_recurrence_templates'] = [
        {
          'owner_id': 'u1',
          'id': 't1',
          'version': 1,
          'created_at': _server(old),
          'updated_at': _server(old),
          'description': 'Aluguel',
          'frequency': 'monthly',
          'starts_on': '2025-01-10',
          'monthly_reference_day': 10,
          'value_mode': 'fixed',
          'default_amount_centavos': 1000,
          'category_id': null,
          'subcategory_id': null,
          'is_active': true,
        },
      ];
      reader.tables['investment_allocations'] = [
        _investment('inv-velho-cancelado', old),
        _investment('inv-velho-ativo', old, cancelled: false),
      ];
      await DownloadService(db, reader, clock: () => now).downloadAll('u1');
      await enqueue('income_entry', 'pendente-na-fila');
      await conflict('com-conflito', 'income_entry', 'open', old);
      await conflict('conflito-resolvido', 'income_entry', 'resolved', old);
      await conflict('resolvido-recente', 'income_entry', 'resolved', recent);
      await audit('aud-velha', old);
      await audit('aud-recente', recent);

      final result = await LocalRetention(db, clock: () => now).purge('u1');

      expect(await ids('income_entries'), {
        'recente-cancelada',
        'velha-ativa',
        'ocorrencia-cancelada',
        'pendente-na-fila',
        'com-conflito',
      });
      expect(await ids('investment_allocations'), {'inv-velho-ativo'});
      expect(result.entries, 3);
      expect(await ids('audit_events'), {'aud-recente'});
      expect(await ids('sync_conflicts'), {
        'c-com-conflito',
        'c-resolvido-recente',
      });

      // Repetir não muda nada.
      final again = await LocalRetention(db, clock: () => now).purge('u1');
      expect(again.total, 0);
    });

    test('formato do aparelho (Z, milissegundos) também é entendido', () async {
      reader.tables['income_entries'] = [
        _income('a', old, status: 'cancelled'),
      ];
      await DownloadService(db, reader, clock: () => now).downloadAll('u1');
      await db.customStatement(
        "UPDATE income_entries SET updated_at = ? WHERE id = 'a'",
        [old.toIso8601String()],
      );
      await LocalRetention(db, clock: () => now).purge('u1');
      expect(await ids('income_entries'), isEmpty);
    });
  });

  group('download desde o início (aparelho parado)', () {
    Future<void> firstDownload(DateTime at) async {
      await DownloadService(db, reader, clock: () => at).downloadAll('u1');
    }

    test('parado há mais de 11 meses: refaz o download e apaga o que o '
        'servidor já limpou', () async {
      // Aparelho B baixou em out/2025: X ainda ativo nele.
      reader.tables['income_entries'] = [
        _income('x', old),
        _income('fica', old),
      ];
      await firstDownload(old);
      // Outro aparelho apagou X; 12 meses depois o servidor o limpou.
      reader.tables['income_entries'] = [_income('fica', old)];
      // B também tem uma ocorrência gerada agora no aparelho (ainda não está
      // no servidor) e uma criação na fila.
      await db.customStatement(
        'INSERT INTO income_entries (id, owner_id, version, created_at, '
        'updated_at, amount_centavos, status, received_on) '
        "VALUES ('nova-local', 'u1', 1, ?, ?, '10', 'received', '2026-11-18')",
        [now.toIso8601String(), now.toIso8601String()],
      );
      await db.customStatement(
        'INSERT INTO income_entries (id, owner_id, version, created_at, '
        'updated_at, amount_centavos, status, received_on) '
        "VALUES ('na-fila', 'u1', 0, ?, ?, '10', 'received', '2025-01-10')",
        [_server(old), _server(old)],
      );
      await enqueue('income_entry', 'na-fila');

      reader.requests.clear();
      final result = await DownloadService(
        db,
        reader,
        clock: () => now,
      ).downloadAll('u1');

      expect(result.completed, isTrue);
      expect(
        reader.requests.where((r) => r.startsWith('income_entries|')).first,
        'income_entries|null',
        reason: 'lançamentos baixados desde o início',
      );
      expect(await ids('income_entries'), {'fica', 'nova-local', 'na-fila'});
    });

    test('download recente: incremental, nada é apagado', () async {
      reader.tables['income_entries'] = [_income('x', old)];
      await firstDownload(DateTime.utc(2026, 10, 1));
      reader.tables['income_entries'] = [];
      reader.requests.clear();
      await DownloadService(db, reader, clock: () => now).downloadAll('u1');
      expect(
        reader.requests.where((r) => r.startsWith('income_entries|')).first,
        isNot('income_entries|null'),
      );
      expect(await ids('income_entries'), {'x'});
    });

    test('guarda o instante do último download concluído', () async {
      await DownloadService(db, reader, clock: () => now).downloadAll('u1');
      final row = await db
          .customSelect(
            'SELECT last_order_value FROM sync_cursors '
            'WHERE owner_id = ? AND source_table = ?',
            variables: [
              Variable.withString('u1'),
              Variable.withString(lastCompleteDownloadKey),
            ],
          )
          .getSingle();
      expect(DateTime.parse(row.read<String>('last_order_value')), now);
    });

    test('alteração recusada e descartada (versão 0): sai do aparelho se o '
        'servidor não tem mais o lançamento', () async {
      reader.tables['expense_entries'] = [];
      await firstDownload(DateTime.utc(2026, 11, 1));
      await db.customStatement(
        'INSERT INTO expense_entries (id, owner_id, version, created_at, '
        'updated_at, amount_centavos, status, competence_on) '
        "VALUES ('apagada', 'u1', 0, ?, ?, '10', 'pending', '2025-01-10')",
        [now.toIso8601String(), now.toIso8601String()],
      );
      // `discardAndRevert` apaga o cursor da tabela.
      await db.customStatement(
        "DELETE FROM sync_cursors WHERE source_table = 'expense_entries'",
      );
      await DownloadService(db, reader, clock: () => now).downloadAll('u1');
      expect(await ids('expense_entries'), isEmpty);
    });
  });

  group('motivo da recusa em português', () {
    test('lançamento que não existe mais no servidor', () {
      for (final m in [
        'one-time income was not found',
        'one-time expense was not found',
        'investment allocation was not found for the authenticated user',
        'expense recurrence occurrence was not found',
      ]) {
        expect(rejectionReasonText(m), contains('foi apagado'), reason: m);
      }
    });

    test('reenvio antigo demais', () {
      expect(
        rejectionReasonText('idempotency key reused with different content'),
        contains('antiga demais'),
      );
    });

    test('outros motivos seguem como vieram', () {
      expect(rejectionReasonText('nome não aceito'), 'nome não aceito');
      expect(
        rejectionReasonText('category was not found'),
        'category was not found',
      );
      expect(rejectionReasonText(null), isNull);
    });
  });
}
