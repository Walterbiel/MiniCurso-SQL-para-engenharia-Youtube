# AULA 5 — SQL no Data Warehouse
**⏱️ ~30 min** | SQL Server (T-SQL) | Arquivo de código: [`exemplos.sql`](exemplos.sql)

> **Abertura — falar:**
> "Tudo que você aprendeu nas 4 aulas anteriores — JOIN, CTE, window function, constraints, índice — vira ferramenta aqui. O Data Warehouse não é uma tecnologia nova e misteriosa. É um padrão arquitetural. E SQL é a linguagem que move dados dentro dele. Nessa aula você vai ver um pipeline completo de DW rodando — extração, carga de dimensões, carga de fato, e tratamento de mudanças históricas."

---

## Checklist antes de começar

- [ ] `banco.sql` já foi executado — `loja_db` e `dw_loja` existem
- [ ] Confirmar as tabelas de `dw_loja`: stg_pedidos, dim_cliente, dim_produto, dim_tempo, fato_vendas

---

## 5.1 — OLTP vs OLAP: dois mundos com objetivos opostos

**Conceito para falar:**
"Todo dado começa num sistema transacional — OLTP. O sistema de e-commerce, o ERP, o CRM. Esses sistemas são otimizados para transações rápidas: INSERT de um pedido, UPDATE de um status, SELECT de um cliente. Alta frequência de operações pequenas."

"O problema é que perguntas analíticas em OLTP são pesadas. 'Qual categoria vendeu mais nos últimos 6 meses por região?' exige JOINs em 4 tabelas, varrer milhões de linhas. Isso compete com as transações do dia a dia e deixa o sistema lento para todos."

"O OLAP — Data Warehouse — resolve isso. Os dados são transformados e carregados em um modelo específico para análise: desnormalizado, otimizado para leitura, com histórico completo."

**Diferenças centrais:**

| Característica | OLTP | OLAP (DW) |
|----------------|------|-----------|
| Objetivo | Operações do dia a dia | Análise e relatórios |
| Modelo | Normalizado (evita redundância) | Desnormalizado (performance analítica) |
| Operações frequentes | INSERT, UPDATE, DELETE | SELECT com agregações |
| Volume por query | Poucas linhas | Muitas linhas |
| Histórico | Atual | Completo (anos) |
| Atualização | Tempo real | Periódica (batch) |

```sql
USE loja_db;

-- No OLTP: uma pergunta analítica simples exige 4 JOINs
-- Em escala de bilhões de linhas, isso é muito custoso
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

**Falar:** "Guarda esse resultado — categoria e receita de janeiro/2024. A gente vai repetir a mesma pergunta no DW mais adiante. Compare a quantidade de JOINs e a complexidade da query."

---

## 5.2 — Star Schema: o modelo do Data Warehouse

**Conceito para falar:**
"No DW, você tem dois tipos de tabela fundamentais:"

**Dimensão (dim_):** o *contexto* — quem comprou, o quê foi comprado, quando, onde. São os atributos descritivos. Mudam pouco, têm histórico. Exemplos: dim_cliente, dim_produto, dim_tempo.

**Fato (fato_):** o *que aconteceu*, em números. Cada linha é um evento mensurável — uma venda, um clique, uma transação. Contém as FKs para as dimensões e as métricas numéricas (quantidade, valor, etc).

"O modelo estrela (Star Schema) conecta a tabela fato ao centro, e as dimensões nas pontas — daí o nome estrela."

"Um detalhe crítico: a fato usa *surrogate keys* (sk_) — chaves geradas pelo próprio DW, não as do OLTP. Isso permite guardar histórico de mudanças, integrar múltiplas fontes e desacoplar o DW do sistema de origem."

```sql
USE dw_loja;

-- Estrutura da dimensão de cliente
-- Repare: id_cliente_origem (do OLTP), sk_cliente (chave do DW), campos de SCD (data_inicio, data_fim, ativo)
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_cliente'
ORDER BY ORDINAL_POSITION;

