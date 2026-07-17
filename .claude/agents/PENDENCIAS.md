# PENDÊNCIAS DE INSTALAÇÃO — contrato de preenchimento

Este arquivo é o contrato consumido pelo **comando 2** (vínculo com o Google Cloud do cliente).
Convenção: todo dado da empresa aparece nos agentes como `{{PLACEHOLDER}}` (chaves duplas + nome
em maiúsculas, convenção definida em `SETUP-AGENTE.md`, ETAPA 0). Nenhum valor está preenchido — quem preenche é o comando 2.

Arquivos cobertos: `.claude/agents/isaura.md` e `.claude/agents/angelica.md`.

---

## 1. Placeholders de instalação

### Obrigatórios (o agente não opera sem)

| Placeholder | O que é | Pergunta ao cliente | Exemplo | Obrigatório? | Usado em | Status |
|---|---|---|---|---|---|---|
| `{{DONO}}` | Primeiro nome/apelido do dono | "Qual seu primeiro nome (ou apelido)?" | `Joao` | Sim | isaura.md, angelica.md | ⏳ vazio |
| `{{EMAIL_DONO}}` | E-mail pessoal do dono | "Qual seu e-mail pessoal?" | `joao@meusite.com` | Sim | isaura.md, angelica.md | ⏳ vazio |
| `{{NICHO_DONO}}` | Nome da empresa/escritório | "Qual o nome do seu escritório/empresa?" | `Empresa X Pericias` | Sim | isaura.md, angelica.md | ⏳ vazio |
| `{{EMAIL_INSTITUCIONAL}}` | Caixa institucional que a Isaura opera | "Qual o e-mail institucional do escritório (caixa que a secretária vai operar)?" | `contato@meusite.com` | Sim | isaura.md | ⏳ vazio |
| `{{DRIVE_RAIZ}}` | Caminho raiz da empresa no Google Drive montado | "Qual o caminho da pasta raiz da empresa no seu Google Drive?" | `H:/Meu Drive/00.EMPRESA X` | Sim | isaura.md | ⏳ vazio |
| `{{TAG_AGENDA}}` | Tag em MAIÚSCULAS usada nos títulos de evento da agenda | "Qual sigla identifica sua empresa na agenda (MAIÚSCULAS)?" | `EMPRESAX` | Sim | isaura.md | ⏳ vazio |
| `{{GESTOR}}` | Quem toca a operação no dia a dia (ver regra 3) | "Quem toca a operação no dia a dia é você mesmo ou tem um sócio/gestor? Qual o nome?" | `Joao` (se solo, igual ao dono) | Sim (só Isaura) | isaura.md | ⏳ vazio |
| `{{EMAIL_GESTOR}}` | E-mail do gestor (ver regra 3) | "Qual o e-mail de quem toca a operação?" | `joao@meusite.com` (se solo, igual ao do dono) | Sim (só Isaura) | isaura.md | ⏳ vazio |

### Opcionais / com default

| Placeholder | O que é | Pergunta ao cliente | Exemplo | Obrigatório? | Usado em | Status |
|---|---|---|---|---|---|---|
| `{{DONO_NOME_COMPLETO}}` | Nome completo do dono | "Qual seu nome completo?" | `Joao Silva` | Não (default: valor de DONO) | isaura.md, angelica.md | ⏳ vazio |
| `{{CARGO_DONO}}` | Cargo/título profissional do dono (assinatura) | "Qual seu cargo/título profissional para assinatura?" | `Perito Contabil` | Não | isaura.md | ⏳ vazio |
| `{{EMAIL_GESTOR_ALT}}` | Segundo e-mail do gestor (ver regra 5) | "O gestor tem um segundo e-mail que também deve receber relatórios?" | `joao.alt@meusite.com` | Não (se não houver, o comando 2 remove da whitelist) | isaura.md | ⏳ vazio |
| `{{REGISTRO_CRC_DONO}}` | Registro CRC do perito | "Qual seu registro no CRC (se houver)?" | `CRC-UF 000000/O` | Não | isaura.md | ⏳ vazio |
| `{{REGISTRO_CORECON_DONO}}` | Registro CORECON do perito | "Qual seu registro no CORECON (se houver)?" | `CORECON-UF 0.000/D` | Não | isaura.md | ⏳ vazio |
| `{{PREFIXO_LABEL_GMAIL}}` | Prefixo das labels de triagem no Gmail | "Qual prefixo usar nas labels do Gmail?" | `EmpresaX` | Não (default: `{{TAG_AGENDA}}` em Title Case) | isaura.md | ⏳ vazio |
| `{{DRIVE_LETRA}}` | Letra do drive onde o Google Drive está montado | "Em qual letra o Google Drive está montado no Windows?" | `H:` | Não (default: `H:`) | isaura.md | ⏳ vazio |
| `{{PATH_DATA_AGENTE}}` | Diretório de dados operacionais do agente | "Onde ficam os arquivos de dados do agente?" | `/opt/braia/data` | Não (default: `/opt/braia/data`) | isaura.md | ⏳ vazio |
| `{{DRIVE_FOLDER_ID_MODELOS}}` | Folder ID (Drive) da pasta ZZ - MODELOS | "Qual o ID da pasta de modelos de proposta no Drive?" | `1AbC...xyz` | Não | isaura.md | ⏳ vazio |
| `{{USUARIO_WINDOWS}}` | Usuário do Windows da máquina da instalação | "Qual o nome de usuário do Windows nessa máquina?" | `joao` | Não | isaura.md | ⏳ vazio |
| `{{GATEWAY_PAGAMENTO}}` | Gateway de cobrança usado pelo escritório | "Qual gateway de pagamento você usa (se usar)?" | `Gateway X` | Não | isaura.md | ⏳ vazio |
| `{{CRM_NOME}}` | Nome do CRM do escritório | "Qual CRM você usa (se usar)?" | `Meu CRM` | Não | isaura.md | ⏳ vazio |

