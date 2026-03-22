# Aula 3 — Views, Procedures e Funções

## Views

Uma **View** é uma consulta SQL salva com um nome. Funciona como uma tabela virtual.

```sql
CREATE VIEW vw_pedidos_pagos AS
SELECT * FROM pedidos WHERE status = 'pago';

-- Usar como se fosse uma tabela
SELECT * FROM vw_pedidos_pagos;
```

### Quando usar Views?

- Esconder complexidade de queries longas
- Controlar o que cada usuário/time pode ver
- Reutilizar lógica de negócio sem duplicar código
- Criar camadas de dados (raw → staging → marts)

### View vs Tabela

| | View | Tabela |
|--|------|--------|
| Armazena dados? | Não (executa na consulta) | Sim |
| Sempre atualizada? | Sim | Só quando você faz INSERT/UPDATE |
| Performance | Depende da query | Mais rápido para dados fixos |

### View Materializada (PostgreSQL)

Salva o resultado fisicamente. Precisa ser atualizada manualmente.

```sql
CREATE MATERIALIZED VIEW mv_resumo AS
SELECT estado, COUNT(*) FROM clientes GROUP BY estado;

-- Atualizar os dados
REFRESH MATERIALIZED VIEW mv_resumo;
```

---

## Stored Procedures

Uma **Procedure** é um bloco de código SQL reutilizável, executado por nome. Pode ter lógica (IF, LOOP), executar múltiplas operações e não precisa retornar valor.

```sql
CREATE OR REPLACE PROCEDURE cancelar_pedido(p_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE pedidos SET status = 'cancelado' WHERE id = p_id;
    RAISE NOTICE 'Pedido % cancelado.', p_id;
END;
$$;

-- Executar
CALL cancelar_pedido(5);
```

### Quando usar Procedures?

- Operações de manutenção e limpeza de dados
- Processos ETL dentro do banco
- Regras de negócio complexas que afetam múltiplas tabelas

---

## Funções (Functions)

**Funções** são similares a procedures, mas **sempre retornam um valor** e podem ser usadas dentro de um SELECT.

```sql
CREATE OR REPLACE FUNCTION calcular_desconto(preco NUMERIC, pct NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN preco - (preco * pct / 100);
END;
$$ LANGUAGE plpgsql;

-- Usar no SELECT
SELECT nome, preco, calcular_desconto(preco, 10) AS preco_com_desconto
FROM produtos;
```

### Procedure vs Function

| | Procedure | Function |
|--|-----------|----------|
| Retorna valor? | Não obrigatório | Sim, sempre |
| Usar no SELECT? | Não | Sim |
| Transações? | Pode controlar | Não pode controlar |
| Chamada | `CALL` | `SELECT` |

---

## Resumo da aula

- Views simplificam e reutilizam queries
- Views materializadas guardam dados físicos (mais performance)
- Procedures encapsulam lógica e operações complexas
- Functions retornam valor e podem ser usadas em SELECT
