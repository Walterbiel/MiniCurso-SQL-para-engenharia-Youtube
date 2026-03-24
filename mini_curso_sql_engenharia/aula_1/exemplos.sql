-- ============================================
-- AULA 1: Fundamentos de Bancos Relacionais
-- Arquivo: aula_1/exemplos.sql
-- ⏱️  Tempo estimado: 25 minutos
-- 📍 Posição no roteiro: Parte 1 de 5
-- ============================================
-- Objetivo: Entender como o banco funciona por dentro,
--           não só dar SELECT.
-- Pré-requisito: execute banco.sql antes desta aula.

USE loja_db;
GO

-- ─────────────────────────────────────────
-- BLOCO 1: O que é um banco relacional
-- O que vamos aprender: dados organizados em tabelas com relacionamentos
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Um banco relacional organiza dados em tabelas (entidades)
-- e define regras de como essas tabelas se relacionam.

-- Veja as tabelas que temos:
SELECT TABLE_NAME AS tabela
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

-- Cada tabela tem colunas com tipos definidos
SELECT COLUMN_NAME     AS coluna,
       DATA_TYPE       AS tipo,
       IS_NULLABLE     AS aceita_nulo
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'clientes';

-- 💡 O que acontece se mudar a tabela?
-- Tente com 'produtos' e 'pedidos' — cada tabela modela uma entidade do negócio
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'produtos';


-- ─────────────────────────────────────────
-- BLOCO 2: Primary Key — identificador único
-- O que vamos aprender: toda linha precisa ser identificável de forma única
-- ⏱️ ~4 minutos
-- ─────────────────────────────────────────

-- A Primary Key garante que não existam dois registros idênticos na mesma tabela
-- Aqui, cada cliente tem um id_cliente único
SELECT id_cliente, nome, email
FROM clientes;

-- Tentativa de inserir id duplicado gera erro (demonstração)
-- Execute e veja o erro: "Violation of PRIMARY KEY constraint"
-- INSERT INTO clientes VALUES (1, 'Duplicado', 'dup@email.com', 'SP', 'SP', '2024-01-01');

-- 💡 O que acontece se mudar?
-- Qual é a PK de pedidos? E de itens_pedido?
SELECT id_pedido, id_cliente, data_pedido, status
FROM pedidos;

SELECT id_item, id_pedido, id_produto, quantidade
FROM itens_pedido;


-- ─────────────────────────────────────────
-- BLOCO 3: Foreign Key — o elo entre tabelas
-- O que vamos aprender: FK garante que referências sempre existam
-- ⏱️ ~4 minutos
-- ─────────────────────────────────────────

-- Um pedido pertence a um cliente — a FK impede pedido sem cliente
-- id_cliente em pedidos aponta para id_cliente em clientes
SELECT p.id_pedido,
       p.id_cliente,
       c.nome    AS nome_cliente,  -- dado vindo de outra tabela via FK
       p.status
FROM pedidos   AS p
JOIN clientes  AS c ON p.id_cliente = c.id_cliente;

-- Tentativa de inserir pedido com cliente inexistente gera erro
-- "The INSERT statement conflicted with the FOREIGN KEY constraint"
-- INSERT INTO pedidos VALUES (99, 999, '2024-01-01', 'pendente', 0);

-- 💡 O que acontece se mudar?
-- Veja o mesmo princípio em itens_pedido → produtos
SELECT i.id_item,
       i.id_pedido,
       pr.nome   AS produto,
       i.quantidade,
       i.preco_unitario
FROM itens_pedido AS i
JOIN produtos     AS pr ON i.id_produto = pr.id_produto;


-- ─────────────────────────────────────────
-- BLOCO 4: Relacionamentos entre tabelas
-- O que vamos aprender: 1:N e N:N são os padrões mais comuns
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Relacionamento 1:N — um cliente tem muitos pedidos
-- Um cliente (1) → vários pedidos (N)
SELECT c.nome          AS cliente,
       COUNT(p.id_pedido) AS total_pedidos
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
GROUP BY c.nome
ORDER BY total_pedidos DESC;

