# AULA 4 — Performance e Qualidade: Índices e Constraints
**⏱️ ~25 min** | SQL Server (T-SQL) | Arquivo de código: [`exemplos.sql`](exemplos.sql)

> **Abertura — falar:**
> "Duas coisas que diferenciam um banco de produção de um banco de desenvolvimento: performance de leitura e qualidade dos dados. Índice garante que a leitura seja rápida. Constraint garante que o dado que entrou é válido. Esses dois juntos fazem a diferença entre um banco funcional e um banco confiável."

---

## Checklist antes de começar

- [ ] `banco.sql` já foi executado
- [ ] `loja_db` selecionada como database ativa

---

## 4.1 — O que é índice e por que importa

**Conceito para falar:**
"Pensa em uma tabela como um livro sem sumário. Para achar uma informação, você lê página por página. No banco, isso se chama *full table scan* — o banco lê todas as linhas da tabela para encontrar o que você quer."

"Com índice, é como ter o índice remissivo do livro — você vai direto na linha certa. Em tabelas grandes, a diferença é de segundos vs milissegundos, ou de minutos vs segundos."

"Todo mundo que cria uma Primary Key automaticamente cria um índice do tipo CLUSTERED — o banco faz isso sem você precisar pedir. Mas outras colunas que você usa com frequência em WHERE, JOIN e ORDER BY precisam de índices extras."

```sql
USE loja_db;

-- Ver os índices existentes em uma tabela
SELECT
    i.name              AS nome_indice,
    i.type_desc         AS tipo_indice,
    i.is_primary_key    AS eh_pk,
    i.is_unique         AS eh_unico,
    STRING_AGG(c.name, ', ')
        WITHIN GROUP (ORDER BY ic.key_ordinal) AS colunas_indexadas
FROM sys.indexes       AS i
JOIN sys.index_columns AS ic
     ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns       AS c
     ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'pedidos'
GROUP BY i.name, i.type_desc, i.is_primary_key, i.is_unique;
```

**Apontar:** "A PK já tem índice CLUSTERED automático. As outras colunas — data_pedido, status, id_cliente — ainda não têm. Vamos criar."

---

## 4.2 — Tipos de índice: Clustered vs Nonclustered

**Conceito para falar:**
"CLUSTERED determina a *ordem física dos dados no disco*. A tabela inteira é organizada pela coluna do índice clustered. Por isso só pode ter UM índice clustered por tabela — você não pode ordenar fisicamente os dados de dois jeitos ao mesmo tempo."

"NONCLUSTERED é uma estrutura separada, uma cópia parcial dos dados que aponta para as linhas originais. Pode ter vários por tabela. É o tipo mais comum de índice que você vai criar no dia a dia."

```sql
-- Índice simples em data_pedido
-- Busca por período é uma das queries mais comuns em qualquer sistema
CREATE NONCLUSTERED INDEX idx_pedidos_data
ON pedidos (data_pedido);
```

```sql
-- Índice composto: duas colunas frequentes juntas em WHERE
-- A ordem das colunas importa muito:
-- Coluna mais seletiva primeiro (a que mais filtra linhas)
-- status antes de data_pedido porque filtra mais
CREATE NONCLUSTERED INDEX idx_pedidos_status_data
ON pedidos (status, data_pedido);
```

```sql
-- Índice com INCLUDE (covering index)
-- As colunas no INCLUDE ficam no índice mas não fazem parte da chave de busca
-- Quando a query busca por id_cliente e também precisa de data_pedido, valor_total e status,
-- o banco lê tudo do índice sem precisar voltar à tabela principal (index seek puro)
CREATE NONCLUSTERED INDEX idx_pedidos_cliente_cobrindo
ON pedidos (id_cliente)
INCLUDE (data_pedido, valor_total, status);
```

```sql
-- Com os índices criados, essas queries são muito mais eficientes

-- Usa idx_pedidos_data — evita full scan na tabela de pedidos
SELECT id_pedido, status, valor_total
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-03-31';

-- Usa idx_pedidos_status_data — duas condições no mesmo índice
SELECT id_pedido, data_pedido, valor_total
FROM pedidos
WHERE status = 'entregue'
  AND data_pedido >= '2024-01-01';

-- Usa idx_pedidos_cliente_cobrindo — lê tudo do índice, sem tocar na tabela
SELECT data_pedido, valor_total, status
FROM pedidos
WHERE id_cliente = 3;
```

