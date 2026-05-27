' ============================================================================
'  run-hidden.vbs - Lanca QUALQUER comando (recebido por argumento) OCULTO.
' ============================================================================
'  Usado pelas tarefas BraiaWin-Autostart e BraiaWin-Keepalive para rodar o
'  start-braia.ps1 SEM piscar janela. wscript.exe nao aloca console; Run(cmd, 0,
'  True) cria o processo filho (powershell + os wsl.exe internos) com SW_HIDE,
'  entao nada aparece na tela. Propaga o exit code de volta para a tarefa.
'
'  Substitui o antigo 'powershell.exe -WindowStyle Hidden' DIRETO, que ainda
'  pisca um console por um instante quando disparado por tarefa interativa.
'
'  Uso: wscript.exe run-hidden.vbs <programa> <arg1> <arg2> ...
'  (os argumentos usados aqui nao contem espacos -> rejuntar por espaco e exato;
'   caminhos como C:\ProgramData\BraiaWin\... nao tem espacos.)
' ============================================================================
Option Explicit
Dim sh, cmd, i
Set sh = CreateObject("WScript.Shell")
cmd = ""
For i = 0 To WScript.Arguments.Count - 1
    If Len(cmd) > 0 Then cmd = cmd & " "
    cmd = cmd & WScript.Arguments(i)
Next
WScript.Quit sh.Run(cmd, 0, True)
