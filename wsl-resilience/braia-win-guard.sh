#!/bin/bash
# ==========================================================================
# braia-win-guard.sh - Reforco de resiliencia da camada Windows/WSL2.
# Idempotente e NAO-destrutivo: apenas HABILITA services para subirem no
# boot da distro. Nunca remove, nunca recria, nunca altera configuracao.
#
# Roda como root, periodicamente, via braia-win-guard.timer.
# Garante que, depois que o SETUP-AGENTE.md criar os services, eles fiquem
# 'enabled' para sempre (mesmo que o SETUP esqueca de habilitar algum).
# ==========================================================================
set +e
LOG=/var/log/braia-win-guard.log
echo "[$(date '+%F %T')] guard run" >> "$LOG"

# cron precisa estar ativo: o healthcheck.sh original (cron a cada 2 min)
# eh quem recria a sessao tmux + claude se ela cair.
systemctl enable --now cron       >/dev/null 2>&1

# Servicos de base do projeto.
systemctl enable --now postgresql >/dev/null 2>&1
systemctl enable caddy            >/dev/null 2>&1

# Habilita QUALQUER service do agente ja criado pelo SETUP-AGENTE.md.
# O nome final depende do AGENTE_NAME (ex.: braia-bot.service), entao
# cobrimos os padroes comuns por correspondencia de nome.
for f in /etc/systemd/system/*.service; do
  [ -e "$f" ] || continue
  n="$(basename "$f")"
  case "$n" in
    *bot*|*agent*|*braia*|AGENTE*|agente*)
      systemctl enable "$n" >/dev/null 2>&1 && \
        echo "[$(date '+%F %T')] enabled $n" >> "$LOG"
      ;;
  esac
done

exit 0
