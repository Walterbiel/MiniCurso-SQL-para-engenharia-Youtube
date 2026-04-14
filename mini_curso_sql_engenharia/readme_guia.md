# 🎬 Guia de Aula — Mini Curso SQL para Engenharia de Dados

> **Como usar este guia:** Leia de cima pra baixo enquanto grava. Tudo está aqui — o que falar, o que rodar, o que apontar na tela. Os arquivos `.sql` são referência de cópia/cola.

**Total: ~2h25 | 5 aulas | SQL Server (T-SQL)**

---

## ⚡ Checklist Antes de Gravar

- [ ] Rodar `banco.sql` — cria `loja_db` (OLTP) e `dw_loja` (DW)
- [ ] Confirmar as duas databases no Object Explorer
- [ ] Confirmar que as 5 tabelas de `loja_db` existem: clientes, categorias, produtos, pedidos, itens_pedido
- [ ] Confirmar que `dw_loja` tem: stg_pedidos, dim_cliente, dim_produto, dim_tempo, fato_vendas
- [ ] Fonte do editor: 16–18px
- [ ] Notificações do Windows: silenciadas
- [ ] Abrir SSMS com `loja_db` selecionada por padrão

---

---

# AULA 1 — Fundamentos de Bancos Relacionais
**⏱️ ~25 min** | Arquivo de referência: [`aula_1/exemplos.sql`](aula_1/exemplos.sql)

> **Abertura — falar devagar:**
> "A maioria aprende SQL só dando SELECT. Mas quem trabalha com engenharia de dados precisa entender como o banco funciona por dentro: por que os dados estão organizados daquele jeito, o que garante que eles são válidos, e o que acontece quando você tenta inserir algo errado. Isso é o que muda quem *usa* banco de quem *entende* banco."

---

### 1.1 — O que é um Banco Relacional

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

"Repara que isso não é só documentação — essas regras são *enforced* pelo banco. Se você tentar inserir um cliente sem nome, o banco vai rejeitar. Na aula 4 a gente vai falar mais sobre isso com Constraints."

---

### 1.2 — Primary Key: a identidade de cada linha

**Conceito para falar:**
"Todo registro precisa ser identificável de forma única e definitiva. Não pode existir dois clientes com o mesmo ID. Não pode existir dois produtos com o mesmo ID. A Primary Key garante isso."

"Ela faz duas coisas ao mesmo tempo: garante unicidade (não pode repetir) e garante que o valor não é NULL (você não pode ter uma linha sem identidade). E como bônus — o banco automaticamente cria um índice na PK, o que faz busca por ID ser extremamente rápida."

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

### 1.3 — Foreign Key: o elo entre tabelas

**Conceito para falar:**
"Se a PK é a identidade de uma linha, a Foreign Key é o elo entre tabelas. Um pedido pertence a um cliente. Esse vínculo é representado pela coluna `id_cliente` na tabela `pedidos` — ela aponta para a PK da tabela `clientes`."

"A FK garante *integridade referencial*: você não pode criar um pedido para um cliente que não existe. E você não pode deletar um cliente que tem pedidos associados. O banco protege os dois lados do relacionamento."

```sql
-- Visualizando pedidos com seus clientes via FK
-- O JOIN funciona exatamente porque essa relação é definida no banco
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

"O banco não deixou. ID 999 não existe em clientes — então não pode existir um pedido para ele. Sem FK, isso passaria silenciosamente e você teria dados corrompidos no banco."

```sql
-- O outro lado da FK: tenta deletar um cliente que tem pedidos
DELETE FROM clientes WHERE id_cliente = 1;
```

**O que apontar:**
Erro de FK na direção contrária. "O banco também protege a deleção. Você não pode deixar pedidos 'órfãos', sem cliente."

---

### 1.4 — Relacionamentos: 1:N e N:N

**Conceito para falar:**
"Entender o tipo de relacionamento entre tabelas é o que determina como você vai fazer JOIN. Existem três tipos principais."

**1 para 1 (1:1):** Raro. Uma pessoa tem um único CPF.
**1 para N (1:N):** O mais comum. Um cliente tem vários pedidos. Uma categoria tem vários produtos.
**N para N (N:N):** Um pedido tem vários produtos, e um produto aparece em vários pedidos.

"O N:N não se representa direto no banco relacional. Você precisa de uma *tabela associativa* no meio. No nosso caso é a `itens_pedido` — ela resolve o N:N entre pedidos e produtos."

```sql
-- 1:N — um cliente, vários pedidos
-- COUNT mostra quantos pedidos cada cliente tem
SELECT
    c.nome                  AS cliente,
    COUNT(p.id_pedido)      AS total_pedidos,
    SUM(p.valor_total)      AS valor_total_gasto
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nome
ORDER BY total_pedidos DESC;
```

**Falar:** "LEFT JOIN aqui porque queremos ver TODOS os clientes, mesmo os que nunca compraram. Com INNER JOIN, eles sumiram."

```sql
-- N:N — pedido com vários produtos (via tabela associativa itens_pedido)
-- Visualize o pedido 8 — ele tem 3 produtos diferentes
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

**O que apontar:** "Itens_pedido tem duas FKs — id_pedido e id_produto. Ela resolve o N:N sendo a tabela do meio. Troque para id_pedido = 1 e veja outro pedido."

---

### 1.5 — Transações e ACID

**Conceito para falar:**
"Uma transação é um conjunto de operações que deve ser executado como uma unidade. Tudo ou nada. Se qualquer passo falhar, tudo é desfeito como se nunca tivesse acontecido. Isso é o coração do ACID."

**ACID:**
- **A**tomicidade: tudo executa, ou nada executa
- **C**onsistência: o banco nunca fica em estado inválido
- **I**solamento: transações simultâneas não interferem entre si
- **D**urabilidade: dado confirmado com COMMIT sobrevive a qualquer falha

"Na engenharia de dados isso importa em carga de dados. Se você está inserindo 100.000 linhas em uma tabela e o servidor cai no meio, o que acontece? Sem transação: metade das linhas está lá, metade não. Com transação: nada foi confirmado, você reprocessa do zero."

```sql
-- Simulando uma venda completa como uma transação atômica
BEGIN TRANSACTION;

    -- Cria o pedido
    INSERT INTO pedidos (id_pedido, id_cliente, data_pedido, status, valor_total)
    VALUES (20, 1, GETDATE(), 'pendente', 0);

    -- Adiciona os itens
    INSERT INTO itens_pedido (id_item, id_pedido, id_produto, quantidade, preco_unitario)
    VALUES (50, 20, 9, 2, 79.90);

    INSERT INTO itens_pedido (id_item, id_pedido, id_produto, quantidade, preco_unitario)
    VALUES (51, 20, 7, 1, 45.00);

    -- Atualiza o valor total com base nos itens inseridos
    UPDATE pedidos
    SET valor_total = (
        SELECT SUM(quantidade * preco_unitario)
        FROM itens_pedido
        WHERE id_pedido = 20
    )
    WHERE id_pedido = 20;

COMMIT;
```

```sql
-- Confirma que tudo foi salvo junto — pedido + itens + valor correto
SELECT id_pedido, status, valor_total FROM pedidos       WHERE id_pedido = 20;
SELECT *                              FROM itens_pedido  WHERE id_pedido = 20;
```

**Falar:** "Se eu trocasse `COMMIT` por `ROLLBACK`, nada disso apareceria. O banco desfaz tudo — como se nunca tivesse acontecido. É isso que protege a consistência dos dados mesmo quando o processo falha."

```sql
-- Demonstração: ROLLBACK desfaz tudo
BEGIN TRANSACTION;
    INSERT INTO pedidos (id_pedido, id_cliente, data_pedido, status, valor_total)
    VALUES (21, 2, GETDATE(), 'pendente', 150.00);
    
    -- Veja que o pedido existe DENTRO da transação
    SELECT id_pedido, status FROM pedidos WHERE id_pedido = 21;

ROLLBACK;

-- Agora confirme que não existe mais
SELECT id_pedido, status FROM pedidos WHERE id_pedido = 21;
```

```sql
-- Limpeza do pedido 20 que foi commitado
DELETE FROM itens_pedido WHERE id_pedido = 20;
DELETE FROM pedidos      WHERE id_pedido = 20;
```

---

### 1.6 — CRUD na visão de engenharia

**Conceito para falar:**
"CRUD — Create, Read, Update, Delete — todo mundo conhece. O que muda na perspectiva de engenheiro de dados são os riscos e as boas práticas."

"O maior perigo é o UPDATE e o DELETE sem WHERE. Sem cláusula WHERE, você afeta **todas** as linhas da tabela. Em produção, isso é catastrófico. Sempre execute um SELECT com o mesmo WHERE antes de rodar um UPDATE ou DELETE importante — confirme quantas linhas vão ser afetadas."

