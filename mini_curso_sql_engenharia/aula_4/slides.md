# AULA 4 — Performance e Qualidade: Índices e Constraints
> Mini Curso SQL para Engenharia de Dados · 5 aulas · SQL Server

---

## Slide 1 — Capa

```
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   AULA 4                                             ║
║   Performance e Qualidade: Índices e Constraints     ║
║                                                      ║
║   Mini Curso SQL para Engenharia de Dados            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
```

---

## Slide 2 — O que você vai aprender

**Nesta aula:**

1. O que é um índice e por que ele importa
2. Tipos de índice — Clustered vs Nonclustered
3. Trade-off: performance de leitura vs escrita
4. Constraints — qualidade de dados garantida pelo banco

**Os dois pilares de um banco em produção:**
- **Índice** → o banco encontra os dados rapidamente
- **Constraint** → o banco aceita apenas dados válidos

---

## Slide 3 — O que é um Índice

**Sem índice:** o banco lê todas as linhas da tabela para encontrar o que você quer.
Isso se chama **full table scan**.

**Com índice:** o banco vai direto ao dado.

```
Sem índice:   [lê linha 1] → [lê linha 2] → ... → [lê linha 10.000.000]
Com índice:   [consulta índice] → vai direto às 3 linhas relevantes
```

**O que o banco indexa automaticamente:**
A **Primary Key** sempre cria um índice do tipo CLUSTERED — sem você precisar pedir.

**O que você precisa indexar manualmente:**
Colunas usadas com frequência em `WHERE`, `JOIN` e `ORDER BY`.

---

## Slide 4 — Tipos de Índice

**CLUSTERED:** determina a ordem física dos dados no disco.

- Só pode existir **um** por tabela
- Criado automaticamente pela Primary Key
- A tabela inteira está fisicamente ordenada por essa coluna

**NONCLUSTERED:** estrutura separada que aponta para as linhas originais.

- Pode existir **vários** por tabela
- O tipo mais comum que você vai criar no dia a dia

**INCLUDE (Covering Index):** colunas extras no índice, sem participar da chave de busca.

```sql
CREATE NONCLUSTERED INDEX idx_pedidos_cliente
ON pedidos (id_cliente)
INCLUDE (data_pedido, valor_total, status);
-- Quando a query busca por id_cliente e precisa dessas colunas,
-- o banco lê tudo do índice sem precisar acessar a tabela principal
```

---

## Slide 5 — Trade-off: Leitura vs Escrita

**Mais índice não é sempre melhor.**

| Operação | Efeito do índice |
|----------|-----------------|
| SELECT | mais rápido — índice reduz linhas lidas |
| INSERT | mais lento — banco atualiza todos os índices da tabela |
| UPDATE | mais lento — idem |
| DELETE | mais lento — idem |

**Em engenharia de dados, existem dois cenários opostos:**

**Tabelas de produção (OLTP):**
Crie índices nas colunas certas — `WHERE`, `JOIN`, `ORDER BY` frequentes.

**Tabelas de staging (carga em massa):**
Remova os índices antes da carga → insira tudo → recrie depois.
Uma carga de 10 milhões de linhas com 5 índices ativos é muito mais lenta do que sem índices.

**Bons candidatos a índice:** colunas com muitos valores distintos (data, ID, email).
**Maus candidatos:** colunas com poucos valores distintos (status com 5 opções, booleano).

---

## Slide 6 — Constraints

**Regras de qualidade definidas diretamente no banco.**
Independente de onde o dado veio — app, pipeline, script — o banco valida antes de aceitar.

| Constraint | O que garante |
|------------|--------------|
| `PRIMARY KEY` | unicidade + NOT NULL na chave |
| `FOREIGN KEY` | integridade referencial entre tabelas |
| `UNIQUE` | unicidade em um campo que não é PK |
| `NOT NULL` | campo obrigatório — não aceita ausência de valor |
| `CHECK` | regra de domínio customizada |
| `DEFAULT` | valor automático quando o campo não é informado |

**Exemplo de CHECK constraint:**
```sql
-- O banco rejeita qualquer preço negativo
CONSTRAINT chk_preco_positivo CHECK (preco > 0)

-- O banco rejeita qualquer status fora dessa lista
CONSTRAINT chk_status CHECK (status IN ('pendente','aprovado','enviado','entregue','cancelado'))
```

> Constraints são sua **última linha de defesa** contra dado inválido.
> Validações no código podem ser contornadas. A constraint no banco, não.

---

## Slide 7 — Índices e Constraints trabalham juntos

**Duas constraints criam índices automaticamente:**

| Constraint | Índice criado automaticamente |
|------------|------------------------------|
| `PRIMARY KEY` | CLUSTERED (por padrão) |
| `UNIQUE` | NONCLUSTERED |

Ao declarar uma constraint `UNIQUE` em `email`, por exemplo, você ganha ao mesmo tempo:
- A garantia de que nenhum email se repete
- A performance de busca rápida por email

---

## Slide 8 — Resumo

```
Performance e Qualidade
│
├── ÍNDICE
│   ├── CLUSTERED    → ordem física dos dados (automático na PK)
│   ├── NONCLUSTERED → acesso rápido por colunas específicas
│   └── INCLUDE      → evita acessar a tabela principal
│
└── CONSTRAINT
    ├── PRIMARY KEY  → unicidade + NOT NULL
    ├── FOREIGN KEY  → integridade referencial
    ├── UNIQUE       → unicidade em campo não-PK
    ├── NOT NULL     → campo obrigatório
    └── CHECK        → regra de domínio personalizada
```

> **Próxima aula:** SQL no Data Warehouse —
> pipeline completo de carga, Star Schema e histórico de mudanças.
