-- ============================================
-- EXERCÍCIOS AVANÇADOS — Mini Curso SQL para Engenharia de Dados
-- Arquivo: exercicios/avancado.sql
-- ⏱️  Tempo estimado: 45-60 minutos
-- 📍 Nível: Casos de uso reais de engenharia de dados
-- ============================================
-- Contexto: Você é engenheiro de dados sênior na "TechVarejo".
-- Os desafios simulam problemas reais de pipelines e Data Warehouses.

-- ─────────────────────────────────────────
-- EXERCÍCIO 1 — Pipeline de carga incremental
-- Baseado em: Aulas 3 e 5
-- ─────────────────────────────────────────
-- Contexto: Você precisa criar uma stored procedure que sincroniza
--           novos pedidos do OLTP (loja_db) para uma tabela de staging.
--
-- Crie a procedure sp_carga_pedidos_novos que:
--   1. Recebe @data_referencia DATE como parâmetro
--   2. Verifica quais pedidos dessa data ainda não estão em uma tabela
--      staging_pedidos (que você também deve criar)
--   3. Insere apenas os pedidos novos (carga incremental, não trunca)
--   4. Retorna quantos registros foram inseridos
--
-- A tabela staging_pedidos deve ter:
--   id_pedido, id_cliente, nome_cliente, data_pedido, status, valor_total, data_carga

USE loja_db;
GO

-- Sua solução aqui:


-- GABARITO:
/*
-- Cria a staging
IF OBJECT_ID('staging_pedidos', 'U') IS NOT NULL DROP TABLE staging_pedidos;
CREATE TABLE staging_pedidos (
    id_pedido    INT,
    id_cliente   INT,
    nome_cliente VARCHAR(100),
    data_pedido  DATE,
    status       VARCHAR(20),
    valor_total  DECIMAL(10,2),
    data_carga   DATETIME DEFAULT GETDATE()
);
GO

-- Cria a procedure
IF OBJECT_ID('sp_carga_pedidos_novos', 'P') IS NOT NULL DROP PROCEDURE sp_carga_pedidos_novos;
GO

CREATE PROCEDURE sp_carga_pedidos_novos
    @data_referencia DATE
AS
BEGIN
    -- Insere apenas pedidos que ainda não estão na staging
    INSERT INTO staging_pedidos (id_pedido, id_cliente, nome_cliente,
                                  data_pedido, status, valor_total)
    SELECT
        p.id_pedido,
        p.id_cliente,
        c.nome,
        p.data_pedido,
        p.status,
        p.valor_total
    FROM pedidos  AS p
    JOIN clientes AS c ON p.id_cliente = c.id_cliente
    WHERE p.data_pedido = @data_referencia
      AND NOT EXISTS (
          SELECT 1 FROM staging_pedidos AS s
          WHERE s.id_pedido = p.id_pedido
      );

    SELECT @@ROWCOUNT AS registros_inseridos, @data_referencia AS data_referencia;
END;
GO

-- Teste: carrega 3 datas diferentes
EXEC sp_carga_pedidos_novos '2024-01-05';
EXEC sp_carga_pedidos_novos '2024-01-10';
EXEC sp_carga_pedidos_novos '2024-01-05';  -- deve inserir 0 (já existe)

SELECT * FROM staging_pedidos ORDER BY data_pedido;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 2 — SCD Tipo 2 completo com MERGE
-- Baseado em: Aula 5
-- ─────────────────────────────────────────
-- Contexto: No DW, a tabela dim_produto precisa suportar SCD Tipo 2.
--           Quando o preço de um produto muda, o histórico deve ser preservado.
--
-- Crie uma procedure sp_atualiza_dim_produto que recebe uma tabela de
-- produtos atualizados e aplica SCD Tipo 2:
--   - Produto com preço diferente: fecha o registro atual e cria um novo
--   - Produto novo: insere normalmente
--   - Produto sem mudança: não faz nada
--
-- Use a data de hoje como data_inicio do novo registro
-- e DATEADD(DAY, -1, GETDATE()) como data_fim do registro anterior.

USE dw_loja;
GO

-- Sua solução aqui:


-- GABARITO:
/*
IF OBJECT_ID('sp_atualiza_dim_produto', 'P') IS NOT NULL DROP PROCEDURE sp_atualiza_dim_produto;
GO

CREATE PROCEDURE sp_atualiza_dim_produto
AS
BEGIN
    DECLARE @hoje DATE = CAST(GETDATE() AS DATE);
    DECLARE @ontem DATE = DATEADD(DAY, -1, @hoje);

    -- Dados atualizados vindos do OLTP
    -- (em produção viriam de uma staging table)
    CREATE TABLE #novos_produtos (
        id_produto INT, nome VARCHAR(100), categoria VARCHAR(50), preco DECIMAL(10,2)
    );

    INSERT INTO #novos_produtos VALUES
    (1,  'Notebook Pro',        'Eletrônicos', 3799.00),  -- preço subiu
    (2,  'Smartphone X',        'Eletrônicos', 1800.00),  -- sem mudança
    (13, 'Monitor Curvo 32"',   'Eletrônicos', 2200.00),  -- produto novo
    (9,  'SQL para Devs',       'Livros',        89.90);  -- preço subiu

    -- Passo 1: Fecha registros que mudaram (SCD Tipo 2)
    UPDATE dim_produto
    SET data_fim = @ontem,
        ativo    = 0
    WHERE ativo = 1
      AND EXISTS (
          SELECT 1 FROM #novos_produtos AS n
          WHERE n.id_produto = dim_produto.id_produto_origem
            AND n.preco <> dim_produto.preco  -- só fecha se mudou algo
      );

    -- Passo 2: Insere nova versão para quem mudou + insere os produtos novos
    INSERT INTO dim_produto (id_produto_origem, nome, categoria, preco, data_inicio, ativo)
    SELECT n.id_produto, n.nome, n.categoria, n.preco, @hoje, 1
    FROM #novos_produtos AS n
    WHERE NOT EXISTS (
        SELECT 1 FROM dim_produto AS d
        WHERE d.id_produto_origem = n.id_produto
          AND d.ativo = 1
    );

    DROP TABLE #novos_produtos;

    -- Retorna o estado atual da dimensão
    SELECT
        id_produto_origem,
        nome,
        preco,
        data_inicio,
        data_fim,
        ativo,
        CASE WHEN data_fim IS NULL THEN 'Versão atual'
             ELSE 'Histórico'
        END AS versao
    FROM dim_produto
    ORDER BY id_produto_origem, data_inicio;
END;
GO

EXEC sp_atualiza_dim_produto;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 3 — Detecção de anomalias com Window Functions
-- Baseado em: Aulas 2 e 4
-- ─────────────────────────────────────────
-- Contexto: O time de qualidade de dados quer detectar pedidos suspeitos —
--           pedidos com valor muito acima ou abaixo da média do cliente.
--
-- Um pedido é "suspeito" se o valor_total estiver mais de 2 desvios padrão
-- acima ou abaixo da média daquele cliente.
--
-- Retorne: nome do cliente, id_pedido, valor_total, media_cliente,
--          desvio_padrao_cliente e uma coluna "suspeito" = 'SIM' ou 'NAO'.
-- Inclua apenas clientes com pelo menos 2 pedidos (desvio padrão precisa de amostra).

USE loja_db;
GO

-- Sua solução aqui:


-- GABARITO:
/*
WITH estatisticas AS (
    SELECT
        p.id_cliente,
        p.id_pedido,
        p.valor_total,
        AVG(p.valor_total) OVER (PARTITION BY p.id_cliente) AS media_cliente,
        STDEV(p.valor_total) OVER (PARTITION BY p.id_cliente) AS desvio_cliente,
        COUNT(p.id_pedido)  OVER (PARTITION BY p.id_cliente) AS qtd_pedidos
    FROM pedidos AS p
    WHERE p.status != 'cancelado'
)
SELECT
    c.nome           AS cliente,
    e.id_pedido,
    e.valor_total,
    ROUND(e.media_cliente,  2) AS media_cliente,
    ROUND(e.desvio_cliente, 2) AS desvio_padrao,
    CASE
        WHEN e.desvio_cliente > 0
         AND ABS(e.valor_total - e.media_cliente) > 2 * e.desvio_cliente
        THEN 'SIM'
        ELSE 'NÃO'
    END AS suspeito
FROM estatisticas AS e
JOIN clientes     AS c ON e.id_cliente = c.id_cliente
WHERE e.qtd_pedidos >= 2
ORDER BY c.nome, e.id_pedido;
*/


