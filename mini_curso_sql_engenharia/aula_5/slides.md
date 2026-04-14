# AULA 5 — SQL no Data Warehouse
> Mini Curso SQL para Engenharia de Dados · 5 aulas · SQL Server

---

## Slide 1 — Capa

```
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   AULA 5                                             ║
║   SQL no Data Warehouse                              ║
║                                                      ║
║   Mini Curso SQL para Engenharia de Dados            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
```

---

## Slide 2 — O que você vai aprender

**Nesta aula:**

1. OLTP vs OLAP — dois sistemas com objetivos opostos
2. Star Schema — o modelo do Data Warehouse
3. Pipeline de carga — Staging → Dimensões → Fato
4. MERGE — inserção e atualização em uma instrução
5. SCD — como tratar mudanças históricas em dimensões

---

## Slide 3 — OLTP vs OLAP

**Todo dado começa em um sistema transacional (OLTP). O DW é um sistema analítico (OLAP).**

| Característica | OLTP | OLAP (DW) |
|----------------|------|-----------|
| Objetivo | operações do dia a dia | análise e relatórios |
| Modelo | normalizado — evita redundância | desnormalizado — performance analítica |
| Operações frequentes | INSERT · UPDATE · DELETE | SELECT com agregações |
| Volume por query | poucas linhas | muitas linhas |
| Histórico | estado atual | histórico completo (anos) |
| Atualização | tempo real | periódica (batch) |

**O problema:** perguntas analíticas em OLTP exigem múltiplos JOINs pesados
que competem com as transações do sistema, tornando tudo mais lento.

**A solução:** carregar os dados transformados em um modelo otimizado para análise.

---

## Slide 4 — Star Schema

**Dois tipos de tabela no Data Warehouse:**

**Dimensão (`dim_`):** o contexto da análise.
Quem comprou, o que foi comprado, quando, onde.
Muda pouco. Tem histórico.

**Fato (`fato_`):** o evento em si, em números.
Cada linha é uma transação mensurável.
Contém as métricas (quantidade, valor) e referências para as dimensões.

```
              dim_cliente
                   │
dim_tempo ── fato_vendas ── dim_produto
                   │
              (outras dims)
```

**Surrogate Key (`sk_`):** cada dimensão tem uma chave própria gerada pelo DW,
independente do ID do sistema de origem. Isso permite guardar histórico de mudanças
e integrar múltiplas fontes sem conflito.

---

## Slide 5 — Pipeline de Carga

**Fluxo obrigatório:**

```
OLTP → Staging → Dimensões → Fato
```

**Staging:** zona de pouso. Extrai os dados do OLTP como vieram.
Isola o DW do sistema de origem.

**Dimensões primeiro:** a fato depende das surrogate keys das dimensões.
Você não pode carregar uma venda se o cliente ainda não existe na dim_cliente.

**Fato por último:** resolve as surrogate keys e carrega os eventos.

**Idempotência:** cada etapa usa `WHERE NOT EXISTS` para garantir que
rodar a carga duas vezes não duplica os dados.

```sql
-- Exemplo: carga incremental de dimensão
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
SELECT DISTINCT s.id_cliente, s.nome_cliente, s.cidade, s.uf, GETDATE(), 1
FROM stg_pedidos AS s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_cliente AS d
    WHERE d.id_cliente_origem = s.id_cliente AND d.ativo = 1
);
```

---

## Slide 6 — MERGE

**Upsert em uma instrução: insere linhas novas e atualiza linhas que mudaram.**

```sql
MERGE dim_cliente AS destino
USING origem ON destino.id_cliente_origem = origem.id_cliente

WHEN MATCHED AND (destino.cidade <> origem.cidade) THEN
    UPDATE SET destino.cidade = origem.cidade    -- atualiza o que mudou

WHEN NOT MATCHED BY TARGET THEN
    INSERT (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
    VALUES (...);                                 -- insere o que é novo
```

| Cenário | Ação |
|---------|------|
| Linha existe nos dois lados e houve mudança | UPDATE |
| Linha existe só na origem (novo) | INSERT |
| Linha existe só no destino (sumiu da origem) | pode ser ignorado ou deletado |

---

## Slide 7 — SCD: Tratando Mudanças em Dimensões

**SCD — Slowly Changing Dimension:**
Como guardar o histórico quando uma dimensão muda.

**Exemplo:** Ana era de São Paulo quando comprou um notebook.
Depois ela se mudou para o Rio de Janeiro e comprou outro produto.
Em qual cidade foi cada compra?

---

**SCD Tipo 1 — Sobrescreve:**
O valor antigo é perdido. Não há histórico.

```sql
UPDATE dim_cliente SET cidade = 'Rio de Janeiro' WHERE id_cliente_origem = 1;
```

Use quando: correção de erro (nome digitado errado), atributo sem valor histórico.

---

**SCD Tipo 2 — Preserva histórico com nova linha:**

```sql
-- Fecha o registro atual
UPDATE dim_cliente SET ativo = 0, data_fim = YESTERDAY WHERE id_cliente_origem = 1 AND ativo = 1;

-- Cria nova versão com nova surrogate key
INSERT INTO dim_cliente (id_cliente_origem, nome, cidade, uf, data_inicio, ativo)
VALUES (1, 'Ana Lima', 'Rio de Janeiro', 'RJ', TODAY, 1);
```

```
sk_cliente │ nome     │ cidade        │ data_inicio │ ativo
───────────┼──────────┼───────────────┼─────────────┼──────
     1     │ Ana Lima │ São Paulo     │ 2024-01-01  │  0   ← versão antiga
     7     │ Ana Lima │ Rio de Janeiro│ 2024-08-01  │  1   ← versão atual
```

As vendas antigas continuam apontando para a `sk = 1` (São Paulo).
As novas vendas apontam para a `sk = 7` (Rio de Janeiro).
**O histórico está preservado sem alterar a tabela fato.**

---

## Slide 8 — Resumo

```
SQL no Data Warehouse
│
├── OLTP vs OLAP     → objetivos opostos, modelos opostos
│
├── Star Schema      → fato no centro · dimensões nas pontas
│                      surrogate keys desacoplam o DW da origem
│
├── Pipeline         → Staging → Dimensões → Fato
│                      idempotência via WHERE NOT EXISTS
│
├── MERGE            → upsert: insere o novo · atualiza o mudado
│
└── SCD
    ├── Tipo 1 → sobrescreve (sem histórico)
    └── Tipo 2 → nova linha por versão (histórico completo)
```

> Tudo que você aprendeu nas 5 aulas — JOINs, CTEs, Window Functions,
> Constraints, Índices — vira ferramenta aqui.
> O modelo mental é o mesmo em qualquer plataforma: SQL Server, BigQuery, Snowflake, Databricks.
