# SQL para Engenharia de Dados

Mini curso de 2 horas dividido em 5 aulas. Material prático e direto ao ponto para quem quer trabalhar com dados.

---

## Estrutura do Curso

| Aula | Tema | Tempo |
|------|------|-------|
| 1 | Bancos relacionais, ACID e CRUD | ~20 min |
| 2 | SQL para engenharia de dados | ~25 min |
| 3 | Views, Procedures e Funções | ~25 min |
| 4 | Index, Constraints e Partições | ~25 min |
| 5 | Data Warehouse: fato, dimensão, star schema, ETL vs ELT | ~25 min |

---

## Como usar este material

1. Execute o arquivo `banco.sql` primeiro para criar as tabelas de exemplo
2. Siga as aulas em ordem
3. Leia o `teoria.md` de cada aula antes de rodar o `exemplos.sql`
4. Todos os exemplos funcionam no **PostgreSQL**

---

## Pré-requisitos

- PostgreSQL instalado (ou qualquer banco compatível com SQL padrão)
- Noção básica de programação (não precisa saber SQL)

---

## Banco de dados de exemplo

O curso usa um banco simples de e-commerce com 3 tabelas:

- `clientes` — quem compra
- `produtos` — o que é vendido
- `pedidos` — as compras realizadas

Execute `banco.sql` para criar e popular o banco antes de começar.
