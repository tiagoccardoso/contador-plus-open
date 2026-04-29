# Contador+ · Guia de Estudo Completo (Obsidian)

> Conteúdo de estudo construído **com base na estrutura real do projeto**.
> Use este arquivo como página principal do seu vault no Obsidian.

---

## Como usar este material

1. Leia a seção [[Mapa da Arquitetura]].
2. Siga a trilha [[Plano de Estudo por Sprints]].
3. Em cada sprint, abra os arquivos indicados e faça os desafios.
4. Registre decisões e dúvidas em uma nota diária (ex.: `Diário - Sprint 01`).

---

## Mapa da Arquitetura

## 1) Entrada e navegação
- `lib/main.dart`
- Responsável por:
  - boot da aplicação
  - carregamento de `.env`
  - hidratação de cache federal
  - configuração de rotas e menu principal

## 2) Camada de features (UI)
Pasta: `lib/src/features/`

Módulos principais:
- `home/` → visão combinada de obrigações (federais + locais)
- `calendar/` → calendário mensal e interação por dia
- `deadline/` → detalhes de vencimento
- `learning/` → perguntas para IA
- `settings/` → preferências do app e configuração de provedores de IA
- `deputados/` e `senadores/` → dados legislativos federais
- `deputados_estaduais_pr/` → ALEP (PR)
- `tse/` → dados eleitorais
- `reforma/` e `reforma_timeline/` → conteúdo e linha do tempo da reforma tributária
- `normas/` → link para normas RFB
- `podcast/` → atalhos para canais no Spotify
- `about/` → fontes e transparência

## 3) Camada shared (regras, integração e utilitários)
Pasta: `lib/src/shared/`

Núcleos mais importantes:
- Estado/modelos:
  - `models.dart`
  - `state.dart`
  - `providers.dart`
- Calendário fiscal:
  - `agenda_federal_service.dart` (scraping + cache)
  - `calendar_service.dart` (carregamento de dataset local)
- IA:
  - `openai_service.dart` (OpenAI/Gemini/DeepSeek)
  - `ai_settings_store.dart` (preferências e prioridade)
- APIs externas:
  - `camara/`
  - `senado/`
  - `alep/`
  - `tse/`
- Infra/cache:
  - `cache/disk_cache.dart`
- Utilitários de UX:
  - `open_link.dart`, `whatsapp_share.dart`, `json_viewer_screen.dart`

## 4) Dados e ativos
- `assets/seeds/` → empresas, obrigações, vencimentos base
- `assets/data/` → obrigações locais/federais de apoio
- `assets/reforma/`, `assets/trails/`, `assets/holidays/`, `assets/legal/`

## 5) Backend auxiliar
- `server/` (Node.js)
- `package.json` sugere proxy/serviços auxiliares para integrações.

---

## Plano de Estudo por Sprints

## Sprint 0 — Setup e orientação (1 dia)
**Objetivo:** rodar o projeto e entender o escopo.

Checklist:
- [ ] Ler `README.md` e `pubspec.yaml`
- [ ] Instalar dependências e executar app
- [ ] Navegar por todas as telas do menu

Entrega:
- Nota `00-setup-e-primeiras-impressoes.md`

---

## Sprint 1 — Fluxo principal do app (2 dias)
**Objetivo:** dominar bootstrap + rotas.

Estudar:
- `lib/main.dart`

Desafios:
1. Desenhar diagrama de rotas.
2. Identificar quais rotas são independentes e quais dependem de estado externo.
3. Adicionar uma rota "laboratório" apenas para estudo.

Entrega:
- `01-mapa-rotas.md`

---

## Sprint 2 — Modelagem e estado (3 dias)
**Objetivo:** entender como o domínio fiscal é representado.

Estudar:
- `lib/src/shared/models.dart`
- `lib/src/shared/state.dart`
- `assets/seeds/companies.json`
- `assets/seeds/obligations.json`
- `assets/seeds/dues.json`

Desafios:
1. Criar um novo campo de negócio (ex.: prioridade da obrigação).
2. Propagar esse campo do JSON até a UI.
3. Criar regra de validação de status.

Entrega:
- `02-modelagem-dominio.md`

---

## Sprint 3 — Home + combinação de dados (3 dias)
**Objetivo:** estudar algoritmo de combinação, busca e deduplicação.

Estudar:
- `lib/src/features/home/home_screen.dart`

Foco:
- união de fontes (local + federal)
- chave de deduplicação
- ordenação por múltiplos critérios

Desafios:
1. Alterar critério de prioridade (local antes de federal).
2. Implementar busca por múltiplos termos.
3. Adicionar filtro por intervalo customizado.

Entrega:
- `03-logica-combinacao-e-busca.md`

---

## Sprint 4 — Calendário e temporalidade (2 dias)
**Objetivo:** entender timers, ciclo de vida e atualização automática.

Estudar:
- `lib/src/features/calendar/calendar_screen.dart`
- `lib/src/features/settings/settings_screen.dart`

Desafios:
1. Explicar a estratégia de atualização na virada do mês.
2. Simular mudança de mês e validar comportamento.
3. Criar flag adicional de atualização para laboratório.

Entrega:
- `04-time-driven-logic.md`

---

## Sprint 5 — Agenda Federal (scraping + cache) (3 dias)
**Objetivo:** dominar integração robusta com fonte oficial.

Estudar:
- `lib/src/shared/agenda_federal_service.dart`
- `lib/src/shared/cache/disk_cache.dart`

Foco:
- parsing HTML
- coleta de links por regex
- persistência em disco
- stale-while-revalidate