**Falar:** "Para ver o plano de execução e confirmar qual índice o banco está usando: pressione Ctrl+M antes de executar (ou clique em 'Include Actual Execution Plan'). O ícone de 'Index Seek' confirma uso de índice — muito mais eficiente que 'Table Scan'."

---

## 4.3 — Trade-off: performance de leitura vs escrita

**Conceito para falar — ponto mais importante de índices em engenharia de dados:**
"Mais índice não é sempre melhor. Índice melhora leitura (SELECT) mas piora escrita (INSERT, UPDATE, DELETE). Cada vez que você insere uma linha, o banco precisa atualizar todos os índices da tabela. Uma tabela com 10 índices tem 10 estruturas para manter a cada escrita."

"Em engenharia de dados isso é crítico porque você trabalha com dois cenários opostos:"

**Tabelas de produção (OLTP):**
- Muitas leituras e escritas frequentes
- Crie índices nas colunas certas — colunas de WHERE, JOIN, ORDER BY frequentes
- Colunas com alta cardinalidade (muitos valores distintos) são candidatos melhores

**Tabelas de staging (carga em massa):**
- Você insere milhões de linhas de uma vez
- Estratégia correta: **remova os índices antes da carga, insira tudo, recrie depois**
- Uma tabela de staging com 5 índices e 10 milhões de linhas por dia sente muito o custo de manutenção de índice

**Regra prática:**
- Coluna frequente em WHERE, JOIN ou ORDER BY → crie índice
- Alta cardinalidade (data, id, email) → índice mais eficiente
- Baixa cardinalidade (status com 5 valores, boolean) → índice pouco eficiente, pense antes
- Tabela de staging ou temp → mínimo de índices
- Nunca crie índice em "toda coluna por precaução" — meça o impacto primeiro

---

## 4.4 — Constraints: qualidade de dados garantida pelo banco

**Conceito para falar:**
"Constraint é uma regra de qualidade definida diretamente no banco. Não importa como o dado chegou — via app, via pipeline, via SQL manual — o banco valida antes de aceitar."

"Em pipelines de dados, isso é sua última linha de defesa contra dado ruim. Você pode ter validações no Python, no Airflow, no dbt — mas se uma constraint está no banco, nada passa por ela."

**Tipos de Constraints:**
| Tipo | O que garante |
|------|--------------|
| PRIMARY KEY | Unicidade + NOT NULL na chave |
| FOREIGN KEY | Integridade referencial entre tabelas |
| UNIQUE | Unicidade sem ser PK |
| NOT NULL | Campo obrigatório |
| CHECK | Regra de domínio customizada (qualquer expressão booleana) |
| DEFAULT | Valor padrão quando não informado |

```sql
-- Ver todas as constraints do banco atual
SELECT
    tc.CONSTRAINT_NAME  AS nome_constraint,
    tc.CONSTRAINT_TYPE  AS tipo,
    tc.TABLE_NAME       AS tabela,
    kcu.COLUMN_NAME     AS coluna
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
LEFT JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS kcu
     ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    AND tc.TABLE_NAME      = kcu.TABLE_NAME
ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME;
```

```sql
-- Ver especificamente as CHECK constraints e suas regras de domínio
SELECT
    cc.CONSTRAINT_NAME,
    tc.TABLE_NAME,
    cc.CHECK_CLAUSE     AS regra
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS AS cc
JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
     ON cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
ORDER BY tc.TABLE_NAME;
```

**Apontar:** `chk_preco_positivo`, `chk_qtd_positiva`, `chk_status`. "Essas regras foram definidas no banco.sql desde o início — são as que protegem os dados no negócio."

```sql
-- TESTE 1: preço negativo é rejeitado pelo banco
INSERT INTO produtos
    (id_produto, nome, id_categoria, preco, estoque)
VALUES
    (99, 'Produto Inválido', 1, -50.00, 10);
```

