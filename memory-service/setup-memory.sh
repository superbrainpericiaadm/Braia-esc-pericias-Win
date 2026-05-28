#!/bin/bash
# ============================================================================
# setup-memory.sh - Configura a memoria da Braia (rodar DEPOIS do SETUP base).
# Constroi as 3 pecas que o repo nao trazia prontas:
#   1) escrita: consolidate.py (cron 2 min) grava as conversas no Postgres
#   2) busca:   search.py (CLI que o Claude chama no boot protocol)
#   3) indices: full-text (GIN) sempre; vetorial (pgvector HNSW) quando ha chave
#
# Filosofia: SEM modelo de embedding local (nao gasta RAM). A busca por
# significado (vetorial) liga sozinha quando OPENAI_API_KEY existe no .env;
# sem chave, cai para full-text (palavras) + raciocinio do Claude.
#
# Idempotente. Rodar como root dentro do WSL/Ubuntu.
#   bash memory-service/setup-memory.sh [OPENAI_API_KEY]
# Se passar a chave como argumento, ela e gravada nos .env (memoria + audio).
# ============================================================================
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MS=/opt/braia/memory-service
OPENAI_KEY="${1:-}"

echo '== 1) indices full-text (tsvector + GIN) =='
sudo -u postgres psql -d braia_memory -v ON_ERROR_STOP=1 < "$SCRIPT_DIR/schema-fulltext.sql"
sudo -u postgres psql -d braia_memory -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;" >/dev/null

echo '== 2) deploy dos scripts =='
mkdir -p "$MS/state"
cp "$SCRIPT_DIR/consolidate.py" "$SCRIPT_DIR/search.py" "$MS/"
chmod +x "$MS"/*.py
chown -R braia:braia "$MS"

echo '== 3) OPENAI_API_KEY no .env (memoria vetorial + audio/whisper) =='
for ENVF in /opt/braia/.env /opt/braia-bot/.env; do
  grep -q '^OPENAI_API_KEY=' "$ENVF" || echo 'OPENAI_API_KEY=' >> "$ENVF"
  if [ -n "$OPENAI_KEY" ]; then
    sed -i "s#^OPENAI_API_KEY=.*#OPENAI_API_KEY=${OPENAI_KEY}#" "$ENVF"
  fi
done
[ -n "$OPENAI_KEY" ] && echo '   chave gravada (memoria vetorial + audio ligados)' || echo '   sem chave -> modo full-text (preencha OPENAI_API_KEY nos .env para ligar vetorial+audio)'

echo '== 4) backfill inicial + cron (a cada 2 min) =='
sudo -u braia python3 "$MS/consolidate.py" || true
# crontab -u braia (root define direto; sudo -u braia crontab - falha em pipe sem tty)
( crontab -u braia -l 2>/dev/null | grep -vF 'consolidate.py'; \
  echo '*/2 * * * * /usr/bin/python3 /opt/braia/memory-service/consolidate.py >> /opt/braia/memory-service/state/consolidate.log 2>&1' ) | crontab -u braia -

echo '== pronto. teste: =='
echo '   sudo -u braia python3 /opt/braia/memory-service/search.py "algum topico"'
echo 'SETUP-MEMORY DONE'
