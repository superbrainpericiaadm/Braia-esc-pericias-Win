# Relatório de Adaptação — Braia Win (Linux → Windows via WSL2)

## Resumo
- **Repositório original:** https://github.com/superbrainpericiaadm/Braia-esc-pericias-CLI
- **Estratégia escolhida e confirmada:** **B — WSL2** (Ubuntu 22.04 LTS)
- **Data:** 2026-05-26
- **Total de arquivos:** **14 criados** · **0 modificados** (no original) · **1 N/D**
  - O repositório original **não foi tocado, clonado nem alterado**.
  - Em WSL2 não se converte `.sh` → `.ps1`; os scripts Linux permanecem intactos
    e são clonados em tempo de instalação **dentro do WSL2**.
  - Inclui camada de **resiliência por padrão** (autostart + guard `systemd` +
    energia) e **protocolo de virtualização** (detecção + ativação de software +
    reboot na UEFI).

## Estratégia escolhida — resumo
WSL2 foi escolhida porque a ponte bot→Claude usa `tmux send-keys` (sem equivalente
no Windows nativo) e a memória vetorial usa `pgvector` (que exige compilação MSVC
no Windows, mas é pacote `apt` no Ubuntu). O `bootstrap.sh` original já tem um ramo
Ubuntu 22+, então roda quase intacto sob WSL2 — funcionamento perfeito com alteração
mínima e **sem mexer na lógica de negócio**. Análise completa em
`ESTRATEGIA-ESCOLHIDA.md`.

## Mudanças aplicadas

| Arquivo original | Arquivo novo | Mudança | Motivo |
|---|---|---|---|
| `bootstrap.sh` (ramo Ubuntu) | `bootstrap.sh` (patcheado, vendorizado) | Self-contained: copia `SETUP-AGENTE.md`/`.env.example` **localmente** (não baixa do GitHub) e instala Claude `@latest` (era `2.1.118`) | Repo privado não pode ser baixado por `curl` no cliente |
| (clone do GitHub na instalação) | `INSTALL-WSL2.ps1` copia arquivos **locais** p/ `/root/projeto` | Deixou de clonar do GitHub; usa a pasta levada ao cliente | Funcionar offline-do-GitHub com repo privado |
| `bootstrap.sh` (ramo macOS/launchd) | — | Ignorado | Específico de macOS; irrelevante no Windows |
| `README.md` | `README.md` (reescrito) | Instruções Windows no topo, sem teto fixo de tempo | Alvo da execução é Windows |
| — | `INSTALL-WINDOWS.ps1` | Criado (ponto de entrada exigido) | Lançador oficial com `ExecutionPolicy Bypass` |
| — | `INSTALL-WINDOWS.bat` | Criado | Fallback para PowerShell restrito |
| — | `README-WSL2.md` | Criado | Guia detalhado + solução de problemas + validação |
| — | `ESTRATEGIA-ESCOLHIDA.md` | Criado | Auditoria da Fase 2 |
| — | `RELATORIO-ADAPTACAO.md` | Criado | Este relatório |
| — | `start-braia.ps1` | Criado | Chamado pela tarefa de autostart; sobe o WSL2 no boot/logon |
| — | `wsl-resilience/braia-win-guard.sh` | Criado | Guard idempotente: habilita `cron`/serviços do agente |
| — | `wsl-resilience/braia-win-guard.service` | Criado | Unit `oneshot` do guard |
| — | `wsl-resilience/braia-win-guard.timer` | Criado | Roda o guard a cada 2 min (resiliência) |
| — | `wsl-resilience/install-resilience.sh` | Criado | Instala o guard dentro do WSL2 (robusto a CRLF) |
| — | `.gitignore` | Criado | Evitar commit de `.env`/segredos e estado local |
| — | `.gitattributes` | Criado | Força LF em `.sh`/`.service`/`.timer` (evita `^M` no Linux) |

## Conversões realizadas

