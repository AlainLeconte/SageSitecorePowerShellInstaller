@Echo OFF
@Echo Launching Powershell as Administrator to execute script : 
set psScript=%1
@Echo psScript: %psScript%
@Echo.
shift
if NOT @%1@==@@ @Echo Param1: %1
if NOT @%2@==@@ @Echo Param2: %2
if NOT @%3@==@@ @Echo Param3: %3
if NOT @%4@==@@ @Echo Param4: %4
if NOT @%5@==@@ @Echo Param5: %5
if NOT @%6@==@@ @Echo Param6: %6
if NOT @%7@==@@ @Echo Param7: %7
if NOT @%8@==@@ @Echo Param8: %8
if NOT @%9@==@@ @Echo Param9: %9
::timeout /t 1
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process -Wait PowerShell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%psScript%\" \"%1\" \"%2\" \"%3\" \"%4\" \"%5\" \"%6\" \"%7\" \"%8\" \"%9\"' -Verb runAs}" 
@Echo.
@Echo Powershell ended.
timeout /t 2
::PAUSE
