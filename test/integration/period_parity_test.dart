@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Paridade do cálculo de períodos: domínio Dart × RPC `create_accounting_period`
/// no Supabase LOCAL. Mesmos parâmetros de `supabase_local_sync_test.dart`.
const _url = String.fromEnvironment('SUPABASE_URL');
const _publishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _secret = String.fromEnvironment('SUPABASE_SECRET_KEY');
final _enabled =
    _url.isNotEmpty && _publishable.isNotEmpty && _secret.isNotEmpty;

String _uuid(Random r) {
  String h(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-a${h(3)}-${h(12)}';
}

Future<SupabaseClient> _newClient(Random r) async {
  final admin = SupabaseClient(_url, _secret);
  final email = 'pp-${r.nextInt(1 << 30)}@teste.local';
  await admin.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: 'Senha-123456',
      emailConfirm: true,
    ),
  );
  final client = SupabaseClient(_url, _publishable);
  await client.auth.signInWithPassword(email: email, password: 'Senha-123456');
  return client;
}

void main() {
  final r = Random();
  final cases = <String, PeriodConfig>{
    'mês-calendário': PeriodConfig.calendarMonth(),
    'dia 20': PeriodConfig.customCycle(20),
    'dia 29': PeriodConfig.customCycle(29),
    'dia 30': PeriodConfig.customCycle(30),
    'dia 31': PeriodConfig.customCycle(31),
  };

  for (final entry in cases.entries) {
    test(
      'fim dos períodos igual ao da RPC: ${entry.key}',
      () async {
        final client = await _newClient(r);
        final config = entry.value;
        final configId = _uuid(r);
        var expected = PeriodCalendar.containing(
          config,
          CalendarDate(2027, 1, 31),
        );
        // Fevereiro de 2027 (comum) e de 2028 (bissexto) entram na faixa.
        for (var i = 0; i < 26; i++) {
          final res = await client.rpc(
            'create_accounting_period',
            params: {
              'p_operation_id': _uuid(r),
              'p_period_id': _uuid(r),
              'p_configuration_id': configId,
              'p_start_date': expected.start.toIso(),
              'p_mode': config.mode.dbValue,
              'p_custom_start_day': config.customStartDay,
            },
          );
          final map = Map<String, dynamic>.from(res as Map);
          expect(map['status'], 'applied', reason: '$expected');
          final period = Map<String, dynamic>.from(map['period'] as Map);
          expect(period['end_date'], expected.end.toIso(), reason: '$expected');
          expected = PeriodCalendar.next(config, expected);
        }
      },
      skip: _enabled ? false : 'defina SUPABASE_URL/PUBLISHABLE_KEY/SECRET_KEY',
    );
  }

  test(
    'períodos anteriores: RPC fecha com o primeiro, igual ao domínio',
    () async {
      final client = await _newClient(r);
      final config = PeriodConfig.customCycle(31);
      var first = PeriodCalendar.containing(config, CalendarDate(2028, 3, 31));
      await client.rpc(
        'create_accounting_period',
        params: {
          'p_operation_id': _uuid(r),
          'p_period_id': _uuid(r),
          'p_configuration_id': _uuid(r),
          'p_start_date': first.start.toIso(),
          'p_mode': 'custom_cycle',
          'p_custom_start_day': 31,
        },
      );
      for (var i = 0; i < 26; i++) {
        final previous = PeriodCalendar.previous(config, first);
        final res = await client.rpc(
          'create_earlier_accounting_period',
          params: {
            'p_operation_id': _uuid(r),
            'p_period_id': _uuid(r),
            'p_start_date': previous.start.toIso(),
          },
        );
        final map = Map<String, dynamic>.from(res as Map);
        expect(map['status'], 'applied', reason: '$previous');
        final period = Map<String, dynamic>.from(map['period'] as Map);
        expect(period['end_date'], first.start.toIso(), reason: '$previous');
        first = previous;
      }
    },
    skip: _enabled ? false : 'defina SUPABASE_URL/PUBLISHABLE_KEY/SECRET_KEY',
  );
}
