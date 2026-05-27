#Requires -Version 5.1
<#
============================================================================
 INSTALL-WSL2.ps1 - Instalador autonomo do agente Braia para Windows (WSL2)
============================================================================
 Porte Windows da versao Linux:
   https://github.com/superbrainpericiaadm/Braia-esc-pericias-CLI

 ESTRATEGIA: WSL2 (Ubuntu 22.04 LTS dentro do Windows).
 Motivo: a ponte bot -> Claude usa `tmux send-keys` (sem equivalente no
 Windows nativo) e o pgvector exige compilacao MSVC no Windows; em WSL2 o
 bootstrap.sh original (que ja tem ramo Ubuntu) roda praticamente intacto.

 FILOSOFIA: "comando preguicoso". O operador da UM comando e fornece apenas
 dados pontuais (login do Claude, token do Telegram). TODA a estrutura ja
 vem 100% fechada por PADRAO - inclusive a resiliencia: se a maquina
 desligar e ligar de novo, WSL2 + systemd + tmux + claude voltam sozinhos.

 ETAPAS (idempotentes e retomaveis apos reboot):
   0. Auto-elevacao para administrador.
   1. Build do Windows (>= 19041 / 2004).
   2. PROTOCOLO DE VIRTUALIZACAO:
        - detecta VT-x/AMD-V (hardware + firmware + hypervisor);
        - liga os recursos de software (WSL + VirtualMachinePlatform);
        - se VT estiver DESLIGADA no BIOS: detecta o fabricante, instrui e
          oferece reiniciar direto na UEFI (shutdown /r /fw);
        - se a CPU nao suportar: aborta com diagnostico.
   3. Kernel WSL (`wsl --update`) + WSL2 como padrao.
   4. Instala Ubuntu 22.04 LTS (sem OOBE interativo).
   5. Habilita systemd dentro do WSL + checa o DNS de saida (login/Telegram).
   6. Copia ESTE repositorio (LOCAL, self-contained) para /root/projeto no WSL.
   7. Roda o bootstrap.sh proprio (Node 22, Python, ffmpeg, PostgreSQL 16 +
      pgvector, Caddy, pm2, Claude Code @latest; ver -ClaudeVersion).
   8. RESILIENCIA (Linux): instala o guard systemd (enable de tudo + cron).
   9. ENERGIA (Windows): impede sleep/hibernate na tomada.
  10. RESILIENCIA (Windows): vmIdleTimeout + ANCORA + tarefas OCULTAS (boot/keepalive).
  11. Imprime os 2 passos interativos finais (login + SETUP).

 NAO converte .sh para .ps1. NAO altera a logica de negocio do projeto.
============================================================================
#>
[CmdletBinding()]
param(
    [string] $Distro       = "Ubuntu-22.04",
    [string] $RepoUrl      = "https://github.com/superbrainpericiaadm/Braia-esc-pericias-Win",  # referencia (repo PRIVADO; a instalacao usa os arquivos LOCAIS, nao clona)
    [string] $CloneDir     = "/root/projeto",
    [string] $ClaudeVersion = "latest",  # sobrepoe o pin antigo do bootstrap; pode fixar (ex.: "2.1.150")
    [switch] $PularBootstrap,    # pula etapas 6/7 (so prepara o WSL2)
    [switch] $SemResiliencia,    # opt-out: nao instala o guard systemd (etapa 8)
    [switch] $SemAjusteEnergia,  # opt-out: nao mexe na energia do Windows (etapa 9)
    [switch] $SemAjusteDNS,      # opt-out: nao testa/corrige o DNS de saida da WSL (etapa 5.5)
    [switch] $SemAutostart       # opt-out: nao cria as tarefas de resiliencia Windows (etapa 10)
)

$ErrorActionPreference = "Stop"
$StateDir  = Join-Path $env:ProgramData "BraiaWin"
$StateFile = Join-Path $StateDir "install-state.txt"

# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------
function Write-Step  ($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok    ($m) { Write-Host "    [OK] $m"  -ForegroundColor Green }
function Write-Warn2 ($m) { Write-Host "    [!]  $m"  -ForegroundColor Yellow }
function Write-Err2  ($m) { Write-Host "    [X]  $m"  -ForegroundColor Red }

# --------------------------------------------------------------------------
# Util: path Windows -> path WSL (/mnt/c/...)
# --------------------------------------------------------------------------
function ConvertTo-WslPath([string]$winPath) {
    $p = $winPath -replace '\\','/'
    if ($p -match '^([A-Za-z]):(.*)$') { return "/mnt/" + $matches[1].ToLower() + $matches[2] }
    return $p
}

# --------------------------------------------------------------------------
# 0) Administrador (auto-elevacao)
# --------------------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin)) {
    Write-Warn2 "Sem privilegios de administrador. Reabrindo elevado..."
    $argList = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Value -is [switch]) { if ($kv.Value) { $argList += "-$($kv.Key)" } }
        else { $argList += @("-$($kv.Key)", "`"$($kv.Value)`"") }
    }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    exit
}
if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force $StateDir | Out-Null }

Write-Host "============================================================" -ForegroundColor White
Write-Host " INSTALADOR BRAIA WIN (WSL2) - autonomo, com resiliencia"     -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

# --------------------------------------------------------------------------
# 1) Build do Windows
# --------------------------------------------------------------------------
Write-Step "Verificando a versao do Windows"
$build = [int][System.Environment]::OSVersion.Version.Build
$ed = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).EditionID
Write-Host "    Build: $build   Edicao: $ed"
if ($build -lt 19041) {
    Write-Err2 "WSL2 exige Windows 10 build 19041 (2004) ou superior, ou Windows 11."
    exit 1
}
Write-Ok "Build compativel com WSL2."

# --------------------------------------------------------------------------
# 1.5) Pre-checagens (desbloqueio MOTW, disco, conectividade)
# --------------------------------------------------------------------------
Write-Step "Pre-checagens do ambiente"

# Desbloqueia arquivos baixados (Mark of the Web): evita SmartScreen/prompt no .ps1
try {
    Get-ChildItem -Path $PSScriptRoot -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
    Write-Ok "Arquivos do repositorio desbloqueados (Mark of the Web)."
} catch { Write-Warn2 "Nao foi possivel desbloquear arquivos (MOTW)." }

# Espaco em disco em C: (o VHDX do WSL2 cresce varios GB)
try {
    $freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
    Write-Host "    Espaco livre em C: $freeGB GB"
    if ($freeGB -lt 15) { Write-Warn2 "Pouco espaco livre (< 15 GB). Ubuntu + PostgreSQL + Node podem nao caber." }
    else { Write-Ok "Espaco em disco suficiente." }
} catch {}

# Conectividade aos hosts criticos do bootstrap (aviso; proxy pode liberar via curl)
function Test-Host443 ($h) {
    try {
        $c = New-Object Net.Sockets.TcpClient
        $ok = $c.BeginConnect($h,443,$null,$null).AsyncWaitHandle.WaitOne(2500)
        $c.Close(); return $ok
    } catch { return $false }
}
$inacessiveis = @()
foreach ($h in @("github.com","raw.githubusercontent.com","registry.npmjs.org","apt.postgresql.org","dl.cloudsmith.io","nodejs.org")) {
    if (-not (Test-Host443 $h)) { $inacessiveis += $h }
}
if ($inacessiveis.Count -gt 0) {
    Write-Warn2 "Sem resposta (443) de: $($inacessiveis -join ', ')."
    Write-Warn2 "Em rede com proxy/firewall corporativo, o bootstrap pode falhar ao baixar pacotes."
} else { Write-Ok "Hosts criticos acessiveis." }

# --------------------------------------------------------------------------
# 2) PROTOCOLO DE VIRTUALIZACAO
# --------------------------------------------------------------------------
Write-Step "Protocolo de virtualizacao (VT-x / AMD-V)"

$cs  = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$hypervisorPresent = [bool]$cs.HypervisorPresent
$firmwareVT        = [bool]$cpu.VirtualizationFirmwareEnabled
$hwVT              = [bool]$cpu.VMMonitorModeExtensions   # CPU suporta VT
$slat              = [bool]$cpu.SecondLevelAddressTranslationExtensions

Write-Host "    HypervisorPresent (hypervisor ativo) : $hypervisorPresent"
Write-Host "    Firmware VT habilitada (BIOS)         : $firmwareVT"
Write-Host "    CPU suporta VT (hardware)             : $hwVT"
Write-Host "    SLAT/EPT                              : $slat"

$fabricante = "$($cs.Manufacturer) / $((Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue).Manufacturer)"

function Show-BiosInstrucoes {
    param([string]$mb)
    $mb = $mb.ToLower()
    $dica =
        if     ($mb -match 'dell')                 { "DELL: tecle F2 no boot -> Virtualization Support / Virtualization -> Enabled." }
        elseif ($mb -match 'hp|hewlett')           { "HP: tecle F10 -> System Configuration -> Virtualization Technology (VTx) -> Enabled." }
        elseif ($mb -match 'lenovo')               { "LENOVO: tecle F1 -> Security -> Virtualization -> Intel VT-x -> Enabled." }
        elseif ($mb -match 'asus')                 { "ASUS: tecle Del/F2 -> Advanced -> CPU Configuration -> Intel VT (ou SVM, se AMD) -> Enabled." }
        elseif ($mb -match 'gigabyte|aorus')       { "GIGABYTE: tecle Del -> M.I.T./Advanced CPU -> SVM Mode (AMD) ou Intel VT -> Enabled." }
        elseif ($mb -match 'msi|micro-star')       { "MSI: tecle Del -> OC/Advanced -> SVM Mode (AMD) ou Intel Virtualization Tech -> Enabled." }
        elseif ($mb -match 'asrock')               { "ASROCK: tecle Del/F2 -> Advanced -> CPU Configuration -> SVM (AMD) ou Intel VT -> Enabled." }
        elseif ($mb -match 'acer')                 { "ACER: tecle F2 -> Main/Advanced -> Virtualization Technology -> Enabled." }
        else                                       { "Entre no Setup do BIOS/UEFI (geralmente Del, F2 ou F10 no boot) e habilite 'Intel VT-x' ou 'SVM Mode' (AMD)." }
    Write-Host ""
    Write-Host "    >> $dica" -ForegroundColor Yellow
    Write-Host "    (Placa detectada: $mb)" -ForegroundColor DarkGray
}

if ($hypervisorPresent) {
    Write-Ok "Virtualizacao ATIVA (hypervisor presente). Seguindo."
}
elseif ($firmwareVT) {
    Write-Ok "VT habilitada no firmware. Os recursos de software serao ligados a seguir."
}
elseif ($hwVT) {
    # CPU suporta, mas BIOS esta com a VT desligada -> software NAO liga isso.
    Write-Err2 "Virtualizacao SUPORTADA pela CPU, porem DESLIGADA no BIOS/UEFI."
    Write-Warn2 "Nenhum software (nem este instalador) liga a VT por dentro do Windows:"
    Write-Warn2 "e um interruptor de firmware. Voce precisa habilita-la no Setup do BIOS."
    Show-BiosInstrucoes -mb $fabricante

    # Agenda retomada automatica apos voce habilitar a VT e o Windows voltar.
    Set-Content -Path $StateFile -Value "AFTER_BIOS_VT" -Encoding utf8
    $resume = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" `
            -Name "BraiaWinResume" -Value $resume -PropertyType String -Force | Out-Null
        Write-Ok "Retomada automatica agendada: quando o Windows voltar, o instalador continua."
    } catch {}

    Write-Host ""
    $r = Read-Host "    Posso REINICIAR agora direto na tela da UEFI/BIOS p/ voce habilitar a VT? (S/N)"
    if ($r -match '^[Ss]') {
        try {
            Write-Warn2 "Reiniciando na UEFI... habilite a VT, salve e o Windows volta automaticamente."
            Start-Process -FilePath "shutdown.exe" -ArgumentList "/r","/fw","/t","3" -Wait
            exit 0
        } catch {
            Write-Err2 "Este equipamento nao suporta reboot direto na UEFI (provavel BIOS legado)."
            Write-Warn2 "Reinicie manualmente, entre no Setup, habilite a VT e rode o instalador de novo."
            exit 1
        }
    } else {
        Write-Warn2 "Ok. Habilite a VT no BIOS e rode o instalador novamente (ou ele retoma sozinho no proximo logon)."
        exit 0
    }
}
else {
    Write-Err2 "A CPU deste equipamento NAO reporta suporte a virtualizacao (VT-x/AMD-V)."
    Write-Err2 "WSL2 nao pode rodar aqui. Verifique se a VT esta oculta no BIOS ou use outra maquina."
    exit 1
}

