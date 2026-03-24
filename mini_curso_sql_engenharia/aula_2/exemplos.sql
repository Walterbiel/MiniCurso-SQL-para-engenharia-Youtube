-- ============================================
-- AULA 2: SQL para Engenharia de Dados
-- Arquivo: aula_2/exemplos.sql
-- ⏱️  Tempo estimado: 35 minutos
-- 📍 Posição no roteiro: Parte 2 de 5
-- ============================================
-- Objetivo: Usar SQL para modelar e transformar dados.
-- Pré-requisito: execute banco.sql antes desta aula.

USE loja_db;
GO

-- ─────────────────────────────────────────
-- BLOCO 1: SELECT bem estruturado
-- O que vamos aprender: SELECT com alias, cálculos e ordenação clara
-- ⏱️ ~4 minutos
-- ─────────────────────────────────────────

-- SELECT mal escrito — funciona, mas dificulta manutenção
SELECT nome,preco,estoque,preco*estoque FROM produtos;

-- SELECT bem escrito — legível, com alias descritivos e formatação
SELECT
    nome                        AS produto,
    preco                       AS preco_unitario,
    estoque                     AS qtd_em_estoque,
    preco * estoque             AS valor_em_estoque,
    GETDATE()                   AS data_consulta
FROM produtos
ORDER BY valor_em_estoque DESC;

-- 💡 O que acontece se mudar?
-- Troque ORDER BY DESC por ASC — o produto de menor valor em estoque fica no topo
-- Engenharia de dados: SELECT limpo = pipeline legível e auditável


-- ─────────────────────────────────────────
-- BLOCO 2: WHERE e filtros inteligentes
-- O que vamos aprender: filtrar com precisão evita processar dado desnecessário
-- ⏱️ ~4 minutos
-- ─────────────────────────────────────────

-- Filtros simples
SELECT nome, preco
FROM produtos
WHERE preco > 100;

-- Múltiplos filtros com AND / OR
SELECT nome, preco, estoque
FROM produtos
WHERE preco > 100
  AND estoque < 50;

-- IN — substitui vários OR
SELECT id_pedido, status
FROM pedidos
WHERE status IN ('pendente', 'aprovado', 'enviado');

-- BETWEEN — intervalo inclusivo
SELECT id_pedido, data_pedido, valor_total
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-03-31';

-- LIKE — busca por padrão de texto
SELECT nome, email
FROM clientes
WHERE email LIKE '%@email.com';

-- 💡 O que acontece se mudar?
-- Troque AND por OR no filtro de preco e estoque — veja que retorna muito mais linhas
-- Use NOT IN para ver pedidos que NÃO estão naqueles status


-- ─────────────────────────────────────────
-- BLOCO 3: CASE WHEN — lógica condicional
-- O que vamos aprender: transformar valores com regras de negócio dentro do SQL
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Classificação de produtos por faixa de preço
SELECT
    nome,
    preco,
    CASE
        WHEN preco < 100  THEN 'Básico'
        WHEN preco < 500  THEN 'Intermediário'
        WHEN preco < 2000 THEN 'Premium'
        ELSE                   'Ultra Premium'
    END AS faixa_preco
FROM produtos
ORDER BY preco;

-- CASE com múltiplas colunas — enriquecimento de dados
SELECT
    id_pedido,
    status,
    valor_total,
    CASE status
        WHEN 'entregue'  THEN 'Receita Confirmada'
        WHEN 'cancelado' THEN 'Receita Perdida'
        ELSE                  'Em Andamento'
    END AS classificacao_receita,
    CASE
        WHEN valor_total >= 1000 THEN 'Alto Valor'
        ELSE                          'Ticket Normal'
    END AS segmento_valor
FROM pedidos;

-- 💡 O que acontece se mudar?
-- Adicione mais um WHEN para pedidos entre 500 e 999 como 'Médio Valor'


-- ─────────────────────────────────────────
-- BLOCO 4: JOINs — combinando tabelas
-- O que vamos aprender: INNER, LEFT, RIGHT e FULL JOIN têm comportamentos distintos
-- ⏱️ ~8 minutos
-- ─────────────────────────────────────────

-- INNER JOIN — só linhas que existem nos dois lados
-- Resultado: apenas clientes que fizeram pedidos
SELECT
    c.nome          AS cliente,
    p.id_pedido,
    p.data_pedido,
    p.valor_total
FROM clientes AS c
INNER JOIN pedidos AS p ON c.id_cliente = p.id_cliente;

-- LEFT JOIN — todos da esquerda, mesmo sem correspondência na direita
-- Resultado: todos os clientes, com NULL onde não há pedido
SELECT
    c.nome          AS cliente,
    p.id_pedido,
    p.status
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente;

-- Filtrando LEFT JOIN: quais clientes NUNCA fizeram pedido?
SELECT c.nome AS cliente_sem_pedido
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
WHERE p.id_pedido IS NULL;

-- JOIN múltiplo — atravessa três tabelas
SELECT
    c.nome           AS cliente,
    pr.nome          AS produto,
    i.quantidade,
    i.preco_unitario,
    i.quantidade * i.preco_unitario AS subtotal
FROM clientes     AS c
JOIN pedidos      AS p  ON c.id_cliente  = p.id_cliente
JOIN itens_pedido AS i  ON p.id_pedido   = i.id_pedido
JOIN produtos     AS pr ON i.id_produto  = pr.id_produto
WHERE p.status = 'entregue'
ORDER BY subtotal DESC;

-- 💡 O que acontece se mudar?
-- Troque INNER JOIN por LEFT JOIN no primeiro exemplo
-- No join múltiplo, remova o WHERE e veja todos os pedidos, incluindo cancelados