**Apontar:** Erro de CHECK. "O banco rejeita na fonte. Não importa se veio de um script Python, de um form web ou de um pipeline Airflow."

```sql
-- TESTE 2: status inválido é rejeitado
INSERT INTO pedidos
    (id_pedido, id_cliente, data_pedido, status, valor_total)
VALUES
    (99, 1, GETDATE(), 'xyz_invalido', 100.00);
```

**Apontar:** Erro de CHECK. "Status 'xyz_invalido' não está na lista de valores permitidos."

```sql
-- Criando uma CHECK constraint para validar UF brasileira
ALTER TABLE clientes
ADD CONSTRAINT chk_uf_valido
CHECK (uf IN ('AC','AL','AP','AM','BA','CE','DF','ES','GO',
              'MA','MT','MS','MG','PA','PB','PR','PE','PI',
              'RJ','RN','RS','RO','RR','SC','SP','SE','TO'));

-- Testando UF inválida
INSERT INTO clientes
    (id_cliente, nome, email, cidade, uf, data_cadastro)
VALUES
    (20, 'Teste', 'x@x.com', 'Cidade', 'ZZ', '2024-01-01');
```

**Apontar:** Erro de CHECK. "UF 'ZZ' bloqueada pelo banco."

```sql
-- Criando constraint UNIQUE para garantir que email não se repita
ALTER TABLE clientes
ADD CONSTRAINT uq_clientes_email UNIQUE (email);

-- Testando email duplicado
INSERT INTO clientes
    (id_cliente, nome, email, cidade, uf, data_cadastro)
VALUES
    (20, 'Novo Cliente', 'ana.lima@email.com', 'SP', 'SP', CAST(GETDATE() AS DATE));
```

**Apontar:** Erro de UNIQUE se o email já existir. "Garantia de unicidade sem ser PK."

```sql
-- Limpeza das constraints de demonstração
ALTER TABLE clientes DROP CONSTRAINT chk_uf_valido;
ALTER TABLE clientes DROP CONSTRAINT uq_clientes_email;
```

---

## 4.5 — Quando constraints e índices trabalham juntos

**Falar:** "Vale notar: PRIMARY KEY cria automaticamente um índice CLUSTERED. UNIQUE cria automaticamente um índice NONCLUSTERED. Então ao criar essas constraints você ganha a performance do índice automaticamente."

```sql
-- Ver resultado: constraint UNIQUE + índice automático
-- Adiciona e depois remove para mostrar o índice criado automaticamente
ALTER TABLE clientes
ADD CONSTRAINT uq_email_demo UNIQUE (email);

-- Consultar os índices — vai aparecer o índice criado pela constraint
SELECT
    i.name, i.type_desc, i.is_unique
FROM sys.indexes AS i
WHERE OBJECT_NAME(i.object_id) = 'clientes';

-- Remove
ALTER TABLE clientes DROP CONSTRAINT uq_email_demo;
```

---

## Resumo da Aula 4

| Ferramenta | Problema que resolve | Quando usar |
|-----------|---------------------|-------------|
| CLUSTERED INDEX | Organização física dos dados | Automático com PK |
| NONCLUSTERED INDEX | Acesso rápido por colunas específicas | WHERE, JOIN, ORDER BY frequentes |
| INCLUDE no INDEX | Evitar voltar à tabela | Quando a query usa colunas além da chave |
| PRIMARY KEY | Unicidade + identidade | Toda tabela |
| FOREIGN KEY | Integridade referencial | Relacionamentos entre tabelas |
| UNIQUE | Unicidade em campos não-PK | Email, CPF, código |
| CHECK | Regra de domínio | Valores válidos, range, formato |
| NOT NULL | Campo obrigatório | Campos que o negócio exige |

---

> **Encerramento — falar:**
> "Com índice você garante performance. Com constraint você garante qualidade. Juntos, eles fazem a diferença entre um banco que funciona e um banco confiável para produção. Na última aula, a gente conecta tudo isso ao mundo do Data Warehouse — onde todo esse SQL vai ser a ferramenta de movimentação de dados."
