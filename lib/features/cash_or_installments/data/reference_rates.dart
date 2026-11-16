import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/domain/calendar_date.dart';
import '../../../core/local_database/stored_database_key_provider.dart'
    show SecureValueStore;

/// Taxas de referência do Banco Central (SGS), spec §10. Leitura pública,
/// sem dados do usuário.

/// Séries do SGS ("% ao ano, base 252").
enum RateIndex {
  cdi(4389, 'CDI'),
  selic(1178, 'Selic');

  const RateIndex(this.series, this.label);
  final int series;
  final String label;
}

/// Taxa anual (centésimos de %) e a data a que se refere.
@immutable
class ReferenceRate {
  const ReferenceRate({required this.annualRateE2, required this.date});

  final int annualRateE2;
  final CalendarDate date;

  Map<String, Object> toJson() => {'e2': annualRateE2, 'data': date.toIso()};

  static ReferenceRate? fromJson(Object? json) {
    if (json is! Map) return null;
    final e2 = json['e2'];
    final date = json['data'];
    if (e2 is! int || date is! String || e2 < 0) return null;
    try {
      return ReferenceRate(annualRateE2: e2, date: CalendarDate.parse(date));
    } on Object {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReferenceRate &&
      other.annualRateE2 == annualRateE2 &&
      other.date == date;

  @override
  int get hashCode => Object.hash(annualRateE2, date);
}

class RateFetchException implements Exception {
  const RateFetchException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cliente da API pública do SGS.
class BcbRateClient {
  BcbRateClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static Uri uriFor(RateIndex index) => Uri.parse(
    'https://api.bcb.gov.br/dados/serie/bcdata.sgs.${index.series}'
    '/dados/ultimos/5?formato=json',
  );

  Future<ReferenceRate> fetch(RateIndex index) async {
    final http.Response response;
    try {
      response = await _client.get(uriFor(index)).timeout(timeout);
    } on TimeoutException {
      throw const RateFetchException('O Banco Central não respondeu.');
    } on Object {
      throw const RateFetchException('Sem conexão com o Banco Central.');
    }
    if (response.statusCode != 200) {
      throw RateFetchException(
        'O Banco Central respondeu com erro (${response.statusCode}).',
      );
    }
    return parseSgsResponse(response.body);
  }
}

final _sgsDate = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
final _sgsValue = RegExp(r'^(\d{1,3})(?:\.(\d+))?$');

/// Lê `[{"data":"dd/mm/aaaa","valor":"14.90"}, …]` e devolve a taxa da
/// **maior data** (a resposta pode vir fora de ordem). Valor com mais de 2
/// casas é arredondado meio para cima.
ReferenceRate parseSgsResponse(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw const RateFetchException('Resposta inválida do Banco Central.');
  }
  if (json is! List || json.isEmpty) {
    throw const RateFetchException('O Banco Central não enviou a taxa.');
  }
  ReferenceRate? best;
  for (final item in json) {
    if (item is! Map) continue;
    final d = _sgsDate.firstMatch('${item['data']}');
    final v = _sgsValue.firstMatch('${item['valor']}'.trim());
    if (d == null || v == null) continue;
    final CalendarDate date;
    try {
      date = CalendarDate(
        int.parse(d.group(3)!),
        int.parse(d.group(2)!),
        int.parse(d.group(1)!),
      );
    } on ArgumentError {
      continue;
    }
    final frac = v.group(2) ?? '';
    var e2 =
        int.parse(v.group(1)!) * 100 +
        int.parse(frac.padRight(2, '0').substring(0, 2));
    if (frac.length > 2 && int.parse(frac[2]) >= 5) e2++;
    if (best == null || date.isAfter(best.date)) {
      best = ReferenceRate(annualRateE2: e2, date: date);
    }
  }
  if (best == null) {
    throw const RateFetchException('Resposta inválida do Banco Central.');
  }
  return best;
}

/// Onde guardar a última taxa obtida.
abstract interface class RateCache {
  Future<ReferenceRate?> read(RateIndex index);
  Future<void> write(RateIndex index, ReferenceRate rate);
}

/// Web e testes: só em memória (spec §10).
class MemoryRateCache implements RateCache {
  final Map<RateIndex, ReferenceRate> _values = {};

  @override
  Future<ReferenceRate?> read(RateIndex index) async => _values[index];

  @override
  Future<void> write(RateIndex index, ReferenceRate rate) async {
    _values[index] = rate;
  }
}

/// Celular: armazenamento seguro do aparelho. Falha ao ler ou gravar não
/// impede a simulação (a taxa pode ser digitada).
class SecureRateCache implements RateCache {
  SecureRateCache(this._store);

  final SecureValueStore _store;

  static String keyFor(RateIndex index) =>
      'norte.cash_or_installments.rate.${index.name}';

  @override
  Future<ReferenceRate?> read(RateIndex index) async {
    try {
      final raw = await _store.read(keyFor(index));
      return raw == null ? null : ReferenceRate.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(RateIndex index, ReferenceRate rate) async {
    try {
      await _store.write(keyFor(index), jsonEncode(rate.toJson()));
    } on Object {
      // Sem cache: na próxima abertura busca de novo.
    }
  }
}

/// Situação da taxa para a tela.
@immutable
class RateLookup {
  const RateLookup({
    this.rate,
    this.fetchFailed = false,
    this.fromCache = false,
  });

  /// `null` = nenhuma taxa (nem buscada, nem guardada): o usuário informa.
  final ReferenceRate? rate;

  /// A busca falhou (a taxa, se houver, é a guardada).
  final bool fetchFailed;
  final bool fromCache;

  /// Taxa com mais de 30 dias em relação a [today].
  bool isStale(CalendarDate today) =>
      rate != null && today.isAfter(rate!.date.addDays(30));
}

/// Busca no Banco Central; se falhar, usa a última guardada.
class ReferenceRateRepository {
  ReferenceRateRepository({required this.client, required this.cache});

  final BcbRateClient client;
  final RateCache cache;

  Future<RateLookup> load(RateIndex index) async {
    try {
      final rate = await client.fetch(index);
      await cache.write(index, rate);
      return RateLookup(rate: rate);
    } on RateFetchException {
      final cached = await cache.read(index);
      return RateLookup(
        rate: cached,
        fetchFailed: true,
        fromCache: cached != null,
      );
    }
  }
}