# --- Recursos de software: WSL + VirtualMachinePlatform -------------------
function Get-FeatureState ($name) {
    try { (Get-WindowsOptionalFeature -Online -FeatureName $name -ErrorAction Stop).State }
    catch { "Unknown" }
}
$fWsl = Get-FeatureState "Microsoft-Windows-Subsystem-Linux"
$fVmp = Get-FeatureState "VirtualMachinePlatform"
Write-Host "    Recurso WSL                    : $fWsl"
Write-Host "    Recurso VirtualMachinePlatform : $fVmp"

$precisaReboot = $false
if ($fWsl -ne "Enabled") {
    Write-Warn2 "Habilitando Microsoft-Windows-Subsystem-Linux..."
    Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -All -NoRestart | Out-Null
    $precisaReboot = $true
}
if ($fVmp -ne "Enabled") {
    Write-Warn2 "Habilitando VirtualMachinePlatform..."
    Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -All -NoRestart | Out-Null
    $precisaReboot = $true
}

if ($precisaReboot) {
    Set-Content -Path $StateFile -Value "AFTER_REBOOT" -Encoding utf8
    $resume = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" `
            -Name "BraiaWinResume" -Value $resume -PropertyType String -Force | Out-Null
        Write-Ok "Retomada automatica agendada (RunOnce)."
    } catch { Write-Warn2 "Rode o instalador de novo apos reiniciar." }
    Write-Host ""
    Write-Warn2 "Recursos habilitados. E PRECISO REINICIAR o Windows para continuar."
    $r = Read-Host "    Reiniciar agora? (S/N)"
    if ($r -match '^[Ss]') { Restart-Computer -Force }
    else { Write-Host "    Reinicie manualmente e rode o script novamente."; exit 0 }
}
Write-Ok "Recursos de virtualizacao por software habilitados."

