# AULA 2 — SQL como Motor de Transformação de Dados
**⏱️ ~35 min** | SQL Server (T-SQL) | Arquivo de código: [`exemplos.sql`](exemplos.sql)

> **Abertura — falar:**
> "SQL não é só SELECT * FROM tabela. É uma linguagem de transformação. Tudo que você vai ver hoje — CASE WHEN, JOIN, GROUP BY, CTE, Window Functions — você usa em pipeline de dados, em dbt, em Spark SQL, em BigQuery. A sintaxe muda um pouco entre plataformas, mas o conceito é exatamente o mesmo. Aprenda o conceito, você aprende todas as plataformas de uma vez."

---

## Checklist antes de começar

- [ ] `banco.sql` já foi executado
- [ ] `loja_db` selecionada como database ativa

---

## 2.1 — SELECT bem estruturado

**Conceito para falar:**
"O SELECT é a instrução mais executada em qualquer sistema. Em engenharia de dados, você vai escrever SELECTs que viram pipelines, que ficam em repositórios, que são revisados em PR, que são mantidos por outras pessoas. Código SQL mal escrito é dívida técnica."

"Dois SELECTs abaixo retornam o mesmo resultado. Mas um é código de produção, o outro é código de improviso."

```sql
USE loja_db;

-- RUIM — funciona, mas é ilegível e impossível de manter
SELECT nome,preco,estoque,preco*estoque FROM produtos;

-- BOM — legível, auditável, com alias descritivos e lógica explícita
SELECT
    nome                        AS produto,
    preco                       AS preco_unitario,
    estoque                     AS qtd_em_estoque,
    preco * estoque             AS valor_total_em_estoque,
    CASE
        WHEN estoque < 5  THEN 'Crítico'
        WHEN estoque < 20 THEN 'Baixo'
        ELSE                   'Normal'
    END                         AS status_estoque
FROM produtos
ORDER BY valor_total_em_estoque DESC;
```

**Falar:** "Alias descritivos, cálculos explícitos, lógica de negócio legível. Qualquer engenheiro na equipe entende o que esse SELECT faz sem precisar perguntar. Em pipeline, SELECT limpo é pipeline auditável."

---

## 2.2 — Ordem de execução do SQL (conceito crítico)

**Conceito para falar — um dos pontos mais importantes da aula:**
"Existe uma ilusão comum sobre SQL: as pessoas escrevem na ordem SELECT → FROM → WHERE → GROUP BY. Mas o banco executa em uma ordem completamente diferente. Entender essa ordem explica comportamentos que parecem estranhos."

**Ordem real de execução:**
```
1. FROM       → de onde vêm os dados (e JOINs)
2. WHERE      → filtra linhas individuais
3. GROUP BY   → agrupa as linhas restantes
4. HAVING     → filtra os grupos
5. SELECT     → calcula as colunas e alias
6. ORDER BY   → ordena o resultado final
7. TOP/LIMIT  → limita a quantidade
```

"Por isso você NÃO PODE usar um alias do SELECT dentro do WHERE — o WHERE roda antes do SELECT ser calculado. E NÃO PODE usar uma função de agregação no WHERE — ela só existe depois do GROUP BY."

```sql
-- Demonstração da ordem: WHERE antes de GROUP BY, HAVING depois
SELECT
    c.nome,
    SUM(p.valor_total)  AS total_gasto,
    COUNT(p.id_pedido)  AS qtd_pedidos
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'          -- 2: filtra linhas ANTES do agrupamento
GROUP BY c.id_cliente, c.nome        -- 3: agrupa
HAVING SUM(p.valor_total) > 1000     -- 4: filtra grupos DEPOIS do agrupamento
ORDER BY total_gasto DESC;           -- 6: ordena o resultado final
```

---

## 2.3 — WHERE e filtros eficientes

**Conceito para falar:**
"Filtrar cedo é um princípio de performance. Cada linha a menos que o banco processa é CPU e memória economizados. Em tabelas com milhões de linhas, um WHERE mal escrito pode transformar uma query de 2 segundos em 2 minutos."

```sql
-- IN — substitui múltiplos OR, mais legível e geralmente mais eficiente
SELECT id_pedido, status, valor_total
FROM pedidos
WHERE status IN ('pendente', 'aprovado', 'enviado');

-- BETWEEN — intervalo inclusivo (inclui as duas datas extremas)
SELECT id_pedido, data_pedido, valor_total
FROM pedidos
WHERE data_pedido BETWEEN '2024-01-01' AND '2024-03-31';

-- LIKE — busca por padrão de texto
-- % = qualquer sequência | _ = exatamente um caractere
SELECT nome, email
FROM clientes
WHERE email LIKE '%@email.com';

-- IS NULL / IS NOT NULL — nunca use = NULL
SELECT nome, email
FROM clientes
WHERE email IS NULL;

-- Filtro composto — use parênteses para clareza
SELECT id_pedido, status, valor_total, data_pedido
FROM pedidos
WHERE (status = 'pendente' OR status = 'aprovado')
  AND valor_total > 200
  AND data_pedido >= '2024-03-01';
```

