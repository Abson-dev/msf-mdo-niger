@echo off
rem Create or replace the dashboard's login accounts:  manage_accounts.bat first.last other.account
rem Replaces ALL accounts: list every account to keep. New random passwords go to app\accounts_passwords.csv,
rem never to the screen. Send each one individually, then delete that file.
setlocal
cd /d "%~dp0"
if "%~1"=="" (
    echo Usage: manage_accounts.bat first.last other.account
    exit /b 1
)
set "CONDA="
for %%P in ("%LOCALAPPDATA%\miniforge3" "%USERPROFILE%\miniforge3" "%ProgramData%\miniforge3" "%LOCALAPPDATA%\mambaforge" "%USERPROFILE%\mambaforge" "%LOCALAPPDATA%\anaconda3" "%USERPROFILE%\anaconda3" "%LOCALAPPDATA%\miniconda3" "%USERPROFILE%\miniconda3") do (
    if not defined CONDA if exist "%%~P\condabin\conda.bat" set "CONDA=%%~P\condabin\conda.bat"
)
if not defined CONDA for /f "delims=" %%C in ('where conda.bat 2^>nul') do if not defined CONDA set "CONDA=%%C"
if not defined CONDA (
    echo Could not find Miniforge or conda.
    exit /b 1
)
call "%CONDA%" activate mdo-niger || exit /b 1
Rscript app\manage_accounts.R %*