```sql
-- BOAS PRÁTICAS DE CRUD

-- INSERT: sempre especifique as colunas — nunca confie na ordem
INSERT INTO clientes (id_cliente, nome, email, cidade, uf, data_cadastro)
VALUES (11, 'Karen Dias', 'karen@email.com', 'Manaus', 'AM', CAST(GETDATE() AS DATE));

-- READ: confirma a inserção
SELECT id_cliente, nome, cidade, uf
FROM clientes
WHERE id_cliente = 11;

-- UPDATE: SEMPRE com WHERE. Antes de rodar, faça o SELECT primeiro
-- SELECT * FROM clientes WHERE id_cliente = 11; -- confirma antes
UPDATE clientes
SET cidade = 'Belém',
    uf     = 'PA'
WHERE id_cliente = 11;

-- Confirma o update
SELECT id_cliente, nome, cidade, uf FROM clientes WHERE id_cliente = 11;

-- DELETE: mesmo cuidado com WHERE
DELETE FROM clientes WHERE id_cliente = 11;

-- Confirma a deleção
SELECT id_cliente, nome FROM clientes WHERE id_cliente = 11;
```

**Falar:** "Repara que o DELETE funcionou porque esse cliente não tinha pedidos. Agora tente deletar um que tem."

```sql
-- FK impedindo DELETE em cascata acidental
-- Isso protege integridade dos dados
DELETE FROM clientes WHERE id_cliente = 1;
```

**O que apontar:**
Erro de FK. "O banco bloqueou. Ana Lima tem pedidos registrados — você não pode deletar ela sem antes lidar com os pedidos. Isso é *integridade referencial* protegendo seus dados de corrupção."

> **Encerramento da aula 1 — falar:**
> "Agora você sabe como o banco funciona por dentro: tabelas relacionadas, chaves garantindo integridade, transações garantindo consistência. Na próxima aula a gente começa a usar SQL como ferramenta de transformação de dados — o papel real do SQL em engenharia."

---

---

# AULA 2 — SQL como Motor de Transformação de Dados
**⏱️ ~35 min** | Arquivo de referência: [`aula_2/exemplos.sql`](aula_2/exemplos.sql)

> **Abertura — falar:**
> "SQL não é só SELECT * FROM tabela. É uma linguagem de transformação. Tudo que você vai ver hoje — CASE WHEN, JOIN, GROUP BY, CTE, Window Functions — você usa em pipeline de dados, em dbt, em Spark SQL, em BigQuery. A sintaxe muda um pouco entre plataformas, mas o conceito é exatamente o mesmo. Aprenda o conceito, você aprende todas as plataformas de uma vez."

---

### 2.1 — SELECT bem estruturado

**Conceito para falar:**
"O SELECT é a instrução mais executada em qualquer sistema. Em engenharia de dados, você vai escrever SELECTs que viram pipelines, que ficam em repositórios, que são revisados em PR, que são mantidos por outras pessoas. Código SQL mal escrito é dívida técnica."

"Dois SELECTs abaixo retornam o mesmo resultado. Mas um é código de produção, o outro é código de improviso."

```sql
-- RUIM — funciona, mas é ilegível e impossível de manter
SELECT nome,preco,estoque,preco*estoque FROM produtos;

-- BOM — legível, auditável, com alias descritivos
SELECT
    nome                        AS produto,
    preco                       AS preco_unitario,
    estoque                     AS qtd_em_estoque,
    preco * estoque             AS valor_total_em_estoque,
    CASE
        WHEN estoque < 5 THEN 'Crítico'
        WHEN estoque < 20 THEN 'Baixo'
        ELSE 'Normal'
    END                         AS status_estoque
FROM produtos
ORDER BY valor_total_em_estoque DESC;
```

**Falar:** "Alias descritivos, cálculos explícitos, lógica de negócio legível. Qualquer engenheiro na equipe entende o que esse SELECT faz sem precisar perguntar. Em pipeline, SELECT limpo é pipeline auditável."

---

### 2.2 — Ordem de execução do SQL (conceito crítico)

**Conceito para falar — este é um dos pontos mais importantes da aula:**
"Existe uma ilusão comum sobre SQL: as pessoas escrevem na ordem SELECT → FROM → WHERE → GROUP BY. Mas o banco executa em outra ordem. E entender essa ordem explica comportamentos que parecem estranhos."

**Ordem real de execução:**
```
1. FROM       → de onde vêm os dados (e JOINs)
2. WHERE      → filtra linhas individuais
3. GROUP BY   → agrupa as linhas restantes
4. HAVING     → filtra os grupos
5. SELECT     → calcula as colunas e alias
6. ORDER BY   → ordena o resultado final
7. LIMIT/TOP  → limita a quantidade
```

"Por isso você NÃO PODE usar um alias do SELECT dentro do WHERE — o WHERE roda antes do SELECT ser calculado. E NÃO PODE usar uma função de agregação no WHERE — ela só existe depois do GROUP BY."

```sql
-- Demonstração da ordem de execução
-- WHERE roda antes do GROUP BY e antes do SELECT
-- Por isso não funciona: WHERE total_gasto > 1000 (alias do SELECT)
-- Por isso funciona: HAVING SUM(valor_total) > 1000

SELECT
    c.nome,
    SUM(p.valor_total)  AS total_gasto,
    COUNT(p.id_pedido)  AS qtd_pedidos
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'          -- filtra linhas ANTES do agrupamento
GROUP BY c.id_cliente, c.nome
HAVING SUM(p.valor_total) > 1000     -- filtra grupos DEPOIS do agrupamento
ORDER BY total_gasto DESC;
```

---

### 2.3 — WHERE e filtros eficientes

**Conceito para falar:**
"Filtrar cedo é um princípio de performance. Cada linha a menos que o banco processa é CPU e memória economizados. Em tabelas com milhões de linhas, um WHERE mal escrito pode transformar uma query de 2 segundos em 2 minutos."

```sql
-- IN — substitui múltiplos OR (mais legível e geralmente mais eficiente)
SELECT id_pedido, status, valor_total
FROM pedidos
WHERE status IN ('pendente', 'aprovado', 'enviado');

-- BETWEEN — intervalo inclusivo (inclui as duas datas extremas)
SELECT id_pedido, data_pedido, valor_total
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-03-31';

-- LIKE — busca por padrão em texto
-- % = qualquer sequência de caracteres
-- _ = exatamente um caractere
SELECT nome, email
FROM clientes
WHERE email LIKE '%@email.com';     -- termina com @email.com

-- IS NULL / IS NOT NULL — nunca use = NULL, isso não funciona em SQL
SELECT nome, email
FROM clientes
WHERE email IS NULL;                -- clientes sem email cadastrado

-- Filtro composto com AND e OR — use parênteses para clareza
SELECT id_pedido, status, valor_total, data_pedido
FROM pedidos
WHERE (status = 'pendente' OR status = 'aprovado')
  AND valor_total > 200
  AND data_pedido >= '2024-03-01';
```

**Falar sobre NULL:** "NULL não é zero, não é string vazia, não é falso. NULL significa *ausência de valor*. NULL = NULL retorna NULL, não verdadeiro. Por isso você usa IS NULL — não = NULL."

---

### 2.4 — CASE WHEN: lógica de negócio dentro do SQL

**Conceito para falar:**
"CASE WHEN é a forma de colocar *regra de negócio* diretamente no SQL. Em vez de buscar o dado cru e tratar no Python depois, você transforma o dado dentro da query. Em pipeline ELT, isso é o que acontece na camada T — de Transformação."

```sql
-- CASE com range de valores: categorização de produtos por faixa de preço
SELECT
    nome,
    preco,
    CASE
        WHEN preco < 50    THEN 'Econômico'
        WHEN preco < 200   THEN 'Básico'
        WHEN preco < 1000  THEN 'Intermediário'
        WHEN preco < 3000  THEN 'Premium'
        ELSE                    'Ultra Premium'
    END AS faixa_preco,
    -- CASE também funciona dentro de agregações
    CASE WHEN estoque = 0 THEN 'Sem Estoque' ELSE 'Disponível' END AS disponibilidade
FROM produtos
ORDER BY preco;
```

```sql
-- CASE com valor exato: classificação de receita por status de pedido
-- Esse padrão é clássico em ETL — você transforma status em categorias analíticas
SELECT
    id_pedido,
    data_pedido,
    status,
    valor_total,
    CASE status
        WHEN 'entregue'   THEN 'Receita Confirmada'
        WHEN 'cancelado'  THEN 'Receita Perdida'
        WHEN 'devolvido'  THEN 'Receita Estornada'
        ELSE                   'Em Andamento'
    END AS classificacao_receita
FROM pedidos
ORDER BY data_pedido;
```

