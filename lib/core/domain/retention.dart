/// Retenção de 12 meses (D15, 18/11/2026; RN029 e RN030).
///
/// O lançamento cancelado ("Apagar" na interface) e a auditoria ficam
/// guardados por 12 meses e depois são apagados, no servidor
/// (`purge_expired_records`) e no aparelho, pela mesma regra.
abstract final class Retention {
  /// Prazo de guarda, em meses.
  static const months = 12;

  /// Depois deste tempo sem um download completo, o aparelho baixa de novo,
  /// desde o início, os lançamentos. Assim ele percebe o que o servidor já
  /// apagou. A margem de um mês cobre relógios desencontrados.
  static const fullDownloadAfterMonths = 11;

  /// Limite: o que foi alterado pela última vez antes dele pode ser apagado.
  static DateTime cutoff(DateTime now) => monthsBefore(now.toUtc(), months);

  /// `true` se o aparelho precisa refazer o download dos lançamentos desde o
  /// início: nunca concluiu um download ou o último foi há 11 meses ou mais.
  static bool needsFullDownload(DateTime? lastCompleteDownload, DateTime now) =>
      lastCompleteDownload == null ||
      !lastCompleteDownload.toUtc().isAfter(
        monthsBefore(now.toUtc(), fullDownloadAfterMonths),
      );

  /// [t] menos [count] meses, como o PostgreSQL faz com `interval 'N months'`.
  /// Se o dia não existir no mês de destino, usa o último dia (29/02/2028
  /// menos 12 meses = 28/02/2027).
  static DateTime monthsBefore(DateTime t, int count) {
    final utc = t.toUtc();
    final index = utc.year * 12 + (utc.month - 1) - count;
    final year = index ~/ 12;
    final month = index % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(
      year,
      month,
      utc.day < lastDay ? utc.day : lastDay,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    );
  }
}
