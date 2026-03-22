# Aula 1 — Bancos Relacionais, ACID e CRUD

## O que é um banco de dados relacional?

Um banco relacional organiza dados em **tabelas** (linhas e colunas), como uma planilha, mas com regras e relacionamentos entre elas.

Cada tabela tem:
- **Colunas** — os atributos (nome, email, preço...)
- **Linhas** — os registros (cada cliente, produto, pedido...)
- **Chave primária (PK)** — identificador único de cada linha
- **Chave estrangeira (FK)** — referência a outra tabela

### Exemplo de relacionamento

```
clientes          pedidos
--------          -------
id  (PK) <---    cliente_id (FK)
nome              total
email             status
```

---

## ACID

ACID é o conjunto de propriedades que garante que as transações num banco são confiáveis.

| Propriedade | Significado | Exemplo prático |
|-------------|-------------|-----------------|
| **A**tomicity | Tudo ou nada. | Transferência bancária: debita OU nada acontece |
| **C**onsistency | Os dados sempre ficam em estado válido. | Não pode ter pedido sem cliente |
| **I**solation | Transações não se interferem. | Duas compras simultâneas não se misturam |
| **D**urability | Dados salvos sobrevivem a falhas. | Após commit, o dado está persistido |

### Por que isso importa para engenharia de dados?

Quando você move dados entre sistemas (ETL/ELT), precisa garantir que as operações sejam **atômicas** — ou a carga toda funciona, ou você faz rollback.

---

## CRUD

CRUD é o acrônimo das 4 operações básicas em qualquer banco de dados.

| Operação | SQL | Descrição |
|----------|-----|-----------|
| **C**reate | `INSERT` | Inserir novos dados |
| **R**ead   | `SELECT` | Consultar dados |
| **U**pdate | `UPDATE` | Atualizar dados existentes |
| **D**elete | `DELETE` | Remover dados |

---

## DDL vs DML

Dois tipos de comandos SQL que você vai usar sempre:

**DDL (Data Definition Language)** — define a estrutura
- `CREATE TABLE` — cria uma tabela
- `ALTER TABLE` — modifica uma tabela
- `DROP TABLE` — apaga uma tabela

**DML (Data Manipulation Language)** — manipula os dados
- `INSERT`, `SELECT`, `UPDATE`, `DELETE`

---

## Resumo da aula

- Bancos relacionais organizam dados em tabelas conectadas por chaves
- ACID garante confiabilidade das transações
- CRUD são as 4 operações básicas
- DDL cria a estrutura, DML manipula os dados
