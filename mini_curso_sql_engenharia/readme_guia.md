# 🎬 Guia de Aula — Mini Curso SQL para Engenharia de Dados

> Documento principal de gravação. Tudo está aqui — leia de cima pra baixo e grave.
> Os arquivos `.sql` são só referência se quiser copiar/colar ou mostrar no editor.

**Total: ~2h25 | 5 aulas | SQL Server (T-SQL)**

---

## ⚡ Antes de Gravar

- [ ] Executar `banco.sql` — cria `loja_db` e `dw_loja`
- [ ] Confirmar as duas databases no Object Explorer
- [ ] Fonte do editor: 16-18px
- [ ] Notificações do Windows: silenciadas

---

---

# AULA 1 — Fundamentos de Bancos Relacionais
**⏱️ ~25 min** | Arquivo de referência: [`aula_1/exemplos.sql`](aula_1/exemplos.sql)

> **Falar na abertura:**
> "A maioria aprende SQL só dando SELECT. Hoje você vai entender como o banco funciona por dentro — e isso é o que separa quem usa banco de quem entende banco."

---

### 1.1 — O que é um banco relacional

**Falar:** "Dados organizados em tabelas. Cada tabela é uma entidade do negócio. O banco guarda metadados — você consegue perguntar pro próprio banco o que ele tem."

```sql
USE loja_db;

-- Quais tabelas existem?
SELECT TABLE_NAME AS tabela
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';
```

**Apontar no resultado:** 5 tabelas — clientes, categorias, produtos, pedidos, itens_pedido.

```sql
-- Quais colunas tem a tabela clientes?
SELECT COLUMN_NAME     AS coluna,
       DATA_TYPE       AS tipo,
       IS_NULLABLE     AS aceita_nulo
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'clientes';
```

**Falar:** "Veja que email aceita nulo, mas nome não. Isso já é uma regra de negócio definida no banco."

---

### 1.2 — Primary Key

**Falar:** "Toda linha precisa ser identificável de forma única. A Primary Key garante isso — não existe dois clientes com o mesmo id."

```sql
SELECT id_cliente, nome, email
FROM clientes;
```

**Falar:** "Se eu tentar inserir um id repetido..."

```sql
-- Execute e mostre o erro
INSERT INTO clientes VALUES (1, 'Duplicado', 'dup@email.com', 'SP', 'SP', '2024-01-01');
```

**Apontar:** Erro `Violation of PRIMARY KEY constraint`. "O banco rejeita. Isso é integridade."

---

### 1.3 — Foreign Key

**Falar:** "FK é o elo entre tabelas. Um pedido pertence a um cliente — a FK garante que esse cliente exista."

```sql
SELECT p.id_pedido,
       c.nome    AS cliente,
       p.status
FROM pedidos   AS p
JOIN clientes  AS c ON p.id_cliente = c.id_cliente;
```

**Falar:** "Se eu tentar criar um pedido para um cliente que não existe..."

```sql
-- Execute e mostre o erro
INSERT INTO pedidos VALUES (99, 999, '2024-01-01', 'pendente', 0);
```

**Apontar:** Erro de FK. "O banco protege a integridade automaticamente."

---

### 1.4 — Relacionamentos: 1:N e N:N

**Falar:** "Um cliente tem vários pedidos — isso é 1 para N. Um pedido tem vários produtos, e um produto aparece em vários pedidos — isso é N para N."

```sql
-- 1:N — um cliente, vários pedidos
SELECT c.nome,
       COUNT(p.id_pedido) AS total_pedidos
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
GROUP BY c.nome
ORDER BY total_pedidos DESC;
```

**Falar:** "Para o N:N, existe uma tabela no meio — itens_pedido. Ela é a tabela associativa."

```sql
-- N:N — pedido com vários produtos
SELECT pr.nome     AS produto,
       i.quantidade
FROM pedidos      AS p
JOIN itens_pedido AS i  ON p.id_pedido  = i.id_pedido
JOIN produtos     AS pr ON i.id_produto = pr.id_produto
WHERE p.id_pedido = 8;
```

**Apontar:** Pedido 8 tem 3 produtos diferentes. Mude para `id_pedido = 1` e mostre outro.

---

### 1.5 — Transações e ACID

**Falar:** "Transação é tudo ou nada. Se qualquer passo falhar, tudo é desfeito. Isso é o A do ACID — Atomicidade."

