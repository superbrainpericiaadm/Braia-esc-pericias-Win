# Guia WSL2 — Braia Win

Guia detalhado da instalação via **WSL2** e da operação do agente no Windows.

---

## 1. Pré-requisitos

- **Windows 10** build **19041 (versão 2004)** ou superior, **ou Windows 11**.
- **Virtualização habilitada no BIOS/UEFI** (Intel VT-x / AMD-V / SVM).
- Conta com **privilégios de administrador**.
- Conexão de internet estável (haverá downloads de centenas de MB).
- Conta **Claude Pro ou Max** (o agente usa login OAuth, não exige API key).
- (Opcional, para áudio) chaves **OpenAI** (Whisper) e **ElevenLabs** (TTS).

Para checar a build do Windows: `Win+R` → `winver`.

---

## 2. Instalação automática

No **PowerShell como Administrador**, dentro da pasta do repositório:

```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALL-WINDOWS.ps1
```

> Por padrão, **tudo já vem fechado**: virtualização, WSL2, Ubuntu, bootstrap,
> clone, **resiliência** (autostart + guard systemd) e **energia**. Os parâmetros
> abaixo são apenas *opt-outs* para casos específicos.

```powershell
# Não criar a tarefa de autostart (boot/logon):
.\INSTALL-WSL2.ps1 -SemAutostart

# Não instalar o guard systemd de resiliência:
.\INSTALL-WSL2.ps1 -SemResiliencia

# Não alterar as configurações de energia do Windows:
.\INSTALL-WSL2.ps1 -SemAjusteEnergia

# Só preparar o WSL2 sem rodar o bootstrap/clone ainda:
.\INSTALL-WSL2.ps1 -PularBootstrap

# Usar outra distro (padrão é Ubuntu-22.04):
.\INSTALL-WSL2.ps1 -Distro "Ubuntu-22.04"
```

### O que o instalador faz, em ordem
1. Auto-eleva para administrador.
2. Confere a build do Windows (≥ 19041).
3. **Protocolo de virtualização** (ver seção 8): detecta VT‑x/AMD‑V, liga os
   recursos de software (**WSL** + **VirtualMachinePlatform**) com reboot +
   retomada automática, e — se a VT estiver desligada no BIOS — instrui e oferece
   reiniciar direto na UEFI.
4. `wsl --update` + `wsl --set-default-version 2`.
5. Instala **Ubuntu 22.04 LTS** com `--no-launch` (sem assistente interativo).
6. Habilita **systemd** dentro do WSL (`/etc/wsl.conf`) — necessário para os
   `systemctl enable --now` do SETUP original.
7. **Copia este repositório (local) para `/root/projeto`** dentro do WSL — não
   clona do GitHub (repo privado e autocontido).
8. Roda o **`bootstrap.sh` próprio** (Node 22 via nvm, Python3, ffmpeg,
   PostgreSQL 16 + pgvector, Caddy, pm2, **Claude Code `@latest`**) — o bootstrap
   original pinava `2.1.118`; para fixar outra, use `-ClaudeVersion "2.1.150"`.
9. **Resiliência (Linux):** instala o guard `systemd` (`braia-win-guard.timer`),
   que a cada 2 min habilita `cron`, `postgresql`, `caddy` e os serviços do agente.