```sql
-- CASE dentro de agregação: pivot manual — transforma linhas em colunas
-- Padrão muito usado em relatórios e dashboards
SELECT
    YEAR(data_pedido)   AS ano,
    MONTH(data_pedido)  AS mes,
    SUM(CASE WHEN status = 'entregue'  THEN valor_total ELSE 0 END) AS receita_confirmada,
    SUM(CASE WHEN status = 'cancelado' THEN valor_total ELSE 0 END) AS receita_perdida,
    COUNT(CASE WHEN status = 'pendente' THEN 1 END)                 AS pedidos_pendentes
FROM pedidos
GROUP BY YEAR(data_pedido), MONTH(data_pedido)
ORDER BY ano, mes;
```

**Falar:** "Esse último exemplo é um pivot manual. Você transforma valores de uma coluna (status) em colunas separadas. É exatamente o que você faria num pipeline de transformação para alimentar um dashboard."

---

### 2.5 — JOINs: combinando tabelas

**Conceito para falar:**
"JOIN é o conceito mais importante de SQL relacional. É o que permite que você desnormalize os dados na hora da consulta — sem precisar duplicar dados no banco. Presta atenção especialmente em *quantas linhas* cada tipo de JOIN retorna."

**Tipos de JOIN:**
- **INNER JOIN**: só retorna linhas que têm correspondência nos dois lados
- **LEFT JOIN**: retorna TODAS as linhas da esquerda + correspondência da direita (NULL onde não há)
- **RIGHT JOIN**: o inverso do LEFT (evite — use LEFT JOIN invertendo as tabelas, é mais claro)
- **FULL OUTER JOIN**: todos de ambos os lados
- **CROSS JOIN**: produto cartesiano (cada linha com cada linha)

```sql
-- INNER JOIN — interseção: só quem existe nos dois lados
-- Clientes sem pedido NÃO aparecem
SELECT
    c.nome           AS cliente,
    p.id_pedido,
    p.data_pedido,
    p.valor_total
FROM clientes AS c
INNER JOIN pedidos AS p ON c.id_cliente = p.id_cliente
ORDER BY c.nome;
```

**Apontar:** Quantas linhas? Menos que o total de clientes. "Clientes sem pedido sumiram."

```sql
-- LEFT JOIN — todos da esquerda, correspondência ou NULL da direita
-- Clientes SEM pedido aparecem com NULL nos campos de pedido
SELECT
    c.nome           AS cliente,
    p.id_pedido,
    p.status,
    p.valor_total
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
ORDER BY c.nome;
```

**Apontar:** Mais linhas. Alguns com NULL em id_pedido. "Esses são os clientes que nunca compraram."

```sql
-- Padrão clássico: quem NUNCA fez X
-- LEFT JOIN + WHERE IS NULL é mais eficiente que NOT EXISTS em muitos bancos
SELECT
    c.nome AS cliente_sem_pedido,
    c.cidade,
    c.data_cadastro
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
WHERE p.id_pedido IS NULL;
```

```sql
-- JOIN múltiplo — atravessa 4 tabelas para montar a visão completa de uma venda
-- Isso é o que você faria para alimentar uma camada analítica
SELECT
    c.nome                              AS cliente,
    c.cidade,
    pr.nome                             AS produto,
    cat.nome                            AS categoria,
    i.quantidade,
    i.preco_unitario,
    i.quantidade * i.preco_unitario     AS subtotal,
    p.data_pedido
FROM clientes     AS c
JOIN pedidos      AS p   ON c.id_cliente   = p.id_cliente
JOIN itens_pedido AS i   ON p.id_pedido    = i.id_pedido
JOIN produtos     AS pr  ON i.id_produto   = pr.id_produto
JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
WHERE p.status = 'entregue'
ORDER BY subtotal DESC;
```

**Falar:** "É assim que você constrói uma visão desnormalizada para análise — montando as peças do modelo relacional em um único conjunto de dados. Esse SELECT é literalmente o que vai para a camada de staging de um Data Warehouse."

---

### 2.6 — GROUP BY e HAVING

**Conceito para falar:**
"GROUP BY *colapsa* linhas em grupos. Você perde o detalhe de cada linha individual e ganha um resumo por grupo. É a base de qualquer relatório, qualquer KPI, qualquer agregação num pipeline de dados."

"HAVING é o filtro que roda **depois** do agrupamento — ele filtra *grupos*, não linhas. WHERE filtra linhas antes do agrupamento. Essa distinção é uma das dúvidas mais comuns em SQL."

```sql
-- Análise de clientes: total de pedidos e valor gasto
-- Funções de agregação: COUNT, SUM, AVG, MIN, MAX
SELECT
    c.nome                  AS cliente,
    COUNT(p.id_pedido)      AS total_pedidos,
    SUM(p.valor_total)      AS valor_total_gasto,
    AVG(p.valor_total)      AS ticket_medio,
    MIN(p.data_pedido)      AS primeiro_pedido,
    MAX(p.data_pedido)      AS ultimo_pedido
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'     -- WHERE filtra ANTES: só pedidos entregues entram no grupo
GROUP BY c.id_cliente, c.nome
ORDER BY valor_total_gasto DESC;
```

```sql
-- HAVING: filtra após o agrupamento
-- Use quando o critério depende do resultado da agregação
SELECT
    c.nome,
    SUM(p.valor_total)   AS total_gasto,
    COUNT(p.id_pedido)   AS qtd_pedidos
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'
GROUP BY c.id_cliente, c.nome
HAVING SUM(p.valor_total) > 1000    -- só clientes que gastaram mais de 1000
ORDER BY total_gasto DESC;
```

**Falar:** "Tente colocar `total_gasto > 1000` no WHERE — o banco vai retornar erro ou resultado incorreto. O alias 'total_gasto' não existe quando o WHERE é avaliado. E SUM() no WHERE também falha — agregação só existe depois do GROUP BY."

```sql
-- Análise por categoria: receita e quantidade por categoria de produto
SELECT
    cat.nome                AS categoria,
    COUNT(DISTINCT i.id_pedido) AS pedidos_com_esta_cat,
    SUM(i.quantidade)       AS unidades_vendidas,
    SUM(i.quantidade * i.preco_unitario) AS receita_total,
    AVG(i.preco_unitario)   AS preco_medio_vendido
FROM categorias   AS cat
JOIN produtos     AS pr ON cat.id_categoria = pr.id_categoria
JOIN itens_pedido AS i  ON pr.id_produto    = i.id_produto
JOIN pedidos      AS p  ON i.id_pedido      = p.id_pedido
WHERE p.status = 'entregue'
GROUP BY cat.id_categoria, cat.nome
ORDER BY receita_total DESC;
```

---

### 2.7 — Subquery e CTE

**Conceito para falar:**
"Às vezes você precisa de uma consulta que depende do resultado de outra. Tem duas formas principais: subquery inline (aninhada) ou CTE — Common Table Expression."

"A CTE, definida com WITH, é como uma 'tabela temporária com nome'. Você a escreve antes do SELECT principal, dá um nome a ela, e usa esse nome como se fosse uma tabela. Em termos de performance são equivalentes na maioria dos bancos — mas CTE é muito mais legível e fácil de debugar."

```sql
-- SUBQUERY ESCALAR: retorna um único valor para comparação
-- Produtos com preço acima da média
SELECT
    nome,
    preco,
    ROUND(preco - (SELECT AVG(preco) FROM produtos), 2) AS diferenca_da_media
FROM produtos
WHERE preco > (SELECT AVG(preco) FROM produtos)
ORDER BY preco DESC;
```

```sql
-- CTE — mesma lógica, mais organizada e extensível
-- Forma recomendada para qualquer coisa acima de uma linha
WITH media_precos AS (
    SELECT AVG(preco) AS preco_medio FROM produtos
),
produtos_acima AS (
    SELECT
        p.nome,
        p.preco,
        p.preco - m.preco_medio AS acima_da_media
    FROM produtos   AS p
    CROSS JOIN media_precos AS m
    WHERE p.preco > m.preco_medio
)
SELECT * FROM produtos_acima ORDER BY acima_da_media DESC;
```

