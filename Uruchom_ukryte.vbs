Option Explicit
Dim sh, fso, folder, exe
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
exe = sh.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
sh.Run Chr(34) & exe & Chr(34) & " -NoLogo -NoProfile -STA -WindowStyle Hidden -File " & Chr(34) & folder & "\TeamsKeepAlive.ps1" & Chr(34), 0, False
