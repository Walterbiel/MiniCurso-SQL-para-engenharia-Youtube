# AULA 1 — Fundamentos de Bancos Relacionais
**⏱️ ~25 min** | SQL Server (T-SQL) | Arquivo de código: [`exemplos.sql`](exemplos.sql)

> **Abertura — falar devagar:**
> "A maioria aprende SQL só dando SELECT. Mas quem trabalha com engenharia de dados precisa entender como o banco funciona por dentro: por que os dados estão organizados daquele jeito, o que garante que eles são válidos, e o que acontece quando você tenta inserir algo errado. Isso é o que muda quem *usa* banco de quem *entende* banco."

---

## Checklist antes de começar

- [ ] `banco.sql` já foi executado — `loja_db` existe no Object Explorer
- [ ] Selecionar `loja_db` como database ativa no SSMS

---

## 1.1 — O que é um Banco Relacional

**Conceito para falar:**
"Um banco relacional organiza dados em tabelas. Cada tabela representa uma entidade do mundo real — clientes, produtos, pedidos. O que torna esse modelo poderoso é que as tabelas se relacionam entre si por meio de chaves. Você não duplica o nome do cliente em cada pedido — você guarda o ID do cliente e busca o nome quando precisa. Isso é normalização."

"Outro ponto importante: o banco guarda *metadados* — dados sobre os próprios dados. Você consegue perguntar pro banco o que ele tem, quais tabelas existem, quais colunas cada tabela tem, quais regras estão definidas. Isso é o que vamos fazer agora."

```sql
USE loja_db;

-- O banco guarda informações sobre si mesmo
-- INFORMATION_SCHEMA é uma view padrão SQL ANSI — funciona em qualquer banco
SELECT
    TABLE_NAME   AS tabela,
    TABLE_TYPE   AS tipo
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
```

**O que apontar no resultado:**
5 tabelas — clientes, categorias, produtos, pedidos, itens_pedido. "Cada uma é uma entidade do negócio."

```sql
-- Agora vamos ver a estrutura detalhada de uma tabela
-- Isso é o que um engenheiro faz antes de qualquer coisa: entende o dado que vai trabalhar
SELECT
    COLUMN_NAME     AS coluna,
    DATA_TYPE       AS tipo_de_dado,
    CHARACTER_MAXIMUM_LENGTH AS tamanho_max,
    IS_NULLABLE     AS aceita_nulo,
    COLUMN_DEFAULT  AS valor_padrao
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'clientes'
ORDER BY ORDINAL_POSITION;
```

**O que apontar:**
- `nome` — NOT NULL. Regra de negócio: cliente sem nome não existe.
- `email` — NULL. Opcional.
- `data_cadastro` — tem `COLUMN_DEFAULT`. Banco preenche sozinho se não vier.

"Repara que isso não é só documentação — essas regras são *enforced* pelo banco. Se você tentar inserir um cliente sem nome, o banco vai rejeitar."

---

## 1.2 — Primary Key: a identidade de cada linha

**Conceito para falar:**
"Todo registro precisa ser identificável de forma única e definitiva. Não pode existir dois clientes com o mesmo ID. A Primary Key garante isso — ela faz duas coisas ao mesmo tempo: garante unicidade (não pode repetir) e garante que o valor não é NULL. E como bônus, o banco automaticamente cria um índice na PK, o que faz busca por ID ser extremamente rápida."

```sql
-- Veja os dados de clientes — o id_cliente é a PK
SELECT
    id_cliente,
    nome,
    email,
    cidade,
    uf
FROM clientes
ORDER BY id_cliente;
```

**Falar:** "10 clientes, IDs de 1 a 10. Agora vamos tentar inserir um com ID que já existe."

```sql
-- Tente executar — vai dar erro
-- Isso é integridade na prática
INSERT INTO clientes
    (id_cliente, nome, email, cidade, uf, data_cadastro)
VALUES
    (1, 'João Duplicado', 'joao2@email.com', 'São Paulo', 'SP', '2024-01-01');
```

**O que apontar:**
Erro `Violation of PRIMARY KEY constraint 'PK__clientes...'`.