```sql
-- CTE prática: resumo de pedidos para enriquecer análise principal
WITH resumo_itens AS (
    SELECT
        id_pedido,
        COUNT(DISTINCT id_produto)           AS qtd_produtos_distintos,
        SUM(quantidade)                      AS total_unidades,
        SUM(quantidade * preco_unitario)     AS valor_calculado
    FROM itens_pedido
    GROUP BY id_pedido
),
clientes_resumo AS (
    SELECT
        c.id_cliente,
        c.nome,
        COUNT(p.id_pedido)                   AS total_pedidos,
        SUM(p.valor_total)                   AS total_gasto
    FROM clientes AS c
    JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
    GROUP BY c.id_cliente, c.nome
)
-- Query principal referencia as CTEs como tabelas normais
SELECT
    cr.nome              AS cliente,
    cr.total_pedidos,
    cr.total_gasto,
    p.id_pedido,
    ri.qtd_produtos_distintos,
    ri.total_unidades,
    ri.valor_calculado
FROM clientes_resumo  AS cr
JOIN pedidos          AS p  ON cr.id_cliente = p.id_cliente
JOIN resumo_itens     AS ri ON p.id_pedido   = ri.id_pedido
ORDER BY cr.total_gasto DESC, p.id_pedido;
```

**Falar:** "Duas CTEs encadeadas, cada uma fazendo sua parte do trabalho. O SELECT final é limpo e legível. Isso é como você escreve transformações complexas em dbt — cada CTE é um passo do pipeline."

---

### 2.8 — Window Functions

**Conceito para falar:**
"Window Function é o que separa quem conhece SQL básico de quem conhece SQL de verdade. E é absolutamente fundamental em engenharia de dados."

"A diferença do GROUP BY: GROUP BY **colapsa** as linhas — você perde o detalhe. Window Function **não colapsa** — você agrega e ainda mantém todas as linhas originais. A função 'janela' (OVER) define sobre quais linhas o cálculo se aplica."

**Sintaxe:**
```
FUNÇÃO() OVER (
    PARTITION BY coluna_agrupadora   -- opcional: como o GROUP BY
    ORDER BY     coluna_ordenação    -- opcional: para ranking e acumulado
    ROWS BETWEEN ...                 -- opcional: define o tamanho da janela
)
```

```sql
-- ROW_NUMBER: numera as linhas dentro de cada partição
-- Caso de uso: pegar o pedido mais recente de cada cliente
SELECT
    c.nome          AS cliente,
    p.id_pedido,
    p.data_pedido,
    p.valor_total,
    ROW_NUMBER() OVER (
        PARTITION BY p.id_cliente    -- reinicia a contagem para cada cliente
        ORDER BY p.data_pedido DESC  -- ordena do mais recente
    ) AS ordem_por_cliente
FROM pedidos  AS p
JOIN clientes AS c ON p.id_cliente = c.id_cliente
ORDER BY c.nome, p.data_pedido DESC;
```

**Apontar:** "Cada cliente tem numeração própria: 1, 2, 3... que reinicia para o próximo cliente. PARTITION BY é o 'agrupador' da janela. ORDER BY define a sequência dentro de cada grupo."

```sql
-- Usando ROW_NUMBER para pegar o ÚLTIMO pedido de cada cliente
-- Padrão clássico em deduplucação e "latest record"
WITH pedidos_numerados AS (
    SELECT
        p.*,
        c.nome AS cliente,
        ROW_NUMBER() OVER (
            PARTITION BY p.id_cliente
            ORDER BY p.data_pedido DESC
        ) AS rn
    FROM pedidos  AS p
    JOIN clientes AS c ON p.id_cliente = c.id_cliente
)
SELECT cliente, id_pedido, data_pedido, valor_total
FROM pedidos_numerados
WHERE rn = 1   -- só o mais recente de cada cliente
ORDER BY cliente;
```

```sql
-- RANK e DENSE_RANK: ranking com tratamento de empates
-- RANK: pula posições em caso de empate (1, 1, 3, 4)
-- DENSE_RANK: não pula posições (1, 1, 2, 3)
SELECT
    nome,
    preco,
    RANK()       OVER (ORDER BY preco DESC) AS rank_preco,
    DENSE_RANK() OVER (ORDER BY preco DESC) AS dense_rank_preco
FROM produtos
ORDER BY preco DESC;
```

```sql
-- SUM/AVG OVER: agregação rodante (sem colapsar linhas)
-- Receita acumulada ao longo do tempo
SELECT
    data_pedido,
    valor_total,
    SUM(valor_total) OVER (
        ORDER BY data_pedido
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS receita_acumulada,
    AVG(valor_total) OVER (
        ORDER BY data_pedido
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS media_movel_3_dias
FROM pedidos
WHERE status = 'entregue'
ORDER BY data_pedido;
```

**Falar:** "Cada linha tem o valor individual E o acumulado até aquele dia E a média dos últimos 3 registros. Impossível fazer isso com GROUP BY sem perder as linhas individuais. Em análise de séries temporais, isso é fundamental."

```sql
-- LAG e LEAD: acessar linha anterior ou próxima
-- Caso de uso: variação entre períodos (MoM, WoW)
SELECT
    data_pedido,
    valor_total,
    LAG(valor_total)  OVER (ORDER BY data_pedido) AS pedido_anterior,
    LEAD(valor_total) OVER (ORDER BY data_pedido) AS proximo_pedido,
    valor_total - LAG(valor_total) OVER (ORDER BY data_pedido) AS variacao
FROM pedidos
WHERE status = 'entregue'
ORDER BY data_pedido;
```

> **Encerramento da aula 2 — falar:**
> "Você agora tem as ferramentas fundamentais de transformação em SQL. Com isso você já resolve 80% dos desafios de dados do dia a dia. Na próxima aula a gente organiza essa lógica dentro do banco — views, procedures e funções — para que qualquer pessoa possa reutilizar sem reescrever."

---

---

# AULA 3 — Objetos do Banco: Views, Procedures e Funções
**⏱️ ~25 min** | Arquivo de referência: [`aula_3/exemplos.sql`](aula_3/exemplos.sql)

> **Abertura — falar:**
> "Você aprendeu a escrever SQL de transformação. Agora você vai aprender a *organizar* esse SQL dentro do banco — para que a lógica de negócio fique em um lugar só, seja reutilizável, e qualquer ferramenta ou pessoa acesse os dados sempre do jeito correto."

---

### 3.1 — VIEW: padronizando o consumo de dados

**Conceito para falar:**
"Sem VIEW, cada analista, cada dashboard, cada pipeline reescreve o mesmo JOIN do zero. Cada um filtra de um jeito diferente. Aí aparece o número errado no relatório e ninguém sabe de onde veio."

"VIEW resolve isso centralizando a lógica. Você define a consulta uma vez, dá um nome a ela, e todo mundo consome pelo mesmo ponto. Quando a lógica precisa mudar, você muda em um lugar só."

"Importante: VIEW não armazena dados. É uma consulta nomeada. Toda vez que você acessa a view, o SELECT interno é executado. Se quiser armazenar o resultado, você usa Materialized View ou tabela temporária."

```sql
-- O problema: todo mundo copia e cola esse JOIN
SELECT c.nome, p.id_pedido, p.valor_total, p.status
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente;

-- A solução: VIEW — encapsula e nomeia a lógica
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
```

```sql
-- Consumir a VIEW como se fosse uma tabela
-- Ninguém precisa saber o JOIN que está por baixo
SELECT * FROM vw_pedidos_clientes WHERE status = 'entregue';

SELECT
    cliente,
    SUM(valor_total) AS total_gasto
FROM vw_pedidos_clientes
WHERE status = 'entregue'
GROUP BY cliente
ORDER BY total_gasto DESC;
```

```sql
-- VIEW de resumo analítico: KPIs por cliente
-- Esse é o tipo de view que alimenta um BI tool ou dashboard
CREATE VIEW vw_kpis_cliente AS
SELECT
    c.id_cliente,
    c.nome                  AS cliente,
    c.cidade,
    c.uf,
    COUNT(p.id_pedido)      AS total_pedidos,
    SUM(p.valor_total)      AS receita_total,
    AVG(p.valor_total)      AS ticket_medio,
    SUM(CASE WHEN p.status = 'entregue'  THEN p.valor_total ELSE 0 END) AS receita_confirmada,
    SUM(CASE WHEN p.status = 'cancelado' THEN p.valor_total ELSE 0 END) AS receita_perdida,
    MAX(p.data_pedido)      AS ultimo_pedido
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nome, c.cidade, c.uf;
```

```sql
SELECT * FROM vw_kpis_cliente ORDER BY receita_confirmada DESC;

-- Você ainda pode filtrar e agregar em cima da VIEW
SELECT uf, SUM(receita_confirmada) AS receita_por_estado
FROM vw_kpis_cliente
GROUP BY uf
ORDER BY receita_por_estado DESC;
```

**Falar:** "Esse padrão de views em camadas — uma para dados brutos, uma para KPIs, uma para resumo — é exatamente o que você implementa com dbt no mundo moderno. O conceito é o mesmo, a ferramenta muda."

---

### 3.2 — Stored Procedure: lógica de processo no banco