```sql
BEGIN TRANSACTION;

    INSERT INTO pedidos VALUES (20, 1, GETDATE(), 'pendente', 0);

    INSERT INTO itens_pedido VALUES (50, 20, 9, 2, 79.90);
    INSERT INTO itens_pedido VALUES (51, 20, 7, 1, 45.00);

    UPDATE pedidos
    SET valor_total = (SELECT SUM(quantidade * preco_unitario)
                       FROM itens_pedido WHERE id_pedido = 20)
    WHERE id_pedido = 20;

COMMIT;
```

```sql
-- Confirma que tudo foi salvo junto
SELECT id_pedido, status, valor_total FROM pedidos WHERE id_pedido = 20;
SELECT * FROM itens_pedido WHERE id_pedido = 20;
```

**Falar:** "Se eu trocasse COMMIT por ROLLBACK, nada disso apareceria. O banco desfaz tudo. ACID na prática: A=tudo ou nada, C=banco nunca fica inválido, I=transações não interferem entre si, D=dado confirmado sobrevive a falha."

```sql
-- Limpeza
DELETE FROM itens_pedido WHERE id_pedido = 20;
DELETE FROM pedidos      WHERE id_pedido = 20;
```

---

### 1.6 — CRUD na visão de engenharia

**Falar:** "CRUD todo mundo conhece. O ponto de engenheiro é: UPDATE e DELETE sempre com WHERE. Sem WHERE, você afeta a tabela inteira."

```sql
INSERT INTO clientes VALUES (11, 'Karen Dias', 'karen@email.com', 'Manaus', 'AM', CAST(GETDATE() AS DATE));

SELECT id_cliente, nome, cidade FROM clientes WHERE id_cliente = 11;

UPDATE clientes SET cidade = 'Belém', uf = 'PA' WHERE id_cliente = 11;

DELETE FROM clientes WHERE id_cliente = 11;
```

**Falar:** "Agora tenta deletar um cliente que tem pedido."

```sql
-- Mostre o erro de FK
DELETE FROM clientes WHERE id_cliente = 1;
```

**Apontar:** Erro de FK. "O banco bloqueia porque existem pedidos ligados a esse cliente. Integridade referencial protegendo seus dados."

> **Encerramento da aula 1:**
> "Agora você sabe como o banco funciona por dentro. Na próxima aula a gente começa a usar SQL de verdade — como ferramenta de transformação de dados."

---

---

# AULA 2 — SQL para Engenharia de Dados
**⏱️ ~35 min** | Arquivo de referência: [`aula_2/exemplos.sql`](aula_2/exemplos.sql)

> **Falar na abertura:**
> "SQL não é só SELECT * FROM tabela. É uma linguagem de transformação. Tudo que você vai ver hoje você usa em pipeline, em dbt, em Spark SQL — a sintaxe muda um pouco, mas o conceito é o mesmo."

---

### 2.1 — SELECT bem estruturado

**Falar:** "Esses dois SELECTs retornam o mesmo resultado. Mas um é código de produção, o outro é código de improviso."

```sql
-- Feio — funciona, mas dificulta manutenção
SELECT nome,preco,estoque,preco*estoque FROM produtos;

-- Limpo — legível, com alias e formatação
SELECT
    nome                  AS produto,
    preco                 AS preco_unitario,
    estoque               AS qtd_em_estoque,
    preco * estoque       AS valor_em_estoque
FROM produtos
ORDER BY valor_em_estoque DESC;
```

**Falar:** "Em engenharia de dados, SELECT limpo é pipeline legível e auditável."

---

### 2.2 — WHERE e filtros

**Falar:** "Filtrar cedo evita processar dado desnecessário. Cada linha a menos que você carrega é processamento economizado."

```sql
-- IN — substitui vários OR
SELECT id_pedido, status
FROM pedidos
WHERE status IN ('pendente', 'aprovado', 'enviado');

-- BETWEEN — intervalo inclusivo
SELECT id_pedido, data_pedido, valor_total
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-03-31';

-- LIKE — padrão de texto
SELECT nome, email
FROM clientes
WHERE email LIKE '%@email.com';
```

---

### 2.3 — CASE WHEN

**Falar:** "CASE WHEN é a forma de colocar regra de negócio dentro do SQL. Você transforma o dado na consulta, sem precisar de código externo."

```sql
SELECT
    nome,
    preco,
    CASE
        WHEN preco < 100  THEN 'Básico'
        WHEN preco < 500  THEN 'Intermediário'
        WHEN preco < 2000 THEN 'Premium'
        ELSE                   'Ultra Premium'
    END AS faixa_preco
FROM produtos
ORDER BY preco;
```

