# 🎓 Mini Curso SQL para Engenharia de Dados

> Aprenda SQL do jeito que engenheiros de dados usam no dia a dia: modelagem, transformação, performance e pipelines.

**⏱️ Duração total:** ~2h 25min
**👥 Nível:** Intermediário
**🛠️ Tecnologia:** SQL Server (T-SQL)
**📦 Banco de dados:** `loja_db` (OLTP) + `dw_loja` (Data Warehouse)

---

## 📺 Roteiro do Mini Curso

| Aula | Arquivo | Conteúdo | ⏱️ Tempo | Acumulado |
|------|---------|----------|----------|-----------|
| Setup | `banco.sql` | Criação de tabelas e dados | ~5 min | 5 min |
| Aula 1 | `aula_1/exemplos.sql` | Fundamentos de bancos relacionais | ~25 min | 30 min |
| Aula 2 | `aula_2/exemplos.sql` | SQL para engenharia de dados | ~35 min | 65 min |
| Aula 3 | `aula_3/exemplos.sql` | Views, procedures e funções | ~25 min | 90 min |
| Aula 4 | `aula_4/exemplos.sql` | Index e constraints | ~25 min | 115 min |
| Aula 5 | `aula_5/exemplos.sql` | SQL no Data Warehouse | ~30 min | **145 min (~2h25)** |

---

## 📝 Exercícios

| Nível | Arquivo | Qtd | Descrição |
|-------|---------|-----|-----------|
| 🟢 Básico | `exercicios/basico.sql` | 8 | Réplica dos exemplos das aulas |
| 🟡 Intermediário | `exercicios/intermediario.sql` | 6 | Combinação de 2+ conceitos |
| 🔴 Avançado | `exercicios/avancado.sql` | 4 | Casos de uso reais de engenharia |

---

## 🗂️ Estrutura do Projeto

```
mini_curso_sql_engenharia/
├── README.md                    ← você está aqui
├── banco.sql                    ← setup: cria e popula todas as tabelas
├── aula_1/
│   └── exemplos.sql             ← Fundamentos de bancos relacionais
├── aula_2/
│   └── exemplos.sql             ← SQL como ferramenta de transformação
├── aula_3/
│   └── exemplos.sql             ← Views, procedures e funções
├── aula_4/
│   └── exemplos.sql             ← Index e constraints
├── aula_5/
│   └── exemplos.sql             ← SQL no Data Warehouse
└── exercicios/
    ├── basico.sql
    ├── intermediario.sql
    └── avancado.sql
```

---

## 🚀 Como começar

1. Execute `banco.sql` para criar os bancos e inserir os dados
2. Siga as aulas em ordem — cada uma se apoia na anterior
3. Após cada aula, resolva os exercícios do nível correspondente

---

## 📌 Pré-requisitos

- SQL Server 2019+ ou Azure SQL Database
- SQL Server Management Studio (SSMS) ou Azure Data Studio
- Não é necessário instalar nada além disso

---

## 🗃️ Modelo de dados usado no curso

### OLTP — `loja_db` (Aulas 1 a 4)

```
clientes ──────< pedidos >────── itens_pedido >────── produtos
                                                          │
                                                      categorias
```

### DW — `dw_loja` (Aula 5)

```
dim_cliente ──┐
dim_produto ──┼──> fato_vendas
dim_tempo ────┘
stg_pedidos (staging — entrada dos dados brutos)
```
