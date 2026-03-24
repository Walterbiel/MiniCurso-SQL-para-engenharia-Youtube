-- ============================================
-- EXERCÍCIOS INTERMEDIÁRIOS — Mini Curso SQL para Engenharia de Dados
-- Arquivo: exercicios/intermediario.sql
-- ⏱️  Tempo estimado: 30-45 minutos
-- 📍 Nível: Combinação de 2+ conceitos das aulas
-- ============================================
-- Contexto: Você é engenheiro de dados na "TechVarejo".
-- Os exercícios combinam SELECT, JOINs, GROUP BY, CASE WHEN, CTEs e Window Functions.

USE loja_db;
GO

-- ─────────────────────────────────────────
-- EXERCÍCIO 1 — JOIN + CASE WHEN + GROUP BY
-- Baseado em: Aulas 2 e 3
-- ─────────────────────────────────────────
-- Contexto: O time de finanças quer um resumo de receita por cliente
--           separando receita confirmada (entregue) de receita em risco (outros status).
-- Retorne:
--   - nome do cliente
--   - receita confirmada (pedidos entregues)
--   - receita em risco (pedidos não cancelados e não entregues)
--   - percentual da receita confirmada sobre o total
-- Ordene por receita confirmada decrescente.
-- Dica: use CASE WHEN dentro do SUM

-- Sua query aqui:


