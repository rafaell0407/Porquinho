import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/domain/calendar_date.dart';
import '../auth/auth_providers.dart';
import '../periods/period_providers.dart';
import 'alert_plan.dart';
import 'alert_scheduler.dart';

/// Agendador de alertas: só no Android (RN018). Web e demais: nada.
final alertSchedulerProvider = Provider<AlertScheduler>(
  (ref) => (kIsWeb || defaultTargetPlatform != TargetPlatform.android)
      ? const NoopAlertScheduler()
      : LocalNotificationsAlertScheduler(),
);

/// `true` se as [alertHour]h de hoje ainda não chegaram na zona do usuário.
bool beforeAlertHour(DateTime nowUtc, String zoneId) {
  tzdata.initializeTimeZones();
  final local = tz.TZDateTime.from(nowUtc.toUtc(), tz.getLocation(zoneId));
  return local.hour < alertHour;
}

/// Recalcula e reagenda os alertas a partir das despesas pendentes com
/// vencimento (avulsas e recorrentes). Chamado ao abrir, sincronizar e salvar
/// (D9). Falhas nunca interrompem o app.
final alertsRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      final db = await ref.read(localDatabaseProvider.future);
      if (db == null) return; // Web: sem alertas
      final owner = ref.read(ownerIdProvider);
      final rows = await db
          .customSelect(
            'SELECT id, due_on FROM expense_entries WHERE owner_id = ? '
            "AND status = 'pending' AND due_on IS NOT NULL",
            variables: [Variable.withString(owner)],
          )
          .get();
      final clock = ref.read(userClockProvider);
      final alerts = planAlerts(
        rows.map(
          (r) => DueExpense(
            id: r.read<String>('id'),
            dueOn: CalendarDate.parse(r.read<String>('due_on')),
          ),
        ),
        clock.today(),
        todayStillAhead: beforeAlertHour(clock.nowUtc(), clock.zoneId),
      );
      await ref
          .read(alertSchedulerProvider)
          .replaceAll(alerts, zoneId: clock.zoneId);
    } on Object catch (e) {
      debugPrint('Alertas: não foi possível atualizar ($e)');
    }
  };
});