# Passamos da fase de features/BIOS: limpa marcadores de retomada.
if (Test-Path $StateFile) { Remove-Item $StateFile -Force -ErrorAction SilentlyContinue }
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "BraiaWinResume" -ErrorAction SilentlyContinue

# --------------------------------------------------------------------------
# 3) Kernel WSL + versao padrao 2
# --------------------------------------------------------------------------
Write-Step "Atualizando o kernel do WSL e fixando WSL2 como padrao"
& wsl.exe --update 2>$null
& wsl.exe --set-default-version 2 2>$null

# GARANTE WSL "da Store/moderno" (necessario p/ systemd). O WSL 'inbox' antigo
# do Win10 NAO suporta systemd -> os services do agente nunca subiriam.
$wslVer = ""
try { $wslVer = (& wsl.exe --version 2>$null) -join " " } catch {}
if (-not $wslVer) {
    Write-Warn2 "WSL parece ser a versao 'inbox' (antiga), que NAO suporta systemd. Migrando..."
    & wsl.exe --update --web-download 2>$null   # --web-download = nao depende da Store
    try { $wslVer = (& wsl.exe --version 2>$null) -join " " } catch {}
    if (-not $wslVer) {
        Write-Err2 "Nao foi possivel obter o WSL moderno (Microsoft Store / download web bloqueados?)."
        Write-Err2 "Sem ele o systemd nao funciona e os services do agente nao sobem."
        Write-Err2 "Libere a Store ou o download web do WSL (politica de grupo) e rode de novo."
        exit 1
    }
}
Write-Ok "WSL2 padrao + versao moderna (suporta systemd)."

