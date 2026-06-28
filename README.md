# SIGFIN — Controle Financeiro

Sistema inteligente de controle financeiro pessoal: lançamento de **receitas e despesas**, leitura e classificação de **faturas de cartão**, e **divisão de contas** — com memória em nuvem. A IA lê as faturas e, nos meses seguintes, já reconhece automaticamente quem é responsável por cada compra.

## Funcionalidades

- 💸 **Módulo Finanças**: lança receitas e despesas no momento em que acontecem (à vista, débito, crédito, Pix), com categorias, despesas fixas/recorrentes e parcelamento
- 📄 **Módulo Faturas**: upload de PDF das faturas (múltiplos cartões), lido por IA (Claude Sonnet)
- 🧠 Memória em nuvem: compras já classificadas são reconhecidas automaticamente no próximo mês
- 👥 Pessoas: divisão de despesas e total por pessoa
- ⚙️ **Admin**: gerencie categorias, pessoas e cartões (criar, editar, excluir)
- 📱 Multiplataforma (celular, tablet e computador) — pode ser salvo como app na tela inicial do iPhone/Android
- ☁️ Acesse de qualquer dispositivo com a mesma URL

---

## Setup — Passo a Passo

### 1. Supabase (banco de dados)

1. Acesse [supabase.com](https://supabase.com) e abra seu projeto
2. Vá em **SQL Editor**
3. Cole e execute o conteúdo do arquivo `supabase_schema.sql`
4. Vá em **Project Settings → API**
5. Copie a **Project URL** e a **anon/public key**

### 2. Variáveis de ambiente no Vercel

No painel do Vercel, vá em **Settings → Environment Variables** e adicione:

| Nome | Valor |
|------|-------|
| `VITE_SUPABASE_URL` | URL do seu projeto Supabase |
| `VITE_SUPABASE_ANON_KEY` | Chave anon do Supabase |
| `ANTHROPIC_API_KEY` | Sua chave da API Anthropic (sem prefixo `VITE_` — fica só no servidor) |

> A leitura dos PDFs acontece na função serverless `api/parse.mjs`, que roda no servidor do Vercel. Por isso a chave da Anthropic usa o nome `ANTHROPIC_API_KEY` (sem `VITE_`): variáveis com prefixo `VITE_` vão embutidas no navegador e ficariam expostas.

### 3. Deploy no Vercel

O projeto é detectado automaticamente como Vite. Conecte o repositório `sigfat` no Vercel e faça o deploy.

---

## Estrutura do Projeto

```
sigfat/
├── index.html           # Aplicação principal (frontend completo)
├── api/parse.mjs        # Função serverless: lê PDF da fatura com a IA (chave fica no servidor)
├── vite.config.js       # Configuração do Vite
├── package.json         # Dependências
├── supabase_schema.sql  # Script para criar as tabelas no Supabase
├── .env.example         # Exemplo de variáveis de ambiente
└── .gitignore
```

## Banco de Dados (Supabase)

| Tabela | O que guarda |
|--------|-------------|
| `pessoas` | Você e as pessoas que você compra no cartão |
| `classificacoes` | Memória: estabelecimento → pessoa responsável |
| `faturas` | Registro de cada fatura processada |
| `transacoes` | Todas as transações extraídas das faturas |

---

## Como usar

1. Acesse a URL do seu app no Vercel
2. **Passo 1:** Coloque os nomes das pessoas e clique em "Salvar nomes"
3. **Passo 2:** Envie as faturas (PDF ou imagem) e clique em "Ler faturas com IA"
4. **Passo 3:** Classifique cada gasto — as compras conhecidas já vêm classificadas automaticamente
5. **Passo 4:** Veja o resumo com o total de cada pessoa

No mês seguinte, repita o processo — a IA já vai reconhecer a maioria das compras!