```sql
SELECT
    id_pedido,
    status,
    valor_total,
    CASE status
        WHEN 'entregue'  THEN 'Receita Confirmada'
        WHEN 'cancelado' THEN 'Receita Perdida'
        ELSE                  'Em Andamento'
    END AS classificacao_receita
FROM pedidos;
```

**Falar:** "Esse segundo exemplo é exatamente o tipo de transformação que você faria em um pipeline ELT."

---

### 2.4 — JOINs

**Falar:** "JOIN é o conceito mais importante de SQL relacional. Vou mostrar INNER, LEFT, e JOIN múltiplo. Presta atenção em quantas linhas cada um retorna."

```sql
-- INNER JOIN — só quem existe nos dois lados
SELECT c.nome, p.id_pedido, p.valor_total
FROM clientes AS c
INNER JOIN pedidos AS p ON c.id_cliente = p.id_cliente;
```

**Apontar:** X linhas. "Clientes sem pedido não aparecem."

```sql
-- LEFT JOIN — todos da esquerda, com NULL onde não há correspondência
SELECT c.nome, p.id_pedido, p.status
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente;
```

**Apontar:** Mais linhas, com NULLs. "Agora aparece todo mundo."

```sql
-- Filtrar: quem NUNCA comprou
SELECT c.nome AS cliente_sem_pedido
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
WHERE p.id_pedido IS NULL;
```

```sql
-- JOIN múltiplo — atravessa 4 tabelas
SELECT
    c.nome           AS cliente,
    pr.nome          AS produto,
    i.quantidade,
    i.quantidade * i.preco_unitario AS subtotal
FROM clientes     AS c
JOIN pedidos      AS p  ON c.id_cliente  = p.id_cliente
JOIN itens_pedido AS i  ON p.id_pedido   = i.id_pedido
JOIN produtos     AS pr ON i.id_produto  = pr.id_produto
WHERE p.status = 'entregue'
ORDER BY subtotal DESC;
```

**Falar:** "É assim que você constrói uma visão desnormalizada pra análise — juntando as peças do modelo relacional."

---

### 2.5 — GROUP BY e HAVING

**Falar:** "GROUP BY resume dados por dimensão. É a base de qualquer relatório e de qualquer agregação num pipeline."

```sql
SELECT
    c.nome             AS cliente,
    COUNT(p.id_pedido) AS total_pedidos,
    SUM(p.valor_total) AS valor_total_gasto,
    AVG(p.valor_total) AS ticket_medio
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'
GROUP BY c.nome
ORDER BY valor_total_gasto DESC;
```

**Falar:** "HAVING é o filtro que roda DEPOIS do agrupamento. WHERE roda antes. Essa é uma das confusões mais comuns."

```sql
SELECT
    c.nome,
    SUM(p.valor_total) AS total_gasto
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'
GROUP BY c.nome
HAVING SUM(p.valor_total) > 1000
ORDER BY total_gasto DESC;
```

**Falar:** "Tenta colocar esse filtro no WHERE — o banco vai dar erro. WHERE não conhece o resultado do GROUP BY ainda."

---

### 2.6 — Subquery e CTE

**Falar:** "Às vezes você precisa de uma consulta que depende de outra. Tem duas formas: subquery inline ou CTE. CTE é mais legível — recomendo para qualquer coisa acima de 5 linhas."

```sql
-- Subquery: produtos acima da média de preço
SELECT nome, preco
FROM produtos
WHERE preco > (SELECT AVG(preco) FROM produtos)
ORDER BY preco;
```

```sql
-- CTE — mesma lógica, mais legível
WITH resumo_pedidos AS (
    SELECT
        id_pedido,
        SUM(quantidade)                  AS total_itens,
        SUM(quantidade * preco_unitario) AS valor_calculado
    FROM itens_pedido
    GROUP BY id_pedido
)
SELECT
    p.id_pedido,
    p.status,
    r.total_itens,
    r.valor_calculado
FROM pedidos        AS p
JOIN resumo_pedidos AS r ON p.id_pedido = r.id_pedido
ORDER BY r.valor_calculado DESC;
```

**Falar:** "A CTE vira uma 'tabela temporária com nome'. Você pode referenciar ela depois como se fosse uma tabela normal."

---

### 2.7 — Window Functions

**Falar:** "Window function é o que muda o nível do seu SQL. GROUP BY colapsa as linhas — você perde o detalhe. OVER não colapsa — você agrega e mantém todas as linhas."

```sql
-- ROW_NUMBER: número do pedido por cliente
SELECT
    c.nome,
    p.id_pedido,
    p.data_pedido,
    p.valor_total,
    ROW_NUMBER() OVER (
        PARTITION BY p.id_cliente
        ORDER BY p.data_pedido
    ) AS numero_pedido_do_cliente
FROM pedidos  AS p
JOIN clientes AS c ON p.id_cliente = c.id_cliente
ORDER BY c.nome, p.data_pedido;
```