# --------------------------------------------------------------------------
# 4) Distro Ubuntu 22.04
# --------------------------------------------------------------------------
function Test-DistroInstalada ($name) {
    $lista = (& wsl.exe -l -q) -replace "`0","" 2>$null
    return ($lista -split "`r?`n" | ForEach-Object { $_.Trim() }) -contains $name
}
Write-Step "Instalando a distro $Distro (se necessario)"
if (Test-DistroInstalada $Distro) {
    Write-Ok "$Distro ja instalada."
} else {
    Write-Host "    Registrando $Distro sem abrir o assistente interativo..."
    & wsl.exe --install -d $Distro --no-launch
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "Falhou pela Store. Tentando com --web-download (nao depende da Store)..."
        & wsl.exe --install -d $Distro --no-launch --web-download
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "Tentando instalacao padrao (WSL mais antigo; pode abrir o assistente de usuario)."
        & wsl.exe --install -d $Distro
    }
    $t = 0
    while (-not (Test-DistroInstalada $Distro) -and $t -lt 30) { Start-Sleep 5; $t++ }
    if (-not (Test-DistroInstalada $Distro)) {
        Write-Err2 "A distro nao apareceu instalada. Confira a VT no BIOS e rode `wsl -l -v`."
        exit 1
    }
    Write-Ok "$Distro instalada."
}
& wsl.exe --set-version $Distro 2 2>$null | Out-Null

# --------------------------------------------------------------------------
# 5) systemd dentro do WSL
# --------------------------------------------------------------------------
Write-Step "Habilitando systemd dentro do $Distro"
& wsl.exe -d $Distro -u root -- bash -lc "printf '[boot]\nsystemd=true\n' > /etc/wsl.conf && echo ok"
& wsl.exe --terminate $Distro 2>$null
Write-Ok "systemd habilitado (/etc/wsl.conf)."

# --------------------------------------------------------------------------
# 5.5) Sanidade de DNS / saida na WSL
#      O login do Claude e o bot do Telegram dependem de HTTPS de SAIDA. Em
#      algumas maquinas o resolv.conf da WSL sobe quebrado e AMBOS falham (foi
#      o "IP do WSL" que travou o deploy de referencia). Testa e SO corrige se
#      realmente falhar (em rede corporativa com proxy, pode ser firewall).
# --------------------------------------------------------------------------
if ($SemAjusteDNS) {
    Write-Warn2 "Checagem de DNS da WSL pulada (-SemAjusteDNS)."
} else {
    Write-Step "Checando a saida HTTPS de dentro do WSL (DNS)"
    function Test-WslHttps {
        $code = (& wsl.exe -d $Distro -u root -- bash -lc "curl -s -o /dev/null -w '%{http_code}' --max-time 8 https://api.anthropic.com 2>/dev/null") 2>$null
        return (("$code".Trim()) -match '^\d{3}$' -and ("$code".Trim()) -ne '000')
    }
    if (Test-WslHttps) {
        Write-Ok "Saida HTTPS da WSL OK (DNS resolvendo)."
    } else {
        Write-Warn2 "WSL sem saida HTTPS (DNS provavelmente quebrado). Aplicando resolvedor publico..."
        $dnsFix = @'
printf '[boot]\nsystemd=true\n\n[network]\ngenerateResolvConf=false\n' > /etc/wsl.conf
rm -f /etc/resolv.conf
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
'@
        & wsl.exe -d $Distro -u root -- bash -lc $dnsFix | Out-Null
        & wsl.exe --terminate $Distro 2>$null
        Start-Sleep -Seconds 3
        if (Test-WslHttps) { Write-Ok "DNS corrigido (1.1.1.1/8.8.8.8); saida HTTPS OK." }
        else { Write-Warn2 "Ainda sem saida HTTPS - provavel proxy/firewall corporativo. Resolva a rede ANTES do login do Claude." }
    }
}