Desafios:
1. Mapear todos os pontos de fallback do scraping.
2. Adicionar telemetria simples (contagem de cache hit/miss).
3. Definir política de invalidação por ambiente.

Entrega:
- `05-scraping-cache-fallback.md`

---

## Sprint 6 — IA aplicada (3 dias)
**Objetivo:** estudar fallback entre provedores e tratamento de erro.

Estudar:
- `lib/src/features/learning/learning_screen.dart`
- `lib/src/shared/openai_service.dart`
- `lib/src/shared/ai_settings_store.dart`

Desafios:
1. Documentar fluxo de tentativa por provedor.
2. Implementar política: “429 => troca automática de provedor”.
3. Criar prompt template orientado por tipo de obrigação.

Entrega:
- `06-ia-resiliente.md`

---

## Sprint 7 — APIs públicas e paginação (3 dias)
**Objetivo:** dominar cliente HTTP robusto e paginação.

Estudar:
- `lib/src/shared/camara/camara_api_client.dart`
- `lib/src/shared/senado/`*
- `lib/src/shared/alep/`*
- `lib/src/shared/tse/`*
- `lib/src/features/deputados/`, `senadores/`, `deputados_estaduais_pr/`, `tse/`

Desafios:
1. Comparar estratégias de cache por módulo.
2. Padronizar shape de erros para UI.
3. Criar função utilitária comum para paginação.

Entrega:
- `07-integracoes-publicas.md`

> \\* Estude primeiro os clients e depois os caches dos respectivos módulos.

---

## Sprint 8 — Conteúdo e produtos complementares (2 dias)
**Objetivo:** entender módulos de conteúdo e distribuição.

Estudar:
- `lib/src/features/reforma/`
- `lib/src/features/reforma_timeline/`
- `lib/src/features/podcast/`
- `lib/src/features/normas/`
- `lib/src/features/about/`

Desafios:
1. Propor melhoria de UX por módulo.
2. Definir quais componentes podem virar “pacotes reutilizáveis”.

Entrega:
- `08-conteudo-e-ux.md`

---

## Projeto Final (1 semana)

Escolha 1 trilha:

### Trilha A — Motor de Regras Fiscais
Criar motor simples de regras por tipo de empresa/obrigação com priorização automática.

### Trilha B — Observatório Legislativo
Unificar dados de Câmara/Senado/ALEP em uma timeline filtrável.

### Trilha C — Assistente Fiscal com IA
Gerar checklist acionável com fontes e aviso de risco por atraso.

Critérios de avaliação:
- corretude lógica
- robustez em erro/rede
- clareza de arquitetura
- qualidade da UX
- qualidade da documentação

---

## Caderno de Lógica (template para cada estudo)

Use este modelo em cada nota de sprint:

```md
# [Tema]

## Problema
(Que problema de negócio este código resolve?)

## Entradas
(Quais dados entram?)

## Regras
(Condições, filtros, ordenação, fallback)

## Saídas
(Que resultado é gerado?)

## Casos de borda
(Quais falhas ou exceções podem acontecer?)

## Melhorias possíveis
(Como tornar mais simples, robusto ou performático?)
```

---

## Roadmap de leitura de código (ordem recomendada)

1. `lib/main.dart`
2. `lib/src/shared/models.dart`
3. `lib/src/shared/state.dart`
4. `lib/src/features/home/home_screen.dart`
5. `lib/src/features/calendar/calendar_screen.dart`
6. `lib/src/shared/agenda_federal_service.dart`
7. `lib/src/features/learning/learning_screen.dart`
8. `lib/src/shared/openai_service.dart`
9. `lib/src/shared/camara/camara_api_client.dart`
10. `lib/src/features/reforma_timeline/rt_timeline_screen.dart`
11. `lib/src/features/tse/tse_screen.dart`
12. `lib/src/features/settings/settings_screen.dart`

---

## Comandos úteis (estudo e inspeção)

```bash
# listar arquivos da camada src
rg --files lib/src

# ver estrutura de features
rg --files lib/src/features

# localizar providers
rg "Provider|StateNotifier|Consumer" lib/src

# localizar chamadas HTTP
rg "http\.get|dio\.post|Uri\.https|launchUrl" lib/src

# localizar estratégia de cache
rg "cache|hydrate|refresh|invalidate" lib/src
```

---

## Índice Obsidian (wiki links)

- [[00-setup-e-primeiras-impressoes]]
- [[01-mapa-rotas]]
- [[02-modelagem-dominio]]
- [[03-logica-combinacao-e-busca]]
- [[04-time-driven-logic]]
- [[05-scraping-cache-fallback]]
- [[06-ia-resiliente]]
- [[07-integracoes-publicas]]
- [[08-conteudo-e-ux]]
- [[Projeto Final - Trilha A]]
- [[Projeto Final - Trilha B]]
- [[Projeto Final - Trilha C]]

---

## Checklist de conclusão

- [ ] Entendi as rotas e ciclo de navegação
- [ ] Entendi modelagem e estado
- [ ] Reproduzi a lógica de deduplicação
- [ ] Entendi estratégia de atualização por tempo
- [ ] Entendi scraping + cache federal
- [ ] Entendi fallback de IA
- [ ] Entendi integrações legislativas e eleitorais
- [ ] Entreguei projeto final com documentação

---

## Próximo nível (após concluir)

- Extrair camadas em módulos/pacotes internos.
- Criar suíte de testes de regras críticas.
- Adicionar observabilidade (logs e métricas).
- Implantar CI com lint + testes + validação de assets.

