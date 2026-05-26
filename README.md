# Braia Win — Agente Claude + Telegram (porte Windows via WSL2)

> Porte para **Windows** do projeto Linux original
> [`Braia-esc-pericias-CLI`](https://github.com/superbrainpericiaadm/Braia-esc-pericias-CLI).
> **Estratégia adotada: WSL2** (Ubuntu 22.04 LTS dentro do Windows).
> A lógica de negócio do projeto original **não foi alterada**.

---

## 🤖 Instalação assistida pelo Claude Code (mais fácil)

Deixe o **Claude Code instalar tudo para você** — você só digita **2 tokens**
(o do **bot do Telegram** e o do **Claude**). Abra o Claude Code na pasta do repo
(como Administrador) e use:

```
/instalar-braia
```

Passo a passo completo e o comando pronto para colar:
**[`INSTALAR-VIA-CLAUDE-CODE.md`](./INSTALAR-VIA-CLAUDE-CODE.md)**.

---

## ⚡ Instalação manual no Windows

**Pré-requisitos:** Windows 10 (build 19041 / versão 2004) ou Windows 11, com
virtualização habilitada no BIOS (Intel VT-x / AMD-V) e privilégios de
administrador.

1. Abra o **PowerShell como Administrador** na pasta deste repositório.
2. Rode:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\INSTALL-WINDOWS.ps1
   ```

   > Se a política de execução bloquear, dê duplo-clique em **`INSTALL-WINDOWS.bat`**.

3. Se for a primeira vez que você habilita o WSL, o instalador vai **pedir um
   reboot** e **retomar sozinho** após reiniciar.
4. Ao final, faça os **2 passos interativos** que o instalador imprime
   (login do Claude + disparo do SETUP). Veja detalhes em
   [`README-WSL2.md`](./README-WSL2.md).

> ⏱️ **Tempo realista:** 15–40 min na primeira execução (download de Ubuntu,
> Node, PostgreSQL, pgvector, Caddy, Claude CLI), fora o reboot. Prioridade é
> **funcionamento perfeito**, não velocidade.

### Acesso depois de instalado
- Painel `agent-manager`: **http://localhost:3600**
- Arquivos do Linux pelo Explorer do Windows: `\\wsl$\Ubuntu-22.04\root\projeto`
- Abrir o ambiente: `wsl -d Ubuntu-22.04 -u root`

### Resiliência — já vem 100% fechada (por padrão)
Você **não precisa configurar nada** para o agente sobreviver a desligamentos.
O instalador deixa pronto:
- **Autostart:** tarefa `BraiaWin-Autostart` sobe o WSL2 no **boot e no logon**.
- **systemd habilitado:** ao subir a distro, ele sobe `postgresql`, `caddy`,
  o daemon `bot.py` e o serviço do agente (que **recria a sessão `tmux` + `claude`**).
- **Guard systemd:** um timer idempotente (a cada 2 min) garante que tudo fique
  `enabled` e mantém o `cron` ativo (o `healthcheck` original recria o `tmux` se cair).
- **Energia:** a máquina **não suspende/hiberna** quando ligada na tomada.

> 🔁 **Cenário "cliente desligou e ligou de volta":** WSL2 → systemd → serviços →
> `tmux` → `claude` voltam **sozinhos**, sem intervenção.
> Para desligar algum desses comportamentos: `-SemAutostart`, `-SemResiliencia`,
> `-SemAjusteEnergia`.

### Virtualização — detecção e ativação automáticas (com limite honesto)
O instalador roda um **protocolo de virtualização** antes de tudo:
- **Liga sozinho** os recursos de software (`WSL` + `VirtualMachinePlatform`) e reinicia
  com retomada automática.
- Se a **VT‑x/AMD‑V estiver desligada no BIOS**, detecta o fabricante da placa, mostra
  a tecla exata do Setup e **oferece reiniciar direto na UEFI** (`shutdown /r /fw`).
- Se a **CPU não suportar** virtualização, aborta com diagnóstico claro.

> ⚠️ A virtualização de **hardware** é um interruptor de **firmware (BIOS/UEFI)** —
> nenhum software a liga por dentro do Windows. O instalador automatiza tudo que é
> possível e te leva direto até o ponto de habilitá-la.

---

## Por que WSL2 (e não Windows nativo)?

| Bloqueador concreto no projeto | Consequência no Windows nativo | Como o WSL2 resolve |
|---|---|---|
| Ponte bot → Claude usa `tmux send-keys` | `tmux` **não existe** no Windows; exigiria reescrever o IPC (proibido alterar a lógica) | `tmux` é nativo no Ubuntu |
| Memória vetorial PostgreSQL 16 + **pgvector** | `pgvector` exige compilação MSVC no Windows | `apt install postgresql-16-pgvector` |
| Serviços `systemd`, `cron`, `nvm`, Caddy, ffmpeg | Inexistentes/divergentes no Windows | Todos nativos no Ubuntu |
| `bootstrap.sh` já tem ramo **Ubuntu 22+** | — | Roda praticamente intacto |

A análise completa das 4 estratégias está em
[`ESTRATEGIA-ESCOLHIDA.md`](./ESTRATEGIA-ESCOLHIDA.md).
O relatório de adaptação está em
[`RELATORIO-ADAPTACAO.md`](./RELATORIO-ADAPTACAO.md).

---

## Como distribuir / instalar no cliente

Este repositório é **privado e autocontido**. O fluxo é:
1. Você **clona ou baixa o ZIP** deste repositório (você tem acesso) e leva a
   pasta para o computador do cliente (pen drive, OneDrive, `git clone`, etc.).
2. No cliente, roda `INSTALL-WINDOWS.ps1` como Administrador.
3. O instalador **copia os arquivos locais** para dentro do WSL2 e roda o
   `bootstrap.sh` próprio — **não baixa nada deste GitHub** (por isso funciona
   mesmo sendo um repositório privado, sem precisar de credencial no cliente).

## O que este repositório contém

É **autocontido**: traz tanto a camada de orquestração Windows quanto a carga da
Braia (app + persona + 3 agentes). Os `.sh` permanecem nativos (sem conversão).

**Camada Windows (instalação):**

| Arquivo | Função |
|---|---|
| `INSTALL-WINDOWS.ps1` / `.bat` | Ponto de entrada (+ fallback p/ PowerShell restrito) |
| `INSTALL-WSL2.ps1` | Instalador real: virtualização, WSL2, Ubuntu, cópia local, bootstrap, resiliência |
| `start-braia.ps1` | Chamado pela tarefa de autostart; sobe o WSL2 no boot/logon |
| `wsl-resilience/` | Guard `systemd` (`.sh` + `.service` + `.timer`) + `install-resilience.sh` |
| `README.md` / `README-WSL2.md` | Este arquivo / guia detalhado + troubleshooting |
| `ESTRATEGIA-ESCOLHIDA.md` / `RELATORIO-ADAPTACAO.md` | Análise das estratégias / relatório |
| `.gitattributes` / `.gitignore` | LF nos scripts Linux; ignora segredos/estado |

**Carga da Braia (deploy do agente):**

| Arquivo | Função |
|---|---|
| `bootstrap.sh` | Instalador Linux **self-contained** (patcheado: cópia local + Claude `@latest`) |
| `CLAUDE.md` | Persona/configuração da **Braia** (agente principal) |
| `.claude/agents/` | **3 agentes**: `isaura`, `angelica`, `paulo-dev` |
| `SETUP-AGENTE.md` | Roteiro que o Claude executa para montar o agente |
| `.env.example` | Modelo de variáveis (token Telegram, DB, áudio…) |
| `braia-bot/` | `bot.py` (daemon Telegram) + `healthcheck.sh` |
| `database/` | `schema.sql` (PostgreSQL + pgvector) |

---

## O que é o Braia (resumo do projeto original)

Agente **Claude Code + Telegram** que roda 24/7. Um daemon Python (`bot.py`)
recebe mensagens do Telegram (long-polling), grava em `inbox/` e injeta comandos
no Claude via `tmux send-keys`. O Claude roda numa sessão `tmux` persistente.
Memória vetorial em PostgreSQL + pgvector; `agent-manager` (FastAPI) sob PM2
atrás do Caddy; healthcheck por `cron` com restart via `systemctl`. Áudio
bidirecional com ffmpeg + Whisper (STT) + ElevenLabs (TTS).