# --------------------------------------------------------------------------
# 6) Copia o repo (LOCAL, self-contained) para o WSL + 7) roda o bootstrap
# --------------------------------------------------------------------------
# Este repositorio e AUTOCONTIDO: o instalador NAO clona do GitHub (o repo e
# privado). Ele copia os arquivos locais (esta pasta) para dentro do WSL e roda
# o bootstrap.sh proprio. Assim funciona offline-do-GitHub na maquina do cliente.
if ($PularBootstrap) {
    Write-Warn2 "Bootstrap pulado (-PularBootstrap)."
} else {
    Write-Step "Copiando o repositorio (local) para $CloneDir dentro do WSL"
    $wslRepo = ConvertTo-WslPath $PSScriptRoot
    & wsl.exe -d $Distro -u root -- bash -lc "rm -rf '$CloneDir' && mkdir -p '$CloneDir' && cp -a '$wslRepo'/. '$CloneDir'/ && sed -i 's/\r`$//' '$CloneDir'/bootstrap.sh && chmod +x '$CloneDir'/bootstrap.sh && echo copiado"
    if ($LASTEXITCODE -ne 0) { Write-Err2 "Falha ao copiar o repositorio para o WSL."; exit 1 }
    Write-Ok "Repositorio disponivel em $CloneDir."

    Write-Step "Aguardando o systemd ficar pronto dentro do $Distro (evita 'Failed to connect to bus')"
    $sdok = $false; $st = ""
    for ($i = 0; $i -lt 24; $i++) {
        $st = (& wsl.exe -d $Distro -u root -- systemctl is-system-running 2>$null)
        if ("$st" -match 'running|degraded') { $sdok = $true; break }
        Start-Sleep 5
    }
    if ($sdok) { Write-Ok "systemd pronto (estado: $st)." }
    else { Write-Warn2 "systemd demorou a responder; seguindo mesmo assim." }

    Write-Step "Rodando o bootstrap.sh (self-contained) no Ubuntu (varios minutos)"
    Write-Host "    Instala Node 22, Python, ffmpeg, PostgreSQL 16 + pgvector, Caddy, pm2 e Claude Code @$ClaudeVersion."
    & wsl.exe -d $Distro -u root -- bash -lic "cd '$CloneDir' && CLAUDE_VERSION='$ClaudeVersion' bash bootstrap.sh"
    if ($LASTEXITCODE -ne 0) { Write-Err2 "Falha no bootstrap."; exit 1 }
    Write-Ok "Pre-requisitos instalados + Claude Code @$ClaudeVersion."
}

# --------------------------------------------------------------------------
# 8) RESILIENCIA (Linux): guard systemd
# --------------------------------------------------------------------------
if ($SemResiliencia) {
    Write-Warn2 "Guard de resiliencia pulado (-SemResiliencia)."
} else {
    Write-Step "Instalando o guard de resiliencia (systemd timer idempotente)"
    $wslResDir = ConvertTo-WslPath (Join-Path $PSScriptRoot "wsl-resilience")
    & wsl.exe -d $Distro -u root -- bash -lc "sed 's/\r`$//' '$wslResDir/install-resilience.sh' | bash -s '$wslResDir'"
    if ($LASTEXITCODE -ne 0) { Write-Warn2 "Nao foi possivel instalar o guard agora (verifique apos o SETUP)." }
    else { Write-Ok "Guard de resiliencia ativo (braia-win-guard.timer)." }
}

