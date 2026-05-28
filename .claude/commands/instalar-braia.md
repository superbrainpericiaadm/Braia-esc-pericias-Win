---
description: Instala a Braia (agente Claude + Telegram) neste Windows via WSL2, pedindo só 2 tokens
---

# Comando: Instalar a Braia neste Windows

Você é o orquestrador de uma instalação **autônoma e completa** da **Braia** —
um agente que combina o **Claude Code** com um **bot do Telegram**, rodando 24/7.

**Repositório:** https://github.com/superbrainpericiaadm/Braia-esc-pericias-Win

## Regra de ouro (inserção mínima)
Peça ao usuário **APENAS TRÊS COISAS**, e nada além:
1. O **token do bot do Telegram** (o código que o `@BotFather` entrega).
2. O **token/login do Claude** (API key `sk-ant-...` **ou** login da conta Pro/Max).
3. A **chave da OpenAI** (`sk-...`) — **destrava a memória semântica (embeddings `text-embedding-3-small`) E o áudio (Whisper)**. É **opcional**: sem ela a memória funciona em modo **full-text** (busca por palavras + raciocínio do Claude, sem custo/sem RAM extra) e o áudio fica desligado. **Recomende fortemente** preencher — é a chave que liga a busca por significado.

**Todo o resto você resolve sozinho** — gera senhas, define nomes, detecta o
ID do Telegram automaticamente, constrói a memória (pgvector + full-text). Nunca
pergunte algo que dê para assumir um padrão ou descobrir sozinho. Nunca imprima
segredos por extenso.

## Passo a passo que você deve executar

### 1. Pré-requisitos
- Confirme que é **Windows 10 (build ≥ 19041) ou Windows 11**.
- Confirme que consegue rodar **PowerShell como Administrador**. Se não estiver
  como Administrador, peça ao usuário para reabrir o Claude Code/terminal como
  Administrador e rodar `/instalar-braia` de novo.

### 2. Obter o repositório localmente
- Se a pasta atual já tiver o `INSTALL-WINDOWS.ps1`, use-a.
- Senão, clone (o repo é público):
  ```powershell
  git clone https://github.com/superbrainpericiaadm/Braia-esc-pericias-Win "$env:USERPROFILE\Braia-esc-pericias-Win"
  ```
  e entre na pasta.

### 3. Rodar o instalador (faz TUDO sozinho)
```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALL-WINDOWS.ps1
```
Ele executa: protocolo de virtualização, WSL2 + Ubuntu 22.04, systemd, bootstrap
(PostgreSQL 16 + pgvector, Caddy, Node 22, pm2, **Claude Code @latest**),
resiliência 24/7 (autostart + guard) e ajuste de energia.

- **Se ele REINICIAR o Windows** (para ligar os recursos do WSL): é normal e
  esperado. Ele **retoma sozinho** após o reboot (RunOnce). Avise o usuário e,
  quando a máquina voltar, **rode `/instalar-braia` de novo** para continuar daqui.
- **Se a virtualização estiver desligada no BIOS:** o instalador explica e oferece
  reiniciar na UEFI. Esse passo é físico (o usuário liga a VT no BIOS). Aguarde.

### 4. Conferir o ambiente
```powershell
wsl -d Ubuntu-22.04 -u root -- bash -lic "claude --version; psql --version; systemctl is-system-running"
```
Só continue quando o ambiente estiver pronto.

### 5. Credencial do Claude (pergunte UMA vez)
Pergunte: **"Cole seu token do Claude (API key `sk-ant-...`) ou digite `login` para usar sua conta Pro/Max."**
- Se for **API key**: grave `ANTHROPIC_API_KEY` no `.env` do agente e no ambiente
  do serviço, para o Claude rodar sem navegador.
- Se for **login**: rode `wsl -d Ubuntu-22.04 -u root -- claude auth login --claudeai`,
  repasse a URL ao usuário e peça o código que ele colar de volta.

### 6. Token do Telegram + ID automático (pergunte UMA vez)
- Pergunte: **"Cole o token do seu bot do Telegram (do @BotFather)."**
- **Descubra o ID do dono automaticamente:** peça ao usuário para abrir o Telegram
  e mandar **`/start`** (ou qualquer mensagem) ao bot. Então chame:
  `https://api.telegram.org/bot<TOKEN>/getUpdates` e leia
  `result[].message.from.id`. Use esse número como `ALLOWED_USERS`. Confirme o ID
  com o usuário em uma linha.