**Apontar:** "Veja que Ana tem pedido 1, 2, 3 — reinicia por cliente. PARTITION BY é o 'agrupador', ORDER BY é a ordenação dentro de cada grupo."

```sql
-- SUM OVER: receita acumulada
SELECT
    data_pedido,
    valor_total,
    SUM(valor_total) OVER (
        ORDER BY data_pedido
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS receita_acumulada
FROM pedidos
WHERE status = 'entregue'
ORDER BY data_pedido;
```

**Falar:** "Cada linha tem o valor do dia E o acumulado até aquele dia. Impossível fazer isso com GROUP BY sem perder as linhas individuais."

> **Encerramento da aula 2:**
> "Com isso você já consegue transformar dados de verdade. Na próxima aula a gente organiza essa lógica dentro do banco — views, procedures e funções."

---

---

# AULA 3 — Views, Procedures e Funções
**⏱️ ~25 min** | Arquivo de referência: [`aula_3/exemplos.sql`](aula_3/exemplos.sql)

> **Falar na abertura:**
> "Você aprendeu a escrever SQL. Agora você vai aprender a organizar esse SQL dentro do banco — para que qualquer pessoa, qualquer ferramenta, acesse sempre o dado do jeito certo."

---

### 3.1 — VIEW

**Falar:** "Sem VIEW, cada pessoa da equipe escreve o mesmo JOIN do zero — e cada um filtra de um jeito diferente. VIEW centraliza a lógica."

```sql
-- Problema: todo mundo reescreve isso
SELECT c.nome, p.id_pedido, p.valor_total, p.status
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente;
```

```sql
-- Solução: criar uma VIEW
CREATE VIEW vw_pedidos_clientes AS
SELECT
    c.id_cliente,
    c.nome          AS cliente,
    c.cidade,
    p.id_pedido,
    p.data_pedido,
    p.status,
    p.valor_total
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente;
```

```sql
-- Consumir como se fosse tabela
SELECT * FROM vw_pedidos_clientes WHERE status = 'entregue';

SELECT cliente, SUM(valor_total) AS total
FROM vw_pedidos_clientes
GROUP BY cliente;
```

**Falar:** "A VIEW não armazena dados. Toda vez que você consulta ela, o SELECT roda. É uma camada de abstração — você padroniza o consumo."

```sql
-- View de resumo: uma por cliente
CREATE VIEW vw_resumo_cliente AS
SELECT
    c.id_cliente,
    c.nome,
    COUNT(p.id_pedido) AS total_pedidos,
    SUM(CASE WHEN p.status = 'entregue'  THEN p.valor_total ELSE 0 END) AS receita_confirmada,
    SUM(CASE WHEN p.status = 'cancelado' THEN p.valor_total ELSE 0 END) AS receita_perdida
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nome;
```

```sql
SELECT * FROM vw_resumo_cliente ORDER BY receita_confirmada DESC;
```

---

### 3.2 — Stored Procedures

**Falar:** "Procedure é lógica de processo dentro do banco. Recebe parâmetros, executa passos, pode fazer INSERT, UPDATE, DELETE. É um step de pipeline dentro do SQL."

```sql
CREATE PROCEDURE sp_pedidos_periodo
    @data_inicio DATE,
    @data_fim    DATE
AS
BEGIN
    SELECT
        p.id_pedido,
        c.nome        AS cliente,
        p.data_pedido,
        p.status,
        p.valor_total
    FROM pedidos  AS p
    JOIN clientes AS c ON p.id_cliente = c.id_cliente
    WHERE p.data_pedido BETWEEN @data_inicio AND @data_fim
    ORDER BY p.data_pedido;
END;
```

```sql
-- Executar com parâmetros diferentes
EXEC sp_pedidos_periodo '2024-01-01', '2024-03-31';
EXEC sp_pedidos_periodo '2024-04-01', '2024-06-30';
```

**Falar:** "Veja — mesma procedure, resultados diferentes. Você passa o período, ela retorna o recorte certo. Em ETL, você chamaria essa procedure dentro do seu pipeline."

```sql
-- Procedure de processo com valor padrão
CREATE PROCEDURE sp_cancelar_pendentes
    @dias_limite INT = 30
AS
BEGIN
    UPDATE pedidos
    SET status = 'cancelado'
    WHERE status = 'pendente'
      AND DATEDIFF(DAY, data_pedido, GETDATE()) > @dias_limite;

    SELECT @@ROWCOUNT AS pedidos_cancelados, GETDATE() AS executado_em;
END;
```