# --------------------------------------------------------------------------
# 9) ENERGIA (Windows): impede sleep/hibernate na tomada
# --------------------------------------------------------------------------
if ($SemAjusteEnergia) {
    Write-Warn2 "Ajuste de energia pulado (-SemAjusteEnergia)."
} else {
    Write-Step "Ajustando energia (na tomada): nunca suspender/hibernar"
    try {
        & powercfg /change standby-timeout-ac 0  | Out-Null
        & powercfg /change hibernate-timeout-ac 0 | Out-Null
        & powercfg /change disk-timeout-ac 0      | Out-Null
        Write-Ok "Maquina nao dorme mais quando ligada na tomada."
    } catch { Write-Warn2 "Nao foi possivel ajustar a energia: $($_.Exception.Message)" }
}

# --------------------------------------------------------------------------
# 10) RESILIENCIA (Windows): vmIdleTimeout + ANCORA + tarefas OCULTAS
#     Fecha as lacunas que o guard Linux (etapa 8) NAO cobre: a WSL2 desliga a
#     VM por ociosidade (~60s) derrubando tudo, e a tarefa antiga deixava uma
#     "janelinha preta" na tela do cliente. Detalhes em wsl-resilience/windows/.
# --------------------------------------------------------------------------
if ($SemAutostart) {
    Write-Warn2 "Resiliencia Windows pulada (-SemAutostart)."
} else {
    Write-Step "Configurando resiliencia Windows (vmIdleTimeout + ancora + tarefas ocultas)"
    $winRes = Join-Path $PSScriptRoot "wsl-resilience\windows\install-win-resilience.ps1"
    if (Test-Path $winRes) {
        try {
            & $winRes -Distro $Distro -StateDir $StateDir -RepoRoot $PSScriptRoot
            Write-Ok "Resiliencia Windows ativa (BraiaWin-Anchor + Autostart + Keepalive, ocultas)."
        } catch {
            Write-Warn2 "Falha ao configurar a resiliencia Windows: $($_.Exception.Message)"
        }
    } else {
        Write-Warn2 "install-win-resilience.ps1 nao encontrado em wsl-resilience\windows\."
    }
}

# --------------------------------------------------------------------------
# 11) Passos manuais finais (interativos por natureza)
# --------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " ESTRUTURA 100% FECHADA. Faltam so os 2 dados pontuais."      -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host @"

A resiliencia ja esta configurada:
  - Tarefas OCULTAS (sem janela): BraiaWin-Anchor (segura a VM 24/7),
    BraiaWin-Autostart (boot/logon) e BraiaWin-Keepalive (a cada 3 min).
  - .wslconfig com vmIdleTimeout=-1: a VM nao desliga mais por ociosidade.
  - systemd habilitado -> sobe postgresql, caddy, bot.py e o service do agente.
  - Guard systemd + healthcheck (cron) mantem tudo 'enabled' e reinicia o que cair.
  - Energia: a maquina nao dorme na tomada.
  => Se desligar e ligar de novo, WSL2 + systemd + tmux + claude voltam sozinhos,
     SEM nenhuma janelinha preta aparecendo para o usuario.

Agora abra o Ubuntu como root:
    wsl -d $Distro -u root

1) Logar no Claude (abre link no navegador, autoriza e cola o codigo):
       claude auth login --claudeai

2) Disparar o SETUP (ele vai pedir o token do Telegram, IDs permitidos, etc.):
       cd $CloneDir
       claude --dangerously-skip-permissions
   Dentro do Claude, cole:
       Leia o arquivo SETUP-AGENTE.md e execute todos os passos.
       Me faca perguntas quando precisar de informacao minha.

Painel: http://localhost:3600   |   Arquivos: \\wsl$\$Distro\root\projeto
Detalhes e troubleshooting em README-WSL2.md.
"@ -ForegroundColor White