"O banco rejeita. Não importa se veio de um app, de um pipeline, de um script manual — a PK protege a unicidade de forma absoluta. Isso é *integridade de entidade*."

---

## 1.3 — Foreign Key: o elo entre tabelas

**Conceito para falar:**
"Se a PK é a identidade de uma linha, a Foreign Key é o elo entre tabelas. Um pedido pertence a um cliente. Esse vínculo é representado pela coluna `id_cliente` na tabela `pedidos` — ela aponta para a PK da tabela `clientes`."

"A FK garante *integridade referencial*: você não pode criar um pedido para um cliente que não existe. E você não pode deletar um cliente que tem pedidos associados. O banco protege os dois lados do relacionamento."

```sql
-- Visualizando pedidos com seus clientes via FK
SELECT
    p.id_pedido,
    c.nome          AS cliente,
    c.cidade,
    p.data_pedido,
    p.status,
    p.valor_total
FROM pedidos   AS p
JOIN clientes  AS c ON p.id_cliente = c.id_cliente
ORDER BY p.data_pedido;
```

**Falar:** "Agora tente criar um pedido para um cliente inexistente."

```sql
-- Erro esperado: violação de FK
INSERT INTO pedidos
    (id_pedido, id_cliente, data_pedido, status, valor_total)
VALUES
    (99, 999, '2024-01-01', 'pendente', 0);
```

**O que apontar:**
Erro `The INSERT statement conflicted with the FOREIGN KEY constraint`.

"O banco não deixou. ID 999 não existe em clientes — então não pode existir um pedido para ele. Sem FK, isso passaria silenciosamente e você teria dados corrompidos."

```sql
-- O outro lado da FK: tenta deletar um cliente que tem pedidos
DELETE FROM clientes WHERE id_cliente = 1;
```

**O que apontar:**
Erro de FK na direção contrária. "O banco também protege a deleção. Você não pode deixar pedidos 'órfãos', sem cliente."

---

## 1.4 — Relacionamentos: 1:N e N:N

**Conceito para falar:**
"Entender o tipo de relacionamento entre tabelas é o que determina como você vai fazer JOIN."

- **1:1** — raro. Uma pessoa, um CPF.
- **1:N** — o mais comum. Um cliente tem vários pedidos.
- **N:N** — um pedido tem vários produtos, um produto aparece em vários pedidos.

"O N:N não se representa direto no banco relacional. Você precisa de uma *tabela associativa* no meio. No nosso caso é a `itens_pedido` — ela resolve o N:N entre pedidos e produtos."

```sql
-- 1:N — um cliente, vários pedidos
SELECT
    c.nome                  AS cliente,
    COUNT(p.id_pedido)      AS total_pedidos,
    SUM(p.valor_total)      AS valor_total_gasto
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nome
ORDER BY total_pedidos DESC;
```

**Falar:** "LEFT JOIN aqui porque queremos ver TODOS os clientes, mesmo os que nunca compraram."

```sql
-- N:N — pedido com vários produtos (via tabela associativa itens_pedido)
SELECT
    p.id_pedido,
    pr.nome         AS produto,
    i.quantidade,
    i.preco_unitario,
    i.quantidade * i.preco_unitario  AS subtotal
FROM pedidos      AS p
JOIN itens_pedido AS i  ON p.id_pedido  = i.id_pedido
JOIN produtos     AS pr ON i.id_produto = pr.id_produto
WHERE p.id_pedido = 8
ORDER BY subtotal DESC;
```

**O que apontar:** "Itens_pedido tem duas FKs — id_pedido e id_produto. Ela resolve o N:N sendo a tabela do meio. Troque para outros IDs e veja."

---

## 1.5 — Transações e ACID

**Conceito para falar:**
"Uma transação é um conjunto de operações que deve ser executado como uma unidade. Tudo ou nada. Se qualquer passo falhar, tudo é desfeito."

**ACID:**
- **A**tomicidade: tudo executa, ou nada executa
- **C**onsistência: o banco nunca fica em estado inválido
- **I**solamento: transações simultâneas não interferem entre si
- **D**urabilidade: dado confirmado com COMMIT sobrevive a qualquer falha

