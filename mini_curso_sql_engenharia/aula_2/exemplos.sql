-- =============================================================
-- AULA 2: SQL para Engenharia de Dados
-- Pré-requisito: execute banco.sql antes
-- =============================================================


-- -------------------------------------------------------------
-- 1. SELECT básico com filtros
-- -------------------------------------------------------------

-- Todos os pedidos pagos
SELECT * FROM pedidos WHERE status = 'pago';

-- Pedidos acima de R$500 e pagos
SELECT * FROM pedidos
WHERE status = 'pago'
  AND total > 500;

-- Clientes de SP ou RJ
SELECT nome, cidade, estado
FROM clientes
WHERE estado IN ('SP', 'RJ');

-- Produtos entre R$100 e R$500
SELECT nome, preco
FROM produtos
WHERE preco BETWEEN 100 AND 500
ORDER BY preco ASC;

-- Clientes cujo nome começa com 'A'
SELECT * FROM clientes WHERE nome LIKE 'A%';


-- -------------------------------------------------------------
-- 2. GROUP BY e funções de agregação
-- -------------------------------------------------------------

-- Quantos clientes por estado?
SELECT estado, COUNT(*) AS total_clientes
FROM clientes
GROUP BY estado
ORDER BY total_clientes DESC;

-- Total faturado por status de pedido
SELECT status,
       COUNT(*)       AS quantidade,
       SUM(total)     AS faturamento,
       AVG(total)     AS ticket_medio,
       MIN(total)     AS menor_pedido,
       MAX(total)     AS maior_pedido
FROM pedidos
GROUP BY status;

-- HAVING: estados com mais de 1 cliente
SELECT estado, COUNT(*) AS total
FROM clientes
GROUP BY estado
HAVING COUNT(*) > 1;


-- -------------------------------------------------------------
-- 3. CTE — Common Table Expression
-- -------------------------------------------------------------

-- Sem CTE (difícil de ler)
SELECT cliente_id, SUM(total)
FROM (SELECT * FROM pedidos WHERE status = 'pago') sub
GROUP BY cliente_id;


-- Com CTE (muito mais legível)
WITH pedidos_pagos AS (
    SELECT * FROM pedidos WHERE status = 'pago'
)
SELECT cliente_id, SUM(total) AS total_gasto
FROM pedidos_pagos
GROUP BY cliente_id
ORDER BY total_gasto DESC;


-- CTE encadeada: clientes com gasto acima da média
WITH pedidos_pagos AS (
    SELECT cliente_id, SUM(total) AS total_gasto
    FROM pedidos
    WHERE status = 'pago'
    GROUP BY cliente_id
),
media_gasto AS (
    SELECT AVG(total_gasto) AS media FROM pedidos_pagos
)
SELECT p.cliente_id, p.total_gasto, m.media
FROM pedidos_pagos p, media_gasto m
WHERE p.total_gasto > m.media
ORDER BY p.total_gasto DESC;


-- -------------------------------------------------------------
-- 4. CTAS — CREATE TABLE AS SELECT
-- (muito usado em pipelines e Data Warehouses)
-- -------------------------------------------------------------

-- Criar tabela de pedidos pagos (staging)
DROP TABLE IF EXISTS stg_pedidos_pagos;

CREATE TABLE stg_pedidos_pagos AS
SELECT
    p.id           AS pedido_id,
    p.cliente_id,
    p.produto_id,
    p.total,
    p.criado_em
FROM pedidos p
WHERE p.status = 'pago';

-- Verificar
SELECT * FROM stg_pedidos_pagos LIMIT 5;


-- -------------------------------------------------------------
-- 5. INSERT com SELECT
-- (mover dados de uma tabela para outra)
-- -------------------------------------------------------------

-- Criar tabela de destino
DROP TABLE IF EXISTS pedidos_cancelados_historico;

CREATE TABLE pedidos_cancelados_historico (
    pedido_id   INT,
    cliente_id  INT,
    total       NUMERIC(10,2),
    cancelado_em DATE
);

-- Inserir dados via SELECT
INSERT INTO pedidos_cancelados_historico (pedido_id, cliente_id, total, cancelado_em)
SELECT id, cliente_id, total, criado_em
FROM pedidos
WHERE status = 'cancelado';

-- Verificar
SELECT * FROM pedidos_cancelados_historico;


-- -------------------------------------------------------------
-- 6. Limpeza
-- -------------------------------------------------------------
DROP TABLE IF EXISTS stg_pedidos_pagos;
DROP TABLE IF EXISTS pedidos_cancelados_historico;
