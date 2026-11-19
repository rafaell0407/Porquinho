import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../export/file_download.dart' as download;
import '../domain/import_template.dart';

/// Entrega o arquivo modelo para download. Testes sobrescrevem.
final importTemplateDownloadProvider =
    Provider<void Function(String fileName, String content)>(
      (_) =>
          (fileName, content) => download.downloadTextFile(fileName, content),
    );

/// Baixa o modelo e avisa o usuário.
void downloadImportTemplate(BuildContext context, WidgetRef ref) {
  ref.read(importTemplateDownloadProvider)(
    ImportTemplate.fileName,
    ImportTemplate.content(),
  );
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Modelo baixado: ${ImportTemplate.fileName}')),
  );
}

/// Mais → Importar dados → Como importar: modelo e passo a passo.
class ImportGuideScreen extends ConsumerWidget {
  const ImportGuideScreen({super.key});

  static const route = '/importar/como-importar';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Como importar')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            key: const Key('importar-tutorial-tela'),
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'O jeito mais fácil é baixar o modelo, colocar seus '
                'lançamentos nele e carregar o arquivo aqui. Se você já tem '
                'uma planilha, um extrato ou uma exportação do Norte, também '
                'pode usar: no assistente você diz o que é cada coluna.',
              ),
              const SizedBox(height: 24),
              _Step(
                number: 1,
                title: 'Baixe o modelo',
                children: [
                  const Text(
                    'É um arquivo CSV com a primeira linha (os nomes das '
                    'colunas) e alguns lançamentos de exemplo. Abre no Excel, '
                    'no Google Planilhas ou no LibreOffice.',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      key: const Key('importar-tutorial-baixar-modelo'),
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar modelo'),
                      onPressed: () => downloadImportTemplate(context, ref),
                    ),
                  ),
                ],
              ),
              const _Step(
                number: 2,
                title: 'Preencha uma linha por lançamento',
                children: [
                  Text(
                    'Apague as linhas de exemplo e coloque as suas. Não mude '
                    'a primeira linha. Colunas que você não usar podem ficar '
                    'vazias.',
                  ),
                  SizedBox(height: 12),
                  _Column(
                    name: 'tipo',
                    required: true,
                    text: 'Receita, Despesa ou Investimento.',
                  ),
                  _Column(
                    name: 'data',
                    required: true,
                    text:
                        'No formato DD/MM/AAAA. Receita: dia do recebimento. '
                        'Despesa: dia da despesa (define o período em que '
                        'conta). Investimento: dia do investimento.',
                  ),
                  _Column(
                    name: 'valor',
                    required: true,
                    text:
                        'Em reais, como 1.234,56. Sem sinal de menos: o tipo '
                        'já diz se entra ou sai.',
                  ),
                  _Column(
                    name: 'descricao',
                    text:
                        'Texto livre, até 120 caracteres. Investimento não '
                        'tem descrição.',
                  ),
                  _Column(
                    name: 'categoria',
                    text:
                        'Nome da categoria, até 60 caracteres. Pode ser uma '
                        'que você já tem ou uma nova. Investimento não tem '
                        'categoria.',
                  ),
                  _Column(
                    name: 'subcategoria',
                    text: 'Opcional. Só com a categoria preenchida.',
                  ),
                  _Column(
                    name: 'situacao',
                    text:
                        'Receita: Recebida. Despesa: Paga ou Pendente. '
                        'Investimento: deixe vazio.',
                  ),
                  _Column(
                    name: 'vencimento',
                    text: 'Só para despesa. Opcional, no formato DD/MM/AAAA.',
                  ),
                  _Column(
                    name: 'data_pagamento',
                    text: 'Obrigatória quando a despesa está Paga.',
                  ),
                ],
              ),
              const _Step(
                number: 3,
                title: 'Salve como CSV',
                children: [
                  _Bullet(
                    'Excel: Arquivo → Salvar como → tipo "CSV UTF-8 '
                    '(delimitado por vírgulas)".',
                  ),
                  _Bullet(
                    'Google Planilhas: Arquivo → Fazer download → Valores '
                    'separados por vírgula (.csv).',
                  ),
                  _Bullet(
                    'LibreOffice: Arquivo → Salvar como → "Texto CSV", com o '
                    'conjunto de caracteres Unicode (UTF-8).',
                  ),
                  _Bullet(
                    'Se os acentos aparecerem estranhos ao carregar, use '
                    '"Ler como Windows-1252" na etapa Arquivo.',
                  ),
                ],
              ),
              const _Step(
                number: 4,
                title: 'Carregue no Norte',
                children: [
                  Text(
                    'Volte para Importar dados, toque em "Nova importação" e '
                    'siga as etapas:',
                  ),
                  SizedBox(height: 8),
                  _Bullet(
                    'Arquivo: escolha o arquivo e confira as primeiras '
                    'linhas.',
                  ),
                  _Bullet(
                    'Colunas: com o modelo, já vêm associadas. Confira o '
                    'formato do valor (Reais com vírgula) e da data '
                    '(DD/MM/AAAA).',
                  ),
                  _Bullet(
                    'Classificação: escolha "Uma coluna diz o tipo de cada '
                    'linha" e diga o que é "receita", "despesa" e '
                    '"investimento". Em Situação: "recebida" → Recebida, '
                    '"paga" → Paga, "pendente" → Pendente, e "(vazio)" '
                    '→ Normal.',
                  ),
                  _Bullet(
                    'Categorias: para cada nome, use uma categoria que você '
                    'já tem, crie uma nova ou deixe sem.',
                  ),
                  _Bullet(
                    'Duplicidades e Recorrências: decida o que fazer com '
                    'lançamentos parecidos com os que você já tem e se quer '
                    'transformar séries mensais em recorrência.',
                  ),
                  _Bullet(
                    'Prévia e confirmação: confira os totais e o dinheiro '
                    'livre de cada período. Nada é gravado antes de você '
                    'confirmar.',
                  ),
                ],
              ),
              const _Step(
                number: 5,
                title: 'Se algo der errado',
                children: [
                  _Bullet(
                    'Linhas com problema aparecem na prévia com o motivo e '
                    'não entram. Corrija o arquivo e importe de novo, se '
                    'quiser.',
                  ),
                  _Bullet(
                    'Em "Importações anteriores", abra a importação e use '
                    '"Desfazer" para cancelar o que entrou e ainda não foi '
                    'mexido.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.children,
  });

  final int number;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text(
              '$number',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.name,
    required this.text,
    this.required = false,
  });

  final String name;
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (required)
              TextSpan(
                text: ' (obrigatória)',
                style: TextStyle(color: muted),
              ),
            TextSpan(text: ' — $text'),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
