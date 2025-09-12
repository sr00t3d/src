@echo off
setlocal enabledelayedexpansion
title JoinVix - Atualizacao de DNS

echo =========================================
echo JoinVix - Atualizacao de DNS
echo =========================================
echo.
echo O procedimento comecara em 5 segundos...
timeout /t 5 /nobreak >nul

:: limpa/renova cache DNS (requer privilegios)
ipconfig /flushdns
#ipconfig /release
#ipconfig /renew

set /p DOMINIO=Digite seu dominio completo (ex: dominio.com.br): 
set "MAIL=mail.%DOMINIO%"

echo.
echo Testando ping para %MAIL%...
ping -n 1 %MAIL%

:: 1) IP resolvido via Google DNS (8.8.8.8)
set "IP_GOOGLE="
for /f "tokens=2 delims=: " %%A in ('nslookup %MAIL% 8.8.8.8 ^| findstr /I "Address"') do set "IP_GOOGLE=%%A"
for /f "tokens=* delims= " %%B in ("!IP_GOOGLE!") do set "IP_GOOGLE=%%B"

:: 2) IP resolvido pelo DNS local (o que o cliente usa)
set "IP_LOCAL="
for /f "tokens=2 delims=: " %%A in ('nslookup %MAIL% ^| findstr /I "Address"') do set "IP_LOCAL=%%A"
for /f "tokens=* delims= " %%B in ("!IP_LOCAL!") do set "IP_LOCAL=%%B"

:: 3) IP consultando o servidor retornado pelo Google (usa o IP_GOOGLE como 'server' se fizer sentido)
set "IP_SERVIDOR="
if defined IP_GOOGLE (
    for /f "tokens=2 delims=: " %%A in ('nslookup %MAIL% !IP_GOOGLE! ^| findstr /I "Address"') do set "IP_SERVIDOR=%%A"
    for /f "tokens=* delims= " %%B in ("!IP_SERVIDOR!") do set "IP_SERVIDOR=%%B"
)

:: 4) IP publico do cliente (via OpenDNS) - opcional
set "IP_PUB="
for /f "tokens=2 delims=: " %%A in ('nslookup myip.opendns.com resolver1.opendns.com ^| findstr /I "Address"') do set "IP_PUB=%%A"
for /f "tokens=* delims= " %%B in ("!IP_PUB!") do set "IP_PUB=%%B"

echo.
echo =========================================
echo Resultado da verificacao:
echo.
echo IP (resolvido por 8.8.8.8) .: !IP_GOOGLE!
echo IP (resolvido pelo DNS local): !IP_LOCAL!
echo IP (consultando servidor) ...: !IP_SERVIDOR!
echo IP publico do cliente ......: !IP_PUB!
echo =========================================
echo.

if "!IP_LOCAL!"=="" (
    echo Erro: nao foi possivel obter a resolucao via DNS local.
) else if "!IP_SERVIDOR!"=="" (
    echo Erro: nao foi possivel obter a resolucao consultando o servidor.
) else (
    if "!IP_LOCAL!"=="!IP_SERVIDOR!" (
        echo [OK] O IP resolvido pelo cliente confere com o IP retornado pelo servidor.
    ) else (
        echo [ALERTA] O IP resolvido pelo cliente NAO confere com o IP retornado pelo servidor.
    )
)

pause
endlocal
exit /b