**Falar:** "Esse parâmetro tem valor padrão — se não passar nada, usa 30 dias. Em produção, essa procedure seria agendada todo dia num job do SQL Server ou num Airflow."

---

### 3.3 — Funções escalares

**Falar:** "Função escalar retorna um único valor. Você usa ela dentro de um SELECT como se fosse uma coluna calculada."

```sql
CREATE FUNCTION fn_valor_com_desconto
(
    @valor        DECIMAL(10,2),
    @pct_desconto DECIMAL(5,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @valor - (@valor * @pct_desconto / 100);
END;
```

```sql
SELECT
    nome,
    preco                                  AS preco_original,
    dbo.fn_valor_com_desconto(preco, 10)   AS preco_10pct_off,
    dbo.fn_valor_com_desconto(preco, 15)   AS preco_15pct_off
FROM produtos
WHERE preco > 100;
```

**Falar:** "A função encapsula o cálculo. Se a regra de desconto mudar, você muda só aqui — todo SELECT que usa ela já recebe o novo cálculo."

---

### 3.4 — Funções de tabela

**Falar:** "Função de tabela retorna um conjunto de linhas — é como uma VIEW que aceita parâmetro."

```sql
CREATE FUNCTION fn_itens_pedido (@id_pedido INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        pr.nome                         AS produto,
        cat.nome                        AS categoria,
        i.quantidade,
        i.preco_unitario,
        i.quantidade * i.preco_unitario AS subtotal
    FROM itens_pedido AS i
    JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
    JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
    WHERE i.id_pedido = @id_pedido
);
```

```sql
-- Chamar para um pedido específico
SELECT * FROM dbo.fn_itens_pedido(8);
```

```sql
-- Usar com CROSS APPLY — chama a função para cada pedido
SELECT
    p.id_pedido,
    c.nome     AS cliente,
    itens.*
FROM pedidos  AS p
JOIN clientes AS c ON p.id_cliente = c.id_cliente
CROSS APPLY dbo.fn_itens_pedido(p.id_pedido) AS itens
WHERE p.id_pedido IN (1, 7, 8);
```

**Falar:** "CROSS APPLY é como um JOIN onde um dos lados é uma função. Para cada pedido, ele chama a função e junta o resultado."

> **Encerramento da aula 3:**
> "Resumo: VIEW para padronizar consulta, Procedure para processo/ação, Função para cálculo reutilizável. Na próxima aula a gente vai falar de performance e qualidade — índices e constraints."

---

---

# AULA 4 — Index e Constraints
**⏱️ ~25 min** | Arquivo de referência: [`aula_4/exemplos.sql`](aula_4/exemplos.sql)

> **Falar na abertura:**
> "Índice garante que a leitura seja rápida. Constraint garante que o dado que entrou é válido. Esses dois juntos são a diferença entre um banco funcional e um banco confiável."

---

### 4.1 — O que é índice

**Falar:** "Sem índice, o banco lê todas as linhas para achar o dado — table scan. Com índice, ele vai direto. É como procurar um nome num livro com e sem índice remissivo."

```sql
-- Ver os índices existentes em clientes
SELECT
    i.name         AS nome_indice,
    i.type_desc    AS tipo,
    i.is_primary_key,
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS colunas
FROM sys.indexes       AS i
JOIN sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns       AS c  ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'clientes'
GROUP BY i.name, i.type_desc, i.is_primary_key, i.is_unique;
```

**Apontar:** "A PRIMARY KEY já criou um índice automaticamente — do tipo CLUSTERED."

---

### 4.2 — Clustered vs Nonclustered

**Falar:** "Clustered organiza os dados físicos da tabela — só pode ter um. Nonclustered é uma estrutura separada que aponta para os dados — pode ter vários."

```sql
-- Clustered = PK da tabela (dados ordenados por id_pedido no disco)

-- Criar nonclustered em data_pedido
-- (busca por período é muito comum)
CREATE NONCLUSTERED INDEX idx_pedidos_data
ON pedidos (data_pedido);

-- Índice composto: status + data
-- Útil quando filtra status E período ao mesmo tempo
CREATE NONCLUSTERED INDEX idx_pedidos_status_data
ON pedidos (status, data_pedido);

-- Índice com INCLUDE: carrega valor_total no próprio índice
-- Evita ir à tabela pra buscar essa coluna
CREATE NONCLUSTERED INDEX idx_pedidos_cliente
ON pedidos (id_cliente)
INCLUDE (data_pedido, valor_total, status);
```

