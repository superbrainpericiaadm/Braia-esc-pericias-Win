#Requires -Version 5.1
<#
============================================================================
 install-win-resilience.ps1 - Resiliencia do lado WINDOWS (camada que falta).
============================================================================
 Fecha as 4 lacunas que a resiliencia Linux (braia-win-guard) NAO cobre e que,
 no campo, derrubavam o agente e/ou apareciam na tela do cliente:

   1. vmIdleTimeout : a WSL2 desliga a VM por ociosidade (~60s) e derruba
      postgres/bot/agente juntos. Grava vmIdleTimeout=-1 no .wslconfig.
   2. ANCORA        : como o vmIdleTimeout=-1 NAO e respeitado em algumas
      versoes do WSL, mantemos uma sessao wsl.exe bloqueante 24/7 (tarefa
      BraiaWin-Anchor) que segura a VM de fato.
   3. JANELA OCULTA : todas as tarefas chamam 'wscript.exe <launcher.vbs>'
      (SW_HIDE), NUNCA wsl.exe/powershell direto -> zero "janelinha preta".
   4. KEEPALIVE      : tarefa a cada 3 min que garante VM viva + ancora viva.

 Idempotente e re-executavel (-Force). Pode rodar STANDALONE para "re-blindar"
 uma maquina ja instalada, sem refazer o bootstrap:
     powershell -ExecutionPolicy Bypass -File install-win-resilience.ps1 -Distro Ubuntu-22.04

 Chamado pelo INSTALL-WSL2.ps1 (etapa 10) no lugar do registro antigo de
 'BraiaWin-Autostart'.
============================================================================
#>
[CmdletBinding()]
param(
    [string] $Distro   = "Ubuntu-22.04",
    [string] $StateDir = (Join-Path $env:ProgramData "BraiaWin"),
    [string] $RepoRoot = "",                 # raiz do repo (onde esta start-braia.ps1); default = ..\..
    [string] $TaskUser = ""                  # conta das tarefas; default = usuario atual
)

$ErrorActionPreference = "Stop"
function Write-Step ($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok   ($m) { Write-Host "    [OK] $m" -ForegroundColor Green }
function Write-Warn2($m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }

if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path }
if (-not $TaskUser) { $TaskUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name }
if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force $StateDir | Out-Null }

# --------------------------------------------------------------------------
# 1) .wslconfig: vmIdleTimeout=-1 (merge nao-destrutivo no perfil do usuario)
# --------------------------------------------------------------------------
Write-Step "Gravando vmIdleTimeout=-1 no .wslconfig"
$wslcfg = Join-Path $env:USERPROFILE ".wslconfig"
if (-not (Test-Path $wslcfg)) {
    @"
# Gerado pela resiliencia Braia: impede a WSL2 de desligar a VM por ociosidade.
[wsl2]
vmIdleTimeout=-1
"@ | Set-Content -Path $wslcfg -Encoding utf8
    Write-Ok ".wslconfig criado."
} else {
    $c = Get-Content $wslcfg -Raw
    if ($c -match '(?im)^\s*vmIdleTimeout\s*=') {
        Write-Ok ".wslconfig ja define vmIdleTimeout (mantido)."
    } elseif ($c -match '(?im)^\s*\[wsl2\]') {
        $c = $c -replace '(?im)^(\s*\[wsl2\]\s*)$', "`$1`r`nvmIdleTimeout=-1"
        Set-Content -Path $wslcfg -Value $c -Encoding utf8
        Write-Ok "vmIdleTimeout=-1 adicionado a secao [wsl2] existente."
    } else {
        Add-Content -Path $wslcfg -Value "`r`n[wsl2]`r`nvmIdleTimeout=-1" -Encoding utf8
        Write-Ok "Secao [wsl2] + vmIdleTimeout=-1 anexada."
    }
}
Write-Warn2 "O vmIdleTimeout so vale apos 'wsl --shutdown'; ate la a ANCORA segura a VM."

# --------------------------------------------------------------------------
# 2) Instala os launchers ocultos + o start-braia.ps1 no StateDir
# --------------------------------------------------------------------------
Write-Step "Instalando launchers ocultos em $StateDir"
$startSrc = Join-Path $RepoRoot "start-braia.ps1"
$startDst = Join-Path $StateDir "start-braia.ps1"
if (Test-Path $startSrc) { Copy-Item $startSrc $startDst -Force; Write-Ok "start-braia.ps1 copiado." }
else { Write-Warn2 "start-braia.ps1 nao encontrado em $RepoRoot." }