10. **Energia (Windows):** desativa suspensão/hibernação na tomada (`powercfg`).
11. **Autostart (Windows):** cria a tarefa `BraiaWin-Autostart` (boot + logon) e
    copia `start-braia.ps1` para `%ProgramData%\BraiaWin\`.
12. Imprime os 2 passos interativos finais (login do Claude + SETUP).

---

## 3. Passos manuais finais (interativos — não automatizáveis)

Abra o Ubuntu como root:

```powershell
wsl -d Ubuntu-22.04 -u root
```

**Passo 1 — login no Claude** (abre link no navegador, autoriza, cola o código):

```bash
claude auth login --claudeai
```

**Passo 2 — disparar o SETUP do agente:**

```bash
cd /root/projeto
claude --dangerously-skip-permissions
```

Dentro do Claude, cole:

```
Leia o arquivo SETUP-AGENTE.md e execute todos os passos.
Me faca perguntas quando precisar de informacao minha.
```

> O `SETUP-AGENTE.md` original cria os diretórios (`/opt/AGENTE`,
> `/opt/AGENTE-bot`), o usuário do sistema, o banco e os services. Ele vai pedir
> seus dados (token do Telegram, IDs permitidos, etc.). Tenha o `.env.example`
> em mãos como referência.

---

## 4. Acessando o agente pelo Windows

| O quê | Como |
|---|---|
| Painel `agent-manager` | Navegador → **http://localhost:3600** |
| Arquivos do projeto | Explorer → `\\wsl$\Ubuntu-22.04\root\projeto` |
| Logs do bot | `wsl -d Ubuntu-22.04 -u root -- tail -f /opt/AGENTE-bot/logs/bot.log` |
| Sessão do Claude (tmux) | `wsl -d Ubuntu-22.04 -u root` → `tmux attach -t AGENTE` |
| Status dos services | `wsl -d Ubuntu-22.04 -u root -- systemctl status AGENTE-bot` |

> `localhost:porta` funciona direto entre Windows e WSL2 (encaminhamento
> automático de portas do WSL2).

---

## 5. Resiliência 24/7 — já configurada por padrão

**Você não precisa fazer nada.** O instalador já deixa a cadeia completa fechada:

| Camada | Mecanismo | Garante |
|---|---|---|
| Windows liga | Tarefa `BraiaWin-Autostart` (boot + logon) | A distro WSL2 inicia sozinha |
| Distro sobe | `systemd` habilitado (`/etc/wsl.conf`) | `postgresql`, `caddy`, `bot.py` e o serviço do agente sobem |
| Serviço do agente | (criado pelo SETUP original) | Recria a sessão `tmux` + `claude --continue` |
| Reforço | `braia-win-guard.timer` (a cada 2 min) | Mantém tudo `enabled` + `cron` ativo |
| `tmux` cai | `healthcheck.sh` original (cron 2 min) | Recria a sessão `tmux` + `claude` |
| Energia | `powercfg` (sem standby/hibernate na tomada) | A máquina não dorme |

> 🔁 **Desligou e ligou de volta → tudo volta sozinho.** Após o **primeiro** login
> do Claude (OAuth fica salvo em `~/.claude`), os reboots seguintes recriam a sessão
> `tmux` autenticada automaticamente.

### Conferir / operar manualmente (opcional)

```powershell
# Estado da tarefa de autostart
Get-ScheduledTask -TaskName "BraiaWin-Autostart" | Select-Object State

# Estado do guard de resiliência dentro do WSL
wsl -d Ubuntu-22.04 -u root -- systemctl status braia-win-guard.timer --no-pager

# Subir manualmente um serviço (se precisar)
wsl -d Ubuntu-22.04 -u root -- systemctl start AGENTE-bot
```

### Resiliência pré-login (headless total, opcional)
A tarefa roda no **logon** do usuário (não exige senha armazenada). Se a máquina
fica num local sem ninguém para logar após o boot, ative o **login automático do
Windows** (`netplwiz` → desmarcar "Os usuários devem digitar...") para que o logon
— e, portanto, o agente — suba sem intervenção.

---

## 6. Solução de problemas

| Sintoma | Causa provável | Solução |
|---|---|---|
| `wsl --install` falha / distro não registra | Virtualização desligada no BIOS | Habilite Intel VT-x / AMD-V (SVM) no BIOS/UEFI |
| `0x80370102` ao iniciar a distro | VirtualMachinePlatform ou Hyper-V desligado | Reabra o instalador; confirme os recursos e reinicie |
| `systemctl` diz "System has not been booted with systemd" | systemd não ativo no WSL | `wsl --update`; confira `/etc/wsl.conf` com `[boot]\nsystemd=true`; `wsl --shutdown` |
| `claude: command not found` | bootstrap não concluiu | Rode de novo: `wsl -d Ubuntu-22.04 -u root -- bash -lic "cd /root/projeto && bash bootstrap.sh"` |
| pgvector/HNSW não cria índice | extensão não instalada | `apt install -y postgresql-16-pgvector` e `CREATE EXTENSION vector;` |
| Login do Claude não abre navegador | sessão headless | Copie a URL impressa e abra manualmente no navegador do Windows |
| Porta 3600 não responde | service do agent-manager parado | `pm2 restart agent-manager` ou rode o SETUP novamente |
| **`wsl --version` não reconhecido** / systemd não sobe | WSL "inbox" antigo (Win10) | O instalador migra com `wsl --update --web-download`; se a Store/web estiver bloqueada por GPO, libere e rode de novo |
| **`wsl --install` falha ao baixar a distro** | Microsoft Store desabilitada (corporativo) | O instalador já tenta `--web-download`; confirme acesso a `github.com`/`raw.githubusercontent.com` |
| **bootstrap falha baixando pacotes** | proxy/firewall corporativo (SSL inspection) | Configure o proxy do sistema; libere `apt.postgresql.org`, `dl.cloudsmith.io`, `registry.npmjs.org`, `nodejs.org` |
| **`.ps1` bloqueado / SmartScreen** | Mark of the Web nos arquivos baixados | O instalador já roda `Unblock-File`; manualmente: `Get-ChildItem -Recurse | Unblock-File` |
| **Sem espaço / VHDX não cresce** | disco C: cheio | Libere ≥ 15 GB; o VHDX do WSL2 + Postgres + Node ocupam vários GB |
| `npm ERR! 404 claude-code@<versão>` | versão pinada/indicada inexistente no npm | O instalador usa `@latest` por padrão; se fixou uma versão via `-ClaudeVersion`, use uma válida |

Logs de diagnóstico:

```powershell
wsl -d Ubuntu-22.04 -u root -- journalctl -u AGENTE-bot -n 100 --no-pager
wsl -d Ubuntu-22.04 -u root -- pm2 logs agent-manager --lines 100
```

---

## 7. Validação pós-instalação

```powershell
# WSL e distro
wsl -l -v

