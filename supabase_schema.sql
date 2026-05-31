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
