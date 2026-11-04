@echo off
rem Niger MDO surveillance dashboard: double-click to start.
rem Finds Miniforge/conda, creates the "mdo-niger" environment on first run, then opens the app in the browser.
rem Options:  run_app.bat --no-browser   start without opening a browser
rem           run_app.bat --no-login     skip the login, on this computer only
setlocal
title Niger MDO dashboard
cd /d "%~dp0"

set "ENV_NAME=mdo-niger"
set "LAUNCH=TRUE"
for %%A in (%*) do (
    if /i "%%~A"=="--no-browser" set "LAUNCH=FALSE"
    if /i "%%~A"=="--no-login" set "MDO_LOCAL=1"
)

call :find_conda || goto :fail

call "%CONDA%" env list | findstr /b /c:"%ENV_NAME% " >nul
if errorlevel 1 (
    echo First run: creating the "%ENV_NAME%" environment from environment.yml. This takes a few minutes.
    call "%CONDA%" env create -f environment.yml || goto :fail
)

call "%CONDA%" activate %ENV_NAME% || goto :fail

rem An environment made before the login was added needs the new packages
Rscript -e "quit(status = !requireNamespace('shinymanager', quietly = TRUE))" >nul 2>nul
if errorlevel 1 (
    echo Updating the "%ENV_NAME%" environment. This takes a few minutes.
    call "%CONDA%" env update -n %ENV_NAME% -f environment.yml || goto :fail
)

rem The data are not in the repository: build the app's tables from data\raw the first time
if not exist "app\data\mdo_annual.csv" (
    if not exist "data\raw\MDO 2024 S43.xls" (
        echo The data files are missing. Put the source workbooks in data\raw and the shapefile in data\shp,
        echo as listed in data\README.md, then run this file again.
        goto :fail
    )
    echo First run: building the dashboard data from data\raw. This takes a few minutes.
    python scripts\run_all.py || goto :fail
)

if not "%MDO_LOCAL%"=="1" if not exist "app\accounts.sqlite" (
    echo No login accounts yet. Create them with:  manage_accounts.bat first.last
    goto :fail
)

echo.
echo Starting the dashboard. It opens in your browser; the address is shown below.
echo Keep this window open while you use the app. Close it, or press Ctrl+C, to stop.
echo.
Rscript -e "shiny::runApp('app', host = '127.0.0.1', launch.browser = %LAUNCH%)"
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
echo The dashboard could not start. See the messages above.
pause
exit /b 1
