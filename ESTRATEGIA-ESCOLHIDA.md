# Estratégia Escolhida — Análise Completa (Fase 2)

- **Repositório original:** https://github.com/superbrainpericiaadm/Braia-esc-pericias-CLI
- **Novo repositório:** Braia Win
- **Data:** 2026-05-26
- **Windows de destino:** Windows 10 (build ≥ 19041) e Windows 11 em diante
- **Virtualização:** usuário pediu para avaliar as 4 estratégias (tratado como "em aberto")
- **Estratégia confirmada:** ✅ **B — WSL2 (Ubuntu 22.04 LTS)**

---

## Fase 1 — Mapa técnico do repositório original

| Item | Achado concreto |
|---|---|
| Linguagem/runtime | Python 3 (68,5%) + Shell (31,5%); Node 22 via **nvm** (Claude CLI + PM2) |
| Banco / fila | **PostgreSQL 16 + pgvector** (índices HNSW `vector_cosine_ops`); fila file-based `inbox/outbox/` |
| Proxy | **Caddy** (reverse proxy `127.0.0.1:3600`, auto-HTTPS) |
| Scripts / IaC | `bootstrap.sh`, `braia-bot/healthcheck.sh`, `SETUP-AGENTE.md` (9 etapas). **Sem** Dockerfile/compose/Makefile |
| Paths Linux | `/opt/AGENTE`, `/opt/AGENTE-bot`, `/root/`, e path macOS hardcoded `/Users/braiarodrigues/braia-bot` em `bot.py` |
| Comandos Linux | `systemctl`, `useradd`, `sudo -u postgres`, `chmod 600`, `chown -R`, `ln -sf`, `sed -i`, `xargs -0`, `journalctl`, `cron`, `sshpass`/`scp` |
| POSIX / nativo | **`tmux`** (ponte bot→Claude), `signal` (SIGTERM/daemon), `subprocess` (ffmpeg, tmux) |
| Serviços | **systemd** (`AGENTE-bot.service`, `Restart=always`), **launchd** (`com.braia.telegram-bot.plist`, macOS), **PM2** (`pm2 startup/save`), **cron** (healthcheck a cada 2 min) |
| CI/CD | Nenhum `.github/workflows/` |
| Case-sensitive | Sem conflitos detectados — baixo risco |
| Sockets/pipes | Sem sockets Unix; IPC por **tmux** + arquivos |
| Containers | Nenhum presente |
| Áudio | **ffmpeg** (MP3→OGG Opus), OpenAI Whisper (STT), ElevenLabs (TTS) |

**Bloqueadores concretos para Windows nativo:** (1) `tmux send-keys` é o mecanismo
central de comunicação bot→Claude e **não tem equivalente no Windows nativo**;
(2) `pgvector` exige compilação MSVC no Windows, enquanto no Ubuntu é um pacote apt.

---

## Avaliação das 4 estratégias

### Estratégia A — Windows nativo puro
- **Viabilidade técnica:** Baixa / quase Inviável.
- **A favor:** sem virtualização; tudo "no metal" do Windows.
- **Contra (risco de funcionamento imperfeito):** `tmux` inexistente → reescrever
  a ponte bot→Claude (mexeria na lógica de negócio, **proibido**); `pgvector` exige
  compilação MSVC; `systemctl`/`useradd`/`chmod`/`chown`/`sed -i`/`xargs -0`
  inexistentes; `signal`/daemon com semântica diferente.
- **Esforço de adaptação:** Altíssimo.
- **Pontos cegos:** comportamento do `claude --dangerously-skip-permissions`
  dirigido por teclas sem tmux; auto-HTTPS do Caddy; encoding de áudio.

### Estratégia B — WSL2 (Ubuntu dentro do Windows) ✅ ESCOLHIDA
- **Viabilidade técnica:** Alta.
- **Pré-requisitos:** W10 build 2004+ ou W11; virtualização no BIOS + recurso
  "Plataforma de Máquina Virtual"; `wsl --install`; Ubuntu 22.04 LTS.
- **A favor:** o `bootstrap.sh` **já tem ramo Ubuntu 22+** → roda quase intacto;
  `tmux`, `systemd`, `pgvector`, `ffmpeg`, `cron`, `nvm` nativos; **zero alteração
  na lógica**; `localhost:3600` acessível do Windows.