**Conceito para falar:**
"Procedure é diferente de VIEW. VIEW é para consultar dados. Procedure é para *executar um processo* — ela pode fazer SELECT, INSERT, UPDATE, DELETE, chamar outras procedures, controlar transações. É um step de pipeline dentro do banco."

"Procedures aceitam parâmetros — você pode passar um período, um ID, uma configuração — e o resultado muda conforme os parâmetros. Em ETL tradicional, procedures são muito usadas para encapsular os passos da carga."

```sql
-- Procedure de consulta parametrizada
-- Retorna pedidos de um período específico
CREATE PROCEDURE sp_pedidos_periodo
    @data_inicio DATE,
    @data_fim    DATE
AS
BEGIN
    SET NOCOUNT ON;  -- boa prática: suprime mensagens de "X rows affected"

    SELECT
        p.id_pedido,
        c.nome          AS cliente,
        p.data_pedido,
        p.status,
        p.valor_total,
        COUNT(i.id_item) OVER (PARTITION BY p.id_pedido) AS qtd_itens
    FROM pedidos      AS p
    JOIN clientes     AS c ON p.id_cliente = c.id_cliente
    JOIN itens_pedido AS i ON p.id_pedido  = i.id_pedido
    WHERE p.data_pedido BETWEEN @data_inicio AND @data_fim
    ORDER BY p.data_pedido, p.valor_total DESC;
END;
```

```sql
-- Executar com diferentes parâmetros
EXEC sp_pedidos_periodo '2024-01-01', '2024-03-31';  -- Q1
EXEC sp_pedidos_periodo '2024-04-01', '2024-06-30';  -- Q2
```

**Falar:** "Mesma procedure, resultados diferentes conforme o parâmetro. Em ETL, você chamaria essa procedure dentro do seu pipeline passando a janela de data de cada execução."

```sql
-- Procedure de processo com parâmetro com valor padrão
-- Cancela pedidos pendentes há mais de N dias (padrão: 30)
CREATE PROCEDURE sp_cancelar_pendentes
    @dias_limite INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @pedidos_afetados INT;

    -- Executa o UPDATE
    UPDATE pedidos
    SET status = 'cancelado'
    WHERE status = 'pendente'
      AND DATEDIFF(DAY, data_pedido, GETDATE()) > @dias_limite;

    SET @pedidos_afetados = @@ROWCOUNT;

    -- Retorna um log da execução
    SELECT
        @pedidos_afetados   AS pedidos_cancelados,
        @dias_limite        AS criterio_dias,
        GETDATE()           AS executado_em;
END;
```

**Falar:** "O parâmetro com valor padrão: se você chamar sem argumentos, usa 30 dias. Se precisar de um critério diferente em algum mês, passa o parâmetro. Em produção, essa procedure seria agendada num job do SQL Server Agent ou disparada por um DAG do Airflow."

---

### 3.3 — Função Escalar: cálculo reutilizável

**Conceito para falar:**
"Função escalar retorna um único valor. Você a usa dentro de um SELECT como se fosse uma coluna calculada. A diferença da procedure é que função pode ser usada dentro de expressões — dentro do SELECT, do WHERE, do ORDER BY."

"O valor está em encapsular a regra de negócio. Se a regra de desconto mudar amanhã, você muda a função em um lugar só — todo SELECT que a usa já reflete o novo cálculo automaticamente."

```sql
-- Função de desconto: recebe valor e percentual, retorna valor com desconto
CREATE FUNCTION fn_valor_com_desconto
(
    @valor        DECIMAL(10,2),
    @pct_desconto DECIMAL(5,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    -- Validação: desconto não pode ser negativo nem maior que 100%
    IF @pct_desconto < 0 OR @pct_desconto > 100
        RETURN @valor;  -- retorna sem desconto se parâmetro inválido

    RETURN @valor - (@valor * @pct_desconto / 100);
END;
```

```sql
-- Usando a função como coluna calculada
SELECT
    nome,
    preco                                   AS preco_original,
    dbo.fn_valor_com_desconto(preco, 10)    AS preco_10pct_off,
    dbo.fn_valor_com_desconto(preco, 15)    AS preco_15pct_off,
    dbo.fn_valor_com_desconto(preco, 20)    AS preco_20pct_off
FROM produtos
WHERE preco > 100
ORDER BY preco DESC;
```

**Falar:** "Repare no prefixo `dbo.` — obrigatório em SQL Server para funções de usuário. A função aparece no SELECT como se fosse uma coluna nativa. Mude a regra de negócio na função, todos os SELECTs herdam automaticamente."

---

### 3.4 — Função de Tabela: VIEW parametrizada

**Conceito para falar:**
"Função de tabela retorna um conjunto de linhas — não um único valor. É como uma VIEW que aceita parâmetro. Onde uma VIEW retorna sempre o mesmo conjunto de dados, a função de tabela retorna dados filtrados pelo parâmetro que você passa."

```sql
-- Retorna os itens de um pedido específico com detalhes de produto
CREATE FUNCTION fn_itens_pedido (@id_pedido INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        pr.nome                                 AS produto,
        cat.nome                                AS categoria,
        i.quantidade,
        i.preco_unitario,
        i.quantidade * i.preco_unitario         AS subtotal,
        -- Percentual que esse item representa no total do pedido
        ROUND(
            (i.quantidade * i.preco_unitario) * 100.0
            / SUM(i.quantidade * i.preco_unitario) OVER (PARTITION BY i.id_pedido),
        1)                                      AS pct_do_pedido
    FROM itens_pedido AS i
    JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
    JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
    WHERE i.id_pedido = @id_pedido
);
```

```sql
-- Consultar os itens de um pedido específico
SELECT * FROM dbo.fn_itens_pedido(8);
SELECT * FROM dbo.fn_itens_pedido(1);
```

```sql
-- CROSS APPLY: chama a função para cada linha da tabela externa
-- É como um JOIN onde um dos lados é uma função
SELECT
    p.id_pedido,
    c.nome      AS cliente,
    p.data_pedido,
    itens.produto,
    itens.categoria,
    itens.subtotal,
    itens.pct_do_pedido
FROM pedidos  AS p
JOIN clientes AS c ON p.id_cliente = c.id_cliente
CROSS APPLY dbo.fn_itens_pedido(p.id_pedido) AS itens
WHERE p.id_pedido IN (1, 7, 8)
ORDER BY p.id_pedido, itens.subtotal DESC;
```

**Falar:** "CROSS APPLY é uma feature poderosa do T-SQL. Para cada pedido, ele invoca a função e junta o resultado. É o cenário onde você quer o detalhe de cada item mas dentro do contexto de cada pedido."

> **Encerramento da aula 3 — falar:**
> "Resumo dos objetos: VIEW para padronizar e reutilizar consultas, Procedure para encapsular processos e steps de pipeline, Função para cálculo reutilizável dentro de queries. Na próxima aula a gente fala de performance e qualidade — índices e constraints — os dois pilares que fazem um banco funcionar bem em produção."

---

---

# AULA 4 — Performance e Qualidade: Índices e Constraints
**⏱️ ~25 min** | Arquivo de referência: [`aula_4/exemplos.sql`](aula_4/exemplos.sql)

> **Abertura — falar:**
> "Duas coisas que diferenciam um banco de produção de um banco de desenvolvimento: performance de leitura e qualidade dos dados. Índice garante que a leitura seja rápida. Constraint garante que o dado que entrou é válido. Esses dois juntos fazem a diferença entre um banco funcional e um banco confiável."

---

### 4.1 — O que é índice e por que importa

**Conceito para falar:**
"Pensa em uma tabela como um livro sem sumário e sem índice remissivo. Para achar uma informação, você lê página por página. No banco, isso se chama *full table scan* ou *table scan* — o banco lê todas as linhas da tabela para encontrar o que você quer."

"Com índice, é como ter o índice remissivo do livro — você vai direto na página certa. Em tabelas grandes, a diferença é de segundos vs milissegundos, ou de minutos vs segundos."

"Todo mundo que cria uma Primary Key automaticamente cria um índice do tipo CLUSTERED — isso é dado pelo banco sem você precisar pedir. Mas outras colunas que você usa em WHERE, JOIN e ORDER BY frequentemente precisam de índices extras."

