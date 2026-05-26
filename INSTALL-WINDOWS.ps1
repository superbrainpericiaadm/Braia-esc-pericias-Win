#Requires -Version 5.1
<#
============================================================================
 INSTALL-WINDOWS.ps1 - Ponto de entrada do instalador Braia Win
============================================================================
 Este e apenas o "lancador" oficial. A logica real esta em INSTALL-WSL2.ps1
 (estrategia escolhida: WSL2). Este wrapper:
   - garante a politica de execucao (Bypass nesta sessao),
   - localiza e chama o INSTALL-WSL2.ps1 ao lado deste arquivo,
   - repassa quaisquer parametros (-Distro, -CriarTarefaInicializacao, etc).

 Uso tipico (PowerShell como Administrador):
     powershell -ExecutionPolicy Bypass -File .\INSTALL-WINDOWS.ps1

 Se a politica de execucao do seu Windows bloquear .ps1, use o
 INSTALL-WINDOWS.bat (mesmo efeito, sem precisar mexer na politica).
============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    $Passthrough
)

$ErrorActionPreference = "Stop"
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch {}

# Desbloqueia arquivos baixados (Mark of the Web) p/ evitar SmartScreen/prompts.
try { Get-ChildItem -Path $PSScriptRoot -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue } catch {}

$alvo = Join-Path $PSScriptRoot "INSTALL-WSL2.ps1"
if (-not (Test-Path $alvo)) {
    Write-Host "[X] INSTALL-WSL2.ps1 nao encontrado ao lado deste arquivo." -ForegroundColor Red
    Write-Host "    Mantenha os dois scripts na mesma pasta." -ForegroundColor Red
    exit 1
}

Write-Host "Chamando INSTALL-WSL2.ps1 (estrategia WSL2)..." -ForegroundColor Cyan
if ($Passthrough) { & $alvo @Passthrough } else { & $alvo }
exit $LASTEXITCODE
