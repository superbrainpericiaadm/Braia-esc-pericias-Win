-- Memoria full-text (busca por palavras, sem custo, sem chave, sem modelo local).
-- Complementa as colunas de embedding (vetorial) ja existentes no schema.sql.
-- Idempotente.

ALTER TABLE conversation_history ADD COLUMN IF NOT EXISTS content_tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('portuguese', content)) STORED;
CREATE INDEX IF NOT EXISTS idx_conv_content_tsv ON conversation_history USING gin(content_tsv);

ALTER TABLE memory_facts ADD COLUMN IF NOT EXISTS fact_tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('portuguese', fact)) STORED;
CREATE INDEX IF NOT EXISTS idx_facts_tsv ON memory_facts USING gin(fact_tsv);

ALTER TABLE memory_chunks ADD COLUMN IF NOT EXISTS content_tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('portuguese', content)) STORED;
CREATE INDEX IF NOT EXISTS idx_chunks_content_tsv ON memory_chunks USING gin(content_tsv);
