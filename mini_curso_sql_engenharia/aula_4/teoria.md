# Aula 4 — Index, Constraints e Partições

## Índices (Indexes)

Um **índice** acelera buscas no banco. Funciona como o índice de um livro — em vez de ler tudo, você vai direto ao ponto.

```sql
-- Sem índice: o banco lê TODAS as linhas (full scan)
SELECT * FROM pedidos WHERE cliente_id = 5;

-- Com índice: o banco vai direto às linhas certas
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);
```

### Quando criar índice?

- Colunas usadas frequentemente no `WHERE`
- Colunas usadas em `JOIN`
- Colunas usadas em `ORDER BY` com grandes volumes

### Quando NÃO criar índice?

- Tabelas pequenas (full scan é mais rápido)
- Colunas com poucos valores distintos (ex: `status` com 3 opções)
- Tabelas com muitos `INSERT/UPDATE` (índice precisa ser atualizado)

### Tipos de índice no PostgreSQL

| Tipo | Quando usar |
|------|-------------|
| `B-tree` (padrão) | Igualdade e intervalos (`=`, `>`, `<`, `BETWEEN`) |
| `Hash` | Apenas igualdade (`=`) |
| `GIN` | Arrays, JSONB, texto completo |
| `BRIN` | Tabelas muito grandes com dados ordenados por data |

---

## Constraints (Restrições)

Constraints garantem a **qualidade e integridade dos dados**.

| Constraint | Descrição | Exemplo |
|------------|-----------|---------|
| `PRIMARY KEY` | Identifica unicamente cada linha | `id SERIAL PRIMARY KEY` |
| `FOREIGN KEY` | Garante referência válida | `REFERENCES clientes(id)` |
| `NOT NULL` | Proíbe valor nulo | `nome VARCHAR NOT NULL` |
| `UNIQUE` | Garante valor único na coluna | `email VARCHAR UNIQUE` |
| `CHECK` | Valida uma condição | `CHECK (preco > 0)` |
| `DEFAULT` | Valor padrão se não informado | `status VARCHAR DEFAULT 'pendente'` |

### Por que constraints importam em engenharia de dados?

- Evitam dados inválidos na fonte (garbage in, garbage out)
- Documentam as regras de negócio no próprio banco
- Reduzem validações manuais nos pipelines

---

## Particionamento

**Partição** divide uma tabela grande em partes menores, mas ela continua parecendo uma só tabela para quem consulta.

```
tabela pedidos (particionada por ano)
├── pedidos_2022
├── pedidos_2023
└── pedidos_2024
```

### Vantagens

- Queries filtradas por data leem só a partição necessária (muito mais rápido)
- Manutenção mais fácil (apagar dados antigos = DROP na partição)
- Essencial em Data Warehouses com bilhões de linhas

### Tipos de particionamento

| Tipo | Quando usar |
|------|-------------|
| `RANGE` | Datas, IDs sequenciais |
| `LIST` | Valores fixos (estado, categoria) |
| `HASH` | Distribuição uniforme sem critério claro |

---

## Resumo da aula

- Índices aceleram leitura, mas têm custo em escrita
- Constraints garantem qualidade dos dados na fonte
- Particionamento é fundamental para escala em Data Warehouses
