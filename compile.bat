echo off
cls

set program=OnlyLast

if exist %program%.exe del %program%.exe
if exist %program%.o del %program%.o
C:\FPC\3.2.2\bin\i386-win32\fpc.exe -Mobjfpc %program%.pas
echo ----------------------------------------
if not "%errorlevel%" == "0" (
  echo Error! Cannot compile %program%.pas
  goto quit
) else (
  echo ---
  %program%.exe files file*.txt 5 --verbose
  echo ...
)
echo errorlevel: %errorlevel%
echo ----------------------------------------
if exist %program%.o del %program%.o

:quit
pause
