@echo off
rem Rebuild every processed table from the raw files in data\raw and data\shp, then test the app.
rem Run after adding or replacing a raw workbook.
setlocal
title Niger MDO: rebuild data
cd /d "%~dp0"

set "ENV_NAME=mdo-niger"
call :find_conda || goto :fail

call "%CONDA%" env list | findstr /b /c:"%ENV_NAME% " >nul
if errorlevel 1 (
    echo First run: creating the "%ENV_NAME%" environment from environment.yml. This takes a few minutes.
    call "%CONDA%" env create -f environment.yml || goto :fail
)
call "%CONDA%" activate %ENV_NAME% || goto :fail

echo == Rebuilding data\processed and app\data
python scripts\run_all.py || goto :fail
echo.
echo == Checking that every dashboard output renders
Rscript app\tests\test_app.R || goto :fail
echo.
echo Done. Data rebuilt and app checked.
pause
goto :eof

:find_conda
set "CONDA="
for %%P in ("%LOCALAPPDATA%\miniforge3" "%USERPROFILE%\miniforge3" "%ProgramData%\miniforge3" "%LOCALAPPDATA%\mambaforge" "%USERPROFILE%\mambaforge" "%LOCALAPPDATA%\anaconda3" "%USERPROFILE%\anaconda3" "%LOCALAPPDATA%\miniconda3" "%USERPROFILE%\miniconda3") do (
    if not defined CONDA if exist "%%~P\condabin\conda.bat" set "CONDA=%%~P\condabin\conda.bat"
)
if not defined CONDA for /f "delims=" %%C in ('where conda.bat 2^>nul') do if not defined CONDA set "CONDA=%%C"
if defined CONDA exit /b 0
echo Could not find Miniforge or conda.
echo Install Miniforge from https://conda-forge.org/download/ and run this file again.
exit /b 1

:fail
echo.
echo Something went wrong. See the messages above.
pause
exit /b 1
