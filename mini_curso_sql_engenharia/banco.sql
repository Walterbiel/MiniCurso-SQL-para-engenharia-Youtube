-- ============================================
-- SETUP: Mini Curso SQL para Engenharia de Dados
-- Arquivo: banco.sql
-- ⏱️  Tempo estimado: 5 minutos (executar antes das aulas)
-- 📍 Execute este arquivo PRIMEIRO, antes de qualquer aula
-- ============================================
-- Este script cria dois bancos:
--   loja_db  → banco OLTP usado nas aulas 1 a 4
--   dw_loja  → Data Warehouse usado na aula 5

-- ═══════════════════════════════════════════
-- PARTE 1: BANCO OLTP — loja_db
-- ═══════════════════════════════════════════

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'loja_db')
    CREATE DATABASE loja_db;
GO

USE loja_db;
GO

-- Limpeza (permite reexecutar o script sem erro)
IF OBJECT_ID('itens_pedido', 'U') IS NOT NULL DROP TABLE itens_pedido;
IF OBJECT_ID('pedidos',      'U') IS NOT NULL DROP TABLE pedidos;
IF OBJECT_ID('produtos',     'U') IS NOT NULL DROP TABLE produtos;
IF OBJECT_ID('categorias',   'U') IS NOT NULL DROP TABLE categorias;
IF OBJECT_ID('clientes',     'U') IS NOT NULL DROP TABLE clientes;
GO

-- ─────────────────────────────────────────
-- TABELA: clientes
-- ─────────────────────────────────────────
CREATE TABLE clientes (
    id_cliente    INT          PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    email         VARCHAR(100) UNIQUE,
    cidade        VARCHAR(50),
    uf            CHAR(2),
    data_cadastro DATE         NOT NULL
);

-- ─────────────────────────────────────────
-- TABELA: categorias
-- ─────────────────────────────────────────
CREATE TABLE categorias (
    id_categoria INT         PRIMARY KEY,
    nome         VARCHAR(50) NOT NULL
);

-- ─────────────────────────────────────────
-- TABELA: produtos
-- ─────────────────────────────────────────
CREATE TABLE produtos (
    id_produto   INT           PRIMARY KEY,
    nome         VARCHAR(100)  NOT NULL,
    id_categoria INT           NOT NULL,
    preco        DECIMAL(10,2) NOT NULL,
    estoque      INT           NOT NULL DEFAULT 0,
    CONSTRAINT fk_produto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    CONSTRAINT chk_preco_positivo   CHECK (preco > 0)
);

-- ─────────────────────────────────────────
-- TABELA: pedidos
-- ─────────────────────────────────────────
CREATE TABLE pedidos (
    id_pedido   INT           PRIMARY KEY,
    id_cliente  INT           NOT NULL,
    data_pedido DATE          NOT NULL,
    status      VARCHAR(20)   NOT NULL DEFAULT 'pendente',
    valor_total DECIMAL(10,2),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT chk_status CHECK (status IN ('pendente','aprovado','enviado','entregue','cancelado'))
);

-- ─────────────────────────────────────────
-- TABELA: itens_pedido
-- ─────────────────────────────────────────
CREATE TABLE itens_pedido (
    id_item        INT           PRIMARY KEY,
    id_pedido      INT           NOT NULL,
    id_produto     INT           NOT NULL,
    quantidade     INT           NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_item_pedido  FOREIGN KEY (id_pedido)  REFERENCES pedidos(id_pedido),
    CONSTRAINT fk_item_produto FOREIGN KEY (id_produto) REFERENCES produtos(id_produto),
    CONSTRAINT chk_qtd_positiva CHECK (quantidade > 0)
);
GO

-- ─────────────────────────────────────────
-- DADOS: clientes
-- ─────────────────────────────────────────
INSERT INTO clientes VALUES
(1,  'Ana Lima',      'ana@email.com',   'São Paulo',      'SP', '2023-01-10'),
(2,  'Bruno Santos',  'bruno@email.com', 'Rio de Janeiro', 'RJ', '2023-02-15'),
(3,  'Carla Souza',   'carla@email.com', 'Belo Horizonte', 'MG', '2023-03-20'),
(4,  'Diego Rocha',   'diego@email.com', 'Curitiba',       'PR', '2023-04-05'),
(5,  'Elena Martins', 'elena@email.com', 'Porto Alegre',   'RS', '2023-05-12'),
(6,  'Fábio Costa',   'fabio@email.com', 'Salvador',       'BA', '2023-06-01'),
(7,  'Gabi Ferreira', 'gabi@email.com',  'São Paulo',      'SP', '2023-07-18'),
(8,  'Hugo Neves',    'hugo@email.com',  'Recife',         'PE', '2023-08-22'),
(9,  'Isabela Pinto', 'isa@email.com',   'Fortaleza',      'CE', '2023-09-30'),
(10, 'João Alves',    'joao@email.com',  'São Paulo',      'SP', '2023-10-14');