```sql
-- Ver os índices existentes em uma tabela
SELECT
    i.name              AS nome_indice,
    i.type_desc         AS tipo_indice,
    i.is_primary_key    AS eh_pk,
    i.is_unique         AS eh_unico,
    STRING_AGG(c.name, ', ')
        WITHIN GROUP (ORDER BY ic.key_ordinal) AS colunas
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

### 4.2 — Tipos de índice: Clustered vs Nonclustered

**Conceito para falar:**
"CLUSTERED determina a *ordem física dos dados no disco*. A tabela inteira é organizada pela coluna do índice clustered. Por isso só pode ter UM índice clustered por tabela — você não pode ordenar fisicamente os dados de dois jeitos ao mesmo tempo."

"NONCLUSTERED é uma estrutura separada, uma cópia parcial dos dados que aponta para as linhas originais. Pode ter até 999 por tabela (na prática, muito menos). É o tipo mais comum de índice que você vai criar."

```sql
-- Índice simples em data_pedido — busca por período é muito frequente
CREATE NONCLUSTERED INDEX idx_pedidos_data
ON pedidos (data_pedido);

-- Índice composto: colunas frequentes juntas em WHERE
-- A ordem importa: status primeiro porque geralmente é o filtro mais seletivo
-- Regra: coluna mais seletiva primeiro
CREATE NONCLUSTERED INDEX idx_pedidos_status_data
ON pedidos (status, data_pedido);

-- Índice com INCLUDE: carrega colunas extras no índice sem fazer parte da chave
-- Evita voltar à tabela para buscar essas colunas (covering index)
CREATE NONCLUSTERED INDEX idx_pedidos_cliente_cobrindo
ON pedidos (id_cliente)
INCLUDE (data_pedido, valor_total, status);
```

```sql
-- Com os índices criados, essas queries são muito mais eficientes
-- O banco usa o índice em vez de fazer full scan

-- Usa idx_pedidos_data
SELECT id_pedido, status, valor_total
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-03-31';

-- Usa idx_pedidos_status_data
SELECT id_pedido, data_pedido, valor_total
FROM pedidos
WHERE status = 'entregue'
  AND data_pedido >= '2024-01-01';

-- Usa idx_pedidos_cliente_cobrindo — sem precisar ir à tabela principal
SELECT data_pedido, valor_total, status
FROM pedidos
WHERE id_cliente = 3;
```

**Falar:** "Para ver o plano de execução e confirmar qual índice o banco está usando: clique em 'Include Actual Execution Plan' ou pressione Ctrl+M antes de executar. O ícone de 'Index Seek' confirma que o índice foi usado — muito mais eficiente que 'Table Scan'."

---

### 4.3 — Trade-off: performance de leitura vs escrita

**Conceito para falar — este é o ponto mais importante de índices em engenharia de dados:**
"Mais índice não é sempre melhor. Índice melhora leitura (SELECT) mas piora escrita (INSERT, UPDATE, DELETE). Cada vez que você insere uma linha, o banco precisa atualizar todos os índices da tabela. Uma tabela com 10 índices tem 10 estruturas para manter."

"Em engenharia de dados isso é crítico porque você trabalha com dois cenários opostos:"
- **Tabelas de produção (OLTP):** muitas leituras e escritas — índices nas colunas certas
- **Tabelas de staging de carga em massa:** você está inserindo milhões de linhas — remova os índices antes, insira tudo, recrie os índices depois

**Regra prática para criar índices:**
- Coluna aparece com frequência em WHERE, JOIN ou ORDER BY → crie
- Coluna com alta cardinalidade (muitos valores distintos) → índice mais eficiente
- Tabela de staging ou temp → sem índice (ou mínimo)
- Nunca crie índice em toda coluna "por precaução" — meça o impacto primeiro

---

### 4.4 — Constraints: qualidade de dados garantida pelo banco

**Conceito para falar:**
"Constraint é uma regra de qualidade definida diretamente no banco. Não importa como o dado chegou — via app, via pipeline, via SQL manual — o banco valida antes de aceitar."

"Em pipelines de dados, isso é sua última linha de defesa contra dado ruim. Você pode ter validações no Python, no Airflow, no dbt — mas se uma constraint está no banco, nada passa por ela."

**Tipos de Constraints:**
- **PRIMARY KEY**: unicidade + NOT NULL
- **FOREIGN KEY**: integridade referencial entre tabelas
- **UNIQUE**: unicidade sem ser PK
- **NOT NULL**: campo obrigatório
- **CHECK**: regra de domínio customizada (qualquer expressão booleana)
- **DEFAULT**: valor padrão quando não informado

```sql
-- Ver todas as constraints do banco
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

-- Ver especificamente as CHECK constraints e suas regras
SELECT
    cc.CONSTRAINT_NAME,
    tc.TABLE_NAME,
    cc.CHECK_CLAUSE
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS AS cc
JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
     ON cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
ORDER BY tc.TABLE_NAME;
```

**Apontar:** `chk_preco_positivo`, `chk_qtd_positiva`, `chk_status`. "Essas regras estavam no banco.sql desde o início."

```sql
-- Testar CHECK constraint: preço negativo é rejeitado na fonte
INSERT INTO produtos
    (id_produto, nome, id_categoria, preco, estoque)
VALUES
    (99, 'Produto Inválido', 1, -50.00, 10);
```

**Apontar:** Erro de CHECK. "O banco rejeita na fonte. Não importa se veio de um script Python, de um form web ou de um pipeline Airflow — a regra está no banco."

```sql
-- Criando uma CHECK constraint para validar UF
ALTER TABLE clientes
ADD CONSTRAINT chk_uf_valido
CHECK (uf IN ('AC','AL','AP','AM','BA','CE','DF','ES','GO',
              'MA','MT','MS','MG','PA','PB','PR','PE','PI',
              'RJ','RN','RS','RO','RR','SC','SP','SE','TO'));

-- Testar: UF inválida
INSERT INTO clientes
    (id_cliente, nome, email, cidade, uf, data_cadastro)
VALUES
    (20, 'Teste', 'x@x.com', 'Cidade', 'ZZ', '2024-01-01');
```

**Apontar:** Erro de CHECK. "UF 'ZZ' não existe. O banco rejeitou."

```sql
-- Criando constraint UNIQUE para garantir que email não se repita
ALTER TABLE clientes
ADD CONSTRAINT uq_clientes_email UNIQUE (email);

-- Testando
INSERT INTO clientes
    (id_cliente, nome, email, cidade, uf, data_cadastro)
VALUES
    (20, 'Novo Cliente', 'ana.lima@email.com', 'SP', 'SP', CAST(GETDATE() AS DATE));
```

**Apontar:** Erro de UNIQUE se o email já existir. "Garantia de unicidade sem ser PK."

```sql
-- Limpeza das constraints de demo
ALTER TABLE clientes DROP CONSTRAINT chk_uf_valido;
ALTER TABLE clientes DROP CONSTRAINT uq_clientes_email;
```

> **Encerramento da aula 4 — falar:**
> "Com índice você garante performance. Com constraint você garante qualidade. Juntos, eles fazem a diferença entre um banco que funciona e um banco confiável para produção. Na última aula, a gente conecta tudo isso ao mundo do Data Warehouse — onde todo esse SQL vai ser a ferramenta de movimentação de dados."

---

---

# AULA 5 — SQL no Data Warehouse
**⏱️ ~30 min** | Arquivo de referência: [`aula_5/exemplos.sql`](aula_5/exemplos.sql)

> **Abertura — falar:**
> "Tudo que você aprendeu nas 4 aulas anteriores — JOIN, CTE, window function, constraints, índice — vira ferramenta aqui. O Data Warehouse não é uma tecnologia nova e misteriosa. É um padrão arquitetural. E SQL é a linguagem que move dados dentro dele. Nessa aula você vai ver um pipeline completo de DW rodando."

---

### 5.1 — OLTP vs OLAP: dois mundos diferentes

**Conceito para falar:**
"Todo dado começa num sistema transacional — OLTP. O sistema de e-commerce, o ERP, o CRM. Esses sistemas são otimizados para transações rápidas: INSERT de um pedido, UPDATE de um status, SELECT de um cliente. Alta frequência de operações pequenas."

"O problema é que perguntas analíticas em OLTP são pesadas: 'qual categoria vendeu mais nos últimos 6 meses por região?' exige JOINs em 4 tabelas, varrer milhões de linhas. Isso compete com as transações do dia a dia e deixa o sistema lento."

"O OLAP — Data Warehouse — resolve isso. Os dados são transformados e carregados em um modelo específico para análise: *desnormalizado*, otimizado para leitura, com histórico completo. No OLTP você normaliza para evitar redundância. No OLAP você desnormaliza para ter performance analítica."

```sql
USE loja_db;

-- No OLTP: para responder uma pergunta analítica simples, você precisa de 4 JOINs
-- Isso em uma tabela com 1 bilhão de itens_pedido seria muito pesado
SELECT
    cat.nome                                        AS categoria,
    SUM(i.quantidade * i.preco_unitario)            AS receita_total