| Tipo | Original (Linux) | Novo (Windows/WSL2) |
|---|---|---|
| Habilitar subsistema | (n/a) | `wsl --install` + `Enable-WindowsOptionalFeature` (WSL + VirtualMachinePlatform) |
| Instalar distro | (n/a) | `wsl --install -d Ubuntu-22.04 --no-launch` |
| Rodar pré-requisitos | `bash bootstrap.sh` (root) | `wsl -d Ubuntu-22.04 -u root -- bash -lic "curl … \| bash"` |
| Serviços `systemd` | `systemctl enable --now` | **mantido** — systemd habilitado no WSL via `/etc/wsl.conf` |
| `tmux` (ponte bot→Claude) | nativo Linux | **mantido** — nativo no Ubuntu do WSL2 |
| `pgvector` | `apt install postgresql-16-pgvector` | **mantido** — idem dentro do WSL2 |
| Clonar projeto | (manual) | `git clone … /root/projeto` dentro do WSL2 |
| Acesso ao app | `localhost:3600` | `http://localhost:3600` (forward automático WSL2→Windows) |
| Acesso a arquivos | filesystem Linux | `\\wsl$\Ubuntu-22.04\root\projeto` |
| Virtualização | (pressuposta) | **Protocolo novo:** detecta VT via CIM; liga WSL+VMP; oferece `shutdown /r /fw` |
| Autostart no boot | `systemd enable` (na VPS) | Tarefa `BraiaWin-Autostart` (boot+logon) → sobe a distro → systemd |
| Reforço de enable | (implícito no SETUP) | `braia-win-guard.timer` (a cada 2 min, idempotente) |
| Manter vivo (energia) | (VPS sempre ligada) | `powercfg` desativa standby/hibernate na tomada |
| Recriação do `tmux` | `healthcheck.sh` (cron) | **mantido** — cron garantido `enabled` pelo guard |
| Versão do Claude Code | pin `2.1.118` no bootstrap | `npm i -g @anthropic-ai/claude-code@latest` após o bootstrap (sem tocar no original) |

> **Não convertido (correto para WSL2):** `braia-bot/bot.py`, `braia-bot/healthcheck.sh`,
> `database/schema.sql`, `SETUP-AGENTE.md`, `.env.example`, `CLAUDE.md`,
> `.claude/agents/*` — permanecem **originais**, ficam **incluídos neste repositório**
> e são **copiados** para o WSL2 na instalação (não clonados do GitHub).
> **Reduções:** `.claude/agents/` mantém só **3** (`isaura`, `angelica`, `paulo-dev`;
> sai `juliana-ops`); excluídos `launchd/` (macOS) e os guias de instalação Linux/aluno
> (`INSTRUCAO-PARA-ALUNO.md`, `PASSO-A-PASSO.txt`, `prompt-instalador.txt`).

## Dependências com observação

| Dependência | Status | Observação |
|---|---|---|
| WSL2 + VirtualMachinePlatform | Ativado pelo instalador | Recursos de software ligados automaticamente (+ reboot/retomada) |
| Virtualização de hardware (BIOS) | **Não automatizável por software** | Instalador detecta, instrui por fabricante e oferece reboot na UEFI (`shutdown /r /fw`) |
| systemd no WSL | Ativado pelo instalador | `[boot] systemd=true` em `/etc/wsl.conf` + `wsl --terminate` |
| Autostart 24/7 | Ativado pelo instalador | Tarefa `BraiaWin-Autostart` + guard `systemd` (padrão; opt-out disponível) |
| PostgreSQL 16 + pgvector | OK no Ubuntu | Instalado pelo bootstrap; índices HNSW criados no SETUP |
| Caddy | OK no Ubuntu | auto-HTTPS depende de domínio público (opcional num desktop) |
| Claude Code CLI (`@latest`) | Login interativo | Instalador sobrepõe o pin antigo (`2.1.118`) pela versão mais recente; `claude auth login --claudeai` (OAuth) não é automatizável |
| OpenAI / ElevenLabs | Opcionais | Só para áudio bidirecional; configurar no `.env` |
| launchd (macOS) | Não se aplica | Ignorado no Windows |
| sshpass/scp (MODO B) | Opcional | Só para deploy remoto; desnecessário em instalação local |

## Itens N/D — requerem revisão manual

1. **`braia-bot/bot.py` (código-fonte verbatim):** a leitura remota retornou a
   análise arquitetural (uso de `tmux send-keys`, `ffmpeg`, `signal`, `subprocess`,
   path macOS hardcoded `/Users/braiarodrigues/braia-bot`), mas **não** as linhas
   literais. **Impacto na estratégia WSL2: nenhum** — o arquivo não é alterado.
   Recomenda-se conferir, durante o SETUP, se algum path absoluto macOS/`/opt`
   precisa de ajuste ao novo ambiente (o `SETUP-AGENTE.md` cuida disso ao criar
   `/opt/AGENTE-bot`).

## Passo a passo de instalação no Windows destino

| # | Comando / ação | Tempo estimado |
|---|---|---|
| 1 | PowerShell **como Administrador** na pasta do repo | — |
| 2 | `powershell -ExecutionPolicy Bypass -File .\INSTALL-WINDOWS.ps1` | < 1 min p/ iniciar |
| 3 | **Protocolo de virtualização** (detecção; se VT off no BIOS → UEFI + retomada) | 0–5 min (+ trip à UEFI, se preciso) |
| 4 | (1ª vez) habilitar recursos WSL/VMP + **reboot** (retomada automática via RunOnce) | 2–5 min + reboot |
| 5 | `wsl --update` + instalar Ubuntu 22.04 | 3–8 min |
| 6 | Habilitar systemd (`wsl.conf`) + `wsl --terminate` | < 1 min |
| 7 | `bootstrap.sh` original (Node, Python, ffmpeg, PostgreSQL+pgvector, Caddy, pm2) **+ sobrepõe Claude CLI p/ `@latest`** | 8–25 min |
| 8 | `git clone` do projeto em `/root/projeto` | < 1 min |
| 9 | **Resiliência:** instala `braia-win-guard.timer` no WSL | < 1 min |
| 10 | **Energia:** `powercfg` (sem standby/hibernate na tomada) | < 1 min |
| 11 | **Autostart:** registra tarefa `BraiaWin-Autostart` + copia `start-braia.ps1` | < 1 min |
| 12 | **Manual:** `claude auth login --claudeai` (OAuth) | 1–2 min |
| 13 | **Manual:** `claude --dangerously-skip-permissions` → "Leia o SETUP-AGENTE.md…" | variável (IA conduz) |