-- ─────────────────────────────────────────
-- DADOS: categorias
-- ─────────────────────────────────────────
INSERT INTO categorias VALUES
(1, 'Eletrônicos'),
(2, 'Roupas'),
(3, 'Alimentos'),
(4, 'Livros'),
(5, 'Casa e Jardim');

-- ─────────────────────────────────────────
-- DADOS: produtos
-- ─────────────────────────────────────────
INSERT INTO produtos VALUES
(1,  'Notebook Pro',        1, 3500.00, 15),
(2,  'Smartphone X',        1, 1800.00, 30),
(3,  'Fone Bluetooth',      1,  250.00, 50),
(4,  'Camiseta Casual',     2,   89.90, 100),
(5,  'Calça Jeans',         2,  199.90, 80),
(6,  'Tênis Running',       2,  349.90, 45),
(7,  'Café Especial 500g',  3,   45.00, 200),
(8,  'Azeite Extra 500ml',  3,   38.50, 150),
(9,  'SQL para Devs',       4,   79.90, 60),
(10, 'Engenharia de Dados', 4,   89.90, 40),
(11, 'Luminária LED',       5,  120.00, 35),
(12, 'Vaso Decorativo',     5,   65.00, 25);

-- ─────────────────────────────────────────
-- DADOS: pedidos
-- ─────────────────────────────────────────
INSERT INTO pedidos VALUES
(1,  1, '2024-01-05', 'entregue',  3750.00),
(2,  2, '2024-01-10', 'entregue',  1850.00),
(3,  3, '2024-01-15', 'entregue',   289.90),
(4,  1, '2024-02-01', 'entregue',   349.90),
(5,  4, '2024-02-10', 'enviado',    269.80),
(6,  5, '2024-02-20', 'aprovado',  3500.00),
(7,  6, '2024-03-01', 'entregue',   289.80),
(8,  7, '2024-03-10', 'entregue',   460.00),
(9,  8, '2024-03-15', 'cancelado',  199.90),
(10, 9, '2024-04-01', 'entregue',  1800.00),
(11, 10,'2024-04-10', 'entregue',   214.80),
(12, 1, '2024-04-20', 'aprovado',   167.00),
(13, 2, '2024-05-05', 'entregue',   349.90),
(14, 3, '2024-05-15', 'enviado',    250.00),
(15, 5, '2024-05-20', 'entregue',   157.90);

-- ─────────────────────────────────────────
-- DADOS: itens_pedido
-- ─────────────────────────────────────────
INSERT INTO itens_pedido VALUES
(1,  1,  1, 1, 3500.00),  -- Notebook
(2,  1,  3, 1,  250.00),  -- Fone
(3,  2,  2, 1, 1800.00),  -- Smartphone
(4,  2,  7, 1,   45.00),  -- Café
(5,  3,  4, 1,   89.90),  -- Camiseta
(6,  3,  8, 2,   38.50),  -- 2x Azeite
(7,  3,  7, 2,   45.00),  -- 2x Café
(8,  4,  6, 1,  349.90),  -- Tênis
(9,  5,  4, 1,   89.90),  -- Camiseta
(10, 5,  7, 4,   45.00),  -- 4x Café
(11, 6,  1, 1, 3500.00),  -- Notebook
(12, 7,  4, 1,   89.90),  -- Camiseta
(13, 7,  8, 5,   38.50),  -- 5x Azeite
(14, 8, 11, 1,  120.00),  -- Luminária
(15, 8,  3, 1,  250.00),  -- Fone
(16, 8,  7, 2,   45.00),  -- 2x Café
(17, 9,  5, 1,  199.90),  -- Calça
(18,10,  2, 1, 1800.00),  -- Smartphone
(19,11,  9, 1,   79.90),  -- Livro SQL
(20,11, 10, 1,   89.90),  -- Livro Eng Dados
(21,11,  7, 1,   45.00),  -- Café
(22,12,  7, 2,   45.00),  -- 2x Café
(23,12,  8, 2,   38.50),  -- 2x Azeite
(24,13,  6, 1,  349.90),  -- Tênis
(25,14,  3, 1,  250.00),  -- Fone
(26,15,  9, 1,   79.90),  -- Livro SQL
(27,15,  8, 2,   38.50);  -- 2x Azeite
GO