```sql
-- Essas queries agora usam os índices criados
SELECT id_pedido, status, valor_total
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-03-31';

SELECT id_pedido, data_pedido, valor_total
FROM pedidos
WHERE id_cliente = 1;
```

---

### 4.3 — Trade-off: leitura vs escrita

**Falar:** "Mais índice não é sempre melhor. Leitura fica mais rápida, mas escrita fica mais lenta — cada INSERT e UPDATE precisa atualizar todos os índices também."

**Falar:** "Regra prática: coluna que aparece muito no WHERE, JOIN ou ORDER BY — cria índice. Tabela de staging que recebe carga em massa — remove os índices antes da carga, recria depois. Uma tabela de staging com 5 índices e 10 milhões de linhas por dia sente muito isso."

---

### 4.4 — Constraints

**Falar:** "Constraint é regra de qualidade definida no banco. Não importa se veio de um app, de um pipeline ou de um script manual — o banco valida."

```sql
-- Ver as constraints do banco
SELECT
    tc.CONSTRAINT_NAME  AS constraint,
    tc.CONSTRAINT_TYPE  AS tipo,
    tc.TABLE_NAME       AS tabela,
    kcu.COLUMN_NAME     AS coluna
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE  AS kcu
     ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    AND tc.TABLE_NAME      = kcu.TABLE_NAME
ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_TYPE;
```

**Falar:** "Já temos PRIMARY KEY, FOREIGN KEY e UNIQUE criados. Vamos ver as CHECK constraints — regras de domínio em SQL."

```sql
-- Ver as CHECK constraints
SELECT cc.CONSTRAINT_NAME, cc.TABLE_NAME, cc.CHECK_CLAUSE
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS AS cc
JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
     ON cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME;
```

**Apontar:** `chk_preco_positivo`, `chk_qtd_positiva`, `chk_status`. "Essas regras já estavam no banco.sql."

```sql
-- Testar: preço negativo
INSERT INTO produtos VALUES (99, 'Teste', 1, -50, 0);
```

**Apontar:** Erro de CHECK. "O banco rejeita na fonte."

```sql
-- Criar nova CHECK constraint
ALTER TABLE clientes
ADD CONSTRAINT chk_uf_valido
CHECK (uf IN ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA',
              'MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN',
              'RS','RO','RR','SC','SP','SE','TO'));

-- Testar
INSERT INTO clientes VALUES (20, 'Teste', 'x@x.com', 'XX', 'ZZ', '2024-01-01');
```

**Apontar:** Erro. "UF inválida bloqueada pelo banco."

```sql
-- Remove (para manter o banco limpo)
ALTER TABLE clientes DROP CONSTRAINT chk_uf_valido;
```

> **Encerramento da aula 4:**
> "Você agora consegue garantir performance com índice e qualidade com constraint. Na última aula a gente conecta tudo isso ao mundo do Data Warehouse."

---

---

# AULA 5 — SQL no Data Warehouse
**⏱️ ~30 min** | Arquivo de referência: [`aula_5/exemplos.sql`](aula_5/exemplos.sql)

> **Falar na abertura:**
> "Tudo que você aprendeu nas 4 aulas anteriores — JOIN, CTE, window function, constraints, índice — vira ferramenta aqui. O DW não é uma tecnologia nova. É um padrão. E SQL é a linguagem que move dados dentro dele."

---

### 5.1 — OLTP vs OLAP

**Falar:** "OLTP é o banco operacional — muitas transações pequenas e rápidas. OLAP é o banco analítico — poucas queries grandes sobre muitos dados. No OLTP você normaliza pra evitar redundância. No OLAP você desnormaliza pra ter performance analítica."

```sql
USE loja_db;

-- No OLTP: essa query simples precisa de 4 JOINs
SELECT
    cat.nome                                    AS categoria,
    SUM(i.quantidade * i.preco_unitario)        AS receita_janeiro
FROM itens_pedido AS i
JOIN pedidos      AS p   ON i.id_pedido     = p.id_pedido
JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
WHERE p.data_pedido BETWEEN '2024-01-01' AND '2024-01-31'
  AND p.status = 'entregue'
GROUP BY cat.nome;
```

**Falar:** "Guarda esse resultado. A gente vai fazer a mesma pergunta no DW no final da aula — muito mais simples."

---

### 5.2 — Star Schema: fato e dimensão

**Falar:** "No DW, você tem dois tipos de tabela. Dimensão = contexto: quem, o quê, quando, onde. Fato = o que aconteceu em números. O modelo estrela conecta as dimensões à fato."