FROM itens_pedido AS i
JOIN pedidos      AS p   ON i.id_pedido     = p.id_pedido
JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
WHERE p.data_pedido BETWEEN '2024-01-01' AND '2024-01-31'
  AND p.status = 'entregue'
GROUP BY cat.nome
ORDER BY receita_total DESC;
```

**Falar:** "Guarda bem esse resultado — categoria e receita. Vamos fazer a mesma pergunta no DW mais adiante. Compare a quantidade de JOINs e a complexidade."

---

### 5.2 — Star Schema: o modelo do Data Warehouse

**Conceito para falar:**
"No DW, você tem dois tipos de tabela fundamentais:"
- **Dimensão (dim_)**: o *contexto* — quem comprou, o quê foi comprado, quando, onde. São os atributos descritivos. Mudam pouco, têm histórico.
- **Fato (fato_)**: o *que aconteceu*, em números. Cada linha é um evento mensurável — uma venda, um clique, uma transação. Têm FK para as dimensões e as métricas numéricas.

"O modelo estrela (Star Schema) conecta a tabela fato ao centro, e as dimensões nas pontas — daí o nome estrela."

"Um detalhe crítico: a fato usa *surrogate keys* (sk_) — chaves geradas pelo próprio DW, não as do OLTP. Isso permite guardar histórico de mudanças, independe do sistema de origem e facilita integração de múltiplas fontes."

```sql
USE dw_loja;

-- Estrutura da dimensão de cliente
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_cliente'
ORDER BY ORDINAL_POSITION;

-- Estrutura da tabela fato
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fato_vendas'
ORDER BY ORDINAL_POSITION;
```

**Apontar:**
- `sk_cliente` em `fato_vendas` — a surrogate key gerada pelo DW, não o `id_cliente` do OLTP
- `data_inicio`, `data_fim`, `ativo` em `dim_cliente` — campos que vão suportar histórico de mudanças (SCD Tipo 2, que veremos mais adiante)

---

### 5.3 — Arquitetura de carga: Staging → Dimensões → Fato

**Conceito para falar:**
"O fluxo de carga do DW segue sempre essa sequência:"

```
OLTP → Staging → Dimensões → Fato
```

"**Staging**: extrai os dados do OLTP como vieram, sem transformação. É a 'zona de pouso' — você isola o DW do sistema operacional e tem um snapshot dos dados para processar."

"**Dimensões**: carrega primeiro porque a fato precisa das surrogate keys das dimensões. Só clientes novos e produtos novos são inseridos (carga incremental)."

"**Fato**: carrega por último, resolvendo as surrogate keys das dimensões e os dados da staging."

```sql
USE dw_loja;

-- PASSO 1: Staging — extrai do OLTP e pousa na zona de staging
-- TRUNCATE antes para reprocessar do zero (ou use incremental com delta de data)
TRUNCATE TABLE stg_pedidos;

INSERT INTO stg_pedidos (
    id_pedido, id_cliente, nome_cliente, cidade, uf,
    id_produto, nome_produto, categoria, preco_produto,
    data_pedido, quantidade, valor
)
SELECT
    p.id_pedido,
    c.id_cliente,
    c.nome,
    c.cidade,
    c.uf,
    pr.id_produto,
    pr.nome,
    cat.nome,
    pr.preco,
    p.data_pedido,
    i.quantidade,
    i.quantidade * i.preco_unitario
FROM loja_db.dbo.itens_pedido AS i
JOIN loja_db.dbo.pedidos      AS p   ON i.id_pedido     = p.id_pedido
JOIN loja_db.dbo.clientes     AS c   ON p.id_cliente    = c.id_cliente
JOIN loja_db.dbo.produtos     AS pr  ON i.id_produto    = pr.id_produto
JOIN loja_db.dbo.categorias   AS cat ON pr.id_categoria = cat.id_categoria
WHERE p.status = 'entregue';

SELECT COUNT(*) AS linhas_na_staging FROM stg_pedidos;
```

```sql
-- PASSO 2: Carrega dim_cliente — só clientes novos (carga incremental)
-- WHERE NOT EXISTS evita duplicação
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
SELECT DISTINCT
    s.id_cliente,
    s.nome_cliente,
    s.cidade,
    s.uf,
    CAST(GETDATE() AS DATE),
    1
FROM stg_pedidos AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_cliente AS d
    WHERE d.id_cliente_origem = s.id_cliente
      AND d.ativo = 1
);

-- PASSO 3: Idem para dim_produto
INSERT INTO dim_produto (id_produto_origem, nome, categoria, preco, data_inicio, ativo)
SELECT DISTINCT
    s.id_produto,
    s.nome_produto,
    s.categoria,
    s.preco_produto,
    CAST(GETDATE() AS DATE),
    1
FROM stg_pedidos AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_produto AS d
    WHERE d.id_produto_origem = s.id_produto
      AND d.ativo = 1
);

SELECT COUNT(*) AS clientes_na_dim FROM dim_cliente;
SELECT COUNT(*) AS produtos_na_dim FROM dim_produto;
```

**Falar:** "Execute os dois INSERTs de dimensão uma segunda vez — vai retornar 0 linhas inseridas. O `WHERE NOT EXISTS` é o mecanismo de idempotência: você pode rodar quantas vezes quiser, o resultado é o mesmo. Isso é fundamental em pipelines de dados — a carga deve ser segura para re-execução."

---

### 5.4 — Carregando a Fato e validando com OLTP

```sql
-- PASSO 4: Carrega fato_vendas resolvendo as surrogate keys
INSERT INTO fato_vendas (sk_cliente, sk_produto, sk_tempo, id_pedido_origem, quantidade, valor)
SELECT
    dc.sk_cliente,
    dp.sk_produto,
    dt.sk_tempo,
    s.id_pedido,
    s.quantidade,
    s.valor
FROM stg_pedidos AS s
-- Resolve SK de cliente pelo id de origem + ativo=1
JOIN dim_cliente AS dc ON s.id_cliente = dc.id_cliente_origem AND dc.ativo = 1
-- Resolve SK de produto pelo id de origem + ativo=1
JOIN dim_produto AS dp ON s.id_produto = dp.id_produto_origem AND dp.ativo = 1
-- Resolve SK de tempo (chave inteira no formato yyyymmdd)
JOIN dim_tempo   AS dt ON CAST(FORMAT(s.data_pedido, 'yyyyMMdd') AS INT) = dt.sk_tempo
-- Idempotência: não duplica se já foi carregado
WHERE NOT EXISTS (
    SELECT 1
    FROM fato_vendas AS f
    WHERE f.id_pedido_origem = s.id_pedido
      AND f.sk_produto       = dp.sk_produto
);

SELECT COUNT(*) AS linhas_na_fato FROM fato_vendas;
```

```sql
-- VALIDAÇÃO: mesma pergunta do OLTP — agora no DW
-- Compare a simplicidade com os 4 JOINs do OLTP
USE dw_loja;

SELECT
    dp.categoria,
    SUM(f.valor)        AS receita_total,
    COUNT(f.sk_cliente) AS qtd_vendas
FROM fato_vendas AS f
JOIN dim_produto AS dp ON f.sk_produto = dp.sk_produto
JOIN dim_tempo   AS dt ON f.sk_tempo   = dt.sk_tempo
WHERE dt.mes = 1
  AND dt.ano = 2024
GROUP BY dp.categoria
ORDER BY receita_total DESC;
```

**Falar:** "Mesmo resultado que o OLTP. Mas agora: sem JOIN em pedidos, sem JOIN em clientes, sem JOIN em itens_pedido, sem JOIN em categorias. No OLTP eram 4 JOINs em 5 tabelas. No DW são 2 JOINs. Com bilhões de linhas, em petabytes de dados, essa diferença determina se a query demora 2 segundos ou 20 minutos."

---

### 5.5 — MERGE: upsert em uma instrução

**Conceito para falar:**
"MERGE resolve em uma única instrução o que normalmente exigiria dois passos: inserir linhas novas e atualizar linhas que mudaram. É o operador de 'upsert' do SQL. Muito usado em carga incremental de dimensões e fatos."

```sql
-- Simulando um delta de clientes: mudanças + novo
CREATE TABLE #stg_clientes_delta (
    id_cliente  INT,
    nome        VARCHAR(100),
    cidade      VARCHAR(50),
    uf          CHAR(2)
);

INSERT INTO #stg_clientes_delta VALUES
(1,  'Ana Lima',     'Campinas',       'SP'),  -- mudou de cidade (era São Paulo)
(2,  'Bruno Santos', 'Rio de Janeiro', 'RJ'),  -- sem mudança
(11, 'Karen Dias',   'Belém',          'PA');  -- cliente novo no DW
```

```sql
-- MERGE: um único comando faz insert e update
MERGE dim_cliente AS destino
USING (
    SELECT id_cliente, nome, cidade, uf
    FROM #stg_clientes_delta
) AS origem
ON destino.id_cliente_origem = origem.id_cliente
AND destino.ativo = 1