Copy-Item (Join-Path $PSScriptRoot "run-hidden.vbs") (Join-Path $StateDir "run-hidden.vbs") -Force

# anchor-hidden.vbs: substitui __DISTRO__ pela distro real ao instalar.
$anchorTpl = Get-Content (Join-Path $PSScriptRoot "anchor-hidden.vbs") -Raw
$anchorDst = Join-Path $StateDir "anchor-hidden.vbs"
($anchorTpl -replace '__DISTRO__', $Distro) | Set-Content -Path $anchorDst -Encoding ascii
Write-Ok "anchor-hidden.vbs e run-hidden.vbs instalados (distro=$Distro)."

$runHidden = Join-Path $StateDir "run-hidden.vbs"

# --------------------------------------------------------------------------
# 3) Registra as 3 tarefas (acao = wscript.exe <vbs>, sempre OCULTA)
# --------------------------------------------------------------------------
Write-Step "Registrando tarefas BraiaWin-Anchor / Autostart / Keepalive (ocultas)"
$principal = New-ScheduledTaskPrincipal -UserId $TaskUser -LogonType Interactive -RunLevel Highest
$baseSet   = @{ AllowStartIfOnBatteries = $true; DontStopIfGoingOnBatteries = $true;
                StartWhenAvailable = $true; MultipleInstances = "IgnoreNew" }

# --- ANCORA: peca-chave. Fica Running para sempre; religa se cair. ---
$aAction = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$anchorDst`""
$aSet    = New-ScheduledTaskSettingsSet @baseSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
             -RestartInterval (New-TimeSpan -Minutes 1) -RestartCount 999
Register-ScheduledTask -TaskName "BraiaWin-Anchor" -Force -Action $aAction `
    -Trigger @((New-ScheduledTaskTrigger -AtLogOn), (New-ScheduledTaskTrigger -AtStartup)) `
    -Principal $principal -Settings $aSet `
    -Description "Ancora de resiliencia: sessao wsl.exe bloqueante 24/7 (oculta) p/ a WSL2 nao desligar a VM por ociosidade." | Out-Null

# --- AUTOSTART: boot/logon -> acorda distro, espera systemd, garante ancora. ---
$bArg    = "`"$runHidden`" powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startDst`" -Distro $Distro -Mode Boot"
$bAction = New-ScheduledTaskAction -Execute "wscript.exe" -Argument $bArg
$bSet    = New-ScheduledTaskSettingsSet @baseSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
             -RestartInterval (New-TimeSpan -Minutes 1) -RestartCount 3
Register-ScheduledTask -TaskName "BraiaWin-Autostart" -Force -Action $bAction `
    -Trigger @((New-ScheduledTaskTrigger -AtLogOn), (New-ScheduledTaskTrigger -AtStartup)) `
    -Principal $principal -Settings $bSet `
    -Description "Autostart Braia (oculto): no boot/logon acorda a WSL2, espera o systemd e garante a ancora." | Out-Null

# --- KEEPALIVE: a cada 3 min garante VM viva + ancora viva (read-only). ---
$kArg    = "`"$runHidden`" powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startDst`" -Distro $Distro -Mode Keepalive"
$kAction = New-ScheduledTaskAction -Execute "wscript.exe" -Argument $kArg
$kTrigRep = New-ScheduledTaskTrigger -Once -At ((Get-Date).Date.AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes 3)
$kSet    = New-ScheduledTaskSettingsSet @baseSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName "BraiaWin-Keepalive" -Force -Action $kAction `
    -Trigger @((New-ScheduledTaskTrigger -AtLogOn), (New-ScheduledTaskTrigger -AtStartup), $kTrigRep) `
    -Principal $principal -Settings $kSet `
    -Description "Keepalive Braia (oculto): a cada 3 min garante a VM da WSL2 viva e a ancora viva." | Out-Null

Write-Ok "Tarefas registradas (acao = wscript.exe + launcher .vbs oculto)."

# --------------------------------------------------------------------------
# 4) Sobe a ancora agora
# --------------------------------------------------------------------------
Start-ScheduledTask -TaskName "BraiaWin-Anchor" -ErrorAction SilentlyContinue
Write-Ok "Ancora iniciada. Resiliencia Windows completa."
