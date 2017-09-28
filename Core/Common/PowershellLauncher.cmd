@Echo OFF
Setlocal enabledelayedexpansion
@Echo Launching Powershell as Administrator : 
set cd=%1
set cd=%cd:#= %
@Echo CD: %cd%
set psScript=%cd%%2
@Echo psScript: %psScript%
@Echo.
set "psPath="
call::funcGetPathOnly psPath "%psScript%"
@Echo Create "%psPath%cd.ps1"
@Echo $cd="%cd%" >"%psPath%cd.ps1"
@Echo.
set /a aIdx=0
set /a pIdx=0
for %%x in (%*) do (
  set /a "aIdx+=1"
  if !aIdx! geq 3 (
    set /a "pIdx+=1"
    ::@Echo p!pIdx!: %%x
    set p=%%x
    ::@Echo p!pIdx!:!p:#= !
    If "!p:~0,1!" == "\" (
      ::@Echo Relative path
      set "p=%cd%!p!"
    )
    If "!p:~0,1!" == "-" (
      set "p!pIdx!=!p!"
    ) else (
      set "p!pIdx!=\"!p!\""
    )
  )
)
::@Echo pIdx= %pIdx%
for /l %%i in (1,1,%pIdx%) do (
  @Echo p%%i: !p%%i!
)
@Echo.
::timeout /t 1
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process -Wait PowerShell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%psScript%\" %p1% %p2% %p3% %p4% %p5% %p6% %p7% %p8% %p9%' -Verb runAs}" 
@Echo.
@Echo Powershell ended.
timeout /t 1
call:funcDeleteCurrendDirFile %psScript%
goto:eof

:funcDeleteCurrendDirFile
    del %~dp1\cd.ps1	
goto:eof

:funcGetPathOnly
  set "%~1=%~dp2"
goto:eof
