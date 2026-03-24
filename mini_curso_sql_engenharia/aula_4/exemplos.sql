-- ============================================
-- AULA 4: Index e Constraints
-- Arquivo: aula_4/exemplos.sql
-- ⏱️  Tempo estimado: 25 minutos
-- 📍 Posição no roteiro: Parte 4 de 5
-- ============================================
-- Objetivo: Garantir performance e qualidade dos dados.
-- Pré-requisito: execute banco.sql antes desta aula.

USE loja_db;
GO

-- ═══════════════════════════════════════════
-- PARTE 1: ÍNDICES
-- ═══════════════════════════════════════════

-- ─────────────────────────────────────────
-- BLOCO 1: O que é índice e como o banco o usa
-- O que vamos aprender: índice = sumário que acelera a busca
-- ⏱️ ~5 minutos
-- ─────────────────────────────────────────

-- Sem índice: o banco lê TODAS as linhas para encontrar o dado (table scan)
-- Com índice: o banco vai direto ao dado (index seek)

-- Analogia: imagine buscar um nome em um livro sem índice remissivo
-- vs buscar no índice e ir direto à página certa.

-- Ver os índices existentes na tabela clientes
SELECT
    i.name          AS nome_indice,
    i.type_desc     AS tipo,
    i.is_primary_key,
    i.is_unique,
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS colunas
FROM sys.indexes     AS i
JOIN sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns     AS c  ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'clientes'
GROUP BY i.name, i.type_desc, i.is_primary_key, i.is_unique;

-- 💡 O que acontece se mudar?
-- Troque 'clientes' por 'pedidos' ou 'produtos' — veja os índices de cada tabela


-- ─────────────────────────────────────────
-- BLOCO 2: Clustered vs Nonclustered
-- O que vamos aprender: clustered organiza os dados; nonclustered é uma estrutura separada
-- ⏱️ ~8 minutos
-- ─────────────────────────────────────────

-- CLUSTERED INDEX:
-- → Os dados da tabela ficam fisicamente ordenados por esse índice
-- → Cada tabela pode ter APENAS 1 clustered index
-- → Normalmente é a PRIMARY KEY

-- Exemplo: a tabela pedidos já tem clustered index na PK (id_pedido)
-- O banco armazena os pedidos ordenados por id_pedido fisicamente no disco

-- NONCLUSTERED INDEX:
-- → Estrutura separada que aponta para os dados
-- → Uma tabela pode ter vários nonclustered indexes
-- → Ideal para colunas muito usadas em WHERE, JOIN e ORDER BY

-- Criando um nonclustered index na coluna data_pedido
-- (busca por período é muito comum em análise de dados)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_pedidos_data' AND OBJECT_NAME(object_id) = 'pedidos'
)
    CREATE NONCLUSTERED INDEX idx_pedidos_data
    ON pedidos (data_pedido);

-- Criando índice composto: status + data_pedido
-- Útil quando filtramos por status E período ao mesmo tempo
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_pedidos_status_data' AND OBJECT_NAME(object_id) = 'pedidos'
)
    CREATE NONCLUSTERED INDEX idx_pedidos_status_data
    ON pedidos (status, data_pedido);

-- Criando índice com INCLUDE: evita ir à tabela para buscar valor_total
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_pedidos_cliente' AND OBJECT_NAME(object_id) = 'pedidos'
)
    CREATE NONCLUSTERED INDEX idx_pedidos_cliente
    ON pedidos (id_cliente)
    INCLUDE (data_pedido, valor_total, status);  -- colunas extras no índice

-- Consultas que agora usam os índices criados:
SELECT id_pedido, status, valor_total
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-03-31';  -- usa idx_pedidos_data

SELECT id_pedido, data_pedido, valor_total
FROM pedidos
WHERE id_cliente = 1;  -- usa idx_pedidos_cliente (com INCLUDE)

-- 💡 O que acontece se mudar?
-- Crie um índice em clientes.cidade e em clientes.uf
-- Pense: quais colunas de itens_pedido merecem índice?


-- ─────────────────────────────────────────
-- BLOCO 3: Impacto em leitura e escrita
-- O que vamos aprender: mais índice não é sempre melhor
-- ⏱️ ~4 minutos
-- ─────────────────────────────────────────

-- LEITURA (SELECT): índice melhora — o banco vai direto ao dado
-- ESCRITA (INSERT/UPDATE/DELETE): índice piora — o banco precisa atualizar cada índice