-- Relacionamento N:N — um pedido tem muitos produtos, um produto aparece em muitos pedidos
-- A tabela itens_pedido é a tabela ASSOCIATIVA que resolve o N:N
SELECT p.id_pedido,
       pr.nome     AS produto,
       i.quantidade
FROM pedidos      AS p
JOIN itens_pedido AS i  ON p.id_pedido  = i.id_pedido
JOIN produtos     AS pr ON i.id_produto = pr.id_produto
WHERE p.id_pedido = 1;

-- 💡 O que acontece se mudar?
-- Troque o id_pedido para 2, 7 ou 8 — veja que pedidos têm múltiplos produtos


-- ─────────────────────────────────────────
-- BLOCO 5: Transações e ACID
-- O que vamos aprender: transação = tudo ou nada
-- ⏱️ ~4 minutos
-- ─────────────────────────────────────────

-- Uma transação agrupa operações que devem ocorrer em conjunto.
-- Se qualquer parte falhar, tudo é desfeito (ROLLBACK).

-- Exemplo: inserir pedido + seus itens em uma transação
BEGIN TRANSACTION;

    -- Passo 1: insere o pedido
    INSERT INTO pedidos VALUES (20, 1, GETDATE(), 'pendente', 0);

    -- Passo 2: insere os itens
    INSERT INTO itens_pedido VALUES (50, 20, 9, 2, 79.90);
    INSERT INTO itens_pedido VALUES (51, 20, 7, 1, 45.00);

    -- Passo 3: atualiza o valor total
    UPDATE pedidos
    SET valor_total = (SELECT SUM(quantidade * preco_unitario)
                       FROM itens_pedido WHERE id_pedido = 20)
    WHERE id_pedido = 20;

COMMIT; -- confirma tudo de uma vez

-- Verifica o resultado
SELECT id_pedido, status, valor_total FROM pedidos WHERE id_pedido = 20;
SELECT * FROM itens_pedido WHERE id_pedido = 20;

-- 💡 O que acontece se mudar?
-- Substitua COMMIT por ROLLBACK — nada é salvo
-- BEGIN TRANSACTION;
--     INSERT INTO pedidos VALUES (21, 1, GETDATE(), 'pendente', 0);
--     -- simula erro aqui...
-- ROLLBACK; -- desfaz tudo

-- ACID em resumo:
-- A → Atomicidade:  tudo ou nada
-- C → Consistência: o banco nunca fica em estado inválido
-- I → Isolamento:   transações concorrentes não interferem entre si
-- D → Durabilidade: dados confirmados sobrevivem a falhas


-- ─────────────────────────────────────────
-- BLOCO 6: CRUD na visão de engenharia de dados
-- O que vamos aprender: INSERT/UPDATE/DELETE controlados e rastreáveis
-- ⏱️ ~3 minutos
-- ─────────────────────────────────────────

-- CREATE — inserir dado novo
INSERT INTO clientes VALUES (11, 'Karen Dias', 'karen@email.com', 'Manaus', 'AM', CAST(GETDATE() AS DATE));

-- READ — consultar
SELECT id_cliente, nome, cidade FROM clientes WHERE id_cliente = 11;

-- UPDATE — alterar dado existente (SEMPRE com WHERE!)
UPDATE clientes
SET cidade = 'Belém', uf = 'PA'
WHERE id_cliente = 11;

-- DELETE — remover (SEMPRE com WHERE — sem WHERE apaga tudo!)
DELETE FROM clientes WHERE id_cliente = 11;

-- 💡 O que acontece se mudar?
-- Tente deletar um cliente que tem pedidos — o banco vai rejeitar por causa da FK
-- DELETE FROM clientes WHERE id_cliente = 1;
-- Mensagem: "The DELETE statement conflicted with the FOREIGN KEY constraint"
-- Isso é a integridade referencial protegendo seus dados!

-- Limpeza do exemplo da transação
DELETE FROM itens_pedido WHERE id_pedido = 20;
DELETE FROM pedidos      WHERE id_pedido = 20;
GO
