# AULA 3 — Objetos do Banco: Views, Procedures e Funções
> Mini Curso SQL para Engenharia de Dados · 5 aulas · SQL Server

---

## Slide 1 — Capa

```
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   AULA 3                                             ║
║   Objetos do Banco: Views, Procedures e Funções      ║
║                                                      ║
║   Mini Curso SQL para Engenharia de Dados            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
```

---

## Slide 2 — O que você vai aprender

**Nesta aula:**

1. VIEW — padronizando o consumo de dados
2. Stored Procedure — encapsulando processos
3. Função Escalar — cálculo reutilizável em queries
4. Função de Tabela — VIEW com parâmetro

**O problema que os três resolvem:**
> Sem esses objetos, cada analista, pipeline e dashboard
> reescreve a mesma lógica do zero — cada um de um jeito diferente.
> Quando a regra muda, você precisa atualizar em 10 lugares.

---

## Slide 3 — VIEW

**Uma consulta com nome. A lógica fica em um lugar só.**

```sql
CREATE VIEW vw_pedidos_clientes AS
SELECT
    c.nome, c.cidade,
    p.id_pedido, p.data_pedido, p.status, p.valor_total
FROM clientes AS c
JOIN pedidos  AS p ON c.id_cliente = p.id_cliente;
```

**Consumo:** qualquer ferramenta acessa como se fosse uma tabela.

```sql
SELECT * FROM vw_pedidos_clientes WHERE status = 'entregue';
```

**O que VIEW não faz:**
- Não armazena dados — executa o SELECT toda vez que é acessada
- Não aceita parâmetros — para isso, use Função de Tabela

**Benefício principal:**
Quando a lógica muda, você atualiza a VIEW — todos os consumidores herdam automaticamente.

---

## Slide 4 — Stored Procedure

**Um processo com nome. Pode fazer qualquer operação no banco.**

```sql
CREATE PROCEDURE sp_pedidos_periodo
    @data_inicio DATE,
    @data_fim    DATE
AS
BEGIN
    SELECT p.id_pedido, c.nome, p.data_pedido, p.valor_total
    FROM pedidos AS p
    JOIN clientes AS c ON p.id_cliente = c.id_cliente
    WHERE p.data_pedido BETWEEN @data_inicio AND @data_fim;
END;

-- Execução
EXEC sp_pedidos_periodo '2024-01-01', '2024-03-31';
```

**O que a Procedure faz que a VIEW não faz:**

| Capacidade | VIEW | Procedure |
|-----------|------|-----------|
| Aceita parâmetros | Não | Sim |
| Executa INSERT/UPDATE/DELETE | Não | Sim |
| Controla transações | Não | Sim |
| Retorna múltiplos resultados | Não | Sim |

> Em ETL tradicional, procedures encapsulam os passos da carga de dados.

---

## Slide 5 — Função Escalar e Função de Tabela

**Função Escalar:** retorna um único valor. Usada dentro de expressões no SELECT.

```sql
CREATE FUNCTION fn_valor_com_desconto
    (@valor DECIMAL(10,2), @pct_desconto DECIMAL(5,2))
RETURNS DECIMAL(10,2)
AS BEGIN
    RETURN @valor - (@valor * @pct_desconto / 100);
END;

-- Uso
SELECT nome, dbo.fn_valor_com_desconto(preco, 15) AS preco_com_desconto
FROM produtos;
```

**Função de Tabela:** retorna um conjunto de linhas. Uma VIEW que aceita parâmetro.

```sql
CREATE FUNCTION fn_itens_pedido (@id_pedido INT)
RETURNS TABLE AS RETURN
(
    SELECT pr.nome, i.quantidade, i.preco_unitario
    FROM itens_pedido AS i
    JOIN produtos AS pr ON i.id_produto = pr.id_produto
    WHERE i.id_pedido = @id_pedido
);

-- Uso
SELECT * FROM dbo.fn_itens_pedido(8);
```

---

## Slide 6 — Comparativo e Quando Usar

| Objeto | Para que serve | Retorna | Aceita parâmetro |
|--------|---------------|---------|-----------------|
| **VIEW** | padronizar consultas | conjunto de linhas | Não |
| **STORED PROCEDURE** | encapsular processos | qualquer coisa | Sim |
| **FUNÇÃO ESCALAR** | cálculo reutilizável em queries | um único valor | Sim |
| **FUNÇÃO DE TABELA** | VIEW parametrizada | conjunto de linhas | Sim |

**Regra de decisão:**

```
Preciso consultar dados de forma padronizada?    → VIEW
Preciso executar um processo (ETL, carga)?       → PROCEDURE
Preciso de um cálculo dentro do SELECT?          → FUNÇÃO ESCALAR
Preciso de uma VIEW que aceita parâmetro?        → FUNÇÃO DE TABELA
```

---

## Slide 7 — Resumo

```
Objetos do Banco
│
├── VIEW         → lógica centralizada, consumida como tabela
│                  sem parâmetro · sem armazenamento
│
├── PROCEDURE    → processo encapsulado com parâmetros
│                  pode modificar dados · controla transações
│
├── FN ESCALAR   → cálculo reutilizável dentro de queries
│                  retorna um valor · usada em SELECT/WHERE
│
└── FN TABELA    → VIEW com parâmetro
                   retorna conjunto de linhas · CROSS APPLY
```

> **Próxima aula:** performance e qualidade —
> Índices e Constraints.
