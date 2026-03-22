# Aula 5 — Data Warehouse: Fato, Dimensão, Star Schema, ETL vs ELT

## O que é um Data Warehouse?

Um **Data Warehouse (DW)** é um banco otimizado para **análise e leitura**, não para transações do dia a dia.

| | Banco Transacional (OLTP) | Data Warehouse (OLAP) |
|--|--------------------------|----------------------|
| Propósito | Operações do dia a dia | Análises e relatórios |
| Queries | Muitos INSERTs/UPDATEs | Muitos SELECTs pesados |
| Granularidade | Detalhe de cada transação | Agregações e histórico |
| Exemplos | PostgreSQL, MySQL | Snowflake, BigQuery, Redshift |

---

## Tabela Fato

A **tabela fato** guarda os **eventos de negócio** — o que aconteceu, quando e quanto.

Características:
- Contém métricas numéricas (`total`, `quantidade`, `receita`)
- Contém chaves estrangeiras para as dimensões
- Geralmente é a maior tabela do DW
- Não tem descrições — só IDs e números

```
fato_pedidos
────────────
id_pedido (PK)
id_cliente (FK)
id_produto (FK)
id_data (FK)
quantidade
total
```

---

## Tabela Dimensão

A **tabela dimensão** guarda o **contexto** dos eventos — quem, o quê, onde, como.

Características:
- Contém atributos descritivos (nome, cidade, categoria)
- Geralmente menor que a fato
- Muda pouco com o tempo

```
dim_clientes        dim_produtos         dim_data
────────────        ────────────         ────────
id_cliente (PK)     id_produto (PK)      id_data (PK)
nome                nome                 data_completa
cidade              categoria            ano
estado              preco                mes
                                         dia_semana
```

---

## Star Schema (Esquema Estrela)

O **Star Schema** conecta uma tabela fato central com várias dimensões ao redor. É o modelo mais comum em DW.

```
           dim_clientes
                |
dim_data — fato_pedidos — dim_produtos
                |
           dim_localidade
```

### Por que Star Schema?

- Queries simples (poucos JOINs)
- Fácil para ferramentas de BI lerem
- Ótima performance para agregações

---

## ETL vs ELT

Dois padrões para mover dados até o DW:

### ETL — Extract, Transform, Load

```
Fonte → [Extrair] → [Transformar] → [Carregar no DW]
```

- A transformação acontece **antes** de entrar no DW
- Tradicional, usado quando o DW tem menos poder computacional
- Ferramentas: Pentaho, Informatica, Talend

### ELT — Extract, Load, Transform

```
Fonte → [Extrair] → [Carregar no DW] → [Transformar dentro do DW]
```

- A transformação acontece **dentro** do DW, com SQL
- Moderno, aproveitando a escala de clouds como BigQuery e Snowflake
- Ferramentas: dbt, Spark, SQL puro

### Qual usar?

| Contexto | ETL | ELT |
|----------|-----|-----|
| DW poderoso (cloud) | | ✓ |
| Dados sensíveis (não podem entrar brutos) | ✓ | |
| Time com forte habilidade em SQL | | ✓ |
| Legado e sistemas antigos | ✓ | |

---

## Resumo da aula

- DW é otimizado para análise, não para transações
- Fato = eventos com métricas, Dimensão = contexto descritivo
- Star Schema = 1 fato + N dimensões ao redor
- ETL transforma antes de carregar, ELT carrega e transforma depois
- Hoje o padrão moderno é **ELT com dbt + SQL no cloud**
