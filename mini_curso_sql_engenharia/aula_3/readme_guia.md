# AULA 3 — Objetos do Banco: Views, Procedures e Funções
**⏱️ ~25 min** | SQL Server (T-SQL) | Arquivo de código: [`exemplos.sql`](exemplos.sql)

> **Abertura — falar:**
> "Você aprendeu a escrever SQL de transformação. Agora você vai aprender a *organizar* esse SQL dentro do banco — para que a lógica de negócio fique em um lugar só, seja reutilizável, e qualquer ferramenta ou pessoa acesse os dados sempre do jeito correto."

---

## Checklist antes de começar

- [ ] `banco.sql` já foi executado
- [ ] `loja_db` selecionada como database ativa

---

## 3.1 — VIEW: padronizando o consumo de dados

**Conceito para falar:**
"Sem VIEW, cada analista, cada dashboard, cada pipeline reescreve o mesmo JOIN do zero. Cada um filtra de um jeito diferente. Aí aparece o número errado no relatório e ninguém sabe de onde veio."

"VIEW resolve isso centralizando a lógica. Você define a consulta uma vez, dá um nome a ela, e todo mundo consome pelo mesmo ponto. Quando a lógica precisa mudar, você muda em um lugar só."

"Importante: VIEW **não armazena dados**. É uma consulta nomeada. Toda vez que você acessa a view, o SELECT interno é executado. Se quiser armazenar o resultado, você usa Materialized View ou tabela temp."

```sql
USE loja_db;

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
-- VIEW analítica: KPIs por cliente
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
SELECT
    uf,
    SUM(receita_confirmada)  AS receita_por_estado,
    COUNT(id_cliente)        AS qtd_clientes
FROM vw_kpis_cliente
GROUP BY uf
ORDER BY receita_por_estado DESC;
```

**Falar:** "Esse padrão de views em camadas — uma para dados brutos, uma para KPIs, uma para resumo — é exatamente o que você implementa com dbt no mundo moderno. O conceito é o mesmo, a ferramenta muda."

---

## 3.2 — Stored Procedure: lógica de processo no banco

**Conceito para falar:**
"Procedure é diferente de VIEW. VIEW é para *consultar* dados. Procedure é para *executar um processo* — ela pode fazer SELECT, INSERT, UPDATE, DELETE, chamar outras procedures, controlar transações. É um step de pipeline dentro do banco."

"Procedures aceitam parâmetros — você pode passar um período, um ID, uma configuração — e o resultado muda conforme os parâmetros. Em ETL tradicional, procedures são muito usadas para encapsular os passos da carga."

```sql
-- Procedure de consulta parametrizada
CREATE PROCEDURE sp_pedidos_periodo
    @data_inicio DATE,
    @data_fim    DATE
AS
BEGIN
    SET NOCOUNT ON;  -- boas práticas: suprime mensagem "X rows affected"

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

    UPDATE pedidos
    SET status = 'cancelado'
    WHERE status = 'pendente'
      AND DATEDIFF(DAY, data_pedido, GETDATE()) > @dias_limite;

    SET @pedidos_afetados = @@ROWCOUNT;

    -- Retorna um log da execução — útil para monitoramento em pipeline
    SELECT
        @pedidos_afetados   AS pedidos_cancelados,
        @dias_limite        AS criterio_dias,
        GETDATE()           AS executado_em;
END;
```

**Falar:** "O parâmetro com valor padrão: se você chamar sem argumentos, usa 30 dias. Em produção, essa procedure seria agendada num job do SQL Server Agent ou disparada por um DAG do Airflow."

```sql
-- Procedure com transação: processo atômico com rollback em caso de erro
CREATE PROCEDURE sp_registrar_venda
    @id_pedido  INT,
    @id_cliente INT,
    @id_produto INT,
    @quantidade INT,
    @preco      DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

            INSERT INTO pedidos (id_pedido, id_cliente, data_pedido, status, valor_total)
            VALUES (@id_pedido, @id_cliente, GETDATE(), 'aprovado', @quantidade * @preco);

            INSERT INTO itens_pedido (id_item, id_pedido, id_produto, quantidade, preco_unitario)
            VALUES (@id_pedido * 10, @id_pedido, @id_produto, @quantidade, @preco);

        COMMIT;
        SELECT 'Venda registrada com sucesso' AS resultado;

    END TRY
    BEGIN CATCH
        ROLLBACK;
        SELECT ERROR_MESSAGE() AS erro;
    END CATCH;
END;
```

