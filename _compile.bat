@echo off
rem Project: Tiko Editor
rem File: _compile.bat
rem Purpose: Build the native FreeBASIC application on Windows.
rem Responsibilities: locate the repository and compile src/tiko.bas with omaGUI.
rem This script intentionally does not package the legacy Windows application.

setlocal
cd /d "%~dp0"
if not exist bin mkdir bin
fbc -i "src\omaGUI-main" "src\tiko.bas" -x "bin\tiko.exe"
if errorlevel 1 exit /b %ERRORLEVEL%

rem end of _compile.bat
