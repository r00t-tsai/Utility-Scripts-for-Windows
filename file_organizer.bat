@echo off
setlocal EnableDelayedExpansion
title File Organizer

:dir_menu
cls
echo ========================================================
echo                 FILE ORGANIZER
echo ========================================================
echo Select the messy directory you want to auto-organize:
echo.
echo [1] Desktop
echo [2] Documents
echo [3] Downloads
echo [4] Enter a Custom Directory Path
echo [5] Exit Script
echo ========================================================
set /p dir_choice="Choose a directory (1-5): "

if "%dir_choice%"=="1" set "TARGET_DIR=%USERPROFILE%\Desktop" & goto check_dir
if "%dir_choice%"=="2" set "TARGET_DIR=%USERPROFILE%\Documents" & goto check_dir
if "%dir_choice%"=="3" set "TARGET_DIR=%USERPROFILE%\Downloads" & goto check_dir
if "%dir_choice%"=="4" goto custom_dir
if "%dir_choice%"=="5" exit
goto dir_menu

:custom_dir
echo.
set /p TARGET_DIR="Enter the full directory path (e.g., D:\Work): "

:check_dir
if not exist "%TARGET_DIR%\" (
    echo.
    echo [ERROR] Directory does not exist: %TARGET_DIR%
    pause
    goto dir_menu
)
cd /d "%TARGET_DIR%"

:confirm
cls
echo ========================================================
echo                 ORGANIZATION CONFIRMATION
echo ========================================================
echo This will create category folders (Images, Documents, 
echo Videos, Archives, Programs) inside:
echo %TARGET_DIR%
echo.
echo And automatically move all loose files into them based
echo on their file extensions.
echo.
echo If a file with the same name already exists in the
echo destination folder, the incoming file will be renamed
echo with a (1), (2), etc. suffix instead of being skipped
echo or overwritten.
echo ========================================================
echo.
set /p final_choice="Proceed with organizing this folder? (Y/N): "

if /i "%final_choice%"=="Y" goto organize_files
if /i "%final_choice%"=="N" goto dir_menu
goto confirm

:organize_files
echo.
echo Organizing files...

mkdir "Images" 2>nul
mkdir "Documents" 2>nul
mkdir "Videos" 2>nul
mkdir "Music" 2>nul
mkdir "Archives" 2>nul
mkdir "Programs" 2>nul
mkdir "Scripts" 2>nul
mkdir "Projects & Assets\Photoshop" 2>nul
mkdir "Projects & Assets\3D & Modeling" 2>nul
mkdir "Projects & Assets\Video Editing Projects" 2>nul
mkdir "Projects & Assets\Vector & Design" 2>nul

echo Moving Standard Images...
for %%F in (*.jpg *.jpeg *.png *.gif *.jfif *.webp *.tiff *.bmp *.avif *.dng *.nef *.cr2 *.raw) do call :SafeMove "%%F" "Images"

echo Moving Digital Art, 3D, and Design Projects...
for %%F in (*.psd *.psb *.clip *.kra) do call :SafeMove "%%F" "Projects & Assets\Photoshop"
for %%F in (*.blend *.obj *.fbx *.stl *.max *.ma *.mb *.c4d) do call :SafeMove "%%F" "Projects & Assets\3D & Modeling"
for %%F in (*.ai *.eps *.svg *.indd) do call :SafeMove "%%F" "Projects & Assets\Vector & Design"
for %%F in (*.prproj *.aep *.drp *.veg) do call :SafeMove "%%F" "Projects & Assets\Video Editing Projects"

echo Moving Documents...
for %%F in (*.pdf *.doc *.docx *.txt *.xls *.xlsx *.ppt *.pptx) do call :SafeMove "%%F" "Documents"

echo Moving Videos...
for %%F in (*.mp4 *.mkv *.avi *.mov) do call :SafeMove "%%F" "Videos"

echo Moving Music...
for %%F in (*.mp3 *.wav *.flac) do call :SafeMove "%%F" "Music"

echo Moving Archives...
for %%F in (*.zip *.rar *.7z) do call :SafeMove "%%F" "Archives"

echo Moving Programs...
for %%F in (*.exe *.msi) do call :SafeMove "%%F" "Programs"

echo Moving Scripts and Code Files...
for %%F in (*.ahk *.py *.pyw *.ipynb *.pyi *.pyx *.pxd *.html *.htm *.css *.js *.ts *.php *.rb *.java *.c *.h *.cpp *.cc *.cxx *.cs *.go *.rs *.swift *.kt *.sql *.r *.json *.xml *.yaml *.yml *.sh *.ps1) do call :SafeMove "%%F" "Scripts"
for %%F in (*.bat *.cmd) do (
    if /I not "%%F"=="%~nx0" call :SafeMove "%%F" "Scripts"
)

echo.
echo Organization complete!
pause
goto dir_menu

:SafeMove
setlocal EnableDelayedExpansion
set "SRC=%~1"
set "DESTDIR=%~2"

if not exist "%SRC%" (
    endlocal
    goto :eof
)

set "BASENAME=%~n1"
set "EXT=%~x1"
set "DESTPATH=%DESTDIR%\%~nx1"

if not exist "%DESTPATH%" (
    move "%SRC%" "%DESTPATH%" >nul 2>&1
    endlocal
    goto :eof
)

set "COUNT=1"
:SafeMove_Loop
set "CANDIDATE=%DESTDIR%\%BASENAME% (!COUNT!)%EXT%"
if exist "!CANDIDATE!" (
    set /a COUNT+=1
    goto SafeMove_Loop
)
move "%SRC%" "!CANDIDATE!" >nul 2>&1
endlocal
goto :eof
