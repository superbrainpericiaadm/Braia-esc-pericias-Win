# 🤖 Instalar a Braia pelo Claude Code (assistido, quase sem digitar)

Este guia faz o **Claude Code instalar a Braia para você** — um agente que junta
o **Claude** a um **bot do Telegram**, rodando 24/7 no Windows (via WSL2).

> **Repositório:** https://github.com/superbrainpericiaadm/Braia-esc-pericias-Win

## ✋ O que VOCÊ vai precisar digitar (só isto)
1. **Token do bot do Telegram** — crie um bot no **[@BotFather](https://t.me/BotFather)**
   (`/newbot`) e copie o token.
2. **Token/login do Claude** — uma **API key** `sk-ant-...` **ou** o **login**
   da sua conta **Pro/Max**.

Todo o resto (WSL2, Ubuntu, banco, serviços, resiliência, ID do Telegram, senhas)
o Claude Code resolve **sozinho**.

---

## ▶️ Como usar

### Opção A — Slash command (recomendado)
1. Abra o **Claude Code** numa pasta qualquer (de preferência como **Administrador**).
2. Clone o repositório e abra-o:
   ```powershell
   git clone https://github.com/superbrainpericiaadm/Braia-esc-pericias-Win
   cd Braia-esc-pericias-Win
   ```
3. No Claude Code, digite:
   ```
   /instalar-braia
   ```
4. Responda **só** quando ele pedir o **token do Telegram** e o **token/login do Claude**.

### Opção B — Colar o comando (se não quiser usar slash command)
Abra o **Claude Code como Administrador** e **cole exatamente isto**:

```
Instale a Braia (agente Claude + Telegram) neste Windows, de forma autônoma e
completa, a partir do repositório
https://github.com/superbrainpericiaadm/Braia-esc-pericias-Win

Regra: peça-me APENAS DUAS coisas — (1) o token do bot do Telegram e (2) meu
token/login do Claude. Defaulte e auto-detecte todo o resto. Faça assim:

1. Confirme Windows 10/11 e PowerShell como Administrador.
2. Clone o repositório (é público) em %USERPROFILE%\Braia-esc-pericias-Win e entre nele.
3. Rode:  powershell -ExecutionPolicy Bypass -File .\INSTALL-WINDOWS.ps1
   (faz virtualização, WSL2 + Ubuntu 22.04, systemd, bootstrap com PostgreSQL+
   pgvector+Caddy+Node+pm2+Claude Code @latest, resiliência 24/7 e energia).
   Se reiniciar a máquina, ele retoma sozinho; quando voltar, continue daqui.
   Se a virtualização estiver off no BIOS, ele me orienta a ligar.
4. Confira: wsl -d Ubuntu-22.04 -u root -- bash -lic "claude --version; psql --version; systemctl is-system-running"
5. Pergunte meu token do Claude (API key sk-ant-... ou 'login' p/ Pro/Max) e configure.
6. Pergunte o token do meu bot do Telegram. Para o ID permitido, peça-me para mandar
   /start ao bot e descubra meu chat_id via https://api.telegram.org/bot<TOKEN>/getUpdates.
7. Leia /root/projeto/SETUP-AGENTE.md e execute TODOS os passos no WSL, com padrões
   automáticos (AGENTE_NAME=braia, OWNER_NAME=Braia, senha do Postgres aleatória),
   preenchendo os .env, criando banco+pgvector+índices, serviços systemd e a sessão
   tmux com claude --continue, usando os 5 agentes (.claude/agents) e o CLAUDE.md.
8. Valide: peça-me para mandar mensagem ao bot e confirme que a Braia responde
   (systemctl is-active braia-bot, curl http://localhost:3600/health).
9. Me dê um relatório final. Nunca exponha segredos por extenso.
```

---

## ⏱️ O que esperar
- **Tempo:** ~15–40 min na primeira vez (+ 1 reboot, automático).
- **Reboot:** se aparecer, é o WSL sendo ligado — a instalação **retoma sozinha**.
- **Ao final:** a Braia responde no Telegram e **volta sozinha** se a máquina
  desligar e ligar de novo (resiliência já configurada).

## ❓ Dúvidas comuns
- **Não tenho conta Pro/Max** → use uma **API key** `sk-ant-...` (consumo é cobrado por uso).
- **Virtualização desligada** → o instalador detecta e te leva direto à UEFI para ligar.
- **Detalhes técnicos / problemas** → veja [`README-WSL2.md`](./README-WSL2.md).