-- ─────────────────────────────────────────
-- EXERCÍCIO 4 — Análise de cohort simples
-- Baseado em: Aulas 2 e 5
-- ─────────────────────────────────────────
-- Contexto: Análise de cohort é fundamental em engenharia de dados.
--           Um "cohort" agrupa clientes pelo mês em que fizeram o primeiro pedido.
--
-- Crie uma query que mostre, para cada cohort (mês do primeiro pedido):
--   - mês do cohort (ex: 2024-01)
--   - quantos clientes entraram nesse cohort
--   - receita total dos clientes desse cohort em cada mês seguinte
--
-- Resultado esperado:
--   cohort | mes_atividade | clientes | receita
--   2024-01|    2024-01    |    2     | 5600.00
--   2024-01|    2024-04    |    1     |  167.00
--   ...

USE loja_db;
GO

-- Sua solução aqui:


-- GABARITO:
/*
WITH primeiro_pedido AS (
    -- Identifica o mês do primeiro pedido de cada cliente
    SELECT
        id_cliente,
        MIN(data_pedido) AS data_primeiro_pedido,
        FORMAT(MIN(data_pedido), 'yyyy-MM') AS cohort
    FROM pedidos
    WHERE status != 'cancelado'
    GROUP BY id_cliente
),
pedidos_por_cliente AS (
    -- Todos os pedidos com o cohort do cliente
    SELECT
        p.id_cliente,
        pp.cohort,
        FORMAT(p.data_pedido, 'yyyy-MM') AS mes_atividade,
        p.valor_total
    FROM pedidos        AS p
    JOIN primeiro_pedido AS pp ON p.id_cliente = pp.id_cliente
    WHERE p.status != 'cancelado'
)
SELECT
    cohort,
    mes_atividade,
    COUNT(DISTINCT id_cliente) AS clientes_ativos,
    SUM(valor_total)           AS receita_cohort
FROM pedidos_por_cliente
GROUP BY cohort, mes_atividade
ORDER BY cohort, mes_atividade;
*/
GO
