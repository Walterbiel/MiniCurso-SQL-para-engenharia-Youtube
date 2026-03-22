-- =============================================================
-- AULA 3: Views, Procedures e Funções
-- Pré-requisito: execute banco.sql antes
-- =============================================================


-- -------------------------------------------------------------
-- 1. VIEWS
-- -------------------------------------------------------------

-- View simples: pedidos com nome do cliente e produto
CREATE OR REPLACE VIEW vw_pedidos_detalhados AS
SELECT
    p.id          AS pedido_id,
    c.nome        AS cliente,
    c.estado,
    pr.nome       AS produto,
    pr.categoria,
    p.quantidade,
    p.total,
    p.status,
    p.criado_em
FROM pedidos p
JOIN clientes c  ON c.id = p.cliente_id
JOIN produtos pr ON pr.id = p.produto_id;

-- Usar a view como se fosse uma tabela
SELECT * FROM vw_pedidos_detalhados;

-- Filtrar na view
SELECT * FROM vw_pedidos_detalhados
WHERE status = 'pago' AND estado = 'SP';


-- View de resumo: faturamento por categoria
CREATE OR REPLACE VIEW vw_faturamento_por_categoria AS
SELECT
    pr.categoria,
    COUNT(p.id)   AS total_pedidos,
    SUM(p.total)  AS faturamento
FROM pedidos p
JOIN produtos pr ON pr.id = p.produto_id
WHERE p.status = 'pago'
GROUP BY pr.categoria
ORDER BY faturamento DESC;

SELECT * FROM vw_faturamento_por_categoria;


-- Remover uma view
-- DROP VIEW IF EXISTS vw_pedidos_detalhados;


-- -------------------------------------------------------------
-- 2. VIEW MATERIALIZADA (PostgreSQL)
-- -------------------------------------------------------------

-- Cria e salva os dados fisicamente
DROP MATERIALIZED VIEW IF EXISTS mv_clientes_por_estado;

CREATE MATERIALIZED VIEW mv_clientes_por_estado AS
SELECT
    estado,
    COUNT(*)      AS total_clientes,
    MAX(criado_em) AS ultimo_cadastro
FROM clientes
GROUP BY estado
ORDER BY total_clientes DESC;

-- Consultar
SELECT * FROM mv_clientes_por_estado;

-- Atualizar os dados (rodar após novos inserts)
REFRESH MATERIALIZED VIEW mv_clientes_por_estado;


-- -------------------------------------------------------------
-- 3. STORED PROCEDURES
-- -------------------------------------------------------------

-- Procedure: cancela um pedido pelo ID
CREATE OR REPLACE PROCEDURE sp_cancelar_pedido(p_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    -- Verifica se o pedido existe
    IF NOT EXISTS (SELECT 1 FROM pedidos WHERE id = p_id) THEN
        RAISE EXCEPTION 'Pedido % não encontrado.', p_id;
    END IF;

    -- Atualiza o status
    UPDATE pedidos SET status = 'cancelado' WHERE id = p_id;

    RAISE NOTICE 'Pedido % cancelado com sucesso.', p_id;
END;
$$;

-- Executar
CALL sp_cancelar_pedido(2);

-- Verificar
SELECT id, status FROM pedidos WHERE id = 2;

-- Restaurar para o exemplo não ficar sujo
UPDATE pedidos SET status = 'pago' WHERE id = 2;


-- Procedure: atualiza estoque após pedido pago
CREATE OR REPLACE PROCEDURE sp_baixar_estoque(p_produto_id INT, p_quantidade INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_estoque INT;
BEGIN
    SELECT estoque INTO v_estoque FROM produtos WHERE id = p_produto_id;

    IF v_estoque < p_quantidade THEN
        RAISE EXCEPTION 'Estoque insuficiente. Disponível: %, Solicitado: %', v_estoque, p_quantidade;
    END IF;

    UPDATE produtos
    SET estoque = estoque - p_quantidade
    WHERE id = p_produto_id;

    RAISE NOTICE 'Estoque atualizado. Novo estoque: %', v_estoque - p_quantidade;
END;
$$;

-- Testar
CALL sp_baixar_estoque(2, 5);  -- produto 2, baixa 5 unidades

-- Ver resultado
SELECT id, nome, estoque FROM produtos WHERE id = 2;


-- -------------------------------------------------------------
-- 4. FUNÇÕES
-- -------------------------------------------------------------

-- Função: calcula preço com desconto
CREATE OR REPLACE FUNCTION fn_aplicar_desconto(preco NUMERIC, percentual NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN ROUND(preco - (preco * percentual / 100), 2);
END;
$$ LANGUAGE plpgsql;

-- Usar no SELECT
SELECT
    nome,
    preco                             AS preco_original,
    fn_aplicar_desconto(preco, 10)    AS preco_10pct_desconto,
    fn_aplicar_desconto(preco, 15)    AS preco_15pct_desconto
FROM produtos;


-- Função: classifica pedido por valor
CREATE OR REPLACE FUNCTION fn_classificar_pedido(valor NUMERIC)
RETURNS VARCHAR AS $$
BEGIN
    IF    valor < 100    THEN RETURN 'Baixo';
    ELSIF valor < 1000   THEN RETURN 'Médio';
    ELSE                      RETURN 'Alto';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Usar no SELECT
SELECT
    id,
    total,
    fn_classificar_pedido(total) AS classificacao
FROM pedidos
ORDER BY total;


-- -------------------------------------------------------------
-- 5. Limpeza
-- -------------------------------------------------------------
DROP VIEW IF EXISTS vw_pedidos_detalhados;
DROP VIEW IF EXISTS vw_faturamento_por_categoria;
DROP MATERIALIZED VIEW IF EXISTS mv_clientes_por_estado;
DROP PROCEDURE IF EXISTS sp_cancelar_pedido(INT);
DROP PROCEDURE IF EXISTS sp_baixar_estoque(INT, INT);
DROP FUNCTION IF EXISTS fn_aplicar_desconto(NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS fn_classificar_pedido(NUMERIC);