-- Estrutura da tabela fato
-- Repare: usa sk_ (surrogate keys) para referenciar dimensões — não os IDs do OLTP
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fato_vendas'
ORDER BY ORDINAL_POSITION;
```

**Apontar:**
- `sk_cliente` em `fato_vendas` — surrogate key gerada pelo DW, não o `id_cliente` do OLTP
- `data_inicio`, `data_fim`, `ativo` em `dim_cliente` — campos para suportar histórico de mudanças (SCD Tipo 2, veremos adiante)

---

## 5.3 — Arquitetura de carga: OLTP → Staging → Dimensões → Fato

**Conceito para falar:**
"O fluxo de carga do DW segue sempre essa sequência obrigatória:"

```
OLTP → Staging → Dimensões → Fato
```

"**Staging**: extrai os dados do OLTP como vieram, sem transformação. É a 'zona de pouso' — você isola o DW do sistema operacional e tem um snapshot dos dados para processar com segurança."

"**Dimensões antes da fato**: você carrega clientes e produtos antes de carregar vendas, porque a fato precisa das surrogate keys das dimensões para fazer referência correta."

"**Fato por último**: resolve as surrogate keys das dimensões e carrega os fatos (as métricas)."

```sql
USE dw_loja;

-- PASSO 1: Staging — extrai do OLTP e pousa na zona de staging
-- TRUNCATE antes de recarregar (processamento idempotente do zero)
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
    i.quantidade * i.preco_unitario     -- valor já calculado na staging
FROM loja_db.dbo.itens_pedido AS i
JOIN loja_db.dbo.pedidos      AS p   ON i.id_pedido     = p.id_pedido
JOIN loja_db.dbo.clientes     AS c   ON p.id_cliente    = c.id_cliente
JOIN loja_db.dbo.produtos     AS pr  ON i.id_produto    = pr.id_produto
JOIN loja_db.dbo.categorias   AS cat ON pr.id_categoria = cat.id_categoria
WHERE p.status = 'entregue';    -- só vendas confirmadas vão para o DW

-- Quantas linhas foram extraídas?
SELECT COUNT(*) AS linhas_na_staging FROM stg_pedidos;
```

```sql
-- PASSO 2: Carrega dim_cliente — carga incremental, só clientes novos
-- WHERE NOT EXISTS é o mecanismo de idempotência
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
SELECT DISTINCT
    s.id_cliente,
    s.nome_cliente,
    s.cidade,
    s.uf,
    CAST(GETDATE() AS DATE),
    1                           -- ativo = 1 = registro atual (para SCD Tipo 2)
FROM stg_pedidos AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_cliente AS d
    WHERE d.id_cliente_origem = s.id_cliente
      AND d.ativo = 1
);

-- PASSO 3: Carrega dim_produto — mesma lógica incremental
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

**Falar:** "Execute os dois INSERTs de dimensão uma segunda vez — vai retornar 0 linhas inseridas. O `WHERE NOT EXISTS` é o mecanismo de idempotência: você pode rodar quantas vezes quiser, o resultado é o mesmo. Isso é fundamental em pipelines — a carga deve ser segura para re-execução sem duplicar dados."

---

## 5.4 — Carregando a Fato e validando com OLTP

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
-- Resolve SK de cliente: JOIN por id_origem + ativo=1 (versão atual)
JOIN dim_cliente AS dc ON s.id_cliente = dc.id_cliente_origem AND dc.ativo = 1
-- Resolve SK de produto: mesma lógica
JOIN dim_produto AS dp ON s.id_produto = dp.id_produto_origem AND dp.ativo = 1
-- Resolve SK de tempo: chave inteira no formato yyyymmdd (ex: 20240115)
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
-- VALIDAÇÃO CRUZADA: mesma pergunta — agora no DW
-- Compare com o OLTP lá do início: antes eram 4 JOINs em 5 tabelas
USE dw_loja;

