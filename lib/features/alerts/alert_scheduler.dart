import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/domain/user_clock.dart';
import 'alert_plan.dart';

/// Agenda e cancela os alertas de vencimento no aparelho (Android).
abstract interface class AlertScheduler {
  /// Substitui todos os alertas pelos de [alerts]. Pede permissão de
  /// notificações na primeira vez; se negada, não agenda e não falha.
  Future<void> replaceAll(List<PlannedAlert> alerts, {String? zoneId});

  /// Remove todos (logout, troca de usuário).
  Future<void> cancelAll();
}

/// Web e plataformas sem alertas: não faz nada (RN018: só Android).
class NoopAlertScheduler implements AlertScheduler {
  const NoopAlertScheduler();

  @override
  Future<void> replaceAll(List<PlannedAlert> alerts, {String? zoneId}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Android: notificações locais agendadas com `flutter_local_notifications`.
/// Usa agendamento inexato (sem permissão de alarme exato): o aviso chega
/// por volta das 9h, o que basta para um lembrete de vencimento.
class LocalNotificationsAlertScheduler implements AlertScheduler {
  LocalNotificationsAlertScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _permissionAsked = false;

  static const _channel = AndroidNotificationDetails(
    'vencimentos',
    'Vencimentos',
    channelDescription: 'Avisos de despesas que vencem ou estão em atraso',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    visibility: NotificationVisibility.private,
  );

  Future<void> _init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _init();
      await _plugin.cancelAllPendingNotifications();
    } on Object catch (e) {
      debugPrint('Alertas: não foi possível cancelar ($e)');
    }
  }

  @override
  Future<void> replaceAll(List<PlannedAlert> alerts, {String? zoneId}) async {
    try {
      await _init();
      await _plugin.cancelAllPendingNotifications();
      if (alerts.isEmpty) return;
      if (!_permissionAsked) {
        _permissionAsked = true;
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        if (granted == false) return;
      }
      final location = tz.getLocation(zoneId ?? defaultTimeZoneId);
      for (final alert in alerts) {
        await _plugin.zonedSchedule(
          id: alert.id,
          title: 'Norte',
          body: alert.body,
          scheduledDate: tz.TZDateTime(
            location,
            alert.date.year,
            alert.date.month,
            alert.date.day,
            alertHour,
          ),
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object catch (e) {
      // Permissão negada ou falha do sistema não pode quebrar o app.
      debugPrint('Alertas: não foi possível agendar ($e)');
    }
  }
}
