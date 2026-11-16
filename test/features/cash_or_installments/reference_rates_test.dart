import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/local_database/stored_database_key_provider.dart';
import 'package:porquinho/features/cash_or_installments/data/reference_rates.dart';

class _FailingStore implements SecureValueStore {
  @override
  Future<void> delete(String name) async => throw StateError('falha');
  @override
  Future<String?> read(String name) async => throw StateError('falha');
  @override
  Future<void> write(String name, String value) async =>
      throw StateError('falha');
}

void main() {
  group('resposta do SGS', () {
    test('usa a maior data, mesmo fora de ordem', () {
      final r = parseSgsResponse(
        '[{"data":"12/11/2026","valor":"14.90"},'
        '{"data":"13/11/2026","valor":"14.65"},'
        '{"data":"10/11/2026","valor":"15.00"}]',
      );
      expect(r.annualRateE2, 1465);
      expect(r.date, CalendarDate(2026, 11, 13));
    });

    test('casas decimais', () {
      int v(String s) =>
          parseSgsResponse('[{"data":"01/01/2027","valor":"$s"}]').annualRateE2;
      expect(v('14.9'), 1490);
      expect(v('14'), 1400);
      expect(v('13.654'), 1365);
      expect(v('13.655'), 1366);
    });

    test('ignora item inválido; recusa resposta sem nenhum válido', () {
      final r = parseSgsResponse(
        '[{"data":"31/02/2026","valor":"1.00"},{"data":"02/01/2026",'
        '"valor":"abc"},{"data":"05/01/2026","valor":"12.15"}]',
      );
      expect(r.annualRateE2, 1215);
      for (final bad in ['', '[]', '{}', '[{"x":1}]', 'html']) {
        expect(
          () => parseSgsResponse(bad),
          throwsA(isA<RateFetchException>()),
          reason: bad,
        );
      }
    });

    test('endereço das séries', () {
      expect(
        BcbRateClient.uriFor(RateIndex.cdi).toString(),
        'https://api.bcb.gov.br/dados/serie/bcdata.sgs.4389/dados/ultimos/5'
        '?formato=json',
      );
      expect(BcbRateClient.uriFor(RateIndex.selic).path, contains('sgs.1178'));
    });
  });

  group('repositório', () {
    const body = '[{"data":"12/11/2026","valor":"14.90"}]';
    final rate = ReferenceRate(
      annualRateE2: 1490,
      date: CalendarDate(2026, 11, 12),
    );

    ReferenceRateRepository repo(http.Client client, RateCache cache) =>
        ReferenceRateRepository(
          client: BcbRateClient(
            client: client,
            timeout: const Duration(milliseconds: 200),
          ),
          cache: cache,
        );

    test('busca e guarda no armazenamento seguro', () async {
      final store = InMemorySecureValueStore();
      final cache = SecureRateCache(store);
      final r = await repo(
        MockClient((_) async => http.Response(body, 200)),
        cache,
      ).load(RateIndex.cdi);
      expect(r.rate, rate);
      expect(r.fetchFailed, isFalse);
      expect(await cache.read(RateIndex.cdi), rate);
      expect(await cache.read(RateIndex.selic), isNull);
      expect(
        await store.read('norte.cash_or_installments.rate.cdi'),
        '{"e2":1490,"data":"2026-11-12"}',
      );
    });

    test('falha usa a guardada e avisa', () async {
      final cache = MemoryRateCache();
      await cache.write(RateIndex.selic, rate);
      for (final client in [
        MockClient((_) async => http.Response('erro', 500)),
        MockClient((_) async => throw http.ClientException('sem rede')),
        MockClient((_) => Completer<http.Response>().future),
      ]) {
        final r = await repo(client, cache).load(RateIndex.selic);
        expect(r.rate, rate);
        expect(r.fetchFailed, isTrue);
        expect(r.fromCache, isTrue);
      }
    });

    test('falha sem taxa guardada: usuário informa', () async {
      final r = await repo(
        MockClient((_) async => http.Response('erro', 503)),
        MemoryRateCache(),
      ).load(RateIndex.cdi);
      expect(r.rate, isNull);
      expect(r.fetchFailed, isTrue);
    });

    test('armazenamento com defeito não impede a busca', () async {
      final r = await repo(
        MockClient((_) async => http.Response(body, 200)),
        SecureRateCache(_FailingStore()),
      ).load(RateIndex.cdi);
      expect(r.rate, rate);
    });

    test('valor guardado corrompido é ignorado', () async {
      final store = InMemorySecureValueStore();
      await store.write('norte.cash_or_installments.rate.cdi', 'xyz');
      expect(await SecureRateCache(store).read(RateIndex.cdi), isNull);
    });

    test('mais de 30 dias = taxa antiga', () {
      final lookup = RateLookup(rate: rate);
      expect(lookup.isStale(CalendarDate(2026, 12, 12)), isFalse);
      expect(lookup.isStale(CalendarDate(2026, 12, 13)), isTrue);
      expect(const RateLookup().isStale(CalendarDate(2030, 1, 1)), isFalse);
    });
  });
}
