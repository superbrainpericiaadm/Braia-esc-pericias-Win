#Requires -Version 5.1
<#
============================================================================
 start-braia.ps1 - Sobe o ambiente do agente Braia no boot/logon do Windows
============================================================================
 Este script e chamado pela tarefa agendada "BraiaWin-Autostart".
 Ele NAO faz instalacao: apenas inicia a distro WSL2, o que dispara o
 systemd da distro, que por sua vez sobe TODOS os services 'enabled'
 (postgresql, caddy, bot.py, o service do agente que recria o tmux+claude).

 E intencionalmente leve e idempotente: pode ser chamado quantas vezes for.

 O instalador (INSTALL-WSL2.ps1) copia este arquivo para:
     %ProgramData%\BraiaWin\start-braia.ps1
 e registra a tarefa apontando para la (independente da pasta do repositorio).
============================================================================
#>
[CmdletBinding()]
param(
    [string] $Distro = "Ubuntu-22.04"
)

$ErrorActionPreference = "Continue"
$logDir = Join-Path $env:ProgramData "BraiaWin"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
$log = Join-Path $logDir "autostart.log"

function Log($m) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $log -Value "[$ts] $m" -Encoding utf8
}

Log "Autostart disparado para distro '$Distro'."

# 1) Inicia a distro (dispara o systemd -> sobe os services enabled).
#    -u root e '/bin/true' apenas "acordam" a distro; o systemd faz o resto.
try {
    & wsl.exe -d $Distro -u root -- /bin/true
    Log "Distro iniciada (exit=$LASTEXITCODE)."
} catch {
    Log "ERRO ao iniciar a distro: $($_.Exception.Message)"
}

# 2) Aguarda o systemd terminar de subir e registra o estado (diagnostico).
Start-Sleep -Seconds 8
try {
    $estado = (& wsl.exe -d $Distro -u root -- systemctl is-system-running) 2>$null
    Log "systemd is-system-running: $estado"
    $svc = (& wsl.exe -d $Distro -u root -- bash -lc "systemctl is-active postgresql caddy cron 2>/dev/null | tr '\n' ' '")
    Log "servicos base (postgresql caddy cron): $svc"
} catch {
    Log "Aviso: nao foi possivel consultar o estado do systemd."
}

Log "Autostart concluido."
