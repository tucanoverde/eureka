# CRM Eureka — Como cada número é calculado

Documento para responder às perguntas do Luis sobre as fórmulas usadas no sistema. Referências de linha apontam para `index.html`.

---

## 0. Conceitos-base (engine, linhas 1022–1186)

Toda a parte financeira parte de três coisas:

- **Receita bruta** de um município (`calcReceita`, linha 1067):
  ```
  receita = ef1_alunos × R$ 400 + ef2_alunos × R$ 500
  ```
  Os tickets (400/500) vêm de **Configurações** (`repasse_aluno_ef1`/`ef2`).

- **Peso de etapa** (Configurações → "Pesos de Forecast por Etapa"; defaults na linha 1032):
  ```
  SQL = 25%   R1 = 30%   R2 = 40%   R3 = 50%
  Licitação = 85%   Empenho = 90%   Entrega = 95%   Win = 100%
  ```

- **Peso de farol** (Configurações → "Pesos de Conversão por Farol"; defaults na linha 1035):
  ```
  Quente = 30%   Morno = 15%   Frio = 5%
  ```

- **Receita ajustada** de um município (`calcReceitaAjustada`, linha 1083):
  ```
  receita_ajustada = receita × peso_etapa
  ```
  É o equivalente da coluna **K27** da planilha Excel original.

- **Forecast ajustado total** (`calcForecastAjustado`, linha 1089):
  ```
  forecast = SOMA( receita_ajustada ) de todos os municípios com status ativo
  ```
  Status ativos = `SQL, R1, R2, R3, Licitação, Empenho, Entrega, Win` (linha 1029).
  Equivale a **Health!A24 = SUM(K27:K503)** da planilha.

> **Importante**: o peso de farol **não entra** no forecast canônico — só no **Dashboard / Funil de Vendas** (veja seção 1.4 abaixo). Isso explica diferenças entre telas.

---

## 1. Dashboard

### 1.1 TAM total
- Soma da **receita bruta** de **todos** os municípios da base (incluindo os sem farol, sem status).
- Código: linha 1421 — `tamTotal = SOMA( ef1×400 + ef2×500 )` de **todo** `state.municipios`.

### 1.2 Receita potencial (pipeline) — KPI roxo
- Soma da **receita bruta** dos municípios com status **SQL, R1, R2, R3, Licitação** (apenas 5 etapas — **divergência**, veja seção 5).
- Código: linhas 1403, 1412, 1416.

### 1.3 Forecast — KPI
- Soma de `receita × peso_etapa` desses mesmos 5 status (SQL→Licitação).
- Código: linha 1417: `forecastPipeline = soma(rec × PESOS[status])`.
- **Não bate com Health/Tracking** porque ignora Empenho, Entrega, Win — explicação na seção 5.

### 1.4 Funil de Vendas — receita ao lado de cada etapa
- Mostra todos os 8 status. A receita de cada etapa é calculada como:
  ```
  receita_funil = SOMA( receita × peso_etapa × peso_farol )
  ```
- Código: linhas 1428–1436. Há **dupla ponderação**: peso_etapa **e** peso_farol.
- Por isso o valor do funil é sempre menor que o forecast do KPI.

### 1.5 TAM por Região Administrativa (tabela)
Código: linhas 1454–1468. Para cada região:

| Coluna | Como é calculada |
|---|---|
| Municípios | Quantos municípios da base estão nessa região |
| TAM EF1 | Soma de `ef1_alunos` de **todos** os municípios da região |
| TAM EF2 | Soma de `ef2_alunos` de **todos** os municípios da região |
| Alunos SOM | Soma de alunos EF1+EF2, **só dos municípios COM farol definido** |
| Penetração | Alunos SOM / TAM total da região |
| Receita Estimada | `receita bruta` (ef1×400+ef2×500), **só dos municípios com farol** |

> A "Receita Estimada" da região **não usa peso de etapa nem de farol** — é receita bruta dos municípios que têm classificação de farol.

### 1.6 Top 10 — atualmente duplicado
- Dois cards lado a lado mostram exatamente a mesma lista (linhas 1650–1682).
- **Decidido**: trocar o segundo por "Top 10 · Prioritárias" (filtrando `status = 'Prioritaria'`).

