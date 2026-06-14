# Customer Revenue Recovery Platform — Plataforma de Recuperação de Receita SaaS

![CI](https://github.com/rodrigodesouza7/customer-revenue-recovery-platform/actions/workflows/ci.yml/badge.svg)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-blue)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED)
![Pytest](https://img.shields.io/badge/Tests-29%20passed-brightgreen)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

Plataforma analítica em PostgreSQL para monitoramento de receita, saúde de clientes e recuperação de receita em risco, aplicada a um cenário de empresa SaaS B2B. O projeto cobre modelagem relacional, SQL avançado, governança via auditoria automática, geração de dados sintéticos em escala, testes automatizados e pipeline de CI/CD com Docker.

---

## Visão Geral

### Problema de Negócio

Empresas SaaS frequentemente enfrentam perda de receita por churn, inadimplência, queda de engajamento e falhas de pagamento, sem visibilidade clara sobre:

- Quanto de receita está em risco neste momento?
- Quais clientes têm maior probabilidade de churn?
- Qual a saúde geral da base de clientes (uso, pagamentos, suporte)?
- Quais pagamentos já foram recuperados após falha?

### Solução

Modelo relacional em PostgreSQL com schemas separados por responsabilidade (`core`, `analytics`, `audit`), views analíticas para métricas de receita e saúde do cliente, trigger de auditoria automática para mudanças de status de pagamento, e um gerador de dados sintéticos reprodutível para testes e demonstração em volume.

---

## Tech Stack

### Banco de Dados
- **PostgreSQL 18** — banco relacional principal
- **DBeaver** — administração e queries

### Geração de Dados
- **Python 3.14**
- **Pandas + Faker** — geração de dataset sintético (500 clientes, ~3 anos de histórico)
- **psycopg3** — carga via `COPY`

### Testes
- **Pytest** — 29 testes automatizados (schema, qualidade de dados, views, trigger)

### Infraestrutura
- **Docker Compose** — ambiente Postgres replicável

### DevOps
- **GitHub Actions** — CI/CD automatizado

---

## Arquitetura do Sistema
data_generator/ (Python: Faker + Pandas)

↓

CSV files (output/)

↓

COPY → PostgreSQL 18

↓

┌───────────────┬──────────────────┬─────────────┐

│   core         │    analytics      │   audit     │

│ customers      │ vw_customer_      │ payment_    │

│ plans          │   revenue         │   audit_log │

│ subscriptions  │ vw_customer_      │             │

│ payments       │   health          │             │

│ support_tickets│ vw_revenue_       │             │

│ usage_events   │   recovery        │             │

│                │ vw_recovered_     │             │

│                │   payments        │             │

└───────────────┴──────────────────┴─────────────┘

↓

pytest (29 tests) → GitHub Actions CI/CD

---

## Modelo de Dados

### Schema `core`

**customers** — clientes da plataforma SaaS (segmento, país, status)
**plans** — planos contratados (Starter, Pro, Enterprise — mensal/anual)
**subscriptions** — vínculo cliente/plano com ciclo de vida (active, past_due, canceled)
**payments** — pagamentos por assinatura (paid, late, failed, pending)
**support_tickets** — tickets de suporte com tempo de resolução
**usage_events** — eventos de uso da plataforma (login, feature_used, etc.)

### Schema `audit`

**payment_audit_log** — log automático de mudanças de status de pagamento, populado via trigger

### Schema `analytics`

- `vw_customer_revenue` — MRR atual e receita total paga por cliente
- `vw_customer_health` — Health Score (0–100) combinando uso, pagamentos e suporte
- `vw_revenue_recovery` — receita em risco (late/failed/pending) por cliente
- `vw_recovered_payments` — pagamentos recuperados (transição late/failed → paid)

---

## SQL Avançado

### Views Analíticas
- `vw_customer_revenue` — CTEs para MRR (normalizado mensal/anual) e receita acumulada
- `vw_customer_health` — Health Score ponderado (uso 40% + pagamentos 40% + suporte 20%), com `FILTER`, `CASE` e múltiplas CTEs
- `vw_revenue_recovery` — agregação com `FILTER` por status de pagamento e `HAVING`
- `vw_recovered_payments` — join com audit log para rastrear recuperação de receita

### Trigger de Auditoria
- `trg_payment_status_audit` — `AFTER UPDATE` em `core.payments`, registra automaticamente toda mudança de status em `audit.payment_audit_log`

### Constraints e Governança
- `CHECK` constraints para integridade de domínio (status, valores não-negativos, datas consistentes)
- Foreign keys com `ON DELETE CASCADE` / `RESTRICT` conforme a regra de negócio
- Índices em colunas de filtro e join frequentes

---

## Diagrama ER

![ER Diagram](docs/diagrams/er_diagram.png)

---

## Métricas Implementadas

| Métrica | Valor | Implementação |
|---|---|---|
| Clientes totais | 500 | `core.customers` |
| Clientes com receita em risco | 218 | `vw_revenue_recovery` |
| Receita total em risco | R$ 127.416,00 | `vw_revenue_recovery` |
| Health Score | 0–100 por cliente | `vw_customer_health` |
| Status de saúde | healthy / at_risk / critical | `vw_customer_health` |

### Receita em Risco por Cliente

![Revenue Recovery](docs/diagrams/revenue_recovery.png)

### Health Score por Cliente

![Customer Health](docs/diagrams/customer_health.png)

---

## Performance — EXPLAIN ANALYZE

Teste de impacto de índice na coluna `status` de `core.payments` (4.626 registros):

### Com índice (`idx_payments_status`)

![Explain with index](docs/diagrams/explain_with_index.png)

Bitmap Index Scan — Execution Time: **5.501 ms**

### Sem índice (Seq Scan)

![Explain without index](docs/diagrams/explain_without_index.png)

Seq Scan — Execution Time: **2.428 ms**

**Conclusão:** com o volume atual (4.6k registros), o planner do PostgreSQL corretamente prefere Seq Scan — o overhead de acessar o índice e depois a heap (Bitmap Heap Scan) supera o custo de varrer a tabela inteira, que cabe em poucos blocos. Índices em colunas de baixa cardinalidade só compensam a partir de volumes onde o Seq Scan se torna proporcionalmente mais caro. O índice foi mantido no schema para volumes maiores e para suportar joins/filtros combinados usados pelas views analíticas.

---

## Volume de Dados

| Tabela | Registros |
|---|---|
| core.customers | 500 |
| core.subscriptions | 500 |
| core.payments | 4.626 |
| core.support_tickets | 9.790 |
| core.usage_events | 133.850 |

Dados gerados via `data_generator/` com seed fixo (`RANDOM_SEED = 42`), garantindo reprodutibilidade.

---

## Testes Automatizados

29 testes pytest cobrindo:

- **Schema** — existência de schemas, tabelas, views, trigger, colunas esperadas
- **Qualidade de dados** — integridade referencial, consistência de status/datas, ausência de inconsistências
- **Views** — ranges válidos (health_score 0-100), valores não-negativos, consistência entre view e dados brutos
- **Trigger** — validação funcional da auditoria de mudança de status (com rollback automático)
29 passed in 0.23s

---

## CI/CD Pipeline

![CI/CD](docs/diagrams/github_actions.png)

GitHub Actions executado em todo push/PR para `main`:

1. Sobe PostgreSQL 18 como serviço (container efêmero)
2. Aplica schema, tabelas, views e trigger (`01` a `05`)
3. Instala dependências Python
4. Gera e carrega dados sintéticos (500 clientes)
5. Executa os 29 testes pytest

**Status:** CI passing ✅

---

## Ambiente de Desenvolvimento

![VS Code](docs/diagrams/vscode_structure.png)

---

## Como Reproduzir

### Pré-requisitos
- Docker Desktop
- Python 3.x
- DBeaver (opcional)

### 1. Clonar repositório

```bash
git clone https://github.com/rodrigodesouza7/customer-revenue-recovery-platform.git
cd customer-revenue-recovery-platform
```

### 2. Subir o ambiente

```bash
docker compose up -d
```

### 3. Aplicar o schema

```bash
docker exec -i crrp_postgres psql -U postgres -d customer_revenue_recovery < sql/01_schema.sql
docker exec -i crrp_postgres psql -U postgres -d customer_revenue_recovery < sql/02_tables.sql
docker exec -i crrp_postgres psql -U postgres -d customer_revenue_recovery < sql/04_views.sql
docker exec -i crrp_postgres psql -U postgres -d customer_revenue_recovery < sql/05_audit_trigger.sql
```

### 4. Gerar e carregar dados sintéticos

```bash
cd data_generator
pip install -r requirements.txt
ENV_FILE=.env.docker python3 generate_data.py
ENV_FILE=.env.docker python3 db_loader.py
cd ..
```

### 5. Executar os testes

```bash
pip install -r tests/requirements.txt
ENV_FILE=.env.docker pytest tests/ -v
```

---

## Estrutura do Projeto
customer-revenue-recovery-platform/

├── .github/

│   └── workflows/

│       └── ci.yml

├── data_generator/

│   ├── config.py

│   ├── generate_data.py

│   ├── db_loader.py

│   ├── requirements.txt

│   └── output/

├── diagrams/

│   ├── er_diagram.png

│   ├── revenue_recovery.png

│   ├── customer_health.png

│   ├── explain_with_index.png

│   ├── explain_without_index.png

│   ├── github_actions.png

│   └── vscode_structure.png

├── docs/

│   └── project_report.md

├── sql/

│   ├── 01_schema.sql

│   ├── 02_tables.sql

│   ├── 04_views.sql

│   ├── 05_audit_trigger.sql

│   └── 06_test_queries.sql

├── tests/

│   ├── conftest.py

│   ├── test_schema.py

│   ├── test_data_quality.py

│   ├── test_views.py

│   └── requirements.txt

├── docker-compose.yml

├── .env.docker

└── README.md

---

## Aprendizados Técnicos

### Banco de Dados Relacional
- Modelagem com separação de schemas por responsabilidade (core/analytics/audit)
- SQL avançado — CTEs, window functions implícitas via `FILTER`, views analíticas em camadas
- Trigger de auditoria com `AFTER UPDATE` para governança automática
- `EXPLAIN ANALYZE` para análise de plano de execução e decisão consciente sobre indexação

### Engenharia de Dados
- Geração de dados sintéticos reprodutíveis (seed fixo) respeitando regras de negócio e constraints
- Carga em massa via `COPY` com `psycopg3`
- Pipeline reproduzível: geração → truncate → load → reset de sequences

### DevOps
- Ambiente containerizado com Docker Compose, espelhando o ambiente de CI
- CI/CD com GitHub Actions: schema, dados e testes validados a cada push
- 29 testes automatizados cobrindo schema, qualidade de dados, regras de negócio e trigger

---

## Status do Projeto

✅ Modelagem / DDL completo
✅ Views analíticas (receita, health score, revenue recovery, recuperação)
✅ Trigger de auditoria funcional
✅ Geração de dados sintéticos (500 clientes, 134k+ eventos)
✅ Testes automatizados — 29/29 passing
✅ Docker Compose — ambiente replicável
✅ CI/CD — GitHub Actions verde
✅ EXPLAIN ANALYZE documentado
✅ Documentação completa

---

## Sobre o Autor

Rodrigo de Souza Silva
Profissional de TI com formação em Sistemas de Informação e pós-graduação em Data Science, Machine Learning e IA.

- LinkedIn: [linkedin.com/in/rodrigodesouzasilva](https://linkedin.com/in/rodrigodesouzasilva)
- GitHub: [github.com/rodrigodesouza7](https://github.com/rodrigodesouza7)

---

## Licença

MIT License — Projeto de portfólio profissional
