/// Relatório 4 (evolução do dinheiro livre): diferença do período selecionado
/// para o anterior da sequência (número novo aprovado em 17/11/2026, spec
/// `docs/ferramentas/relatorios.md` §4.4). Subtração exata em centavos.
library;

/// [surpluses]: dinheiro livre de cada período da sequência, do mais antigo
/// ao selecionado (o último). Devolve selecionado − anterior, ou `null` sem
/// período anterior.
BigInt? freeMoneyChangeFromPrevious(List<BigInt> surpluses) {
  if (surpluses.length < 2) return null;
  return surpluses[surpluses.length - 1] - surpluses[surpluses.length - 2];
}
