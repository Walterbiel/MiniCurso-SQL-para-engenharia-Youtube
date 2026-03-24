-- ============================================
-- EXERCÍCIOS BÁSICOS — Mini Curso SQL para Engenharia de Dados
-- Arquivo: exercicios/basico.sql
-- ⏱️  Tempo estimado: 20-30 minutos
-- 📍 Nível: Réplica dos exemplos das aulas
-- ============================================
-- Contexto: Você trabalha como analista de dados na empresa "TechVarejo",
-- uma loja online. Use o banco loja_db para responder às questões.

USE loja_db;
GO

-- ─────────────────────────────────────────
-- EXERCÍCIO 1 — SELECT com cálculo
-- Baseado em: Aula 2, Bloco 1
-- ─────────────────────────────────────────
-- Contexto: O gestor de estoque quer saber o valor total de cada produto em estoque.
-- Escreva uma query que retorne:
--   - nome do produto
--   - preço unitário
--   - quantidade em estoque
--   - valor total em estoque (preco * estoque)
-- Ordene do maior para o menor valor total.

-- Sua query aqui:


-- GABARITO:
/*
SELECT
    nome                  AS produto,
    preco                 AS preco_unitario,
    estoque               AS qtd_em_estoque,
    preco * estoque       AS valor_em_estoque
FROM produtos
ORDER BY valor_em_estoque DESC;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 2 — WHERE com múltiplos filtros
-- Baseado em: Aula 2, Bloco 2
-- ─────────────────────────────────────────
-- Contexto: O time de marketing quer contatar clientes de SP e MG cadastrados em 2023.
-- Retorne: nome, cidade, uf e data_cadastro desses clientes.
-- Ordene por data_cadastro do mais recente ao mais antigo.

-- Sua query aqui:


-- GABARITO:
/*
SELECT
    nome,
    cidade,
    uf,
    data_cadastro
FROM clientes
WHERE uf IN ('SP', 'MG')
  AND data_cadastro BETWEEN '2023-01-01' AND '2023-12-31'
ORDER BY data_cadastro DESC;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 3 — CASE WHEN
-- Baseado em: Aula 2, Bloco 3
-- ─────────────────────────────────────────
-- Contexto: A logística precisa priorizar pedidos.
-- Crie uma coluna "prioridade" com base no status:
--   - 'enviado'   → 'URGENTE'
--   - 'aprovado'  → 'PROCESSAR'
--   - 'pendente'  → 'AGUARDAR'
--   - demais      → 'ENCERRADO'
-- Retorne: id_pedido, status, valor_total, prioridade.
-- Ordene por prioridade e depois por valor_total decrescente.

-- Sua query aqui:


-- GABARITO:
/*
SELECT
    id_pedido,
    status,
    valor_total,
    CASE status
        WHEN 'enviado'  THEN 'URGENTE'
        WHEN 'aprovado' THEN 'PROCESSAR'
        WHEN 'pendente' THEN 'AGUARDAR'
        ELSE                 'ENCERRADO'
    END AS prioridade
FROM pedidos
ORDER BY prioridade, valor_total DESC;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 4 — INNER JOIN
-- Baseado em: Aula 2, Bloco 4
-- ─────────────────────────────────────────
-- Contexto: O financeiro precisa de uma lista de pedidos entregues com o nome do cliente.
-- Retorne: id_pedido, nome do cliente, data_pedido, valor_total.
-- Somente pedidos com status 'entregue'.
-- Ordene por valor_total decrescente.

-- Sua query aqui:


-- GABARITO:
/*
SELECT
    p.id_pedido,
    c.nome          AS cliente,
    p.data_pedido,
    p.valor_total
FROM pedidos  AS p
JOIN clientes AS c ON p.id_cliente = c.id_cliente
WHERE p.status = 'entregue'
ORDER BY p.valor_total DESC;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 5 — LEFT JOIN + IS NULL
-- Baseado em: Aula 2, Bloco 4
-- ─────────────────────────────────────────
-- Contexto: O time de retenção quer ver produtos que NUNCA foram vendidos.
-- Retorne o nome dos produtos que não aparecem em nenhum item de pedido.

-- Sua query aqui:


-- GABARITO:
/*
SELECT pr.nome AS produto_sem_venda
FROM produtos      AS pr
LEFT JOIN itens_pedido AS i ON pr.id_produto = i.id_produto
WHERE i.id_item IS NULL;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 6 — GROUP BY com agregações
-- Baseado em: Aula 2, Bloco 5
-- ─────────────────────────────────────────
-- Contexto: O relatório mensal precisa mostrar receita por mês.
-- Retorne: ano, mês, total de pedidos entregues e soma de valor_total.
-- Ordene por ano e mês.

-- Sua query aqui:


-- GABARITO:
/*
SELECT
    YEAR(data_pedido)   AS ano,
    MONTH(data_pedido)  AS mes,
    COUNT(id_pedido)    AS total_pedidos,
    SUM(valor_total)    AS receita_total
FROM pedidos
WHERE status = 'entregue'
GROUP BY YEAR(data_pedido), MONTH(data_pedido)
ORDER BY ano, mes;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 7 — HAVING
-- Baseado em: Aula 2, Bloco 5
-- ─────────────────────────────────────────
-- Contexto: Queremos ver apenas categorias que geraram mais de R$ 500 em vendas.
-- Retorne: nome da categoria e receita total.
-- Considere apenas pedidos entregues.

-- Sua query aqui:


-- GABARITO:
/*
SELECT
    cat.nome             AS categoria,
    SUM(i.quantidade * i.preco_unitario) AS receita_total
FROM categorias   AS cat
JOIN produtos     AS pr ON cat.id_categoria = pr.id_categoria
JOIN itens_pedido AS i  ON pr.id_produto    = i.id_produto
JOIN pedidos      AS p  ON i.id_pedido      = p.id_pedido
WHERE p.status = 'entregue'
GROUP BY cat.nome
HAVING SUM(i.quantidade * i.preco_unitario) > 500
ORDER BY receita_total DESC;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 8 — CTE simples
-- Baseado em: Aula 2, Bloco 6
-- ─────────────────────────────────────────
-- Contexto: Usando CTE, encontre os 3 produtos mais vendidos (em quantidade total).
-- Retorne: nome do produto, categoria, total de unidades vendidas.

-- Sua query aqui:


-- GABARITO:
/*
WITH vendas_por_produto AS (
    SELECT
        pr.nome              AS produto,
        cat.nome             AS categoria,
        SUM(i.quantidade)    AS total_vendido
    FROM itens_pedido AS i
    JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
    JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
    GROUP BY pr.nome, cat.nome
)
SELECT TOP 3
    produto,
    categoria,
    total_vendido
FROM vendas_por_produto
ORDER BY total_vendido DESC;
*/
GO