PRINT '✅ loja_db criado com sucesso!';
GO

-- ═══════════════════════════════════════════
-- PARTE 2: DATA WAREHOUSE — dw_loja (Aula 5)
-- ═══════════════════════════════════════════

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'dw_loja')
    CREATE DATABASE dw_loja;
GO

USE dw_loja;
GO

IF OBJECT_ID('fato_vendas', 'U') IS NOT NULL DROP TABLE fato_vendas;
IF OBJECT_ID('dim_tempo',   'U') IS NOT NULL DROP TABLE dim_tempo;
IF OBJECT_ID('dim_produto', 'U') IS NOT NULL DROP TABLE dim_produto;
IF OBJECT_ID('dim_cliente', 'U') IS NOT NULL DROP TABLE dim_cliente;
IF OBJECT_ID('stg_pedidos', 'U') IS NOT NULL DROP TABLE stg_pedidos;
GO

-- Área de staging: entrada dos dados brutos vindos do OLTP
CREATE TABLE stg_pedidos (
    id_pedido     INT,
    id_cliente    INT,
    nome_cliente  VARCHAR(100),
    cidade        VARCHAR(50),
    uf            CHAR(2),
    id_produto    INT,
    nome_produto  VARCHAR(100),
    categoria     VARCHAR(50),
    preco_produto DECIMAL(10,2),
    data_pedido   DATE,
    quantidade    INT,
    valor         DECIMAL(10,2),
    data_carga    DATETIME DEFAULT GETDATE()
);

-- Dimensão cliente (suporta SCD Tipo 2)
CREATE TABLE dim_cliente (
    sk_cliente        INT IDENTITY(1,1) PRIMARY KEY,  -- surrogate key
    id_cliente_origem INT          NOT NULL,            -- chave do OLTP
    nome              VARCHAR(100),
    cidade            VARCHAR(50),
    uf                CHAR(2),
    data_inicio       DATE         NOT NULL,
    data_fim          DATE,                             -- NULL = registro ativo
    ativo             BIT          NOT NULL DEFAULT 1
);

-- Dimensão produto (suporta SCD Tipo 2)
CREATE TABLE dim_produto (
    sk_produto        INT IDENTITY(1,1) PRIMARY KEY,
    id_produto_origem INT           NOT NULL,
    nome              VARCHAR(100),
    categoria         VARCHAR(50),
    preco             DECIMAL(10,2),
    data_inicio       DATE          NOT NULL,
    data_fim          DATE,
    ativo             BIT           NOT NULL DEFAULT 1
);

-- Dimensão tempo (grain = dia)
CREATE TABLE dim_tempo (
    sk_tempo   INT PRIMARY KEY,  -- formato YYYYMMDD: 20240105
    data       DATE NOT NULL,
    ano        INT,
    mes        INT,
    dia        INT,
    trimestre  INT,
    nome_mes   VARCHAR(20),
    dia_semana VARCHAR(20)
);

-- Tabela fato
CREATE TABLE fato_vendas (
    sk_venda         INT IDENTITY(1,1) PRIMARY KEY,
    sk_cliente       INT NOT NULL,
    sk_produto       INT NOT NULL,
    sk_tempo         INT NOT NULL,
    id_pedido_origem INT,
    quantidade       INT,
    valor            DECIMAL(10,2),
    FOREIGN KEY (sk_cliente) REFERENCES dim_cliente(sk_cliente),
    FOREIGN KEY (sk_produto) REFERENCES dim_produto(sk_produto),
    FOREIGN KEY (sk_tempo)   REFERENCES dim_tempo(sk_tempo)
);
GO

-- Popula dim_tempo com todos os dias de 2024
INSERT INTO dim_tempo (sk_tempo, data, ano, mes, dia, trimestre, nome_mes, dia_semana)
SELECT
    CAST(FORMAT(d, 'yyyyMMdd') AS INT),
    d,
    YEAR(d),
    MONTH(d),
    DAY(d),
    DATEPART(QUARTER, d),
    DATENAME(MONTH, d),
    DATENAME(WEEKDAY, d)
FROM (
    SELECT DATEADD(DAY, n, '2023-12-31') AS d
    FROM (
        SELECT TOP 366 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
        FROM sys.objects a CROSS JOIN sys.objects b
    ) AS nums
    WHERE YEAR(DATEADD(DAY, n, '2023-12-31')) = 2024
) AS dias;
GO

PRINT '✅ dw_loja criado com sucesso!';
PRINT '';
PRINT '▶ Próximo passo: execute aula_1/exemplos.sql';
GO
