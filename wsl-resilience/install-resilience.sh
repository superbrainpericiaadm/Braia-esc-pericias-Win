#!/bin/bash
# ==========================================================================
# install-resilience.sh - Instala a camada de resiliencia (guard) no WSL2.
# Roda como root, dentro do Ubuntu.
#
# Uso:
#   bash install-resilience.sh [DIRETORIO_FONTE]
#   (DIRETORIO_FONTE = pasta com os arquivos guard; default = dir deste script)
#
# Robusto a CRLF: remove '\r' dos arquivos instalados (caso venham de /mnt).
# ==========================================================================
set -e
SRC="${1:-$(cd "$(dirname "$0")" && pwd)}"

echo "[braia] instalando resiliencia a partir de: $SRC"

install -m 0755 "$SRC/braia-win-guard.sh"      /usr/local/sbin/braia-win-guard.sh
install -m 0644 "$SRC/braia-win-guard.service" /etc/systemd/system/braia-win-guard.service
install -m 0644 "$SRC/braia-win-guard.timer"   /etc/systemd/system/braia-win-guard.timer

# Normaliza fim de linha (defensivo contra CRLF do Windows).
sed -i 's/\r$//' /usr/local/sbin/braia-win-guard.sh \
                 /etc/systemd/system/braia-win-guard.service \
                 /etc/systemd/system/braia-win-guard.timer

systemctl daemon-reload
systemctl enable --now braia-win-guard.timer

echo "[braia] OK: braia-win-guard.timer ativo (reforco a cada 2 min)."
