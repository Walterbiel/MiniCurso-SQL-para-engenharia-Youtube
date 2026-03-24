-- ============================================
-- AULA 3: Views, Procedures e Funções
-- Arquivo: aula_3/exemplos.sql
-- ⏱️  Tempo estimado: 25 minutos
-- 📍 Posição no roteiro: Parte 3 de 5
-- ============================================
-- Objetivo: Organizar lógica de dados no próprio banco —
--           reutilização, padronização e SQL como parte do ETL/ELT.
-- Pré-requisito: execute banco.sql antes desta aula.

USE loja_db;
GO

-- ═══════════════════════════════════════════
-- PARTE 1: VIEWS
-- ═══════════════════════════════════════════

-- ─────────────────────────────────────────
-- BLOCO 1: O que é VIEW e quando usar
-- O que vamos aprender: VIEW = SELECT salvo com nome, reutilizável como tabela
-- ⏱️ ~7 minutos
-- ─────────────────────────────────────────

-- Sem VIEW: toda equipe escreve o mesmo JOIN de novo
-- Isso gera inconsistência — cada pessoa filtra de um jeito diferente
SELECT c.nome, p.id_pedido, p.valor_total, p.status
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente;

-- Com VIEW: a lógica fica centralizada no banco
IF OBJECT_ID('vw_pedidos_clientes', 'V') IS NOT NULL DROP VIEW vw_pedidos_clientes;
GO

CREATE VIEW vw_pedidos_clientes AS
SELECT
    c.id_cliente,
    c.nome          AS cliente,
    c.cidade,
    c.uf,
    p.id_pedido,
    p.data_pedido,
    p.status,
    p.valor_total
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente;
GO

-- Consumir a view é como ler uma tabela
SELECT * FROM vw_pedidos_clientes WHERE status = 'entregue';
SELECT cliente, SUM(valor_total) AS total FROM vw_pedidos_clientes GROUP BY cliente;

-- View mais elaborada: resumo financeiro por cliente
IF OBJECT_ID('vw_resumo_cliente', 'V') IS NOT NULL DROP VIEW vw_resumo_cliente;
GO

CREATE VIEW vw_resumo_cliente AS
SELECT
    c.id_cliente,
    c.nome              AS cliente,
    c.cidade,
    COUNT(p.id_pedido)  AS total_pedidos,
    SUM(CASE WHEN p.status = 'entregue' THEN p.valor_total ELSE 0 END) AS receita_confirmada,
    SUM(CASE WHEN p.status = 'cancelado' THEN p.valor_total ELSE 0 END) AS receita_perdida,
    MAX(p.data_pedido)  AS ultimo_pedido
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nome, c.cidade;
GO

SELECT * FROM vw_resumo_cliente ORDER BY receita_confirmada DESC;

-- 💡 O que acontece se mudar?
-- A VIEW não armazena dados — ela executa o SELECT toda vez que é consultada
-- Crie uma VIEW de produtos por categoria e tente filtrá-la como se fosse tabela


-- ═══════════════════════════════════════════
-- PARTE 2: STORED PROCEDURES
-- ═══════════════════════════════════════════

-- ─────────────────────────────────────────
-- BLOCO 2: Stored Procedures — lógica de processo no banco
-- O que vamos aprender: procedures encapsulam lógica e recebem parâmetros
-- ⏱️ ~8 minutos
-- ─────────────────────────────────────────

-- Procedure simples: relatório de pedidos por período
IF OBJECT_ID('sp_pedidos_periodo', 'P') IS NOT NULL DROP PROCEDURE sp_pedidos_periodo;
GO

CREATE PROCEDURE sp_pedidos_periodo
    @data_inicio DATE,
    @data_fim    DATE
AS
BEGIN
    SELECT
        p.id_pedido,
        c.nome        AS cliente,
        p.data_pedido,
        p.status,
        p.valor_total
    FROM pedidos  AS p
    JOIN clientes AS c ON p.id_cliente = c.id_cliente
    WHERE p.data_pedido BETWEEN @data_inicio AND @data_fim
    ORDER BY p.data_pedido;
END;
GO

-- Executar a procedure
EXEC sp_pedidos_periodo '2024-01-01', '2024-03-31';
EXEC sp_pedidos_periodo '2024-04-01', '2024-06-30';

