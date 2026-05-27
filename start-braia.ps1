#Requires -Version 5.1
<#
============================================================================
 start-braia.ps1 - Sobe e mantem o ambiente do agente Braia (WSL2)
============================================================================
 Chamado pelas tarefas agendadas (via wscript.exe + run-hidden.vbs, OCULTO):

   "BraiaWin-Autostart"  -> -Mode Boot       (boot/logon do Windows)
       Acorda a distro (dispara o systemd -> services 'enabled'), espera o
       systemd subir, GARANTE a ancora e registra o estado (diagnostico).

   "BraiaWin-Keepalive"  -> -Mode Keepalive  (a cada 3 min)
       Read-only: so confirma que a VM/systemd estao vivos e que a ancora
       esta viva. NAO reinicia services (isso e tarefa do healthcheck.sh
       interno, cron a cada 2 min, que so funciona se a VM estiver viva - e
       e justamente isso que este modo assegura).

 NAO faz instalacao. Idempotente. O INSTALL-WSL2.ps1 copia este arquivo para
 %ProgramData%\BraiaWin\start-braia.ps1 e as tarefas apontam para la.

 A ANCORA (BraiaWin-Anchor) e o que impede a WSL2 de desligar a VM por
 ociosidade; sem ela postgres/bot/agente caem juntos a cada ~60s.
============================================================================
#>
[CmdletBinding()]
param(
    [string] $Distro = "Ubuntu-22.04",
    [ValidateSet("Boot", "Keepalive")]
    [string] $Mode = "Boot"
)

$ErrorActionPreference = "Continue"
$logDir = Join-Path $env:ProgramData "BraiaWin"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
$log = Join-Path $logDir "autostart.log"

function Log($m) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $log -Value "[$ts] [$Mode] $m" -Encoding utf8
}

# Garante a ANCORA viva: se o PID do pidfile nao responde, religa a tarefa
# dedicada BraiaWin-Anchor (deteccao por pidfile, sem auto-match de pgrep).
function Ensure-Anchor {
    $alive = (& wsl.exe -d $Distro -u root -- bash -c '[ -f /run/braia-anchor.pid ] && kill -0 $(cat /run/braia-anchor.pid) 2>/dev/null && printf SIM || printf NAO') 2>$null
    if ("$alive".Trim() -ne "SIM") {
        Log "Ancora AUSENTE -> Start-ScheduledTask BraiaWin-Anchor"
        Start-ScheduledTask -TaskName "BraiaWin-Anchor" -ErrorAction SilentlyContinue
        return "religada"
    }
    return "viva"
}

Log "==== Disparo (distro '$Distro') ===="

# 1) Acorda a distro -> dispara o systemd e os services 'enabled'.
& wsl.exe -d $Distro -u root -- /bin/true 2>$null
Log "Distro acordada (exit=$LASTEXITCODE)."

# 2) Espera o systemd subir de verdade (ate 60s).
$estado = ""; $systemdOk = $false
for ($i = 0; $i -lt 30; $i++) {
    $estado = (& wsl.exe -d $Distro -u root -- systemctl is-system-running) 2>$null
    if ("$estado" -match 'running|degraded') { $systemdOk = $true; break }
    Start-Sleep -Seconds 2
}
Log "systemd is-system-running: '$estado' (ok=$systemdOk)"

# 3) Garante a ancora (sem ela a VM cai por ociosidade e nada se sustenta).
if (-not $systemdOk) {
    Log "VM/systemd ainda nao respondeu; garantindo ancora e saindo (proximo ciclo tenta de novo)."
    Ensure-Anchor | Out-Null
    exit 1
}
$anchor = Ensure-Anchor

# 4) Diagnostico dos services base (quem reinicia e o healthcheck.sh interno).
$svc = (& wsl.exe -d $Distro -u root -- bash -lc "systemctl is-active postgresql caddy cron 2>/dev/null | tr '\n' ' '") 2>$null
Log "OK (Mode=$Mode) - ancora=$anchor | base(postgresql caddy cron)='$($svc.Trim())'"
exit 0