### 6.5. Chave da OpenAI (pergunte UMA vez, opcional)
- Pergunte: **"Cole sua chave da OpenAI (`sk-...`) para ligar a memória semântica e o áudio. Se não tiver agora, pode pular e preencher depois."**
- Guarde para gravar nos `.env` no passo de memória (7.5). Se o usuário pular, a
  memória funciona em **full-text** e o áudio fica desligado — sem erro.

### 7. Rodar o SETUP você mesmo (NÃO peça para o usuário fazer)
Execute os passos dentro do WSL deployando os **arquivos do repo** (não os genéricos),
aplicando estes padrões automaticamente (sem perguntar):
- `AGENTE_NAME=braia`, `OWNER_NAME=Braia`, `TMUX_SESSION=braia`.
- Gere uma **senha forte aleatória** para o PostgreSQL.
- Preencha os `.env` (`/opt/braia/.env` e `/opt/braia-bot/.env`) com:
  `TELEGRAM_BOT_TOKEN`, `ALLOWED_USERS` (o ID detectado), `DATABASE_URL` e a
  credencial do Claude.
- Crie usuário/banco no PostgreSQL + extensão `vector` + índices HNSW a partir de
  `database/schema.sql` (aplique via **stdin**: `psql < schema.sql`, pois o user
  `postgres` não lê `/root`). Use o role **`n8n`** e o banco **`braia_memory`**.
- Use os 3 agentes em `.claude/agents/` (`isaura`, `angelica`, `paulo-dev`) e o
  `CLAUDE.md` como a persona da **Braia**.

> **Gotchas obrigatórios (senão quebra):**
> - O agente roda como usuário **não-root** `braia` (o `claude` recusa `--dangerously-skip-permissions` como root). Mas o `node`/`claude` ficam em `/root/.nvm` (700) → **copie para `/opt/node22` e crie symlinks em `/usr/local/bin`** (node, npm, npx, claude, pm2).
> - **Pré-complete o onboarding do `claude` para o `braia`:** `~/.claude.json` → `{"hasCompletedOnboarding":true,"theme":"dark"}`; aceite o trust de `/opt/braia` 1x; `~/.claude/settings.json` → `{"skipDangerousModePermissionPrompt":true}`. Autentique via `CLAUDE_CODE_OAUTH_TOKEN` no `.env`.
> - **`bot.py`**: troque o `BOT_DIR` mac por `/opt/braia-bot` e substitua `{{TELEGRAM_USER_ID_DONO}}` pelo chat_id (aparece como código Python cru). `py_compile` para validar.
> - **Serviços** (nomes que o `healthcheck.sh` exige): `braia-telegram-bot` (bot) e `braia-agent` (tmux+claude). Launcher: loop com `claude --continue --dangerously-skip-permissions || claude --dangerously-skip-permissions` (o `--continue` sai na 1ª vez).

### 7.5. Memória (pgvector + full-text) — construa na hora
Rode o configurador de memória (constrói o consolidador, a busca e os índices):
```bash
bash /root/projeto/memory-service/setup-memory.sh "<CHAVE_OPENAI_OU_VAZIO>"
```
Isso: aplica os índices full-text, instala `consolidate.py` (cron 2 min, grava as
conversas no `conversation_history`) e `search.py` (busca que o `CLAUDE.md` chama no
boot). **Com** a chave OpenAI → busca **vetorial** por significado (+ áudio Whisper
ligado); **sem** chave → **full-text**. Não instala modelo local (zero RAM extra).

### 8. Validar de ponta a ponta
- Peça ao usuário para mandar uma mensagem ao bot no Telegram e confirme que a
  Braia **responde**.
- Mostre: `wsl -d Ubuntu-22.04 -u root -- systemctl is-active braia-bot` e
  `curl http://localhost:3600/health`.

### 9. Relatório final
Resuma: o que foi instalado, que a **resiliência está ativa** (volta sozinho após
reiniciar) e que as **únicas** inserções manuais foram os 2 tokens.

## Lembretes
- Pergunte SÓ os 3 itens (Telegram, Claude, OpenAI). A chave OpenAI é opcional mas recomendada (memória vetorial + áudio). Defaulte/auto-detecte todo o resto.
- Seja explícito sobre o comportamento de reboot.
- Nunca exponha segredos por extenso nas mensagens.
- Ao final, confirme: Braia responde no Telegram **e** a memória está gravando (`conversation_history` crescendo) — com chave, em modo vetorial; sem chave, full-text.