-- Procedure de processo: atualiza status de pedidos antigos pendentes
IF OBJECT_ID('sp_cancelar_pendentes', 'P') IS NOT NULL DROP PROCEDURE sp_cancelar_pendentes;
GO

CREATE PROCEDURE sp_cancelar_pendentes
    @dias_limite INT = 30   -- parâmetro com valor padrão
AS
BEGIN
    DECLARE @cancelados INT;

    -- Cancela pedidos pendentes mais antigos que X dias
    UPDATE pedidos
    SET status = 'cancelado'
    WHERE status = 'pendente'
      AND DATEDIFF(DAY, data_pedido, GETDATE()) > @dias_limite;

    SET @cancelados = @@ROWCOUNT;

    -- Retorna resumo do que foi feito
    SELECT @cancelados AS pedidos_cancelados,
           GETDATE()   AS executado_em;
END;
GO

-- Uso real em ETL: a procedure vira um step do pipeline
-- EXEC sp_cancelar_pendentes 30;   -- usa o padrão de 30 dias
-- EXEC sp_cancelar_pendentes 7;    -- versão mais agressiva: 7 dias

-- 💡 O que acontece se mudar?
-- Adicione um parâmetro @status_destino para flexibilizar o destino (não só 'cancelado')
-- Inclua TRY/CATCH para tratamento de erro em produção


-- ═══════════════════════════════════════════
-- PARTE 3: FUNÇÕES
-- ═══════════════════════════════════════════

-- ─────────────────────────────────────────
-- BLOCO 3: Funções escalares — retornam um valor
-- O que vamos aprender: encapsular cálculos reutilizáveis
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Função escalar: calcula o valor com desconto
IF OBJECT_ID('fn_valor_com_desconto', 'FN') IS NOT NULL DROP FUNCTION fn_valor_com_desconto;
GO

CREATE FUNCTION fn_valor_com_desconto
(
    @valor          DECIMAL(10,2),
    @pct_desconto   DECIMAL(5,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @valor - (@valor * @pct_desconto / 100);
END;
GO

-- Usando a função em um SELECT
SELECT
    nome,
    preco                                       AS preco_original,
    dbo.fn_valor_com_desconto(preco, 10)        AS preco_10pct_off,
    dbo.fn_valor_com_desconto(preco, 15)        AS preco_15pct_off
FROM produtos
WHERE preco > 100;

-- 💡 O que acontece se mudar?
-- Crie uma função que classifica o cliente como 'VIP', 'Regular' ou 'Novo'
-- baseado no número de pedidos (VIP > 3, Regular >= 1, Novo = 0)


-- ─────────────────────────────────────────
-- BLOCO 4: Funções de tabela — retornam um conjunto de linhas
-- O que vamos aprender: função que age como VIEW parametrizada
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Função de tabela: retorna itens de um pedido com detalhes
IF OBJECT_ID('fn_itens_pedido', 'TF') IS NOT NULL DROP FUNCTION fn_itens_pedido;
GO

CREATE FUNCTION fn_itens_pedido (@id_pedido INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        pr.nome                          AS produto,
        cat.nome                         AS categoria,
        i.quantidade,
        i.preco_unitario,
        i.quantidade * i.preco_unitario  AS subtotal
    FROM itens_pedido AS i
    JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
    JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
    WHERE i.id_pedido = @id_pedido
);
GO

-- Usar como se fosse uma tabela, passando o parâmetro
SELECT * FROM dbo.fn_itens_pedido(8);

-- Combinar com outras tabelas
SELECT
    p.id_pedido,
    c.nome          AS cliente,
    p.data_pedido,
    itens.*
FROM pedidos  AS p
JOIN clientes AS c ON p.id_cliente = c.id_cliente
CROSS APPLY dbo.fn_itens_pedido(p.id_pedido) AS itens
WHERE p.id_pedido IN (1, 7, 8);

-- 💡 O que acontece se mudar?
-- CROSS APPLY é como um JOIN com função — só retorna linhas onde a função retorna resultado
-- Troque por OUTER APPLY para manter pedidos mesmo que a função retorne vazio

-- VIEW vs PROCEDURE vs FUNÇÃO — quando usar cada um?
-- VIEW        → consulta padronizada, sem parâmetro, consumida como tabela
-- PROCEDURE   → processo/ação com lógica, pode fazer INSERT/UPDATE/DELETE
-- FUNÇÃO      → cálculo reutilizável, pode ser usada dentro de um SELECT
GO