> **Total realista:** 15–40 min + reboot. Etapas 3–11 são **automáticas**; só 12–13
> pedem os dados pontuais (login + token). Prioridade: **funcionamento perfeito**.

## Riscos conhecidos e mitigações

| Risco | Mitigação |
|---|---|
| **VT desligada no BIOS** (software não liga) | Instalador detecta, instrui por fabricante e **reinicia na UEFI** (`shutdown /r /fw`) + retoma sozinho |
| CPU sem suporte a VT | Instalador aborta com diagnóstico; usar outra máquina |
| `0x80370102` ao iniciar a distro | VMP/Hyper-V ou Memory Integrity em conflito → conferir recursos e Core Isolation |
| systemd não ativo (WSL antigo) | `wsl --update`; `[boot] systemd=true`; `wsl --terminate` (o instalador faz) |
| **WSL "inbox" sem systemd** | Instalador checa `wsl --version`; se ausente, migra com `wsl --update --web-download`; aborta com clareza se Store/web bloqueada |
| **Store desabilitada (GPO)** | Instalador instala a distro com `--web-download` (fallback automático) |
| **Proxy/firewall corporativo** | Preflight testa 443 nos hosts críticos e avisa antes; libere github/npm/apt.postgresql/cloudsmith/nodejs |
| **Mark of the Web (SmartScreen)** | Instalador roda `Unblock-File` no próprio repositório (wrapper + main) |
| **Disco cheio** | Preflight avisa se C: < 15 GB livre |
| **Race do systemd no bootstrap** | Instalador aguarda `is-system-running` = running/degraded antes de rodar o bootstrap |
| **Pin antigo do Claude Code (`2.1.118`)** | **Resolvido:** instalador força `@anthropic-ai/claude-code@latest` após o bootstrap (param `-ClaudeVersion`) |
| Agente não sobe após reboot | Tarefa `BraiaWin-Autostart` + guard `systemd` já cobrem; se ninguém loga, ativar login automático (`netplwiz`) |
| Máquina dorme/hiberna | `powercfg` desativa standby/hibernate na tomada (o instalador faz) |
| OAuth do Claude não abre navegador | Copiar a URL impressa e abrir manualmente no navegador do Windows |
| `--no-launch` não suportado (WSL antigo) | Instalador cai no `wsl --install -d` padrão automaticamente |
| CRLF quebrando `.sh` no Linux | `.gitattributes` força LF; `install-resilience.sh` ainda faz `sed 's/\r$//'` |
| Segredos no `.env` | `.gitignore` já ignora `.env`; usar `chmod 600` no WSL |

## Como validar que está funcionando

```powershell
wsl -l -v
wsl -d Ubuntu-22.04 -u root -- bash -lic "node -v; python3 --version; claude --version; psql --version; caddy version; pm2 -v"
wsl -d Ubuntu-22.04 -u root -- systemctl is-system-running
wsl -d Ubuntu-22.04 -u root -- systemctl is-active AGENTE-bot
wsl -d Ubuntu-22.04 -u root -- sudo -u postgres psql -c "SELECT * FROM pg_available_extensions WHERE name='vector';"
curl http://localhost:3600/health

# Resiliência (camada Windows/WSL2)
Get-ScheduledTask -TaskName "BraiaWin-Autostart" | Select-Object State
wsl -d Ubuntu-22.04 -u root -- systemctl is-active braia-win-guard.timer
powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
```

Critério de sucesso: `wsl -l -v` mostra `Ubuntu-22.04 ... 2`; as versões aparecem;
`is-system-running` retorna `running`/`degraded`; `AGENTE-bot` está `active`; o
`pg_available_extensions` lista `vector`; o endpoint `/health` responde; a tarefa
`BraiaWin-Autostart` está `Ready`; `braia-win-guard.timer` está `active`; e o
standby na tomada está `0` (desativado).

## Teste de resiliência (recomendado)
Para validar o cenário "desligou e ligou de volta": após o SETUP completo e o
agente funcionando, **reinicie o Windows**, faça login e — sem abrir nada — envie
uma mensagem ao bot no Telegram. Ela deve ser respondida, provando que WSL2 →
systemd → serviços → `tmux` → `claude` subiram sozinhos.
