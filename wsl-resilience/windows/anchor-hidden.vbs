' ============================================================================
'  anchor-hidden.vbs - Ancora WSL2 INVISIVEL (sem janelinha de console).
' ============================================================================
'  Mantem uma sessao wsl.exe bloqueante 24/7 (sleep infinity) para a WSL2 NAO
'  desligar a VM por ociosidade (~60s sem sessao ativa -> systemctl poweroff ->
'  derruba postgres/bot/agente TODOS juntos). Esta e a correcao CRITICA: o
'  vmIdleTimeout=-1 do .wslconfig sozinho NAO e respeitado em algumas versoes
'  do WSL (visto na 2.7.3), entao a ancora e a garantia de fato.
'
'  POR QUE .vbs: wscript.exe nao aloca console proprio e Run(cmd, 0, True) usa
'  SW_HIDE -> o wsl.exe filho roda OCULTO. Chamar wsl.exe (ou powershell direto)
'  numa tarefa interativa deixa uma "janelinha preta" visivel na tela do cliente.
'
'  O placeholder __DISTRO__ e substituido pelo install-win-resilience.ps1.
'  Laco auto-curativo: se o wsl.exe morrer, Run retorna e religa em 2s.
'  Grava o PID do bash em /run/braia-anchor.pid (lido pelo Ensure-Anchor).
' ============================================================================
Option Explicit
Dim sh, cmd
Set sh = CreateObject("WScript.Shell")
cmd = "wsl.exe -d __DISTRO__ -u root -- bash -c ""echo $$ > /run/braia-anchor.pid; exec -a braia-anchor sleep infinity"""
Do
    sh.Run cmd, 0, True   ' 0 = SW_HIDE (oculto); True = espera (segura a VM)
    WScript.Sleep 2000    ' se o wsl morreu, religa em 2s
Loop