**Falar sobre NULL:** "NULL não é zero, não é string vazia, não é falso. NULL significa *ausência de valor*. NULL = NULL retorna NULL, não verdadeiro. Por isso você usa IS NULL — não = NULL."

---

## 2.4 — CASE WHEN: lógica de negócio dentro do SQL

**Conceito para falar:**
"CASE WHEN é a forma de colocar *regra de negócio* diretamente no SQL. Em vez de buscar o dado cru e tratar no Python depois, você transforma o dado dentro da query. Em pipeline ELT, isso é o que acontece na camada T — de Transformação."

```sql
-- CASE com range de valores: categorização por faixa de preço
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
    CASE WHEN estoque = 0 THEN 'Sem Estoque' ELSE 'Disponível' END AS disponibilidade
FROM produtos
ORDER BY preco;
```

```sql
-- CASE com valor exato: transformação de status em categoria analítica
-- Padrão clássico de ETL
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
-- CASE dentro de agregação: pivot manual — transforma valores de coluna em colunas
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

**Falar:** "Esse último é um pivot manual. Você transforma valores de uma coluna em colunas separadas — exatamente o que você faria num pipeline de transformação para alimentar um dashboard."

---

## 2.5 — JOINs: combinando tabelas

**Conceito para falar:**
"JOIN é o conceito mais importante de SQL relacional. Presta atenção especialmente em *quantas linhas* cada tipo de JOIN retorna."

**Tipos:**
- **INNER JOIN**: só retorna linhas com correspondência nos dois lados
- **LEFT JOIN**: TODAS as linhas da esquerda + correspondência da direita (NULL onde não há)
- **FULL OUTER JOIN**: todos de ambos os lados
- **CROSS JOIN**: produto cartesiano

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

**Apontar:** "Clientes sem pedido sumiram."

```sql
-- LEFT JOIN — todos da esquerda, NULL onde não há correspondência
SELECT
    c.nome           AS cliente,
    p.id_pedido,
    p.status,
    p.valor_total
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
ORDER BY c.nome;
```

```sql
-- Padrão clássico: quem NUNCA fez X
-- LEFT JOIN + WHERE IS NULL
SELECT
    c.nome AS cliente_sem_pedido,
    c.cidade,
    c.data_cadastro
FROM clientes AS c
LEFT JOIN pedidos AS p ON c.id_cliente = p.id_cliente
WHERE p.id_pedido IS NULL;
```

```sql
-- JOIN múltiplo — visão completa de uma venda atravessando 4 tabelas
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
JOIN pedidos      AS p   ON c.id_cliente    = p.id_cliente
JOIN itens_pedido AS i   ON p.id_pedido     = i.id_pedido
JOIN produtos     AS pr  ON i.id_produto    = pr.id_produto
JOIN categorias   AS cat ON pr.id_categoria = cat.id_categoria
WHERE p.status = 'entregue'
ORDER BY subtotal DESC;
```

**Falar:** "É assim que você constrói uma visão desnormalizada para análise. Esse SELECT é literalmente o que vai para a camada de staging de um Data Warehouse."

---

## 2.6 — GROUP BY e HAVING

**Conceito para falar:**
"GROUP BY *colapsa* linhas em grupos. Você perde o detalhe de cada linha individual e ganha um resumo por grupo. É a base de qualquer relatório, qualquer KPI, qualquer agregação num pipeline."

"HAVING filtra *grupos* (após GROUP BY). WHERE filtra *linhas* (antes de GROUP BY). Essa distinção é uma das dúvidas mais comuns em SQL."

```sql
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
WHERE p.status = 'entregue'
GROUP BY c.id_cliente, c.nome
ORDER BY valor_total_gasto DESC;
```

```sql
-- HAVING: filtra após o agrupamento
SELECT
    c.nome,
    SUM(p.valor_total)   AS total_gasto,
    COUNT(p.id_pedido)   AS qtd_pedidos
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
WHERE p.status = 'entregue'
GROUP BY c.id_cliente, c.nome
HAVING SUM(p.valor_total) > 1000
ORDER BY total_gasto DESC;
```

**Falar:** "Tente colocar `total_gasto > 1000` no WHERE — o banco vai dar erro. O alias 'total_gasto' não existe quando o WHERE é avaliado. E SUM() no WHERE também falha — lembra da ordem de execução?"

```sql
-- Receita por categoria
SELECT
    cat.nome                                        AS categoria,
    COUNT(DISTINCT i.id_pedido)                     AS pedidos_com_esta_cat,
    SUM(i.quantidade)                               AS unidades_vendidas,
    SUM(i.quantidade * i.preco_unitario)            AS receita_total,
    AVG(i.preco_unitario)                           AS preco_medio_vendido