"Na engenharia de dados isso importa na carga de dados. Se você está inserindo 100.000 linhas e o servidor cai no meio, sem transação metade está lá e metade não — dado corrompido. Com transação, nada foi confirmado e você reprocessa do zero com segurança."

```sql
-- Simulando uma venda completa como uma transação atômica
BEGIN TRANSACTION;

    INSERT INTO pedidos (id_pedido, id_cliente, data_pedido, status, valor_total)
    VALUES (20, 1, GETDATE(), 'pendente', 0);

    INSERT INTO itens_pedido (id_item, id_pedido, id_produto, quantidade, preco_unitario)
    VALUES (50, 20, 9, 2, 79.90);

    INSERT INTO itens_pedido (id_item, id_pedido, id_produto, quantidade, preco_unitario)
    VALUES (51, 20, 7, 1, 45.00);

    UPDATE pedidos
    SET valor_total = (
        SELECT SUM(quantidade * preco_unitario)
        FROM itens_pedido
        WHERE id_pedido = 20
    )
    WHERE id_pedido = 20;

COMMIT;

-- Confirma que tudo foi salvo junto
SELECT id_pedido, status, valor_total FROM pedidos       WHERE id_pedido = 20;
SELECT *                              FROM itens_pedido  WHERE id_pedido = 20;
```

```sql
-- Demonstração de ROLLBACK: tudo é desfeito
BEGIN TRANSACTION;
    INSERT INTO pedidos (id_pedido, id_cliente, data_pedido, status, valor_total)
    VALUES (21, 2, GETDATE(), 'pendente', 150.00);
    
    -- Dentro da transação o dado existe
    SELECT id_pedido, status FROM pedidos WHERE id_pedido = 21;

ROLLBACK;

-- Agora confirme: não existe mais
SELECT id_pedido, status FROM pedidos WHERE id_pedido = 21;
```

```sql
-- Limpeza
DELETE FROM itens_pedido WHERE id_pedido = 20;
DELETE FROM pedidos      WHERE id_pedido = 20;
```

---

## 1.6 — CRUD na visão de engenharia

**Conceito para falar:**
"CRUD — Create, Read, Update, Delete — todo mundo conhece. O que muda na perspectiva de engenheiro de dados são os riscos."

"O maior perigo é o UPDATE e o DELETE sem WHERE. Sem cláusula WHERE, você afeta **todas** as linhas da tabela. Em produção, isso é catastrófico. Sempre execute um SELECT com o mesmo WHERE antes de rodar um UPDATE ou DELETE importante — confirme quantas linhas vão ser afetadas."

```sql
-- INSERT: sempre especifique as colunas — nunca confie na ordem das colunas
INSERT INTO clientes (id_cliente, nome, email, cidade, uf, data_cadastro)
VALUES (11, 'Karen Dias', 'karen@email.com', 'Manaus', 'AM', CAST(GETDATE() AS DATE));

-- READ: confirma a inserção
SELECT id_cliente, nome, cidade, uf
FROM clientes
WHERE id_cliente = 11;

-- UPDATE: SEMPRE com WHERE
-- Antes de rodar, execute o SELECT com o mesmo WHERE para confirmar o escopo
UPDATE clientes
SET cidade = 'Belém',
    uf     = 'PA'
WHERE id_cliente = 11;

SELECT id_cliente, nome, cidade, uf FROM clientes WHERE id_cliente = 11;

-- DELETE: mesmo cuidado
DELETE FROM clientes WHERE id_cliente = 11;

SELECT id_cliente, nome FROM clientes WHERE id_cliente = 11;
```

```sql
-- FK impedindo DELETE em cascata acidental — proteção real em produção
DELETE FROM clientes WHERE id_cliente = 1;
```

**O que apontar:**
Erro de FK. "O banco bloqueou. Ana Lima tem pedidos registrados — você não pode deletar ela sem antes tratar os pedidos. Integridade referencial protegendo seus dados de corrupção."

---

> **Encerramento — falar:**
> "Agora você sabe como o banco funciona por dentro: tabelas relacionadas, chaves garantindo integridade, transações garantindo consistência. Na próxima aula a gente começa a usar SQL como ferramenta de transformação de dados — o papel real do SQL em engenharia de dados."