-- Regra prática para engenharia de dados:
--   - Colunas de filtro (WHERE): criar índice
--   - Colunas de JOIN: criar índice
--   - Colunas de ORDER BY em relatórios: criar índice
--   - Tabelas de staging (carga em massa): REMOVER índices antes, criar depois

-- Ver todos os índices da tabela pedidos com seus tipos
SELECT
    i.name         AS nome_indice,
    i.type_desc    AS tipo,
    i.is_unique,
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS colunas_chave
FROM sys.indexes       AS i
JOIN sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
                              AND ic.is_included_column = 0
JOIN sys.columns       AS c  ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'pedidos'
GROUP BY i.name, i.type_desc, i.is_unique;

-- 💡 O que acontece se mudar?
-- Uma tabela de staging que recebe 10 milhões de linhas por dia
-- Se tiver 5 índices, cada INSERT atualiza 6 estruturas (tabela + 5 índices)
-- Solução: DROP INDEX antes da carga, CREATE INDEX depois


-- ═══════════════════════════════════════════
-- PARTE 2: CONSTRAINTS
-- ═══════════════════════════════════════════

-- ─────────────────────────────────────────
-- BLOCO 4: Constraints — regras de qualidade no banco
-- O que vamos aprender: constraints protegem a integridade dos dados na fonte
-- ⏱️ ~8 minutos
-- ─────────────────────────────────────────

-- Ver as constraints existentes no banco
SELECT
    tc.CONSTRAINT_NAME  AS constraint,
    tc.CONSTRAINT_TYPE  AS tipo,
    tc.TABLE_NAME       AS tabela,
    kcu.COLUMN_NAME     AS coluna
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS      AS tc
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE       AS kcu
     ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    AND tc.TABLE_NAME      = kcu.TABLE_NAME
ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_TYPE;

-- PRIMARY KEY — identidade única da linha (já vimos na aula 1)
-- Não permite NULL, não permite duplicata
-- Cada tabela tem exatamente uma PK

-- UNIQUE — unicidade sem ser PK (permite ONE NULL em SQL Server)
-- Exemplo: email de cliente deve ser único, mas não é a PK
SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_NAME = 'clientes' AND CONSTRAINT_TYPE = 'UNIQUE';

-- Testando: tentativa de email duplicado
-- INSERT INTO clientes VALUES (20, 'Teste', 'ana@email.com', 'SP', 'SP', '2024-01-01');
-- Erro: "Cannot insert duplicate key row in object 'dbo.clientes' with unique index"

-- FOREIGN KEY — integridade referencial (já vimos na aula 1)
-- Garante que a referência sempre exista
SELECT
    fk.name                       AS constraint_name,
    OBJECT_NAME(fk.parent_object_id)     AS tabela_origem,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id)   AS coluna_origem,
    OBJECT_NAME(fk.referenced_object_id) AS tabela_destino
FROM sys.foreign_keys     AS fk
JOIN sys.foreign_key_columns AS fkc ON fk.object_id = fkc.constraint_object_id;

-- NOT NULL — campo obrigatório
-- Em produtos, nome e preco são NOT NULL
-- INSERT INTO produtos VALUES (99, NULL, 1, 100, 0);  → erro: "Cannot insert the value NULL"

-- CHECK — regra de domínio definida em SQL
-- Exemplos já criados no banco.sql:
--   chk_preco_positivo: preco > 0
--   chk_qtd_positiva:   quantidade > 0
--   chk_status:         status IN ('pendente','aprovado','enviado','entregue','cancelado')

-- Ver todas as CHECK constraints
SELECT
    cc.CONSTRAINT_NAME,
    cc.TABLE_NAME,
    cc.CHECK_CLAUSE
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS AS cc
JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
     ON cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME;

-- Testando: preço negativo
-- INSERT INTO produtos VALUES (99, 'Teste', 1, -50, 0);
-- Erro: "The INSERT statement conflicted with the CHECK constraint 'chk_preco_positivo'"

-- Adicionando uma nova CHECK constraint
ALTER TABLE clientes
ADD CONSTRAINT chk_uf_valido
CHECK (uf IN ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS',
              'MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC',
              'SP','SE','TO'));

-- Testando a nova constraint
-- INSERT INTO clientes VALUES (20, 'Teste', 'xx@email.com', 'XX', 'ZZ', '2024-01-01');
-- Erro: conflito com chk_uf_valido

-- Removendo a constraint (só para manter o banco limpo)
ALTER TABLE clientes DROP CONSTRAINT chk_uf_valido;

-- 💡 O que acontece se mudar?
-- Crie uma CHECK constraint em pedidos para garantir que valor_total >= 0
-- Pense: qual constraint protegeria contra um estoque negativo em produtos?
GO