FROM categorias   AS cat
JOIN produtos     AS pr ON cat.id_categoria = pr.id_categoria
JOIN itens_pedido AS i  ON pr.id_produto    = i.id_produto
JOIN pedidos      AS p  ON i.id_pedido      = p.id_pedido
WHERE p.status = 'entregue'
GROUP BY cat.id_categoria, cat.nome
ORDER BY receita_total DESC;
```

---

## 2.7 — Subquery e CTE

**Conceito para falar:**
"Às vezes você precisa de uma consulta que depende do resultado de outra. Tem duas formas principais: subquery inline ou CTE — Common Table Expression."

"A CTE, definida com WITH, é como uma 'tabela temporária com nome'. Em termos de performance são equivalentes na maioria dos bancos — mas CTE é muito mais legível, fácil de debugar e de manter. Recomendo para qualquer coisa acima de 5 linhas."

```sql
-- SUBQUERY ESCALAR: retorna um único valor para comparação
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
WITH media_precos AS (
    SELECT AVG(preco) AS preco_medio FROM produtos
)
SELECT
    p.nome,
    p.preco,
    ROUND(p.preco - m.preco_medio, 2) AS acima_da_media
FROM produtos    AS p
CROSS JOIN media_precos AS m
WHERE p.preco > m.preco_medio
ORDER BY acima_da_media DESC;
```

```sql
-- CTE com múltiplos passos — cada CTE é um passo do pipeline
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
        COUNT(p.id_pedido)   AS total_pedidos,
        SUM(p.valor_total)   AS total_gasto
    FROM clientes AS c
    JOIN pedidos  AS p ON c.id_cliente = p.id_cliente
    GROUP BY c.id_cliente, c.nome
)
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

**Falar:** "Isso é como você escreve transformações complexas em dbt — cada CTE é um step do pipeline, com nome descritivo, fácil de testar individualmente."

---

## 2.8 — Window Functions

**Conceito para falar:**
"Window Function é o que separa quem conhece SQL básico de quem domina SQL. E é absolutamente fundamental em engenharia de dados."

"A diferença do GROUP BY: GROUP BY **colapsa** as linhas — você perde o detalhe. Window Function **não colapsa** — você agrega e ainda mantém todas as linhas originais. A 'janela' (OVER) define sobre quais linhas o cálculo se aplica."

**Sintaxe:**
```sql
FUNÇÃO() OVER (
    PARTITION BY coluna_agrupadora   -- opcional: como o GROUP BY
    ORDER BY     coluna_ordenação    -- para ranking e acumulado
    ROWS BETWEEN ...                 -- define o tamanho da janela
)
```

```sql
-- ROW_NUMBER: numera as linhas dentro de cada partição
-- Caso de uso: histórico de pedidos numerado por cliente
SELECT
    c.nome          AS cliente,
    p.id_pedido,
    p.data_pedido,
    p.valor_total,
    ROW_NUMBER() OVER (
        PARTITION BY p.id_cliente
        ORDER BY p.data_pedido DESC
    ) AS ordem_por_cliente
FROM pedidos  AS p
JOIN clientes AS c ON p.id_cliente = c.id_cliente
ORDER BY c.nome, p.data_pedido DESC;
```

**Apontar:** "Cada cliente tem numeração própria que reinicia. PARTITION BY é o 'agrupador' da janela."

```sql
-- Pegando o ÚLTIMO pedido de cada cliente
-- Padrão clássico de deduplicação e "latest record"
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
WHERE rn = 1
ORDER BY cliente;
```

```sql
-- RANK vs DENSE_RANK: tratamento de empates
-- RANK: pula posições (1, 1, 3) | DENSE_RANK: não pula (1, 1, 2)
SELECT
    nome,
    preco,
    RANK()       OVER (ORDER BY preco DESC) AS rank_preco,
    DENSE_RANK() OVER (ORDER BY preco DESC) AS dense_rank_preco
FROM produtos
ORDER BY preco DESC;
```

```sql
-- SUM OVER: receita acumulada e média móvel
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
    ) AS media_movel_3_pedidos
FROM pedidos
WHERE status = 'entregue'
ORDER BY data_pedido;
```

**Falar:** "Cada linha tem o valor individual E o acumulado até aquele ponto E a média dos últimos 3. Impossível com GROUP BY sem perder as linhas individuais. Em análise de séries temporais isso é fundamental."

```sql
-- LAG e LEAD: acessar linha anterior ou próxima
-- Caso de uso: variação entre períodos
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

---

> **Encerramento — falar:**
> "Você agora tem as ferramentas fundamentais de transformação em SQL. Com isso você resolve 80% dos desafios de dados do dia a dia. Na próxima aula a gente organiza essa lógica dentro do banco — views, procedures e funções — para que qualquer pessoa possa reutilizar sem reescrever."