- **Contra:** depende de virtualização; 24/7 exige Windows ligado + ajuste anti-sono;
  OAuth do Claude abre navegador (contornável com URL manual).
- **Esforço de adaptação:** Baixo.
- **Pontos cegos:** systemd em WSL antigo (exige `wsl --update` + `systemd=true`);
  persistência do daemon após reboot do Windows.

### Estratégia C — Docker Desktop (containers Linux)
- **Viabilidade técnica:** Média.
- **Pré-requisitos:** Docker Desktop (backend WSL2 mesmo assim) + **licença paga em
  uso comercial**; repo **sem** Dockerfile/compose (criar do zero).
- **A favor:** reprodutível; isola Postgres/Caddy.
- **Contra:** containerizar **sessão Claude interativa + tmux + OAuth por navegador
  + PM2 + systemd** é antinatural (container = 1 processo, não um host multi-serviço);
  exige compose multi-serviço novo e adaptação da inicialização interativa.
- **Esforço de adaptação:** Alto.
- **Pontos cegos:** OAuth dentro do container; persistência de volumes da sessão
  tmux; áudio/ffmpeg em container.

### Estratégia D — Híbrida (app em WSL2 + Postgres/Caddy em Docker)
- **Viabilidade técnica:** Média.
- **Configuração sugerida:** bot+Claude+tmux em WSL2; PostgreSQL+pgvector e Caddy
  em containers no Windows.
- **A favor:** isola o banco.
- **Contra:** **complexidade sem ganho** — o bot já exige WSL2 (tmux), então mover
  só o Postgres para Docker adiciona uma segunda runtime de rede para o mesmo
  resultado; dois ambientes para manter.
- **Esforço de adaptação:** Médio-alto.
- **Pontos cegos:** rede WSL2↔container, `127.0.0.1` vs `host.docker.internal`.

---

## Recomendação final (confirmada pelo usuário)

**Estratégia B — WSL2.** Justificativa baseada em características concretas do
repositório: (1) a ponte bot→Claude é literalmente `tmux send-keys`, e `tmux` só
existe em Linux — em WSL2 funciona sem reescrever a lógica; (2) o `bootstrap.sh`
**já tem um ramo Ubuntu 22+ pronto**, então a instalação original roda quase
intacta; (3) `pgvector` + índices HNSW instalam por `apt` no Ubuntu, mas exigiriam
compilação MSVC no Windows nativo; (4) `systemd`, `cron`, `nvm`, `ffmpeg` e Caddy
são todos Linux-nativos e já presumidos pelos scripts. É o caminho de
**funcionamento perfeito com alteração mínima** — a prioridade definida.

---

## Adendo — fechamento dos pontos cegos da Estratégia B

Os dois pontos cegos levantados na avaliação da Estratégia B foram **resolvidos
por padrão** na geração (Fase 3), atendendo à exigência de estrutura 100% fechada
e resiliente:

| Ponto cego original | Como foi fechado |
|---|---|
| systemd em WSL antigo | `INSTALL-WSL2.ps1` força `wsl --update` e grava `[boot] systemd=true` em `/etc/wsl.conf`, com `wsl --terminate` para aplicar |
| Persistência do daemon após reboot do Windows | Tarefa `BraiaWin-Autostart` (boot + logon) sobe a distro; `systemd` sobe os serviços; `braia-win-guard.timer` mantém tudo `enabled`; `powercfg` impede sleep/hibernate |

### Virtualização — protocolo dedicado
Como o destino pode cair em máquina com VT desligada no BIOS, o instalador inclui
um **protocolo de virtualização** que detecta o estado real via CIM
(`HypervisorPresent`, `VirtualizationFirmwareEnabled`, `VMMonitorModeExtensions`),
liga os recursos de software (WSL + VirtualMachinePlatform) e — quando a VT está
desligada no firmware — instrui por fabricante e oferece **reiniciar direto na
UEFI** (`shutdown /r /fw`), retomando a instalação sozinho. O único limite é
físico: a VT de hardware é uma trava de firmware que **nenhum software liga por
dentro do Windows**.