-- ─────────────────────────────────────────
-- BLOCO 5: GROUP BY e agregações
-- O que vamos aprender: resumir dados por dimensão — base de qualquer relatório
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Quanto cada cliente gastou no total?
SELECT
    c.nome             AS cliente,
    COUNT(p.id_pedido) AS total_pedidos,
    SUM(p.valor_total) AS valor_total_gasto,
    AVG(p.valor_total) AS ticket_medio,
    MAX(p.valor_total) AS maior_pedido
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'
GROUP BY c.nome
ORDER BY valor_total_gasto DESC;

-- Vendas por categoria de produto
SELECT
    cat.nome             AS categoria,
    COUNT(DISTINCT p.id_pedido)  AS pedidos_com_item,
    SUM(i.quantidade)            AS itens_vendidos,
    SUM(i.quantidade * i.preco_unitario) AS receita_total
FROM categorias   AS cat
JOIN produtos     AS pr ON cat.id_categoria = pr.id_categoria
JOIN itens_pedido AS i  ON pr.id_produto    = i.id_produto
JOIN pedidos      AS p  ON i.id_pedido      = p.id_pedido
WHERE p.status != 'cancelado'
GROUP BY cat.nome
ORDER BY receita_total DESC;

-- HAVING — filtro aplicado DEPOIS do GROUP BY (diferente do WHERE)
-- Quais clientes gastaram mais de R$ 1.000?
SELECT
    c.nome             AS cliente,
    SUM(p.valor_total) AS total_gasto
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'
GROUP BY c.nome
HAVING SUM(p.valor_total) > 1000
ORDER BY total_gasto DESC;

-- 💡 O que acontece se mudar?
-- Tente colocar o filtro HAVING no WHERE — o banco retorna erro
-- WHERE roda ANTES do agrupamento; HAVING roda DEPOIS


-- ─────────────────────────────────────────
-- BLOCO 6: Subquery e CTE
-- O que vamos aprender: organizar consultas complexas em etapas legíveis
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Subquery inline — quais produtos custam mais que a média?
SELECT nome, preco
FROM produtos
WHERE preco > (SELECT AVG(preco) FROM produtos)
ORDER BY preco;

-- Subquery no FROM — total de itens por pedido como uma "tabela temporária"
SELECT
    p.id_pedido,
    p.status,
    resumo.total_itens,
    resumo.valor_calculado
FROM pedidos AS p
JOIN (
    SELECT
        id_pedido,
        SUM(quantidade)                        AS total_itens,
        SUM(quantidade * preco_unitario)       AS valor_calculado
    FROM itens_pedido
    GROUP BY id_pedido
) AS resumo ON p.id_pedido = resumo.id_pedido;

-- CTE (Common Table Expression) — mesma lógica, mais legível
WITH resumo_pedidos AS (
    SELECT
        id_pedido,
        SUM(quantidade)                  AS total_itens,
        SUM(quantidade * preco_unitario) AS valor_calculado
    FROM itens_pedido
    GROUP BY id_pedido
)
SELECT
    p.id_pedido,
    p.status,
    r.total_itens,
    r.valor_calculado
FROM pedidos          AS p
JOIN resumo_pedidos   AS r ON p.id_pedido = r.id_pedido
ORDER BY r.valor_calculado DESC;

-- 💡 O que acontece se mudar?
-- Adicione uma segunda CTE para filtrar só pedidos entregues:
-- WITH resumo_pedidos AS (...),
--      pedidos_entregues AS (SELECT ... FROM pedidos WHERE status = 'entregue')
-- SELECT ... FROM pedidos_entregues JOIN resumo_pedidos ...


-- ─────────────────────────────────────────
-- BLOCO 7: Window Functions — análise sem perder detalhes
-- O que vamos aprender: agregar e rankear mantendo todas as linhas
-- ⏱️ ~4 minutos
-- ─────────────────────────────────────────

-- ROW_NUMBER — ranking de pedidos por cliente
SELECT
    c.nome             AS cliente,
    p.id_pedido,
    p.data_pedido,
    p.valor_total,
    ROW_NUMBER() OVER (
        PARTITION BY p.id_cliente   -- reinicia o contador por cliente
        ORDER BY p.data_pedido      -- ordena do mais antigo ao mais recente
    ) AS numero_pedido_do_cliente
FROM pedidos  AS p
JOIN clientes AS c ON p.id_cliente = c.id_cliente
ORDER BY c.nome, p.data_pedido;

-- SUM OVER — total acumulado de receita ao longo do tempo
SELECT
    data_pedido,
    valor_total,
    SUM(valor_total) OVER (
        ORDER BY data_pedido
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS receita_acumulada
FROM pedidos
WHERE status = 'entregue'
ORDER BY data_pedido;

-- RANK — qual produto vendeu mais (em valor) dentro de cada categoria?
WITH vendas_produto AS (
    SELECT
        pr.id_categoria,
        cat.nome                              AS categoria,
        pr.nome                               AS produto,
        SUM(i.quantidade * i.preco_unitario)  AS receita
    FROM itens_pedido AS i
    JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
    JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
    GROUP BY pr.id_categoria, cat.nome, pr.nome
)
SELECT
    categoria,
    produto,
    receita,
    RANK() OVER (PARTITION BY id_categoria ORDER BY receita DESC) AS ranking_categoria
FROM vendas_produto
ORDER BY categoria, ranking_categoria;

-- 💡 O que acontece se mudar?
-- Troque RANK() por DENSE_RANK() — veja a diferença quando há empate
-- Troque ROW_NUMBER() por NTILE(3) para dividir pedidos em 3 grupos iguais
GO
