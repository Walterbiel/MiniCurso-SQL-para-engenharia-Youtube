# AULA 2 — SQL como Motor de Transformação de Dados
> Mini Curso SQL para Engenharia de Dados · 5 aulas · SQL Server

---

## Slide 1 — Capa

```
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   AULA 2                                             ║
║   SQL como Motor de Transformação de Dados           ║
║                                                      ║
║   Mini Curso SQL para Engenharia de Dados            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
```

---

## Slide 2 — O que você vai aprender

**Nesta aula:**

1. SELECT bem estruturado — código de produção vs improviso
2. Ordem real de execução do SQL
3. Filtros eficientes com WHERE
4. CASE WHEN — lógica de negócio no SQL
5. JOINs — combinando tabelas
6. GROUP BY e HAVING — agregação e filtro de grupos
7. CTE — consultas em etapas com nome
8. Window Functions — análise sem perder o detalhe

---

## Slide 3 — Ordem de Execução do SQL

**Você escreve nessa ordem. O banco executa em outra.**

| Passo | Cláusula | O que faz |
|-------|----------|-----------|
| 1 | `FROM` + `JOIN` | define de onde vêm os dados |
| 2 | `WHERE` | filtra linhas individuais |
| 3 | `GROUP BY` | agrupa as linhas restantes |
| 4 | `HAVING` | filtra os grupos |
| 5 | `SELECT` | calcula colunas e alias |
| 6 | `ORDER BY` | ordena o resultado |
| 7 | `TOP / LIMIT` | limita a quantidade |

**Por que isso importa:**
- Alias criados no `SELECT` não existem ainda no `WHERE`
- Funções de agregação (`SUM`, `COUNT`) não podem ser usadas no `WHERE`
- `HAVING` é o filtro de grupos — não de linhas

---

## Slide 4 — CASE WHEN

**Regra de negócio diretamente no SQL.**

```sql
SELECT
    nome,
    preco,
    CASE
        WHEN preco < 50   THEN 'Econômico'
        WHEN preco < 200  THEN 'Básico'
        WHEN preco < 1000 THEN 'Intermediário'
        ELSE                   'Premium'
    END AS faixa_preco
FROM produtos;
```

**Usos principais:**

| Padrão | Aplicação |
|--------|-----------|
| Classificação por faixa | categorizar valores numéricos |
| Tradução de status | transformar código em rótulo legível |
| Pivot manual | transformar valores de linhas em colunas |

> Em um pipeline ELT, `CASE WHEN` é a camada **T** — de Transformação.

---

## Slide 5 — JOINs

**Combina linhas de duas tabelas com base em uma condição.**

| Tipo | Retorna |
|------|---------|
| `INNER JOIN` | só linhas com correspondência nos dois lados |
| `LEFT JOIN` | todas da esquerda + correspondência da direita (NULL onde não há) |
| `FULL OUTER JOIN` | todos de ambos os lados |
| `CROSS JOIN` | produto cartesiano (todas × todas) |

**Padrão clássico — "quem nunca fez X":**

```sql
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
WHERE p.id_pedido IS NULL   -- clientes sem nenhum pedido
```

> A escolha do tipo de JOIN determina **quantas linhas** o resultado vai ter.
> Errar o tipo de JOIN é uma das fontes mais comuns de dado incorreto em pipelines.

---

## Slide 6 — GROUP BY e HAVING

**GROUP BY colapsa linhas em grupos. Você troca detalhe por resumo.**

```sql
SELECT
    c.nome,
    COUNT(p.id_pedido)  AS total_pedidos,
    SUM(p.valor_total)  AS valor_total_gasto
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'       -- filtra LINHAS (antes do grupo)
GROUP BY c.id_cliente, c.nome
HAVING SUM(p.valor_total) > 1000  -- filtra GRUPOS (depois do agrupamento)
ORDER BY valor_total_gasto DESC;
```

| Cláusula | Quando usar |
|----------|-------------|
| `WHERE` | filtrar linhas antes de agrupar |
| `HAVING` | filtrar grupos depois de agrupar |

> `WHERE` não aceita funções de agregação (`SUM`, `COUNT`).
> Para isso, use `HAVING`.

---

## Slide 7 — CTE e Window Functions

**CTE — Common Table Expression:**
Consulta nomeada definida com `WITH`. Cada CTE é um passo do pipeline, com nome descritivo e fácil de testar.

```sql
WITH resumo_cliente AS (
    SELECT id_cliente, SUM(valor_total) AS total
    FROM pedidos
    GROUP BY id_cliente
)
SELECT * FROM resumo_cliente WHERE total > 1000;
```

**Window Function:**
Calcula uma agregação por linha — **sem colapsar** o resultado como o GROUP BY faz.

```sql
ROW_NUMBER() OVER (PARTITION BY id_cliente ORDER BY data_pedido DESC)
SUM(valor)   OVER (ORDER BY data_pedido ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
LAG(valor)   OVER (ORDER BY data_pedido)  -- valor da linha anterior
```

| Função | Uso |
|--------|-----|
| `ROW_NUMBER` | numerar e deduplicar (pegar o registro mais recente) |
| `RANK` / `DENSE_RANK` | ranking com tratamento de empates |
| `SUM OVER` | acumulado e média móvel |
| `LAG` / `LEAD` | variação entre períodos |

---

## Slide 8 — Resumo

```
SQL de Transformação
│
├── SELECT estruturado  → código legível é código auditável
├── Ordem de execução   → FROM → WHERE → GROUP BY → HAVING → SELECT
├── CASE WHEN           → lógica de negócio dentro do SQL
├── JOINs               → combinação de tabelas (atenção ao tipo)
├── GROUP BY / HAVING   → agregação de dados
├── CTE                 → pipelines em etapas com nome
└── Window Functions    → agregação sem perder o detalhe da linha
```

> **Próxima aula:** organizar essa lógica dentro do banco —
> Views, Stored Procedures e Funções.