-- GABARITO:
/*
SELECT
    c.nome  AS cliente,
    SUM(CASE WHEN p.status = 'entregue'
             THEN p.valor_total ELSE 0 END)                           AS receita_confirmada,
    SUM(CASE WHEN p.status NOT IN ('entregue', 'cancelado')
             THEN p.valor_total ELSE 0 END)                           AS receita_em_risco,
    CAST(
        SUM(CASE WHEN p.status = 'entregue' THEN p.valor_total ELSE 0 END)
        * 100.0
        / NULLIF(SUM(p.valor_total), 0)
    AS DECIMAL(5,1))                                                  AS pct_confirmado
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status != 'cancelado'
GROUP BY c.nome
ORDER BY receita_confirmada DESC;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 2 — CTE + Window Function
-- Baseado em: Aulas 2 e 3
-- ─────────────────────────────────────────
-- Contexto: O time de produto quer saber, dentro de cada categoria,
--           qual produto gerou mais receita e qual ocupa o último lugar.
-- Retorne: categoria, produto, receita total e ranking dentro da categoria.
-- Mostre apenas o 1º e o último colocado de cada categoria.
-- Dica: use CTE + RANK() OVER (PARTITION BY ...)

-- Sua query aqui:


-- GABARITO:
/*
WITH receita_produto AS (
    SELECT
        cat.nome                               AS categoria,
        pr.nome                                AS produto,
        SUM(i.quantidade * i.preco_unitario)   AS receita,
        RANK() OVER (
            PARTITION BY cat.id_categoria
            ORDER BY SUM(i.quantidade * i.preco_unitario) DESC
        ) AS ranking_asc,
        RANK() OVER (
            PARTITION BY cat.id_categoria
            ORDER BY SUM(i.quantidade * i.preco_unitario) ASC
        ) AS ranking_desc
    FROM itens_pedido AS i
    JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
    JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
    GROUP BY cat.id_categoria, cat.nome, pr.nome
)
SELECT categoria, produto, receita,
       CASE WHEN ranking_asc  = 1 THEN '🥇 Melhor'
            WHEN ranking_desc = 1 THEN '🔻 Pior'
       END AS posicao
FROM receita_produto
WHERE ranking_asc = 1 OR ranking_desc = 1
ORDER BY categoria, ranking_asc;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 3 — Subquery + agregação + filtro
-- Baseado em: Aula 2, Blocos 5 e 6
-- ─────────────────────────────────────────
-- Contexto: O time de fidelização quer identificar "clientes acima da média".
-- Encontre clientes cujo ticket médio (valor médio por pedido) é maior que
-- o ticket médio geral de todos os pedidos entregues.
-- Retorne: nome, quantidade de pedidos, ticket médio do cliente.
-- Dica: use subquery para calcular a média geral

-- Sua query aqui:


-- GABARITO:
/*
SELECT
    c.nome             AS cliente,
    COUNT(p.id_pedido) AS total_pedidos,
    AVG(p.valor_total) AS ticket_medio_cliente
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'
GROUP BY c.nome
HAVING AVG(p.valor_total) > (
    SELECT AVG(valor_total)
    FROM pedidos
    WHERE status = 'entregue'
)
ORDER BY ticket_medio_cliente DESC;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 4 — VIEW + query analítica
-- Baseado em: Aulas 2 e 3
-- ─────────────────────────────────────────
-- Contexto: Crie uma VIEW chamada vw_itens_detalhados que junte
--           itens_pedido + produtos + categorias + pedidos.
-- A VIEW deve retornar:
--   id_pedido, data_pedido, status, produto, categoria,
--   quantidade, preco_unitario, subtotal (quantidade * preco_unitario)
-- Depois, use a VIEW para responder: qual o produto mais vendido em valor em março/2024?

-- Sua query aqui:


-- GABARITO:
/*
-- Cria a view
IF OBJECT_ID('vw_itens_detalhados', 'V') IS NOT NULL DROP VIEW vw_itens_detalhados;
GO

CREATE VIEW vw_itens_detalhados AS
SELECT
    p.id_pedido,
    p.data_pedido,
    p.status,
    pr.nome                              AS produto,
    cat.nome                             AS categoria,
    i.quantidade,
    i.preco_unitario,
    i.quantidade * i.preco_unitario      AS subtotal
FROM itens_pedido AS i
JOIN pedidos      AS p   ON i.id_pedido    = p.id_pedido
JOIN produtos     AS pr  ON i.id_produto   = pr.id_produto
JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria;
GO

-- Consulta usando a view
SELECT TOP 1
    produto,
    SUM(subtotal) AS receita_marco
FROM vw_itens_detalhados
WHERE MONTH(data_pedido) = 3
  AND YEAR(data_pedido)  = 2024
  AND status != 'cancelado'
GROUP BY produto
ORDER BY receita_marco DESC;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 5 — Window Function acumulada
-- Baseado em: Aula 2, Bloco 7
-- ─────────────────────────────────────────
-- Contexto: O CFO quer um relatório de receita acumulada mês a mês em 2024.
-- Retorne: mês, receita do mês, receita acumulada até aquele mês.
-- Considere apenas pedidos entregues.

-- Sua query aqui:


-- GABARITO:
/*
WITH receita_mensal AS (
    SELECT
        MONTH(data_pedido)  AS mes,
        SUM(valor_total)    AS receita_mes
    FROM pedidos
    WHERE status = 'entregue'
      AND YEAR(data_pedido) = 2024
    GROUP BY MONTH(data_pedido)
)
SELECT
    mes,
    receita_mes,
    SUM(receita_mes) OVER (ORDER BY mes ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        AS receita_acumulada
FROM receita_mensal
ORDER BY mes;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 6 — ROW_NUMBER + primeiro pedido por cliente
-- Baseado em: Aula 2, Bloco 7
-- ─────────────────────────────────────────
-- Contexto: O time de CRM quer saber qual foi o primeiro pedido de cada cliente
--           e quanto ele valeu (para analisar o comportamento de primeiros pedidos).
-- Retorne: nome do cliente, id do primeiro pedido, data e valor_total.
-- Dica: use ROW_NUMBER() OVER (PARTITION BY id_cliente ORDER BY data_pedido)
--       e filtre onde numero = 1

-- Sua query aqui:


-- GABARITO:
/*
WITH pedidos_numerados AS (
    SELECT
        c.nome         AS cliente,
        p.id_pedido,
        p.data_pedido,
        p.valor_total,
        ROW_NUMBER() OVER (
            PARTITION BY p.id_cliente
            ORDER BY p.data_pedido
        ) AS numero
    FROM pedidos  AS p
    JOIN clientes AS c ON p.id_cliente = c.id_cliente
    WHERE p.status != 'cancelado'
)
SELECT cliente, id_pedido, data_pedido, valor_total
FROM pedidos_numerados
WHERE numero = 1
ORDER BY data_pedido;
*/
GO