### 1.7 Top Responsáveis
- Soma de receita por código de `indicacao` × percentual de comissão do indicador (linhas 1491–1502).
- Quando não há dado, mostra "a preencher" — **decidido**: ocultar quando não houver indicador com receita.

---

## 2. Municípios (lista)

### 2.1 Coluna "Receita potencial"
- `(ef1_alunos × repasse_EF1) + (ef2_alunos × repasse_EF2)` (linha 2036).
- Usa os valores de **Configurações**, então acompanha mudanças no ticket.

### 2.2 Multiplicador
- Hoje (linha 2032): `mult = parseFloat(state.filters.multiplicador)` — multiplica a Receita potencial pelo valor.
- **Bug reportado**: não funciona. Investigar (provável: o input mudou de evento ou o `renderTable` não está sendo chamado no `input` event).

### 2.3 Filtro de status — atualmente único
- Linha 2055: `if (f.status) items = items.filter(m => m.status === f.status)`.
- **Decidido**: permitir múltiplos status (ex: SQL + R1).

---

## 3. Reunião Semanal

### 3.1 Forecast no header
- Linha 3300: `cfg = getCfg()`, depois `forecastAdj = SOMA(calcReceitaAjustada)` apenas dos municípios em `ETAPAS_ATIVAS`.
- **Igual ao Health e Pipeline Tracking** (cálculo canônico).
- **NÃO usa peso de farol** — só peso de etapa. A dúvida do Luis ("é através dos pesos de morno/quente/frio") é **não**, mas a sugestão é justa para o **Dashboard**, que mistura tudo.

### 3.2 Health do município (coluna na tabela)
- `calcHealth` (linha 1120). Compara o tempo em dias na etapa atual com `tRef` (tempo médio de municípios com aquele farol):
  - Quente: 🟢 se tempo ≤ tRef · 🟡 se tempo ≤ 1.5×tRef · 🔴 caso contrário
  - Morno: 🟢 ≤ tRef · 🟡 ≤ 1.3×tRef · 🔴 acima
  - Frio: 🟢 ≤ tRef · 🟡 ≤ 1.2×tRef · 🔴 acima

### 3.3 Velocity do município
- `calcVelocity` (linha 1151): `tempo_atual / tempo_referencia_farol`.
- Valor < 1 = município mais rápido que a média do farol. > 1 = mais lento.

### 3.4 "Semanas no Histórico"
- KPI mostra quantas semanas distintas foram salvas em `reuniao_semanal` (linha 3346: `semanasUnicas.length`).

### 3.5 Histórico semanal vazio
- **Bug**: o seletor de semana só re-renderiza, não filtra. Os botões "verSemana(W18)" no rodapé não passam a semana selecionada para o render.

---

## 4. Pipeline Tracking

### 4.1 Receita Potencial Atual / Forecast Atual
- Ambos KPIs mostram o **mesmo número**: `calcForecastAjustado(municípios)` (linha 3051, 3186, 3191).
- Soma de `receita × peso_etapa` dos 8 status ativos.
- **Bate com Health e Reunião Semanal**.

### 4.2 Municípios
- `ativos.length`: quantidade de municípios com status em `SQL, R1, R2, R3, Licitação, Empenho, Entrega, Win`.
- **Após mudança**: vai incluir também `Prioritaria` (passa a 9 status no total).
- Luis viu "7" mas deveria ser **8** — isso significa que faltava 1 município sendo contado (provavelmente um Prioritário).

### 4.3 Eficiência (R$/dia)
- Linha 3054–3065: para cada município ativo, calcula `receita_ajustada / dias_na_etapa`. Pega a **mediana**.
- **Bug**: aparece zerada — investigar (provável: nenhum município tem `data_sql/r1/r2/r3/licitacao` preenchida, então `dias = m.tempo_na_etapa || 1`, e como `tempo_na_etapa` provavelmente é null, todos dão 0 e são filtrados).

### 4.4 Velocity (KPI no histórico)
- Linha 3092, 3283: `(tmFarol.Q + tmFarol.M + tmFarol.F) / 3`.
- Média do tempo médio dos faróis Q/M/F — **medida estranha**, podemos repensar.

