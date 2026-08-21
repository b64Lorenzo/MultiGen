@echo off
setlocal EnableExtensions
title MultiGen

REM ----------------------------------------------
REM Resolve paths
REM ----------------------------------------------
set "HERE=%~dp0"
set "CONFIG=%HERE%config.ini"
set "OUTDIR=%HERE%output"

REM ----------------------------------------------
REM Run MultiGen
REM ----------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%HERE%scripts\_buildFiles.ps1" ^
  -ConfigFile "%CONFIG%" ^
  -OutputRoot "%OUTDIR%"

exit /b %ERRORLEVEL%