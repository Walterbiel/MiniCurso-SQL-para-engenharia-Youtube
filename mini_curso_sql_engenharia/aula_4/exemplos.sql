-- =============================================================
-- AULA 4: Index, Constraints e Partições
-- Pré-requisito: execute banco.sql antes
-- =============================================================


-- -------------------------------------------------------------
-- 1. ÍNDICES
-- -------------------------------------------------------------

-- Verificar se uma query faz full scan (sem índice)
EXPLAIN SELECT * FROM pedidos WHERE cliente_id = 5;

-- Criar índice na coluna cliente_id
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);

-- Verificar agora — deve usar o índice
EXPLAIN SELECT * FROM pedidos WHERE cliente_id = 5;


-- Índice em coluna de data (muito comum em dados)
CREATE INDEX idx_pedidos_data ON pedidos(criado_em);

-- Query com range de datas agora usa o índice
EXPLAIN SELECT * FROM pedidos
WHERE criado_em BETWEEN '2023-01-01' AND '2023-06-30';


-- Índice composto: útil para queries com dois filtros juntos
CREATE INDEX idx_pedidos_cliente_status ON pedidos(cliente_id, status);

EXPLAIN SELECT * FROM pedidos
WHERE cliente_id = 1 AND status = 'pago';


-- Ver todos os índices de uma tabela
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'pedidos';


-- Remover índice
DROP INDEX IF EXISTS idx_pedidos_cliente;
DROP INDEX IF EXISTS idx_pedidos_data;
DROP INDEX IF EXISTS idx_pedidos_cliente_status;


-- -------------------------------------------------------------
-- 2. CONSTRAINTS
-- -------------------------------------------------------------

-- Criando tabela com todas as constraints
CREATE TABLE fornecedores (
    id        SERIAL PRIMARY KEY,                          -- PRIMARY KEY
    cnpj      VARCHAR(18) NOT NULL UNIQUE,                 -- NOT NULL + UNIQUE
    nome      VARCHAR(100) NOT NULL,
    email     VARCHAR(100),
    ativo     BOOLEAN DEFAULT TRUE,                        -- DEFAULT
    criado_em DATE DEFAULT CURRENT_DATE
);

-- CHECK constraint: garante que o valor é válido
CREATE TABLE contratos (
    id           SERIAL PRIMARY KEY,
    fornecedor_id INT REFERENCES fornecedores(id),         -- FOREIGN KEY
    valor        NUMERIC(12, 2) CHECK (valor > 0),         -- CHECK
    data_inicio  DATE NOT NULL,
    data_fim     DATE,
    CHECK (data_fim IS NULL OR data_fim > data_inicio)     -- CHECK entre colunas
);

-- Testar constraints

-- Isso vai funcionar
INSERT INTO fornecedores (cnpj, nome) VALUES ('12.345.678/0001-99', 'Fornecedor A');

-- Isso vai falhar (UNIQUE violation)
-- INSERT INTO fornecedores (cnpj, nome) VALUES ('12.345.678/0001-99', 'Outro');

-- Isso vai falhar (NOT NULL violation)
-- INSERT INTO fornecedores (cnpj, nome) VALUES (NULL, 'Sem CNPJ');


-- Adicionar constraint em tabela existente
ALTER TABLE produtos ADD CONSTRAINT chk_preco_positivo CHECK (preco > 0);
ALTER TABLE pedidos  ADD CONSTRAINT chk_quantidade_positiva CHECK (quantidade > 0);

-- Ver constraints de uma tabela
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'pedidos';

-- Remover constraint
ALTER TABLE produtos DROP CONSTRAINT IF EXISTS chk_preco_positivo;
ALTER TABLE pedidos  DROP CONSTRAINT IF EXISTS chk_quantidade_positiva;


-- -------------------------------------------------------------
-- 3. PARTICIONAMENTO (RANGE por data)
-- -------------------------------------------------------------

-- Criar tabela particionada por ano
DROP TABLE IF EXISTS pedidos_particionados;

CREATE TABLE pedidos_particionados (
    id           SERIAL,
    cliente_id   INT,
    produto_id   INT,
    total        NUMERIC(10, 2),
    status       VARCHAR(20),
    criado_em    DATE NOT NULL
) PARTITION BY RANGE (criado_em);


-- Criar as partições (uma por ano)
CREATE TABLE pedidos_2023
    PARTITION OF pedidos_particionados
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE pedidos_2024
    PARTITION OF pedidos_particionados
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');


-- Inserir dados na tabela principal (vai para a partição certa automaticamente)
INSERT INTO pedidos_particionados (cliente_id, produto_id, total, status, criado_em)
SELECT cliente_id, produto_id, total, status, criado_em FROM pedidos;

-- Consultar normalmente (o banco decide qual partição ler)
SELECT * FROM pedidos_particionados WHERE criado_em >= '2023-01-01';

-- Ver qual partição será usada
EXPLAIN SELECT * FROM pedidos_particionados
WHERE criado_em BETWEEN '2023-01-01' AND '2023-12-31';

-- Ver as partições existentes
SELECT inhrelid::regclass AS particao
FROM pg_inherits
WHERE inhparent = 'pedidos_particionados'::regclass;


-- -------------------------------------------------------------
-- 4. Limpeza
-- -------------------------------------------------------------
DROP TABLE IF EXISTS contratos;
DROP TABLE IF EXISTS fornecedores;
DROP TABLE IF EXISTS pedidos_particionados CASCADE;