# Versões dentro do Ubuntu
wsl -d Ubuntu-22.04 -u root -- bash -lic "node -v; python3 --version; claude --version; psql --version; caddy version; pm2 -v"

# systemd ativo?
wsl -d Ubuntu-22.04 -u root -- systemctl is-system-running

# pgvector disponível?
wsl -d Ubuntu-22.04 -u root -- sudo -u postgres psql -c "SELECT * FROM pg_available_extensions WHERE name='vector';"

# agent-manager respondendo?
curl http://localhost:3600/health
```

---

## 8. Protocolo de virtualização (detalhe)

WSL2 exige **virtualização de hardware** (Intel VT‑x / AMD‑V/SVM). O instalador a
trata antes de qualquer outra coisa, em três estados:

| Estado detectado | Como é detectado | O que o instalador faz |
|---|---|---|
| **Ativa** | `Win32_ComputerSystem.HypervisorPresent = True` | Segue direto |
| **Habilitada no firmware** | `Win32_Processor.VirtualizationFirmwareEnabled = True` | Liga os recursos de software e segue |
| **Suportada mas DESLIGADA no BIOS** | `VMMonitorModeExtensions = True` e firmware `False` | Instrui (por fabricante) e oferece `shutdown /r /fw` |
| **Não suportada** | `VMMonitorModeExtensions = False` | Aborta com diagnóstico |

### O que é automático e o que não é
- ✅ **Automático:** habilitar os recursos **WSL** e **VirtualMachinePlatform**
  (com reboot + retomada via `RunOnce`).
- ✅ **Automático:** reiniciar **direto na tela da UEFI** (`shutdown /r /fw`) para
  você só dar o *toggle* — e retomar a instalação sozinho quando o Windows voltar.
- ❌ **Não automatizável:** ligar a **VT‑x/AMD‑V no BIOS** por software. É uma
  trava de **firmware** — por segurança, nenhum programa rodando no Windows a
  altera. O instalador te leva até o ponto exato de habilitá-la.

### Instruções por fabricante (atalho do Setup)
| Fabricante | Tecla | Caminho |
|---|---|---|
| Dell | F2 | Virtualization Support → Virtualization → *Enabled* |
| HP | F10 | System Configuration → Virtualization Technology (VTx) → *Enabled* |
| Lenovo | F1 | Security → Virtualization → Intel VT‑x → *Enabled* |
| ASUS | Del / F2 | Advanced → CPU Configuration → Intel VT / **SVM** (AMD) → *Enabled* |
| Gigabyte | Del | Advanced CPU → **SVM Mode** (AMD) / Intel VT → *Enabled* |
| MSI | Del | OC/Advanced → **SVM Mode** (AMD) / Intel Virtualization → *Enabled* |
| ASRock | Del / F2 | Advanced → CPU Config → **SVM** (AMD) / Intel VT → *Enabled* |
| Acer | F2 | Main/Advanced → Virtualization Technology → *Enabled* |

> Em CPUs **AMD**, a opção costuma se chamar **SVM Mode** (não "VT‑x").
> Se a VT estiver ligada mas o WSL falhar com `0x80370102`, verifique também se
> não há conflito com **Memory Integrity / Core Isolation** ou outro hypervisor.
