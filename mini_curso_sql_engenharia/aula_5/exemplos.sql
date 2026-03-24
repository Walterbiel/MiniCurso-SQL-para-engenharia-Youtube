-- ============================================
-- AULA 5: SQL no Data Warehouse
-- Arquivo: aula_5/exemplos.sql
-- ⏱️  Tempo estimado: 30 minutos
-- 📍 Posição no roteiro: Parte 5 de 5
-- ============================================
-- Objetivo: Conectar SQL ao mundo real de engenharia de dados —
--           modelagem dimensional, cargas incrementais e SCDs.
-- Pré-requisito: execute banco.sql antes desta aula.
--   Esta aula usa dois bancos: loja_db (OLTP) e dw_loja (DW)

-- ─────────────────────────────────────────
-- BLOCO 1: OLTP vs OLAP — dois mundos diferentes
-- O que vamos aprender: OLTP para operação, OLAP para análise
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- OLTP (Online Transaction Processing) — banco operacional
-- → Muitas transações pequenas e rápidas
-- → Normalizado: evita redundância
-- → Exemplo: loja_db — cada venda atualiza pedidos + itens_pedido

USE loja_db;
GO

-- Para responder "quanto vendemos por categoria em janeiro?"
-- no OLTP precisamos de 4 JOINs pesados:
SELECT
    cat.nome                                       AS categoria,
    SUM(i.quantidade * i.preco_unitario)           AS receita_janeiro
FROM itens_pedido AS i
JOIN pedidos      AS p   ON i.id_pedido    = p.id_pedido
JOIN produtos     AS pr  ON i.id_produto   = pr.id_produto
JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
WHERE p.data_pedido BETWEEN '2024-01-01' AND '2024-01-31'
  AND p.status = 'entregue'
GROUP BY cat.nome;

-- OLAP (Online Analytical Processing) — banco analítico / DW
-- → Poucas queries grandes sobre muitos dados
-- → Desnormalizado: redundância proposital para performance
-- → Modelo dimensional: fato + dimensões

-- 💡 O que acontece se mudar?
-- No DW essa mesma query fica simples (sem JOINs complexos)
-- Vamos construir o DW agora e você vai ver a diferença ao final


-- ─────────────────────────────────────────
-- BLOCO 2: Tabelas fato, dimensão e chaves substitutas
-- O que vamos aprender: star schema — o modelo padrão de DW
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

USE dw_loja;
GO

-- Dimensão = quem, o quê, quando, onde (contexto)
-- Fato = o que aconteceu em números (métricas)

-- Surrogate Key (chave substituta):
-- → Gerada pelo DW (IDENTITY), independente do sistema de origem
-- → Permite SCD Tipo 2 (múltiplas versões do mesmo cliente)
-- → Protege o DW de mudanças na chave de origem

-- Estrutura do star schema:
--
--   dim_cliente ──┐
--   dim_produto ──┼──> fato_vendas
--   dim_tempo ────┘

-- Ver a estrutura das dimensões
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_cliente';

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fato_vendas';

-- 💡 O que acontece se mudar?
-- dim_tempo é pré-carregada (todos os dias do ano) — não depende de venda
-- fato_vendas é append-only: nunca fazemos UPDATE, apenas INSERT


-- ─────────────────────────────────────────
-- BLOCO 3: Carga incremental — staging → DW
-- O que vamos aprender: extrair do OLTP, carregar na staging, depois nas dimensões
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Passo 1: Extrai do OLTP para a staging (simula o trabalho do pipeline)
TRUNCATE TABLE stg_pedidos;  -- limpa staging antes de recarregar

INSERT INTO stg_pedidos (id_pedido, id_cliente, nome_cliente, cidade, uf,
                          id_produto, nome_produto, categoria, preco_produto,
                          data_pedido, quantidade, valor)
SELECT
    p.id_pedido,
    c.id_cliente,
    c.nome,
    c.cidade,
    c.uf,
    pr.id_produto,
    pr.nome,
    cat.nome,
    pr.preco,
    p.data_pedido,
    i.quantidade,
    i.quantidade * i.preco_unitario