SELECT
    dp.categoria,
    SUM(f.valor)            AS receita_total,
    COUNT(*)                AS qtd_itens_vendidos
FROM fato_vendas AS f
JOIN dim_produto AS dp ON f.sk_produto = dp.sk_produto
JOIN dim_tempo   AS dt ON f.sk_tempo   = dt.sk_tempo
WHERE dt.mes = 1
  AND dt.ano = 2024
GROUP BY dp.categoria
ORDER BY receita_total DESC;
```

**Falar devagar:** "Mesmo resultado que o OLTP. Mas agora: sem JOIN em pedidos, sem JOIN em clientes, sem JOIN em itens_pedido, sem JOIN em categorias. No OLTP eram 4 JOINs. No DW são 2 JOINs. Com bilhões de linhas, em petabytes de dados, essa diferença determina se a query demora 2 segundos ou 20 minutos."

---

## 5.5 — MERGE: upsert em uma instrução

**Conceito para falar:**
"MERGE resolve em uma única instrução o que normalmente exigiria dois passos: inserir linhas novas e atualizar linhas que mudaram. É o operador de 'upsert' do SQL — muito usado em carga incremental de dimensões e fatos."

"A sintaxe define três cenários: WHEN MATCHED (linha existe nos dois lados), WHEN NOT MATCHED BY TARGET (linha nova), WHEN NOT MATCHED BY SOURCE (linha que sumiu da origem)."

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
-- MERGE: um único comando faz insert E update
MERGE dim_cliente AS destino
USING (
    SELECT id_cliente, nome, cidade, uf
    FROM #stg_clientes_delta
) AS origem
ON destino.id_cliente_origem = origem.id_cliente
AND destino.ativo = 1

-- Existe nos dois lados E houve mudança em cidade ou uf: ATUALIZA
WHEN MATCHED AND (
    destino.cidade <> origem.cidade OR
    destino.uf     <> origem.uf
) THEN
    UPDATE SET
        destino.cidade = origem.cidade,
        destino.uf     = origem.uf

-- Existe só na origem (cliente novo): INSERE
WHEN NOT MATCHED BY TARGET THEN
    INSERT (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
    VALUES (origem.id_cliente, origem.nome, origem.cidade, origem.uf,
            CAST(GETDATE() AS DATE), 1);

DROP TABLE #stg_clientes_delta;

-- Resultado: Ana em Campinas, Karen inserida, Bruno igual
SELECT sk_cliente, id_cliente_origem, nome, cidade, uf, ativo
FROM dim_cliente
ORDER BY id_cliente_origem;
```

**Apontar:** "Ana agora está em Campinas. Karen foi inserida com nova surrogate key. Bruno permaneceu — o MERGE não tocou porque não houve mudança nos campos verificados."

---

## 5.6 — SCD Tipo 1 e Tipo 2: tratando mudanças históricas em dimensões

**Conceito para falar:**
"SCD — Slowly Changing Dimension — é um dos padrões mais importantes de Data Warehouse. Define como você trata o fato de que dimensões mudam com o tempo."

"Exemplo clássico: Ana mora em São Paulo. Ela compra um notebook. Depois ela se muda para o Rio de Janeiro. Ela compra mais um produto. Quando você analisa 'vendas por cidade', o notebook foi vendido para uma cliente de SP ou RJ?"

"A resposta depende do tipo de SCD implementado."

---

### SCD Tipo 1 — Sobrescreve, sem histórico

- **Quando usar**: dados que corrigem um erro (nome digitado errado, email errado), ou atributos que genuinamente não têm valor histórico
- **Risco**: você perde o histórico — não sabe o que era antes
- **Caso de uso**: preferência de idioma, flag de opt-in, correção de typo