-- Quando existe nos dois lados E houve mudança: atualiza
WHEN MATCHED AND (
    destino.cidade <> origem.cidade OR
    destino.uf     <> origem.uf
) THEN
    UPDATE SET
        destino.cidade = origem.cidade,
        destino.uf     = origem.uf

-- Quando existe só na origem (novo): insere
WHEN NOT MATCHED BY TARGET THEN
    INSERT (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
    VALUES (origem.id_cliente, origem.nome, origem.cidade, origem.uf,
            CAST(GETDATE() AS DATE), 1);

DROP TABLE #stg_clientes_delta;

-- Resultado: Ana mudou, Bruno igual, Karen foi inserida
SELECT sk_cliente, id_cliente_origem, nome, cidade, uf, ativo
FROM dim_cliente
ORDER BY id_cliente_origem;
```

**Apontar:** "Ana agora está em Campinas. Karen foi inserida com nova sk. Bruno permaneceu igual — o MERGE não tocou porque não houve mudança."

---

### 5.6 — SCD Tipo 1 e Tipo 2: tratando mudanças em dimensões

**Conceito para falar:**
"SCD — Slowly Changing Dimension — é um dos padrões mais importantes de Data Warehouse. Define como você trata o fato de que dimensões mudam com o tempo."

"Exemplo clássico: uma cliente mora em São Paulo. Ela compra um notebook. Depois ela se muda para o Rio de Janeiro. Ela compra mais um produto. Quando você analisa vendas por cidade, o notebook foi vendido para uma cliente de SP ou RJ?"

"A resposta depende do tipo de SCD que você implementou."

**SCD Tipo 1 — Sobrescreve, sem histórico:**
- Quando usar: dados que simplesmente corrigem um erro, ou atributos que não têm valor histórico (nome corrigido, email corrigido)
- Risco: você perde o histórico — não sabe o que era antes

```sql
-- SCD Tipo 1: sobrescreve o valor diretamente
-- Caso de uso: correção de nome digitado errado
UPDATE dim_cliente
SET nome = 'Ana Lima Silva'         -- versão corrigida
WHERE id_cliente_origem = 1
  AND ativo = 1;

-- Desfaz para o exemplo
UPDATE dim_cliente
SET nome = 'Ana Lima'
WHERE id_cliente_origem = 1
  AND ativo = 1;
```

**SCD Tipo 2 — Preserva histórico com nova linha:**
- Quando usar: atributos com valor histórico (cidade, cargo, segmento)
- Mecanismo: fecha o registro atual (seta data_fim e ativo=0), insere novo registro com nova SK

```sql
-- SCD Tipo 2: Ana mudou de SP para RJ

-- PASSO 1: fecha o registro atual
UPDATE dim_cliente
SET data_fim = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
    ativo    = 0
WHERE id_cliente_origem = 1
  AND ativo = 1;

-- PASSO 2: insere nova versão com os novos dados
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, data_fim, ativo)
VALUES (1, 'Ana Lima', 'Rio de Janeiro', 'RJ', CAST(GETDATE() AS DATE), NULL, 1);

-- Resultado: duas versões de Ana com SKs diferentes
SELECT
    sk_cliente,
    nome,
    cidade,
    uf,
    data_inicio,
    data_fim,
    ativo
FROM dim_cliente
WHERE id_cliente_origem = 1
ORDER BY data_inicio;
```

**Falar devagar:** "Duas linhas — duas surrogate keys. Quando o notebook foi comprado, a fato_vendas apontou para a sk antiga — que diz SP. Quando o próximo produto foi comprado, vai apontar para a nova sk — que diz RJ. O histórico está preservado automaticamente, sem nenhuma alteração na fato. É por isso que a fato usa surrogate key, não o ID do OLTP."

```sql
-- Consulta histórica: vendas por cidade levando em conta SCD Tipo 2
-- Cada venda reflete a cidade do cliente NO MOMENTO da compra
SELECT
    f.id_pedido_origem,
    dc.nome        AS cliente,
    dc.cidade      AS cidade_na_epoca_da_compra,
    dt.data_completa,
    f.valor
FROM fato_vendas AS f
JOIN dim_cliente AS dc ON f.sk_cliente = dc.sk_cliente   -- usa SK, não id_origem
JOIN dim_tempo   AS dt ON f.sk_tempo   = dt.sk_tempo
WHERE dc.id_cliente_origem = 1
ORDER BY dt.data_completa;
```

**Falar:** "Esse é o poder do SCD Tipo 2. Não é só guardar dado — é guardar o *estado* do dado no momento em que o fato aconteceu. Em análise de comportamento de cliente, em auditoria, em cálculo de receita por região, esse histórico é fundamental."

> **Encerramento final — falar:**
> "Em 5 aulas você foi de 'o que é uma tabela' até SCD Tipo 2, pipeline de DW e window functions. Tudo com SQL. Isso é o que você usa no dia a dia como engenheiro de dados — seja em SQL Server, BigQuery, Snowflake, Databricks."
>
> "O que muda entre as plataformas é a sintaxe de alguns detalhes. O que não muda é o modelo mental: como os dados se relacionam, como você os transforma, como você garante qualidade e performance, como você projeta um Data Warehouse."
>
> "Os exercícios têm três níveis na pasta `/exercicios` — básico, intermediário e avançado, todos com gabarito. Se esse conteúdo foi útil, compartilha com quem está começando na área."

---

---

## 📁 Referências Rápidas

### Guias por aula (use um por vez durante a gravação)

| Guia | Conteúdo |
|------|----------|
| [`aula_1/readme_guia.md`](aula_1/readme_guia.md) | Guia completo da Aula 1 — PK, FK, relacionamentos, ACID, CRUD |
| [`aula_2/readme_guia.md`](aula_2/readme_guia.md) | Guia completo da Aula 2 — SELECT, JOIN, GROUP BY, CTE, Window Functions |
| [`aula_3/readme_guia.md`](aula_3/readme_guia.md) | Guia completo da Aula 3 — VIEW, Procedure, Funções |
| [`aula_4/readme_guia.md`](aula_4/readme_guia.md) | Guia completo da Aula 4 — Índices e Constraints |
| [`aula_5/readme_guia.md`](aula_5/readme_guia.md) | Guia completo da Aula 5 — Data Warehouse, MERGE, SCD |

### Arquivos de código e exercícios

| Arquivo | O que faz |
|---------|-----------|
| [`banco.sql`](banco.sql) | Cria `loja_db` e `dw_loja` com todos os dados. Rode isso antes de tudo. |
| [`aula_1/exemplos.sql`](aula_1/exemplos.sql) | Código completo: fundamentos relacionais, PK, FK, ACID, CRUD |
| [`aula_2/exemplos.sql`](aula_2/exemplos.sql) | Código completo: SELECT, WHERE, CASE, JOIN, GROUP BY, CTE, Window Functions |
| [`aula_3/exemplos.sql`](aula_3/exemplos.sql) | Código completo: VIEW, Stored Procedure, Função escalar, Função de tabela |
| [`aula_4/exemplos.sql`](aula_4/exemplos.sql) | Código completo: Clustered/Nonclustered index, Constraints (PK, FK, CHECK, UNIQUE) |
| [`aula_5/exemplos.sql`](aula_5/exemplos.sql) | Código completo: OLTP vs OLAP, Star Schema, carga Staging→Dim→Fato, MERGE, SCD 1/2 |
| [`exercicios/basico.sql`](exercicios/basico.sql) | 8 exercícios nível básico com gabarito |
| [`exercicios/intermediario.sql`](exercicios/intermediario.sql) | 6 exercícios nível intermediário com gabarito |
| [`exercicios/avancado.sql`](exercicios/avancado.sql) | 4 exercícios nível avançado com gabarito |

---

## 🧭 Conceitos-Chave por Aula (Revisão Rápida)

| Aula | Conceitos Centrais | O que o aluno leva |
|------|--------------------|--------------------|
| 1 | PK, FK, 1:N, N:N, ACID, CRUD | Como o banco garante integridade e consistência |
| 2 | SELECT, JOIN, GROUP BY, HAVING, CTE, Window Functions | SQL como motor de transformação |
| 3 | VIEW, Procedure, Função Escalar, Função de Tabela | Como organizar lógica dentro do banco |
| 4 | Clustered/Nonclustered index, CHECK, UNIQUE, NOT NULL | Como garantir performance e qualidade |
| 5 | OLTP vs OLAP, Star Schema, Staging, MERGE, SCD 1/2 | Como construir e carregar um Data Warehouse |
