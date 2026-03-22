# Aula 2 — SQL para Engenharia de Dados

## SELECT e suas cláusulas

O `SELECT` é o comando mais usado. A ordem das cláusulas importa:

```sql
SELECT   colunas
FROM     tabela
WHERE    filtro de linhas
GROUP BY agrupamento
HAVING   filtro de grupos
ORDER BY ordenação
LIMIT    limite de linhas
```

---

## WHERE — filtrando linhas

Filtra antes de agrupar. Operadores mais usados:

| Operador | Exemplo |
|----------|---------|
| `=` | `WHERE estado = 'SP'` |
| `<>` ou `!=` | `WHERE status <> 'cancelado'` |
| `>`, `<`, `>=`, `<=` | `WHERE total > 500` |
| `BETWEEN` | `WHERE total BETWEEN 100 AND 500` |
| `IN` | `WHERE estado IN ('SP', 'RJ')` |
| `LIKE` | `WHERE nome LIKE 'Ana%'` |
| `IS NULL` | `WHERE cidade IS NULL` |
| `AND`, `OR`, `NOT` | combinações lógicas |

---

## GROUP BY — agrupando dados

Agrupa linhas para aplicar funções de agregação:

```sql
SELECT estado, COUNT(*) AS total_clientes
FROM clientes
GROUP BY estado;
```

Funções de agregação mais usadas:
- `COUNT(*)` — conta linhas
- `SUM(coluna)` — soma
- `AVG(coluna)` — média
- `MIN(coluna)` / `MAX(coluna)` — mínimo e máximo

**HAVING** filtra *após* o agrupamento (diferente do WHERE):

```sql
SELECT estado, COUNT(*) AS total
FROM clientes
GROUP BY estado
HAVING COUNT(*) > 1;
```

---

## CTE — Common Table Expression

CTE é uma consulta temporária nomeada. Torna o SQL mais legível e reutilizável.

```sql
WITH pedidos_pagos AS (
    SELECT * FROM pedidos WHERE status = 'pago'
)
SELECT cliente_id, SUM(total)
FROM pedidos_pagos
GROUP BY cliente_id;
```

**Por que usar CTE em engenharia de dados?**
- Código mais legível que subquery aninhada
- Facilita depuração (você testa cada bloco separado)
- Base para queries de transformação em pipelines

---

## CTAS — CREATE TABLE AS SELECT

Cria uma tabela nova a partir de um SELECT. Muito usado em Data Warehouses e pipelines.

```sql
CREATE TABLE pedidos_pagos AS
SELECT * FROM pedidos WHERE status = 'pago';
```

Útil para:
- Criar tabelas de staging em pipelines
- Materializar consultas pesadas
- Criar snapshots de dados

---

## INSERT com SELECT

Insere dados de uma consulta em outra tabela:

```sql
INSERT INTO tabela_destino (col1, col2)
SELECT col1, col2
FROM tabela_origem
WHERE condicao;
```

---

## Resumo da aula

- `SELECT` + cláusulas = base de qualquer análise
- `WHERE` filtra linhas, `HAVING` filtra grupos
- `GROUP BY` + funções de agregação = análises resumidas
- CTE organiza queries complexas em blocos legíveis
- CTAS e INSERT/SELECT são a base de pipelines de dados