FROM loja_db.dbo.itens_pedido AS i
JOIN loja_db.dbo.pedidos      AS p   ON i.id_pedido    = p.id_pedido
JOIN loja_db.dbo.clientes     AS c   ON p.id_cliente   = c.id_cliente
JOIN loja_db.dbo.produtos     AS pr  ON i.id_produto   = pr.id_produto
JOIN loja_db.dbo.categorias   AS cat ON pr.id_categoria = cat.id_categoria
WHERE p.status = 'entregue';

SELECT COUNT(*) AS linhas_na_staging FROM stg_pedidos;

-- Passo 2: Carrega dim_cliente (carga inicial — apenas clientes novos)
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
SELECT DISTINCT
    s.id_cliente,
    s.nome_cliente,
    s.cidade,
    s.uf,
    CAST(GETDATE() AS DATE),
    1
FROM stg_pedidos AS s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_cliente AS d
    WHERE d.id_cliente_origem = s.id_cliente
      AND d.ativo = 1
);

-- Passo 3: Carrega dim_produto
INSERT INTO dim_produto (id_produto_origem, nome, categoria, preco, data_inicio, ativo)
SELECT DISTINCT
    s.id_produto,
    s.nome_produto,
    s.categoria,
    s.preco_produto,
    CAST(GETDATE() AS DATE),
    1
FROM stg_pedidos AS s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_produto AS d
    WHERE d.id_produto_origem = s.id_produto
      AND d.ativo = 1
);

SELECT COUNT(*) AS clientes_na_dimensao FROM dim_cliente;
SELECT COUNT(*) AS produtos_na_dimensao FROM dim_produto;

-- 💡 O que acontece se mudar?
-- Execute o INSERT nas dimensões duas vezes — o WHERE NOT EXISTS evita duplicatas
-- Esse padrão é a base de qualquer carga incremental


-- ─────────────────────────────────────────
-- BLOCO 4: Carregando a fato_vendas
-- O que vamos aprender: fato referencia as surrogate keys das dimensões
-- ⏱️ ~4 minutos
-- ─────────────────────────────────────────

-- A fato não guarda nomes — guarda só as surrogate keys (sk_)
-- e as métricas (quantidade, valor)
INSERT INTO fato_vendas (sk_cliente, sk_produto, sk_tempo, id_pedido_origem, quantidade, valor)
SELECT
    dc.sk_cliente,
    dp.sk_produto,
    dt.sk_tempo,
    s.id_pedido,
    s.quantidade,
    s.valor
FROM stg_pedidos AS s
JOIN dim_cliente AS dc ON s.id_cliente = dc.id_cliente_origem AND dc.ativo = 1
JOIN dim_produto AS dp ON s.id_produto = dp.id_produto_origem AND dp.ativo = 1
JOIN dim_tempo   AS dt ON CAST(FORMAT(s.data_pedido, 'yyyyMMdd') AS INT) = dt.sk_tempo
WHERE NOT EXISTS (
    SELECT 1 FROM fato_vendas AS f
    WHERE f.id_pedido_origem = s.id_pedido
      AND f.sk_produto       = dp.sk_produto
);

SELECT COUNT(*) AS linhas_na_fato FROM fato_vendas;

-- Consulta analítica no DW — muito mais simples que no OLTP!
SELECT
    dp.categoria,
    SUM(f.valor) AS receita_total,
    SUM(f.quantidade) AS itens_vendidos
FROM fato_vendas AS f
JOIN dim_produto AS dp ON f.sk_produto = dp.sk_produto
JOIN dim_tempo   AS dt ON f.sk_tempo   = dt.sk_tempo
WHERE dt.mes = 1 AND dt.ano = 2024
GROUP BY dp.categoria
ORDER BY receita_total DESC;

-- 💡 O que acontece se mudar?
-- Compare a query acima com a query OLTP do bloco 1
-- Mesmo resultado, mas no DW: sem JOIN em pedidos, clientes, itens_pedido e categorias


-- ─────────────────────────────────────────
-- BLOCO 5: MERGE — upsert (insert + update em uma operação)
-- O que vamos aprender: MERGE resolve carga incremental elegantemente
-- ⏱️ ~6 minutos
-- ─────────────────────────────────────────

