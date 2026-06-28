-- Tabela de pessoas (você + convidados)
CREATE TABLE IF NOT EXISTS pessoas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  cor TEXT NOT NULL,
  posicao INTEGER NOT NULL,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de classificações conhecidas (memória do sistema)
-- Guarda: estabelecimento -> pessoa responsável
CREATE TABLE IF NOT EXISTS classificacoes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  estabelecimento TEXT NOT NULL UNIQUE,
  pessoa_id UUID REFERENCES pessoas(id) ON DELETE SET NULL,
  total_ocorrencias INTEGER DEFAULT 1,
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de faturas processadas
CREATE TABLE IF NOT EXISTS faturas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nome_arquivo TEXT NOT NULL,
  mes_referencia TEXT,
  processado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de transações
CREATE TABLE IF NOT EXISTS transacoes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fatura_id UUID REFERENCES faturas(id) ON DELETE CASCADE,
  descricao TEXT NOT NULL,
  data_compra TEXT,
  valor NUMERIC(10,2) NOT NULL,
  pessoa_id UUID REFERENCES pessoas(id) ON DELETE SET NULL,
  classificado_automaticamente BOOLEAN DEFAULT FALSE,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_classificacoes_estabelecimento ON classificacoes(estabelecimento);
CREATE INDEX IF NOT EXISTS idx_transacoes_fatura_id ON transacoes(fatura_id);
CREATE INDEX IF NOT EXISTS idx_transacoes_pessoa_id ON transacoes(pessoa_id);

-- Habilitar RLS (Row Level Security) mas permitir tudo por ora (sem autenticação)
ALTER TABLE pessoas ENABLE ROW LEVEL SECURITY;
ALTER TABLE classificacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE faturas ENABLE ROW LEVEL SECURITY;
ALTER TABLE transacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "acesso_publico_pessoas" ON pessoas FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acesso_publico_classificacoes" ON classificacoes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acesso_publico_faturas" ON faturas FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acesso_publico_transacoes" ON transacoes FOR ALL USING (true) WITH CHECK (true);

-- Inserir pessoas padrão
INSERT INTO pessoas (nome, cor, posicao) VALUES
  ('Eu', '#185FA5', 0),
  ('Pessoa 1', '#0F6E56', 1),
  ('Pessoa 2', '#854F0B', 2),
  ('Pessoa 3', '#993556', 3),
  ('Pessoa 4', '#3B6D11', 4),
  ('Pessoa 5', '#534AB7', 5),
  ('Pessoa 6', '#993B1D', 6)
ON CONFLICT DO NOTHING;

-- Tabela de configurações gerais (chave Pix, preferências)
CREATE TABLE IF NOT EXISTS config (
  chave TEXT PRIMARY KEY,
  valor TEXT NOT NULL,
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acesso_publico_config" ON config FOR ALL USING (true) WITH CHECK (true);

-- Inserir chave Pix padrão
INSERT INTO config (chave, valor) VALUES ('pix_key', '84999152238') ON CONFLICT DO NOTHING;

-- Adicionar coluna nota nas transações (rodar no SQL Editor do Supabase)
ALTER TABLE transacoes ADD COLUMN IF NOT EXISTS nota TEXT;

-- Adicionar colunas divisao e parcela nas transações
ALTER TABLE transacoes ADD COLUMN IF NOT EXISTS divisao JSONB;
ALTER TABLE transacoes ADD COLUMN IF NOT EXISTS parcela JSONB;

-- Tabela de memória de classificações (chave = descrição normalizada)
-- Permite reusar classificações entre meses: "ASAAS *life academia" → sempre Leandro
CREATE TABLE IF NOT EXISTS memoria_transacao (
  chave TEXT PRIMARY KEY,
  descricao TEXT,
  pessoa_id UUID REFERENCES pessoas(id) ON DELETE SET NULL,
  divisao JSONB,
  nota TEXT,
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE memoria_transacao ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acesso_publico_memoria" ON memoria_transacao FOR ALL USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_memoria_chave ON memoria_transacao(chave);

-- ════════════════════════════════════════════════════════════════════════════
-- MÓDULO FINANÇAS (receitas e despesas) — independente do fluxo de faturas
-- ════════════════════════════════════════════════════════════════════════════

-- Categorias de receita/despesa (com relatório por categoria)
CREATE TABLE IF NOT EXISTS fin_categorias (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  tipo TEXT NOT NULL,           -- 'receita' | 'despesa'
  cor TEXT,
  icone TEXT,                   -- nome do ícone Tabler (ex: 'shopping-cart')
  posicao INTEGER DEFAULT 0,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE fin_categorias ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acesso_publico_fin_categorias" ON fin_categorias FOR ALL USING (true) WITH CHECK (true);

-- Cartões (para agrupar a fatura projetada por cartão)
CREATE TABLE IF NOT EXISTS fin_cartoes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  dia_fechamento INTEGER,
  dia_vencimento INTEGER,
  cor TEXT,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE fin_cartoes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acesso_publico_fin_cartoes" ON fin_cartoes FOR ALL USING (true) WITH CHECK (true);

-- Livro-caixa do módulo: receitas e despesas
CREATE TABLE IF NOT EXISTS fin_lancamentos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tipo TEXT NOT NULL,                 -- 'receita' | 'despesa'
  descricao TEXT NOT NULL,
  valor NUMERIC(10,2) NOT NULL,
  data DATE NOT NULL,                 -- competência (mês a que pertence)
  categoria_id UUID REFERENCES fin_categorias(id) ON DELETE SET NULL,
  forma TEXT,                         -- 'dinheiro'|'debito'|'credito'|'pix'
  cartao_id UUID REFERENCES fin_cartoes(id) ON DELETE SET NULL,
  pessoa_id UUID REFERENCES pessoas(id) ON DELETE SET NULL,
  divisao JSONB,                      -- [{pessoa_id, valor}] — mesmo formato do módulo de faturas
  parcela JSONB,                      -- { atual, total } quando parcelado
  grupo_id UUID,                      -- liga todas as parcelas/repetições de um mesmo lançamento
  fixa BOOLEAN DEFAULT FALSE,         -- despesa fixa/recorrente
  nota TEXT,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE fin_lancamentos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acesso_publico_fin_lancamentos" ON fin_lancamentos FOR ALL USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_fin_lanc_data ON fin_lancamentos(data);
CREATE INDEX IF NOT EXISTS idx_fin_lanc_grupo ON fin_lancamentos(grupo_id);

-- Categorias padrão
INSERT INTO fin_categorias (nome, tipo, cor, icone, posicao) VALUES
  ('Alimentação', 'despesa', '#C0392B', 'tools-kitchen-2', 0),
  ('Moradia',     'despesa', '#8E44AD', 'home',            1),
  ('Transporte',  'despesa', '#2980B9', 'car',             2),
  ('Saúde',       'despesa', '#16A085', 'heart',           3),
  ('Lazer',       'despesa', '#E67E22', 'movie',           4),
  ('Educação',    'despesa', '#2C3E50', 'school',          5),
  ('Assinaturas', 'despesa', '#7F8C8D', 'repeat',          6),
  ('Compras',     'despesa', '#D35400', 'shopping-cart',   7),
  ('Outros',      'despesa', '#95A5A6', 'dots',            8),
  ('Salário',     'receita', '#27AE60', 'cash',            0),
  ('Freela',      'receita', '#1ABC9C', 'briefcase',       1),
  ('Outros',      'receita', '#95A5A6', 'dots',            2)
ON CONFLICT DO NOTHING;