**Falar:** "TRY/CATCH com BEGIN TRANSACTION e ROLLBACK — se qualquer passo falhar, tudo é desfeito e o erro é retornado. Isso é o padrão para procedures de carga em produção."

---

## 3.3 — Função Escalar: cálculo reutilizável

**Conceito para falar:**
"Função escalar retorna um único valor. Você a usa dentro de um SELECT como se fosse uma coluna calculada. A diferença da procedure é que função pode ser usada dentro de expressões — dentro do SELECT, do WHERE, do ORDER BY."

"O valor está em encapsular a regra de negócio. Se a regra de desconto mudar, você muda a função em um lugar só — todo SELECT que a usa já reflete o novo cálculo automaticamente."

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
    -- Parâmetro inválido: retorna sem desconto
    IF @pct_desconto < 0 OR @pct_desconto > 100
        RETURN @valor;

    RETURN @valor - (@valor * @pct_desconto / 100);
END;
```

```sql
-- Usando a função como coluna calculada
-- O prefixo dbo. é obrigatório em SQL Server para funções de usuário
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

**Falar:** "Repare no `dbo.` — obrigatório em SQL Server para funções de usuário. Mude a regra de negócio na função, todos os SELECTs herdam automaticamente."

```sql
-- Outra função: classifica valor em faixa de ticket
CREATE FUNCTION fn_faixa_ticket (@valor DECIMAL(10,2))
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @valor < 100  THEN 'Baixo'
        WHEN @valor < 500  THEN 'Médio'
        WHEN @valor < 2000 THEN 'Alto'
        ELSE                    'Premium'
    END;
END;
```

```sql
-- Usando as duas funções juntas em um SELECT analítico
SELECT
    id_pedido,
    valor_total,
    dbo.fn_faixa_ticket(valor_total)                    AS faixa_ticket,
    dbo.fn_valor_com_desconto(valor_total, 5)           AS valor_com_desconto_5pct
FROM pedidos
WHERE status = 'entregue'
ORDER BY valor_total DESC;
```

---

## 3.4 — Função de Tabela: VIEW parametrizada

**Conceito para falar:**
"Função de tabela retorna um conjunto de linhas — não um único valor. É como uma VIEW que aceita parâmetro. Onde uma VIEW retorna sempre o mesmo conjunto de dados, a função de tabela retorna dados filtrados pelo parâmetro que você passa."

```sql
-- Retorna os itens de um pedido com detalhes e percentual de representatividade
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
-- Consultar itens de pedidos específicos
SELECT * FROM dbo.fn_itens_pedido(8);
SELECT * FROM dbo.fn_itens_pedido(1);
```

```sql
-- CROSS APPLY: chama a função para cada linha da tabela externa
-- Para cada pedido, executa a função e junta o resultado
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

---

## Resumo da Aula 3

| Objeto | Para que serve | Retorna | Aceita parâmetro |
|--------|---------------|---------|-----------------|
| VIEW | Padronizar e reutilizar consultas | Conjunto de linhas | Não |
| STORED PROCEDURE | Encapsular processos e steps de pipeline | Qualquer coisa | Sim |
| FUNÇÃO ESCALAR | Cálculo reutilizável dentro de queries | Um único valor | Sim |
| FUNÇÃO DE TABELA | VIEW que aceita parâmetro | Conjunto de linhas | Sim |

---

> **Encerramento — falar:**
> "Resumo: VIEW para padronizar consulta, Procedure para processo/ação, Função para cálculo reutilizável. Na próxima aula a gente fala de performance e qualidade — índices e constraints — os dois pilares que fazem um banco funcionar bem em produção."
