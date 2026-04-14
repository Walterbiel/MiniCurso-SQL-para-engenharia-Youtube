# AULA 1 — Fundamentos de Bancos Relacionais
> Mini Curso SQL para Engenharia de Dados · 5 aulas · SQL Server

---

## Slide 1 — Capa

```
╔══════════════════════════════════════════════════════╗
║                                                      ║
║   AULA 1                                             ║
║   Fundamentos de Bancos Relacionais                  ║
║                                                      ║
║   Mini Curso SQL para Engenharia de Dados            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
```

---

## Slide 2 — O que você vai aprender

**Nesta aula:**

1. Como um banco relacional organiza dados
2. Primary Key — identidade única de cada registro
3. Foreign Key — elo entre tabelas
4. Tipos de relacionamento: 1:N e N:N
5. Transações e ACID
6. CRUD na perspectiva de engenharia

---

## Slide 3 — Banco Relacional

**Dados organizados em tabelas. Tabelas organizadas por relações.**

```
┌─────────────┐        ┌─────────────┐
│  clientes   │        │   pedidos   │
├─────────────┤        ├─────────────┤
│ id_cliente  │◄───────│ id_cliente  │
│ nome        │        │ id_pedido   │
│ email       │        │ data_pedido │
│ cidade      │        │ valor_total │
└─────────────┘        └─────────────┘
```

**Regra central:** o nome do cliente não se repete em cada pedido — só o seu ID.
Isso é **normalização**: guardar cada informação em um único lugar.

O banco também armazena **metadados** — dados sobre si mesmo:
quais tabelas existem, quais colunas cada uma tem, quais regras estão definidas.

---

## Slide 4 — Primary Key e Foreign Key

**Primary Key (PK):** identidade única e obrigatória de cada linha.

| Garante | Como |
|---------|------|
| Unicidade | não pode repetir o valor |
| Não-nulidade | não pode ser NULL |
| Performance | banco cria índice automaticamente |

**Foreign Key (FK):** elo entre duas tabelas.

| Garante | Exemplo |
|---------|---------|
| Integridade referencial | não cria pedido para cliente inexistente |
| Proteção bidirecional | não deleta cliente que tem pedidos |

> O banco rejeita qualquer operação que viole essas regras —
> independente de onde veio: app, pipeline ou script manual.

---

## Slide 5 — Tipos de Relacionamento

**1:1** — Uma pessoa, um CPF. Raro.

**1:N** — Um cliente tem vários pedidos. O mais comum.

```
clientes ──────< pedidos
   1               N
```

**N:N** — Um pedido tem vários produtos. Um produto aparece em vários pedidos.

```
pedidos >──── itens_pedido ────< produtos
   N                                 N
```

> **Regra:** N:N não existe direto no banco relacional.
> Exige uma **tabela associativa** no meio (`itens_pedido`).

---

## Slide 6 — Transações e ACID

**Transação:** conjunto de operações executado como uma unidade — tudo ou nada.

| Propriedade | Significado |
|-------------|-------------|
| **A**tomicidade | tudo executa, ou nada executa |
| **C**onsistência | banco nunca fica em estado inválido |
| **I**solamento | transações simultâneas não interferem entre si |
| **D**urabilidade | dado confirmado com COMMIT sobrevive a qualquer falha |

```sql
BEGIN TRANSACTION;
    INSERT INTO pedidos ...;
    INSERT INTO itens_pedido ...;
    UPDATE pedidos SET valor_total = ...;
COMMIT;  -- ou ROLLBACK para desfazer tudo
```

> Em engenharia de dados: se uma carga de 100.000 linhas falha no meio,
> com TRANSACTION você reprocessa do zero com segurança.

---

## Slide 7 — CRUD na visão de engenharia

**C**reate · **R**ead · **U**pdate · **D**elete

| Operação | Risco em produção |
|----------|------------------|
| INSERT | sempre especifique as colunas — nunca confie na ordem |
| SELECT | sem risco direto, mas impacta performance |
| UPDATE | **sem WHERE = afeta todas as linhas da tabela** |
| DELETE | **sem WHERE = apaga todas as linhas da tabela** |

**Prática obrigatória:**
Antes de qualquer UPDATE ou DELETE importante, execute um SELECT com o mesmo WHERE para confirmar o escopo exato.

---

## Slide 8 — Resumo

```
Banco Relacional
│
├── Tabelas → entidades do negócio
├── Primary Key → identidade única de cada linha
├── Foreign Key → integridade entre tabelas
├── Relacionamentos → 1:N (mais comum) · N:N (tabela associativa)
├── Transações (ACID) → atomicidade e consistência
└── CRUD → CREATE · READ · UPDATE · DELETE (com cuidado)
```

> **Próxima aula:** SQL como linguagem de transformação —
> CASE WHEN, JOINs, Window Functions.