```sql
-- SCD Tipo 1: sobrescreve o valor diretamente
-- Caso de uso: correção de nome digitado com erro
UPDATE dim_cliente
SET nome = 'Ana Lima Silva'         -- versão corrigida
WHERE id_cliente_origem = 1
  AND ativo = 1;

-- Desfaz para o próximo exemplo
UPDATE dim_cliente
SET nome = 'Ana Lima'
WHERE id_cliente_origem = 1
  AND ativo = 1;
```

**Falar:** "Tipo 1 é simples — sobrescreve e pronto. Mas você perdeu a informação de que o nome anterior era diferente. Não há como saber o histórico. Para atributos sem valor histórico, isso é aceitável."

---

### SCD Tipo 2 — Preserva histórico com nova linha

- **Quando usar**: atributos que mudam e têm valor histórico (cidade, cargo, segmento de cliente, região de vendas)
- **Mecanismo**: fecha o registro atual (seta `data_fim` e `ativo = 0`), insere novo registro com nova surrogate key
- **Resultado**: várias linhas por entidade, cada uma representando um período de tempo

```sql
-- SCD Tipo 2: Ana mudou de SP para RJ — queremos guardar o histórico

-- PASSO 1: fecha o registro atual — define a data em que parou de ser válido
UPDATE dim_cliente
SET data_fim = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
    ativo    = 0
WHERE id_cliente_origem = 1
  AND ativo = 1;

-- PASSO 2: insere nova versão com os novos dados — recebe nova surrogate key
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

**Falar devagar:** "Duas linhas — duas surrogate keys diferentes. As vendas antigas (o notebook) continuam apontando para a sk antiga — que diz que Ana era de SP quando comprou. As novas vendas apontarão para a nova sk — que diz Rio de Janeiro. O histórico está preservado automaticamente, sem nenhuma alteração na tabela fato."

```sql
-- Consulta histórica: qual cidade o cliente era em cada compra
-- O JOIN por sk (não por id_origem) garante que cada venda usa o estado correto do cliente
SELECT
    f.id_pedido_origem,
    dc.nome             AS cliente,
    dc.cidade           AS cidade_na_epoca_da_compra,
    dc.data_inicio      AS versao_cliente_desde,
    dt.data_completa    AS data_venda,
    f.valor
FROM fato_vendas AS f
JOIN dim_cliente AS dc ON f.sk_cliente = dc.sk_cliente   -- usa SK, não id_origem
JOIN dim_tempo   AS dt ON f.sk_tempo   = dt.sk_tempo
WHERE dc.id_cliente_origem = 1
ORDER BY dt.data_completa;
```

**Falar:** "Esse é o poder do DW com SCD Tipo 2. Não é só guardar dado — é guardar o *estado* do dado no momento em que o fato aconteceu. Em análise de comportamento de cliente, em auditoria, em cálculo de receita por região histórica, esse contexto temporal é fundamental."

---

## Visão geral do pipeline que construímos

```
loja_db (OLTP)
    │
    ▼
stg_pedidos (Staging — zona de pouso, dado bruto)
    │
    ├──► dim_cliente  (SCD Tipo 1 ou 2)
    ├──► dim_produto  (carga incremental)
    │
    ▼
fato_vendas (sk_cliente + sk_produto + sk_tempo + métricas)
    │
    ▼
Queries analíticas: 2 JOINs em vez de 4, histórico preservado, surrogate keys
```

---

> **Encerramento final — falar:**
> "Em 5 aulas você foi de 'o que é uma tabela' até SCD Tipo 2, pipeline completo de DW e window functions. Tudo com SQL. Isso é o que você usa no dia a dia como engenheiro de dados — seja em SQL Server, BigQuery, Snowflake, Databricks, Redshift."
>
> "O que muda entre as plataformas é a sintaxe de alguns detalhes. O que não muda é o modelo mental: como os dados se relacionam, como você os transforma, como você garante qualidade e performance, como você projeta um Data Warehouse."
>
> "Os exercícios têm três níveis em `/exercicios` — básico, intermediário e avançado, todos com gabarito. Se esse conteúdo foi útil, compartilha com quem está começando na área."