### Placeholders de runtime (NÃO preencher na instalação)

Preenchidos **por proposta**, em tempo de execução, pela própria Isaura (Skill 5). O comando 2 NÃO toca neles.
São 14 ocorrências na `isaura.md`, 10 nomes:

`{{CLIENTE}}`, `{{ADVERSARIO}}`, `{{QTD_CONTRATOS}}`, `{{VALOR_PARECER}}`, `{{VALOR_COMBO}}`,
`{{VALOR_AVULSO}}`, `{{VALOR_PIX}}`, `{{VALOR_TOTAL}}`, `{{VALOR_PARCELA}}`, `{{PARCELAS}}`

---

## 2. Contrato em JSON (para o comando 2)

```json
[
  {"placeholder": "{{DONO}}", "obrigatorio": true, "default": null, "pergunta": "Qual seu primeiro nome (ou apelido)?", "arquivos": ["isaura.md", "angelica.md"], "valor": null},
  {"placeholder": "{{EMAIL_DONO}}", "obrigatorio": true, "default": null, "pergunta": "Qual seu e-mail pessoal?", "arquivos": ["isaura.md", "angelica.md"], "valor": null},
  {"placeholder": "{{NICHO_DONO}}", "obrigatorio": true, "default": null, "pergunta": "Qual o nome do seu escritorio/empresa?", "arquivos": ["isaura.md", "angelica.md"], "valor": null},
  {"placeholder": "{{EMAIL_INSTITUCIONAL}}", "obrigatorio": true, "default": null, "pergunta": "Qual o e-mail institucional do escritorio?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{DRIVE_RAIZ}}", "obrigatorio": true, "default": null, "pergunta": "Qual o caminho da pasta raiz da empresa no Google Drive?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{TAG_AGENDA}}", "obrigatorio": true, "default": null, "pergunta": "Qual sigla identifica sua empresa na agenda (MAIUSCULAS)?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{GESTOR}}", "obrigatorio": true, "default": "mesmo valor de {{DONO}} se o cliente for solo", "pergunta": "Quem toca a operacao no dia a dia e voce mesmo ou tem um socio/gestor? Qual o nome?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{EMAIL_GESTOR}}", "obrigatorio": true, "default": "mesmo valor de {{EMAIL_DONO}} se o cliente for solo", "pergunta": "Qual o e-mail de quem toca a operacao?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{DONO_NOME_COMPLETO}}", "obrigatorio": false, "default": "valor de {{DONO}}", "pergunta": "Qual seu nome completo?", "arquivos": ["isaura.md", "angelica.md"], "valor": null},
  {"placeholder": "{{CARGO_DONO}}", "obrigatorio": false, "default": null, "pergunta": "Qual seu cargo/titulo profissional para assinatura?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{EMAIL_GESTOR_ALT}}", "obrigatorio": false, "default": null, "pergunta": "O gestor tem um segundo e-mail que tambem deve receber relatorios?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{REGISTRO_CRC_DONO}}", "obrigatorio": false, "default": null, "pergunta": "Qual seu registro no CRC (se houver)?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{REGISTRO_CORECON_DONO}}", "obrigatorio": false, "default": null, "pergunta": "Qual seu registro no CORECON (se houver)?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{PREFIXO_LABEL_GMAIL}}", "obrigatorio": false, "default": "{{TAG_AGENDA}} em Title Case", "pergunta": "Qual prefixo usar nas labels do Gmail?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{DRIVE_LETRA}}", "obrigatorio": false, "default": "H:", "pergunta": "Em qual letra o Google Drive esta montado no Windows?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{PATH_DATA_AGENTE}}", "obrigatorio": false, "default": "/opt/braia/data", "pergunta": "Onde ficam os arquivos de dados do agente?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{DRIVE_FOLDER_ID_MODELOS}}", "obrigatorio": false, "default": null, "pergunta": "Qual o ID da pasta de modelos de proposta no Drive?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{USUARIO_WINDOWS}}", "obrigatorio": false, "default": null, "pergunta": "Qual o nome de usuario do Windows nessa maquina?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{GATEWAY_PAGAMENTO}}", "obrigatorio": false, "default": null, "pergunta": "Qual gateway de pagamento voce usa (se usar)?", "arquivos": ["isaura.md"], "valor": null},
  {"placeholder": "{{CRM_NOME}}", "obrigatorio": false, "default": null, "pergunta": "Qual CRM voce usa (se usar)?", "arquivos": ["isaura.md"], "valor": null}
]
```

