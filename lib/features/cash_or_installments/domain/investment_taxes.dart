/// IR regressivo e IOF da renda fixa (spec §7), por dias corridos desde a
/// aplicação.
abstract final class InvestmentTaxes {
  /// IOF em % do rendimento, por dias corridos (índice 0 a 29). A partir de
  /// 30 dias, zero. (Dia 0 não tem rendimento.)
  static const List<int> iofTable = [
    100, 96, 93, 90, 86, 83, 80, 76, 73, 70, //
    66, 63, 60, 56, 53, 50, 46, 43, 40, 36, //
    33, 30, 26, 23, 20, 16, 13, 10, 6, 3, //
  ];

  /// IOF em % do rendimento.
  static int iofPercent(int calendarDays) {
    if (calendarDays < 0) {
      throw ArgumentError.value(calendarDays, 'calendarDays');
    }
    return calendarDays < iofTable.length ? iofTable[calendarDays] : 0;
  }

  /// IR em milésimos (225 = 22,5%) sobre o rendimento menos o IOF.
  static int irPermil(int calendarDays) {
    if (calendarDays < 0) {
      throw ArgumentError.value(calendarDays, 'calendarDays');
    }
    if (calendarDays <= 180) return 225;
    if (calendarDays <= 360) return 200;
    if (calendarDays <= 720) return 175;
    return 150;
  }
}
