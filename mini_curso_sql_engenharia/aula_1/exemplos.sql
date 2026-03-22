-- =============================================================
-- AULA 1: Bancos Relacionais, ACID e CRUD
-- Pré-requisito: execute banco.sql antes
-- =============================================================


-- -------------------------------------------------------------
-- 1. CRIANDO TABELAS (DDL)
-- -------------------------------------------------------------

-- Criar uma tabela simples
CREATE TABLE categorias (
    id    SERIAL PRIMARY KEY,
    nome  VARCHAR(50) NOT NULL
);

-- Adicionar uma coluna depois (ALTER TABLE)
ALTER TABLE categorias ADD COLUMN ativo BOOLEAN DEFAULT TRUE;

-- Ver a estrutura de uma tabela no PostgreSQL
\d clientes


-- -------------------------------------------------------------
-- 2. INSERT — criando registros (CREATE do CRUD)
-- -------------------------------------------------------------

-- Inserir um registro
INSERT INTO clientes (nome, email, cidade, estado)
VALUES ('Maria Oliveira', 'maria@email.com', 'Campinas', 'SP');

-- Inserir múltiplos registros de uma vez
INSERT INTO clientes (nome, email, cidade, estado) VALUES
    ('Pedro Santos',  'pedro@email.com',  'Florianópolis', 'SC'),
    ('Laura Mendes',  'laura@email.com',  'Goiânia',       'GO');


-- -------------------------------------------------------------
-- 3. SELECT — lendo registros (READ do CRUD)
-- -------------------------------------------------------------

-- Selecionar tudo
SELECT * FROM clientes;

-- Selecionar colunas específicas
SELECT nome, email FROM clientes;

-- Filtrar com WHERE
SELECT * FROM clientes WHERE estado = 'SP';

-- Ordenar resultados
SELECT * FROM clientes ORDER BY nome ASC;


-- -------------------------------------------------------------
-- 4. UPDATE — atualizando registros
-- -------------------------------------------------------------

-- ATENÇÃO: sempre use WHERE no UPDATE!
-- Sem WHERE, você atualiza TODOS os registros.

-- Atualizar o email de um cliente específico
UPDATE clientes
SET email = 'ana.silva@email.com'
WHERE id = 1;

-- Verificar a mudança
SELECT id, nome, email FROM clientes WHERE id = 1;


-- -------------------------------------------------------------
-- 5. DELETE — removendo registros
-- -------------------------------------------------------------

-- ATENÇÃO: sempre use WHERE no DELETE!
-- Sem WHERE, você apaga TODA a tabela.

-- Apagar um registro específico
DELETE FROM clientes WHERE email = 'maria@email.com';

-- Verificar
SELECT * FROM clientes WHERE email = 'maria@email.com';


-- -------------------------------------------------------------
-- 6. TRANSAÇÕES — ACID na prática
-- -------------------------------------------------------------

-- BEGIN inicia uma transação
-- COMMIT confirma todas as operações
-- ROLLBACK cancela tudo se algo der errado

BEGIN;
    INSERT INTO clientes (nome, email, cidade, estado)
    VALUES ('Teste Transacao', 'teste@email.com', 'SP', 'SP');

    -- Simular uma validação. Se der erro, faz rollback.
    -- ROLLBACK; -- descomente para cancelar

COMMIT; -- confirma a inserção


-- -------------------------------------------------------------
-- 7. DROP TABLE — removendo estrutura (cuidado!)
-- -------------------------------------------------------------

-- Remove a tabela que criamos nesta aula
DROP TABLE IF EXISTS categorias;