---

## 3. Regras do contrato

1. **A Angelica só usa 4 placeholders:** `{{DONO}}`, `{{DONO_NOME_COMPLETO}}`, `{{EMAIL_DONO}}` e `{{NICHO_DONO}}`. Todo o resto é da Isaura.
2. **Não existem** neste contrato: `GESTOR_NOME_COMPLETO`, `GERENTE`, `CNPJ_DONO`, `DRIVE_RAIZ_AGENTES`. Os três primeiros colapsaram na sanitização (o cliente é uma pessoa só; a Angelica não precisa de CNPJ); o último virou caminho local fixo (`.claude/`).
3. **O `{{GESTOR}}` só existe na Isaura, e por um motivo:** o SOP dela distingue quem é notificado antes e depois do pagamento. A Angelica não usa. O comando 2 pergunta uma vez: _"quem toca a operação no dia a dia é você mesmo ou tem um sócio/gestor?"_ Se for solo (caso normal — o perito trabalha sozinho), `{{GESTOR}}` e `{{EMAIL_GESTOR}}` recebem o **mesmo valor** de `{{DONO}}`/`{{EMAIL_DONO}}` e a distinção colapsa sem quebrar regra nenhuma.
4. **Um placeholder, um valor, os dois arquivos.** O que aparece nos dois (`{{DONO}}`, `{{DONO_NOME_COMPLETO}}`, `{{EMAIL_DONO}}`, `{{NICHO_DONO}}`) é preenchido uma vez e aplicado nos dois.
5. **Whitelist de e-mail:** se o cliente tiver **um** destinatário só, o comando 2 **remove** `{{EMAIL_GESTOR_ALT}}` da whitelist da regra crítica de e-mail da Isaura — não deixa placeholder órfão dentro de uma regra de segurança.

---

## 4. Pendências estruturais

### Agentes fantasma (invocados pela Isaura, não existem nesta instalação)

A instalação tem 5 agentes: `isaura`, `angelica`, `paulo-dev`, `juliana-ops`, `rebeca-pericia`.
A Isaura referencia 9 que **não existem**. Os fluxos foram mantidos com marca `⏳ PENDENTE` + trava (a Isaura para e pergunta):

1. `caio` — **destaque**: gera o link de pagamento **e** é o outro autorizado a enviar e-mail; a regra crítica de e-mail da Isaura depende dele
2. `jonatas` — pipeline técnico trabalhista (PJe-Calc, dossiê)
3. `igor` — prestação de contas
4. `daniel-pereira` — perícia bancária (veículo, consignado, FIES etc.)
5. `luciana-crosara` — construtora/FGR/MQJS
6. `perito-pasep` — PASEP
7. `perito-sfh` — SFH/financiamento imobiliário
8. `tati` — CAPAG/PGFN
9. `cristina` — apuração de haveres

Os fantasmas da Angelica (`Ana`, `Caroline`, `agents/ana.md`) foram eliminados na sanitização (colapsaram em `juliana-ops`, `isaura` ou no dono).

### Arquivos referenciados que não existem no repo

- `data/regras_empresa.md` (template criado em `data/regras_empresa.template.md`)
- `.claude/agents/EQUIPE.md`
- `.claude/agents/AGENTS-REGISTRY.md`
- `.claude/agents/politica-envio-email.md`
- `{{PATH_DATA_AGENTE}}/tabela-precos-servicos.md`, `catalogo-propostas-drive.md`, `sop-fluxo-atendimento.md`, `equipe-peritos.md`, `template-email-proposta.md`
- `src/skills/prestacao_contas_judicial/SKILL.md`
- `.claude/skills/` (criado no primeiro uso — convenção do Claude Code)

### Buracos de produto (encontrados e NÃO corrigidos — trabalho de outro comando)

- **Ciclo de contratação incompleto:** a Angelica registra o agente novo só no `AGENTS-REGISTRY.md`; a lista de ativação real é o `CLAUDE.md` (`### Quem faz o que:`), que ela não atualiza. Agente fora dessa lista não é acionado por ninguém.
- **`paulo-dev` fora do alcance da Angelica:** existe no disco e no `CLAUDE.md`, mas tinha zero menções na Angelica antes da sanitização e foi mantido fora do roster dela (o comando de sanitização proíbe adicioná-lo — "era 0 antes, continua 0"). O roster da Angelica lista 4 dos 5 agentes reais. Resolver junto com o ciclo de registro.
