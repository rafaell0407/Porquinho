# Arquitetura

## Estado atual

Não há código-fonte, `pubspec.yaml`, configurações de plataforma ou estrutura de aplicativo nesta pasta. Portanto, não existe uma arquitetura implementada para descrever.

## Ambiente identificado

- Flutter instalado: **3.47.9**, canal stable, conforme `bin/cache/flutter.version.json` do SDK encontrado no ambiente.
- Dart instalado: **3.13.7**, confirmado executando diretamente o binário Dart do SDK.
- O `flutter --version` não concluiu neste ambiente: a ferramenta tentou acessar `bin/cache/lockfile` dentro do SDK instalado fora da área gravável. A versão acima foi lida dos metadados locais do SDK; uma execução normal do Flutter CLI continua pendente.
- Não foi encontrado `pubspec.yaml`, `analysis_options.yaml` ou configuração de plataforma para avaliar.

## Diretrizes para decisões futuras

As escolhas abaixo são critérios de avaliação, não decisões arquiteturais aprovadas:

- Definir a organização do código após conhecer os fluxos e o tamanho esperado do produto; evitar camadas e abstrações sem necessidade concreta.
- Manter UI, regras de domínio e acesso a dados com responsabilidades claras quando a complexidade do produto justificar essa separação.
- Escolher gerenciamento de estado, roteamento, injeção de dependências e clientes de rede com base nos requisitos, manutenção e suporte do ecossistema.
- Definir tratamento de erros, telemetria, configuração por ambiente e estratégia de testes antes de depender deles em funcionalidades.
- Fixar as restrições de SDK e formatos de análise no `pubspec.yaml` e na configuração do projeto quando o aplicativo for criado.

## Próxima decisão

Confirmar requisitos e plataformas; então criar ou validar a estrutura Flutter, escolher uma organização mínima e registrar as decisões e alternativas consideradas aqui.