```sql
USE dw_loja;

-- Ver a estrutura das dimensões
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_cliente';

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fato_vendas';
```

**Falar:** "Repara no sk_cliente em fato_vendas — é a surrogate key. Não é o id_cliente do OLTP. O DW gera a própria chave, independente do sistema de origem. Isso permite guardar histórico de mudanças — que a gente vai ver no SCD."

---

### 5.3 — Carga: staging → dimensões

**Falar:** "O fluxo de carga tem três etapas: extrai do OLTP pra staging, da staging pra dimensões, das dimensões pra fato. Vamos executar cada passo."

```sql
-- Passo 1: extrai do OLTP para staging
TRUNCATE TABLE stg_pedidos;

INSERT INTO stg_pedidos (id_pedido, id_cliente, nome_cliente, cidade, uf,
                          id_produto, nome_produto, categoria, preco_produto,
                          data_pedido, quantidade, valor)
SELECT
    p.id_pedido, c.id_cliente, c.nome, c.cidade, c.uf,
    pr.id_produto, pr.nome, cat.nome, pr.preco,
    p.data_pedido, i.quantidade,
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
-- Passo 2: da staging para dim_cliente (só clientes novos)
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
SELECT DISTINCT s.id_cliente, s.nome_cliente, s.cidade, s.uf,
                CAST(GETDATE() AS DATE), 1
FROM stg_pedidos AS s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_cliente AS d
    WHERE d.id_cliente_origem = s.id_cliente AND d.ativo = 1
);

-- Passo 3: idem para dim_produto
INSERT INTO dim_produto (id_produto_origem, nome, categoria, preco, data_inicio, ativo)
SELECT DISTINCT s.id_produto, s.nome_produto, s.categoria, s.preco_produto,
                CAST(GETDATE() AS DATE), 1
FROM stg_pedidos AS s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_produto AS d
    WHERE d.id_produto_origem = s.id_produto AND d.ativo = 1
);

SELECT COUNT(*) AS clientes FROM dim_cliente;
SELECT COUNT(*) AS produtos FROM dim_produto;
```

**Falar:** "O WHERE NOT EXISTS é a lógica de carga incremental — só insere quem ainda não está. Execute duas vezes — na segunda vai retornar 0 inseridos."

---

### 5.4 — Carregando a fato e comparando com OLTP

```sql
-- Carrega fato_vendas referenciando as surrogate keys
INSERT INTO fato_vendas (sk_cliente, sk_produto, sk_tempo, id_pedido_origem, quantidade, valor)
SELECT
    dc.sk_cliente, dp.sk_produto, dt.sk_tempo,
    s.id_pedido, s.quantidade, s.valor
FROM stg_pedidos AS s
JOIN dim_cliente AS dc ON s.id_cliente = dc.id_cliente_origem AND dc.ativo = 1
JOIN dim_produto AS dp ON s.id_produto = dp.id_produto_origem AND dp.ativo = 1
JOIN dim_tempo   AS dt ON CAST(FORMAT(s.data_pedido, 'yyyyMMdd') AS INT) = dt.sk_tempo
WHERE NOT EXISTS (
    SELECT 1 FROM fato_vendas AS f
    WHERE f.id_pedido_origem = s.id_pedido AND f.sk_produto = dp.sk_produto
);

SELECT COUNT(*) AS linhas_na_fato FROM fato_vendas;
```

```sql
-- A mesma pergunta do início — agora no DW
SELECT
    dp.categoria,
    SUM(f.valor) AS receita_total
FROM fato_vendas AS f
JOIN dim_produto AS dp ON f.sk_produto = dp.sk_produto
JOIN dim_tempo   AS dt ON f.sk_tempo   = dt.sk_tempo
WHERE dt.mes = 1 AND dt.ano = 2024
GROUP BY dp.categoria
ORDER BY receita_total DESC;
```

**Falar:** "Mesmo resultado. Mas agora: sem JOIN em pedidos, sem JOIN em clientes, sem JOIN em itens_pedido e categorias. No OLTP eram 4 JOINs. No DW são 2. Em bilhões de linhas, essa diferença é enorme."

---

### 5.5 — MERGE (upsert)

**Falar:** "MERGE resolve em uma instrução o que normalmente precisaria de dois passos: inserir quem é novo, atualizar quem mudou."

