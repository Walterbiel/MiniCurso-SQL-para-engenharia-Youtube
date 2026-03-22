-- =============================================================
-- BANCO DE DADOS DE EXEMPLO: E-commerce simples
-- Execute este arquivo antes de começar qualquer aula
-- =============================================================

-- Limpa as tabelas se já existirem
DROP TABLE IF EXISTS pedidos;
DROP TABLE IF EXISTS produtos;
DROP TABLE IF EXISTS clientes;

-- -------------------------------------------------------------
-- TABELA: clientes
-- -------------------------------------------------------------
CREATE TABLE clientes (
    id         SERIAL PRIMARY KEY,
    nome       VARCHAR(100) NOT NULL,
    email      VARCHAR(100) UNIQUE NOT NULL,
    cidade     VARCHAR(50),
    estado     VARCHAR(2),
    criado_em  DATE DEFAULT CURRENT_DATE
);

-- -------------------------------------------------------------
-- TABELA: produtos
-- -------------------------------------------------------------
CREATE TABLE produtos (
    id         SERIAL PRIMARY KEY,
    nome       VARCHAR(100) NOT NULL,
    categoria  VARCHAR(50),
    preco      NUMERIC(10, 2) NOT NULL,
    estoque    INT DEFAULT 0
);

-- -------------------------------------------------------------
-- TABELA: pedidos
-- -------------------------------------------------------------
CREATE TABLE pedidos (
    id           SERIAL PRIMARY KEY,
    cliente_id   INT REFERENCES clientes(id),
    produto_id   INT REFERENCES produtos(id),
    quantidade   INT NOT NULL DEFAULT 1,
    total        NUMERIC(10, 2),
    status       VARCHAR(20) DEFAULT 'pendente', -- pendente, pago, cancelado
    criado_em    DATE DEFAULT CURRENT_DATE
);

-- =============================================================
-- DADOS DE EXEMPLO
-- =============================================================

INSERT INTO clientes (nome, email, cidade, estado, criado_em) VALUES
    ('Ana Silva',      'ana@email.com',     'São Paulo',      'SP', '2023-01-10'),
    ('Bruno Costa',    'bruno@email.com',   'Rio de Janeiro', 'RJ', '2023-02-15'),
    ('Carla Souza',    'carla@email.com',   'Curitiba',       'PR', '2023-03-20'),
    ('Diego Lima',     'diego@email.com',   'Salvador',       'BA', '2023-04-05'),
    ('Elena Rocha',    'elena@email.com',   'Belo Horizonte', 'MG', '2023-05-12'),
    ('Felipe Nunes',   'felipe@email.com',  'Fortaleza',      'CE', '2023-06-01'),
    ('Gabi Ferreira',  'gabi@email.com',    'Porto Alegre',   'RS', '2023-07-18'),
    ('Hugo Alves',     'hugo@email.com',    'Recife',         'PE', '2023-08-22'),
    ('Iris Martins',   'iris@email.com',    'Manaus',         'AM', '2023-09-09'),
    ('João Pereira',   'joao@email.com',    'São Paulo',      'SP', '2023-10-30');

INSERT INTO produtos (nome, categoria, preco, estoque) VALUES
    ('Notebook Dell',     'Eletrônicos',   3500.00, 15),
    ('Mouse Logitech',    'Periféricos',     89.90,  80),
    ('Teclado Mecânico',  'Periféricos',    299.00,  40),
    ('Monitor 24"',       'Eletrônicos',    999.00,  20),
    ('Cadeira Gamer',     'Móveis',        1200.00,  10),
    ('Headset Sony',      'Eletrônicos',    450.00,  35),
    ('Webcam Logitech',   'Periféricos',    280.00,  50),
    ('HD Externo 1TB',    'Armazenamento',  320.00,  60),
    ('Pendrive 64GB',     'Armazenamento',   45.00, 120),
    ('Suporte Notebook',  'Acessórios',     150.00,  30);

INSERT INTO pedidos (cliente_id, produto_id, quantidade, total, status, criado_em) VALUES
    (1,  1,  1,  3500.00, 'pago',       '2023-01-15'),
    (1,  2,  2,   179.80, 'pago',       '2023-02-10'),
    (2,  3,  1,   299.00, 'pago',       '2023-02-20'),
    (2,  4,  1,   999.00, 'pendente',   '2023-03-05'),
    (3,  5,  1,  1200.00, 'pago',       '2023-03-15'),
    (3,  6,  2,   900.00, 'pago',       '2023-04-01'),
    (4,  7,  1,   280.00, 'cancelado',  '2023-04-10'),
    (4,  8,  3,   960.00, 'pago',       '2023-05-05'),
    (5,  9,  5,   225.00, 'pago',       '2023-05-20'),
    (5, 10,  1,   150.00, 'pago',       '2023-06-01'),
    (6,  1,  1,  3500.00, 'pago',       '2023-06-15'),
    (6,  2,  1,    89.90, 'pendente',   '2023-07-01'),
    (7,  3,  2,   598.00, 'pago',       '2023-07-10'),
    (7,  4,  1,   999.00, 'pago',       '2023-08-05'),
    (8,  5,  1,  1200.00, 'cancelado',  '2023-08-20'),
    (8,  6,  1,   450.00, 'pago',       '2023-09-01'),
    (9,  7,  3,   840.00, 'pago',       '2023-09-15'),
    (9,  8,  1,   320.00, 'pago',       '2023-10-01'),
    (10, 9,  2,    90.00, 'pago',       '2023-10-20'),
    (10, 1,  1,  3500.00, 'pago',       '2023-11-01'),
    (1,  5,  1,  1200.00, 'pago',       '2023-11-15'),
    (2,  6,  2,   900.00, 'pago',       '2023-12-01'),
    (3,  2,  4,   359.60, 'pago',       '2023-12-10'),
    (4,  3,  1,   299.00, 'pendente',   '2024-01-05'),
    (5,  1,  1,  3500.00, 'pago',       '2024-01-20');
