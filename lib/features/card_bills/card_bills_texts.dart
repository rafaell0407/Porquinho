/// Textos da Gestão de Faturas de Cartões. Rascunho do agente (spec §13),
/// para o responsável ajustar depois.
abstract final class CardBillsTexts {
  static const title = 'Gestão de Faturas de Cartões';
  static const catalogName = 'Gestão de faturas';
  static const shortDescription =
      'Quanto do dinheiro separado para os cartões já está comprometido.';

  static const purpose =
      'Responder: do dinheiro que você separou para pagar os cartões, quanto '
      'já está comprometido com faturas e quanto sobra.';

  static const howItWorks =
      'Informe quanto tem reservado e cadastre só o que quiser: cartões, '
      'compras parceladas, assinaturas ou apenas o total de uma fatura. A '
      'ferramenta soma as faturas a pagar e mostra o saldo não comprometido '
      '(reservado − comprometido). Ao pagar uma fatura, diga se o dinheiro '
      'saiu da reserva ou de outras fontes.';

  static const assumptions = [
    'Compra feita antes do dia de fechamento entra na fatura atual; no dia '
        'do fechamento ou depois, na seguinte.',
    'Dia 29, 30 ou 31 em mês sem esse dia vira o último dia do mês.',
    'Parcelas: o total dividido igualmente; os centavos que sobram vão '
        'para a 1ª parcela.',
    'Valor informado numa fatura substitui a soma dos itens (nunca soma os '
        'dois).',
    'Assinaturas entram só na fatura atual de cada cartão.',
    'Só se paga a fatura inteira.',
  ];

  static const disclaimer =
      'Ferramenta separada: não cria lançamentos, não muda o dinheiro livre '
      'nem os relatórios. O "saldo" aqui é só desta ferramenta, não é saldo '
      'bancário.';

  static const emptyTitle = 'Comece pelo seu primeiro cartão';
  static const emptyBody =
      'Cadastre o cartão com os dias de fechamento e vencimento. Depois, '
      'registre compras parceladas, assinaturas ou só o total da fatura.';
}
