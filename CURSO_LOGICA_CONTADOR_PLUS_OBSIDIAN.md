# Curso: Lógica de Programação Aplicada com Contador+

> Arquivo em Markdown pronto para uso no Obsidian.

## 🎯 Visão Geral

- **Título sugerido:** Lógica de Programação Aplicada: construindo o Contador+
- **Objetivo:** ensinar lógica de programação em um sistema real (fiscal) com Flutter.
- **Público-alvo:** iniciantes, devs juniores e profissionais contábeis migrando para tech.

---

## 🧭 Objetivos de Aprendizagem

Ao concluir o curso, o aluno será capaz de:

1. Modelar dados de domínio real (empresa, obrigação, vencimento).
2. Implementar estado com regras de transição.
3. Combinar múltiplas fontes de dados com deduplicação.
4. Trabalhar com assíncrono, loading, erro e ciclo de vida.
5. Consumir APIs com paginação, retry e backoff.
6. Implementar fallback entre provedores (resiliência).

---

## 🗂️ Estrutura do Curso (12 semanas / 24 aulas)

### Semana 1 — Mapa do sistema
- Aula 1: Arquitetura e módulos do app
- Aula 2: Fluxo de navegação e rotas
- **Entrega:** mapa de rotas e fluxo do usuário

### Semana 2 — Modelagem de dados
- Aula 3: Entidades de domínio
- Aula 4: Parsing e imutabilidade
- **Entrega:** nova entidade integrada ao fluxo

### Semana 3 — Estado e transições
- Aula 5: Estado global e notifier
- Aula 6: Eventos e regras de status
- **Entrega:** regra de transição de status

### Semana 4 — Algoritmos de negócio
- Aula 7: Filtro por período
- Aula 8: Deduplicação por chave composta
- **Entrega:** alteração de prioridade entre fontes

### Semana 5 — Busca e ranking
- Aula 9: Busca textual
- Aula 10: Ordenação multi-critério
- **Entrega:** busca com score simples

### Semana 6 — Tempo e ciclo de vida
- Aula 11: Atualização na virada do mês
- Aula 12: Reentrada do app e sincronização
- **Entrega:** política de atualização configurável

### Semana 7 — HTTP robusto
- Aula 13: Requests e tratamento de erro
- Aula 14: Retry e backoff
- **Entrega:** retry configurável

### Semana 8 — Paginação
- Aula 15: Paginação por links
- Aula 16: Limites e performance
- **Entrega:** indicador de progresso por páginas

### Semana 9 — Parsing + cache
- Aula 17: Parsing/scraping de fonte oficial
- Aula 18: Cache memória + disco
- **Entrega:** relatório de cache hit/miss

### Semana 10 — IA resiliente
- Aula 19: Multiprovedores
- Aula 20: Fallback por tipo de erro
- **Entrega:** política automática de fallback

### Semana 11 — UX operacional
- Aula 21: loading, erro e feedback
- Aula 22: onboarding de configuração
- **Entrega:** fluxo guiado para setup

### Semana 12 — Projeto final
- Aula 23: Refinamento técnico
- Aula 24: Demo day
- **Entrega final:** feature autoral com justificativa lógica

---

## ✅ Rubrica de Avaliação

- **Lógica de negócio (30%)** — regras claras, sem contradições
- **Estado e dados (20%)** — modelagem e previsibilidade
- **Resiliência (20%)** — tratamento de falhas/fallback
- **Qualidade de código (20%)** — organização e legibilidade
- **Comunicação técnica (10%)** — clareza de explicação

---

## 🧪 Trilha de Exercícios

### Iniciante
- Filtrar vencimentos por mês
- Contar tarefas por status

### Intermediário
- Deduplicar itens por chave composta
- Ordenar por múltiplos critérios

### Avançado
- Implementar invalidação de cache
- Implementar fallback entre provedores por erro

---

## 🎬 Roteiro de Gravação (primeiras 5 aulas)

### Aula 1 — Pensar em sistema
- Introdução ao problema real
- Mapa de telas e fluxo
- Exercício: desenhar fluxo do usuário

### Aula 2 — Modelagem prática
- Entidades e campos
- Parsing de dados
- Exercício: adicionar campo novo

### Aula 3 — Estado previsível
- Estado global e eventos
- Exercício: criar nova ação de estado

### Aula 4 — Algoritmos de verdade
- Combinar fontes
- Deduplicar e ordenar
- Exercício: mudar regra e comparar saída

### Aula 5 — Assíncrono sem dor
- Loading e erro
- Atualização temporal
- Exercício: simular troca de mês

---

## 🚀 Plano de Execução (7 dias)

1. **Dia 1:** Gravar aulas 1 e 2
2. **Dia 2:** Workbook das aulas 1 e 2
3. **Dia 3:** Gravar aula 3
4. **Dia 4:** Gravar aula 4
5. **Dia 5:** Gravar aula 5
6. **Dia 6:** Página de inscrição beta
7. **Dia 7:** Abrir lista de espera + aula aberta

---

## 📌 Checklist de Publicação

- [ ] Arquitetura revisada
- [ ] Exercícios prontos por módulo
- [ ] Rubrica publicada
- [ ] Materiais de apoio exportados em PDF
- [ ] Landing page e FAQ concluídos
- [ ] Calendário da turma beta definido

---

## 🔗 Sugestão de Links Internos (Obsidian)

- [[Mapa de Rotas]]
- [[Modelagem de Dados]]
- [[Estado e Notifier]]
- [[Deduplicação e Ordenação]]
- [[Assíncrono e Ciclo de Vida]]
- [[HTTP com Retry e Backoff]]
- [[Fallback de IA]]
- [[Projeto Final]]

---

## Notas

Você pode duplicar este arquivo para criar versões:
- `CURSO_LOGICA_CONTADOR_PLUS_TURMA_BETA.md`
- `CURSO_LOGICA_CONTADOR_PLUS_TURMA_OFICIAL.md`

