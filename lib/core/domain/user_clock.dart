import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_date.dart';

const defaultTimeZoneId = 'America/Sao_Paulo';

bool _initialized = false;

/// Data corrente na zona IANA do usuário (RN038; padrão `America/Sao_Paulo`).
///
/// [nowUtc] permite fixar o instante nos testes.
CalendarDate todayInZone(DateTime nowUtc, {String zoneId = defaultTimeZoneId}) {
  if (!_initialized) {
    tzdata.initializeTimeZones();
    _initialized = true;
  }
  final local = tz.TZDateTime.from(nowUtc.toUtc(), tz.getLocation(zoneId));
  return CalendarDate(local.year, local.month, local.day);
}

/// Relógio injetável: o app usa o relógio do sistema; testes fixam o instante.
class UserClock {
  const UserClock({this.zoneId = defaultTimeZoneId, DateTime Function()? now})
    : _now = now;

  final String zoneId;
  final DateTime Function()? _now;

  DateTime nowUtc() => (_now?.call() ?? DateTime.now()).toUtc();

  CalendarDate today() => todayInZone(nowUtc(), zoneId: zoneId);
}
