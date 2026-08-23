@echo off
setlocal
set "DIR=%~dp0\.."

if defined JACI_BIN if exist "%JACI_BIN%" (
    "%JACI_BIN%" "%DIR%\src\init.luau" -a %*
    exit /b %ERRORLEVEL%
)

if defined LUAU_BIN if exist "%LUAU_BIN%" (
    "%LUAU_BIN%" "%DIR%\src\init.luau" -a %*
    exit /b %ERRORLEVEL%
)

if exist "%DIR%\..\build\luau.exe" (
    "%DIR%\..\build\luau.exe" "%DIR%\src\init.luau" -a %*
    exit /b %ERRORLEVEL%
)

luau "%DIR%\src\init.luau" -a %*
exit /b %ERRORLEVEL%