-- Problema: ao recarregar dados, precisamos:
--   → Inserir registros novos
--   → Atualizar registros que mudaram
--   → (Opcionalmente) deletar registros que sumiram

-- MERGE resolve tudo isso em uma instrução

-- Simula uma staging com dados atualizados (cliente mudou de cidade)
CREATE TABLE #stg_clientes_delta (
    id_cliente INT,
    nome       VARCHAR(100),
    cidade     VARCHAR(50),
    uf         CHAR(2)
);

INSERT INTO #stg_clientes_delta VALUES
(1,  'Ana Lima',      'Campinas',   'SP'),  -- mudou de cidade
(2,  'Bruno Santos',  'Rio de Janeiro', 'RJ'),  -- sem mudança
(11, 'Karen Dias',    'Belém',      'PA');   -- cliente novo no DW

-- MERGE: atualiza quem existe, insere quem é novo
MERGE dim_cliente AS destino
USING (
    SELECT id_cliente, nome, cidade, uf FROM #stg_clientes_delta
) AS origem (id_cliente, nome, cidade, uf)
ON destino.id_cliente_origem = origem.id_cliente AND destino.ativo = 1

WHEN MATCHED AND (destino.cidade <> origem.cidade OR destino.uf <> origem.uf) THEN
    UPDATE SET
        destino.cidade = origem.cidade,
        destino.uf     = origem.uf

WHEN NOT MATCHED BY TARGET THEN
    INSERT (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
    VALUES (origem.id_cliente, origem.nome, origem.cidade, origem.uf, CAST(GETDATE() AS DATE), 1);

DROP TABLE #stg_clientes_delta;

-- Verifica o resultado
SELECT sk_cliente, id_cliente_origem, nome, cidade, uf, ativo
FROM dim_cliente
ORDER BY id_cliente_origem;

-- 💡 O que acontece se mudar?
-- Adicione WHEN NOT MATCHED BY SOURCE THEN UPDATE SET ativo = 0
-- para "desativar" clientes que sumiram da staging


-- ─────────────────────────────────────────
-- BLOCO 6: SCD Tipo 1 vs SCD Tipo 2
-- O que vamos aprender: como tratar mudanças históricas nos dados dimensionais
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- SCD Tipo 1 — sobrescreve o valor antigo (sem histórico)
-- Quando usar: correção de erro, dado sem valor histórico
-- Exemplo: nome do cliente foi digitado errado

UPDATE dim_cliente
SET nome = 'Ana Lima Correto'
WHERE id_cliente_origem = 1 AND ativo = 1;

-- Desfaz para ficar limpo
UPDATE dim_cliente
SET nome = 'Ana Lima'
WHERE id_cliente_origem = 1 AND ativo = 1;

-- SCD Tipo 2 — preserva o histórico criando uma nova linha
-- Quando usar: mudanças com impacto histórico (cidade, categoria, preço)
-- Exemplo: cliente Ana mudou de SP para RJ — queremos saber onde ela morava quando comprou

-- Passo 1: fecha o registro atual (define data_fim)
UPDATE dim_cliente
SET data_fim = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
    ativo    = 0
WHERE id_cliente_origem = 1 AND ativo = 1;

-- Passo 2: insere novo registro com os dados atualizados
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
VALUES (1, 'Ana Lima', 'Rio de Janeiro', 'RJ', CAST(GETDATE() AS DATE), 1);

-- Resultado: duas versões de Ana no DW
SELECT sk_cliente, nome, cidade, uf, data_inicio, data_fim, ativo
FROM dim_cliente
WHERE id_cliente_origem = 1
ORDER BY data_inicio;

-- As vendas antigas continuam apontando para a versão antiga (SK antiga)!
-- Isso é a vantagem do SCD Tipo 2: histórico preservado automaticamente

-- 💡 O que acontece se mudar?
-- O MERGE do bloco anterior pode ser adaptado para SCD Tipo 2:
-- WHEN MATCHED AND dados mudaram THEN UPDATE SET ativo=0, data_fim=hoje
-- + INSERT da nova linha (isso é feito com dois passos separados no MERGE)

-- Resumo: SCD Tipo 1 = simples, sem histórico
--         SCD Tipo 2 = histórico completo, mais complexo, sk_cliente diferente por versão
GO
