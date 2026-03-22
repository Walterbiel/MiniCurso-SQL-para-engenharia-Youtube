-- =============================================================
-- AULA 5: Data Warehouse — Fato, Dimensão, Star Schema, ETL/ELT
-- Pré-requisito: execute banco.sql antes
-- =============================================================
-- Nesta aula, vamos transformar nosso banco transacional (OLTP)
-- em um modelo dimensional simples (DW / Star Schema)
-- =============================================================


-- -------------------------------------------------------------
-- 1. CRIAR AS DIMENSÕES
-- -------------------------------------------------------------

-- dim_clientes: contexto sobre quem comprou
DROP TABLE IF EXISTS dim_clientes;

CREATE TABLE dim_clientes AS
SELECT
    id          AS id_cliente,
    nome,
    cidade,
    estado,
    criado_em   AS data_cadastro
FROM clientes;

ALTER TABLE dim_clientes ADD PRIMARY KEY (id_cliente);


-- dim_produtos: contexto sobre o que foi vendido
DROP TABLE IF EXISTS dim_produtos;

CREATE TABLE dim_produtos AS
SELECT
    id        AS id_produto,
    nome,
    categoria,
    preco
FROM produtos;

ALTER TABLE dim_produtos ADD PRIMARY KEY (id_produto);


-- dim_data: dimensão de tempo (fundamental em todo DW)
-- Em produção esta tabela tem milhares de linhas (um por dia)
DROP TABLE IF EXISTS dim_data;

CREATE TABLE dim_data AS
SELECT DISTINCT
    criado_em                                         AS data_completa,
    EXTRACT(YEAR  FROM criado_em)::INT                AS ano,
    EXTRACT(MONTH FROM criado_em)::INT                AS mes,
    EXTRACT(DAY   FROM criado_em)::INT                AS dia,
    TO_CHAR(criado_em, 'Month')                       AS nome_mes,
    EXTRACT(QUARTER FROM criado_em)::INT              AS trimestre,
    CASE EXTRACT(DOW FROM criado_em)::INT
        WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Segunda'
        WHEN 2 THEN 'Terça'
        WHEN 3 THEN 'Quarta'
        WHEN 4 THEN 'Quinta'
        WHEN 5 THEN 'Sexta'
        WHEN 6 THEN 'Sábado'
    END AS dia_semana
FROM pedidos;

ALTER TABLE dim_data ADD PRIMARY KEY (data_completa);

-- Ver a dimensão de data
SELECT * FROM dim_data ORDER BY data_completa;


-- -------------------------------------------------------------
-- 2. CRIAR A TABELA FATO
-- -------------------------------------------------------------

-- fato_pedidos: os eventos de venda com métricas
DROP TABLE IF EXISTS fato_pedidos;

CREATE TABLE fato_pedidos AS
SELECT
    p.id           AS id_pedido,
    p.cliente_id   AS id_cliente,
    p.produto_id   AS id_produto,
    p.criado_em    AS data_pedido,   -- FK para dim_data
    p.quantidade,
    p.total,
    p.status
FROM pedidos p;

ALTER TABLE fato_pedidos ADD PRIMARY KEY (id_pedido);

-- Ver a fato
SELECT * FROM fato_pedidos ORDER BY data_pedido;


-- -------------------------------------------------------------
-- 3. QUERIES ANALÍTICAS NO STAR SCHEMA
-- (é aqui que o DW brilha)
-- -------------------------------------------------------------

-- Faturamento total por mês e ano
SELECT
    d.ano,
    d.mes,
    d.nome_mes,
    SUM(f.total)    AS faturamento,
    COUNT(f.id_pedido) AS total_pedidos
FROM fato_pedidos f
JOIN dim_data d ON d.data_completa = f.data_pedido
WHERE f.status = 'pago'
GROUP BY d.ano, d.mes, d.nome_mes
ORDER BY d.ano, d.mes;


-- Top 3 produtos mais vendidos por faturamento
SELECT
    p.nome           AS produto,
    p.categoria,
    COUNT(f.id_pedido) AS total_vendas,
    SUM(f.total)     AS faturamento
FROM fato_pedidos f
JOIN dim_produtos p ON p.id_produto = f.id_produto
WHERE f.status = 'pago'
GROUP BY p.nome, p.categoria
ORDER BY faturamento DESC
LIMIT 3;


-- Faturamento por estado do cliente
SELECT
    c.estado,
    COUNT(DISTINCT f.id_cliente)  AS clientes_compradores,
    COUNT(f.id_pedido)            AS total_pedidos,
    SUM(f.total)                  AS faturamento
FROM fato_pedidos f
JOIN dim_clientes c ON c.id_cliente = f.id_cliente
WHERE f.status = 'pago'
GROUP BY c.estado
ORDER BY faturamento DESC;


-- Ticket médio por categoria
SELECT
    p.categoria,
    ROUND(AVG(f.total), 2) AS ticket_medio
FROM fato_pedidos f
JOIN dim_produtos p ON p.id_produto = f.id_produto
WHERE f.status = 'pago'
GROUP BY p.categoria
ORDER BY ticket_medio DESC;


-- -------------------------------------------------------------
-- 4. SIMULANDO ELT COM CTE
-- (transformação dentro do banco, estilo dbt)
-- -------------------------------------------------------------

-- Camada 1: staging (dados brutos limpos)
WITH stg_pedidos AS (
    SELECT
        id,
        cliente_id,
        produto_id,
        total,
        status,
        criado_em
    FROM pedidos
    WHERE total IS NOT NULL
),

-- Camada 2: intermediate (enriquece com dimensões)
int_pedidos AS (
    SELECT
        f.id,
        c.nome        AS cliente,
        c.estado,
        p.nome        AS produto,
        p.categoria,
        f.total,
        f.status,
        f.criado_em,
        EXTRACT(YEAR FROM f.criado_em)  AS ano,
        EXTRACT(MONTH FROM f.criado_em) AS mes
    FROM stg_pedidos f
    JOIN clientes c ON c.id = f.cliente_id
    JOIN produtos p ON p.id = f.produto_id
),

-- Camada 3: mart (agregação final para o BI)
mart_faturamento AS (
    SELECT
        ano,
        mes,
        estado,
        categoria,
        COUNT(*)      AS pedidos,
        SUM(total)    AS faturamento
    FROM int_pedidos
    WHERE status = 'pago'
    GROUP BY ano, mes, estado, categoria
)

SELECT * FROM mart_faturamento
ORDER BY ano, mes, faturamento DESC;


-- -------------------------------------------------------------
-- 5. Limpeza
-- -------------------------------------------------------------
DROP TABLE IF EXISTS dim_clientes;
DROP TABLE IF EXISTS dim_produtos;
DROP TABLE IF EXISTS dim_data;
DROP TABLE IF EXISTS fato_pedidos;