```sql
-- Staging com dados atualizados
CREATE TABLE #stg_clientes_delta (
    id_cliente INT, nome VARCHAR(100), cidade VARCHAR(50), uf CHAR(2)
);

INSERT INTO #stg_clientes_delta VALUES
(1,  'Ana Lima',     'Campinas',       'SP'),  -- mudou de cidade
(2,  'Bruno Santos', 'Rio de Janeiro', 'RJ'),  -- sem mudança
(11, 'Karen Dias',   'Belém',          'PA');  -- cliente novo no DW
```

```sql
MERGE dim_cliente AS destino
USING (SELECT id_cliente, nome, cidade, uf FROM #stg_clientes_delta) AS origem
ON destino.id_cliente_origem = origem.id_cliente AND destino.ativo = 1

WHEN MATCHED AND (destino.cidade <> origem.cidade OR destino.uf <> origem.uf) THEN
    UPDATE SET destino.cidade = origem.cidade, destino.uf = origem.uf

WHEN NOT MATCHED BY TARGET THEN
    INSERT (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
    VALUES (origem.id_cliente, origem.nome, origem.cidade, origem.uf,
            CAST(GETDATE() AS DATE), 1);

DROP TABLE #stg_clientes_delta;

SELECT sk_cliente, id_cliente_origem, nome, cidade, uf FROM dim_cliente ORDER BY id_cliente_origem;
```

**Apontar:** Ana agora está em Campinas. Karen foi inserida. Bruno não mudou.

---

### 5.6 — SCD Tipo 1 e Tipo 2

**Falar:** "SCD — Slowly Changing Dimension — define como você trata mudanças nos dados dimensionais. Tipo 1: sobrescreve, sem histórico. Tipo 2: preserva o histórico criando nova linha."

```sql
-- SCD Tipo 1: corrige sem guardar o que era antes
-- Quando usar: correção de erro, campo sem valor histórico
UPDATE dim_cliente
SET nome = 'Ana Lima Silva'
WHERE id_cliente_origem = 1 AND ativo = 1;

-- Desfaz
UPDATE dim_cliente
SET nome = 'Ana Lima'
WHERE id_cliente_origem = 1 AND ativo = 1;
```

**Falar:** "Agora SCD Tipo 2 — imagine que Ana mudou de cidade. Não queremos perder a informação de que ela era de SP quando comprou o Notebook."

```sql
-- Passo 1: fecha o registro atual
UPDATE dim_cliente
SET data_fim = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
    ativo    = 0
WHERE id_cliente_origem = 1 AND ativo = 1;

-- Passo 2: insere nova versão
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
VALUES (1, 'Ana Lima', 'Rio de Janeiro', 'RJ', CAST(GETDATE() AS DATE), 1);

-- Resultado: duas versões de Ana
SELECT sk_cliente, nome, cidade, uf, data_inicio, data_fim, ativo
FROM dim_cliente
WHERE id_cliente_origem = 1
ORDER BY data_inicio;
```

**Falar:** "Duas linhas — duas surrogate keys diferentes. As vendas antigas continuam apontando para a sk antiga, que diz que Ana era de SP. As novas apontam para a nova sk, que diz Rio de Janeiro. Histórico preservado automaticamente."

**Falar:** "Esse é o valor do DW. Não é só guardar dado — é guardar o estado do dado no momento em que o fato aconteceu."

> **Encerramento final:**
> "Em 5 aulas você foi de 'o que é uma tabela' até SCD Tipo 2 e pipeline de DW. Tudo com SQL. Isso é o que você vai usar no dia a dia como engenheiro de dados."
>
> "Os exercícios têm três níveis na pasta `/exercicios` — básico, intermediário e avançado, todos com gabarito. Se esse conteúdo foi útil, compartilha com quem tá começando na área."

---

---

## 📁 Referências Rápidas

| Arquivo | Uso |
|---------|-----|
| [`banco.sql`](banco.sql) | Rodar antes de tudo |
| [`aula_1/exemplos.sql`](aula_1/exemplos.sql) | Código completo da aula 1 |
| [`aula_2/exemplos.sql`](aula_2/exemplos.sql) | Código completo da aula 2 |
| [`aula_3/exemplos.sql`](aula_3/exemplos.sql) | Código completo da aula 3 |
| [`aula_4/exemplos.sql`](aula_4/exemplos.sql) | Código completo da aula 4 |
| [`aula_5/exemplos.sql`](aula_5/exemplos.sql) | Código completo da aula 5 |
| [`exercicios/basico.sql`](exercicios/basico.sql) | 8 exercícios nível básico |
| [`exercicios/intermediario.sql`](exercicios/intermediario.sql) | 6 exercícios nível intermediário |
| [`exercicios/avancado.sql`](exercicios/avancado.sql) | 4 exercícios nível avançado |
