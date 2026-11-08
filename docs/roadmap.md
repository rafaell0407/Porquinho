# Roadmap

Este roteiro organiza decisões e preparação. Não autoriza implementar funcionalidades sem requisitos aprovados.

## Fase 0 — Preparação do repositório

- [x] Registrar instruções de desenvolvimento em `AGENTS.md`.
- [x] Criar a documentação técnica inicial em `docs/`.
- [ ] Confirmar o uso do diretório como raiz do repositório e inicializar Git, se apropriado.
- [ ] Tornar o Flutter CLI executável no ambiente e confirmar `flutter --version`.
- [ ] Criar ou recuperar a estrutura base do aplicativo Flutter quando o escopo do produto for confirmado.

## Fase 1 — Definição do produto

- [ ] Registrar público, problema, plataformas e critérios de aceite em `requisitos.md`.
- [ ] Priorizar o escopo da primeira entrega.
- [ ] Documentar regras confirmadas em `regras_negocio.md`.
- [ ] Definir requisitos de privacidade, segurança e funcionamento sem conexão.

## Fase 2 — Decisões técnicas

- [ ] Escolher e documentar arquitetura proporcional ao escopo em `arquitetura.md`.
- [ ] Decidir se há persistência e escolher uma solução fundamentada em `banco_de_dados.md`.
- [ ] Configurar análise estática, formatação e testes após a estrutura Flutter existir.
- [ ] Avaliar cada dependência e adicionar apenas as necessárias.

## Fase 3 — Entregas do aplicativo

- [ ] Planejar incrementos rastreáveis aos requisitos aprovados.
- [ ] Implementar somente após aprovação dos requisitos, arquitetura inicial e critérios de aceite.
- [ ] Atualizar documentação e executar verificações adequadas a cada incremento.

## Bloqueios conhecidos

- O diretório de trabalho estava vazio na inspeção; não há aplicativo Flutter nem dependências para validar.
- O Flutter CLI encontrado referencia um SDK fora da área gravável e falhou ao acessar o arquivo de bloqueio do SDK. Consultar `arquitetura.md` para os detalhes.