### 4.5 Gargalo
- Hoje (linha 3074–3077): etapa com **maior número de municípios** parados.
- **Luis sugere**: deveria refletir "onde a carteira está travada".
- **Proposta**: mudar para etapa com maior **tempo desperdiçado** = `qtde × tempo_médio_na_etapa`.
- Resultado esperado: se R2 tem 3 municípios parados há 60 dias, ganha de R1 com 5 municípios parados há 10 dias (`180 > 50`).

### 4.6 Faróis com sinal negativo
- Linha 3158: `${(t.municipios_ativos)-(t.quente)-(t.morno)} 🔵`
- Calcula frio por subtração, e quando `quente+morno > ativos` (porque a tabela não tem coluna `frio`), dá negativo.
- **Fix**: salvar `frio` no `pipeline_tracking` e exibir direto.

---

## 5. Health & Forecast

### 5.1 Receita Forecast (KPI verde)
- `calcForecastAjustado` (linha 2859, 3186) — **idêntico** ao Pipeline Tracking e Reunião Semanal.
- **Deve bater entre todas essas três telas.**

### 5.2 Receita Líquida / Faturamento Redesa
- `recLiq = forecast × (1 - impostos)` · `redesa = recLiq × 50%`.

### 5.3 Cenários Globais (Agressivo / Realista / Conservador)
- Multiplica o forecast pela `taxa_de_conversão` do cenário (linhas 1175–1186):
  - Agressivo: 100% (mantém forecast)
  - Realista: 50%
  - Conservador: 25%
- Esses % vêm de Configurações.

### 5.4 Cenários por Farol
- Soma a receita ajustada **só dos municípios daquele farol** (linha 2863–2864), depois aplica os mesmos % de conversão.
- **Deve bater** com Cenários Globais quando somar Q+M+F.
- Se não está batendo, é porque municípios sem farol entram no global mas não nos 3 do farol.

---

## 6. Indicadores & Remuneração

### 6.1 Forecast da tela
- `calcForecastAjustado` — **igual ao Health e Reunião Semanal**.

### 6.2 Comissão estimada por responsável
- `comissao = forecast_do_indicador × (1 - impostos) × 50% × % comissão` (linha 4483).
- Ou seja, é a fatia do Faturamento Redesa que cabe àquele responsável.

---

## Resumo: onde o forecast é o mesmo, onde diverge

| Tela | Fórmula | Bate com Health? |
|---|---|---|
| **Health & Forecast** | `calcForecastAjustado` (8 etapas, só peso etapa) | ✅ referência |
| **Reunião Semanal** | `calcForecastAjustado` | ✅ |
| **Pipeline Tracking** | `calcForecastAjustado` | ✅ |
| **Indicadores** | `calcForecastAjustado` | ✅ |
| **Dashboard – KPI "Forecast"** | só 5 etapas (SQL→Licitação) | ❌ diverge — não conta Empenho/Entrega/Win |
| **Dashboard – Funil receita** | receita × peso_etapa × peso_farol | ❌ diverge — usa peso de farol também |

**Recomendação técnica**: unificar o Dashboard para usar a mesma engine das outras telas. Os KPIs ficam consistentes.

---

## Bugs/melhorias já listados (em paralelo a este documento)

1. Multiplicador na lista de Municípios — não funciona
2. Top 10 duplicado no Dashboard — virar "Top 10 Prioritárias"
3. Top Responsáveis "a preencher" — esconder quando vazio
4. Histórico Semanal da Reunião — vazio (botões de semana não filtram)
5. Faróis frios com sinal negativo no Tracking
6. Eficiência zerada no Tracking
7. Health & Forecast: cenários por farol vs globais
8. Reunião Semanal: campos Próxima Ação / Bloqueio / Fechamento precisam expandir
9. Filtro multi-status nos Municípios
10. Responsável pré-preenchido (REDESA / EUREKA / REDESA-EUREKA)
11. Fonte QEdu (https://qedu.org.br/)
12. Gargalo com fórmula real (tempo desperdiçado)
13. Incluir `Prioritaria` em `ETAPAS_ATIVAS` → Municípios KPI vai a 8
