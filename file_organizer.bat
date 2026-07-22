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
move *.jpg "Images\" 2>nul
move *.jpeg "Images\" 2>nul
move *.png "Images\" 2>nul
move *.gif "Images\" 2>nul
move *.jfif "Images\" 2>nul
move *.webp "Images\" 2>nul
move *.tiff "Images\" 2>nul
move *.bmp "Images\" 2>nul
move *.avif "Images\" 2>nul
move *.dng "Images\" 2>nul
move *.nef "Images\" 2>nul
move *.cr2 "Images\" 2>nul
move *.raw "Images\" 2>nul
echo Moving Digital Art, 3D, and Design Projects...
move *.psd "Projects & Assets\Photoshop\" 2>nul
move *.psb "Projects & Assets\Photoshop\" 2>nul
move *.clip "Projects & Assets\Photoshop\" 2>nul
move *.kra "Projects & Assets\Photoshop\" 2>nul
move *.blend "Projects & Assets\3D & Modeling\" 2>nul
move *.obj "Projects & Assets\3D & Modeling\" 2>nul
move *.fbx "Projects & Assets\3D & Modeling\" 2>nul
move *.stl "Projects & Assets\3D & Modeling\" 2>nul
move *.max "Projects & Assets\3D & Modeling\" 2>nul
move *.ma "Projects & Assets\3D & Modeling\" 2>nul
move *.mb "Projects & Assets\3D & Modeling\" 2>nul
move *.c4d "Projects & Assets\3D & Modeling\" 2>nul
move *.ai "Projects & Assets\Vector & Design\" 2>nul
move *.eps "Projects & Assets\Vector & Design\" 2>nul
move *.svg "Projects & Assets\Vector & Design\" 2>nul
move *.indd "Projects & Assets\Vector & Design\" 2>nul
move *.prproj "Projects & Assets\Video Editing Projects\" 2>nul
move *.aep "Projects & Assets\Video Editing Projects\" 2>nul
move *.drp "Projects & Assets\Video Editing Projects\" 2>nul
move *.veg "Projects & Assets\Video Editing Projects\" 2>nul
echo Moving Documents...
move *.pdf "Documents\" 2>nul
move *.doc "Documents\" 2>nul
move *.docx "Documents\" 2>nul
move *.txt "Documents\" 2>nul
move *.xls "Documents\" 2>nul
move *.xlsx "Documents\" 2>nul
move *.ppt "Documents\" 2>nul
move *.pptx "Documents\" 2>nul
echo Moving Videos...
move *.mp4 "Videos\" 2>nul
move *.mkv "Videos\" 2>nul
move *.avi "Videos\" 2>nul
move *.mov "Videos\" 2>nul
echo Moving Music...
move *.mp3 "Music\" 2>nul
move *.wav "Music\" 2>nul
move *.flac "Music\" 2>nul
echo Moving Archives...
move *.zip "Archives\" 2>nul
move *.rar "Archives\" 2>nul
move *.7z "Archives\" 2>nul
echo Moving Programs...
move *.exe "Programs\" 2>nul
move *.msi "Programs\" 2>nul
@echo off
echo Moving Scripts and Code Files...
move *.py "Scripts\" 2>nul
move *.pyw "Scripts\" 2>nul
move *.ipynb "Scripts\" 2>nul
move *.pyi "Scripts\" 2>nul
move *.pyx "Scripts\" 2>nul
move *.pxd "Scripts\" 2>nul
move *.html "Scripts\" 2>nul
move *.htm "Scripts\" 2>nul
move *.css "Scripts\" 2>nul
move *.js "Scripts\" 2>nul
move *.ts "Scripts\" 2>nul
move *.php "Scripts\" 2>nul
move *.rb "Scripts\" 2>nul
move *.java "Scripts\" 2>nul
move *.c "Scripts\" 2>nul
move *.h "Scripts\" 2>nul
move *.cpp "Scripts\" 2>nul
move *.cc "Scripts\" 2>nul
move *.cxx "Scripts\" 2>nul
move *.cs "Scripts\" 2>nul
move *.go "Scripts\" 2>nul
move *.rs "Scripts\" 2>nul
move *.swift "Scripts\" 2>nul
move *.kt "Scripts\" 2>nul
move *.sql "Scripts\" 2>nul
move *.r "Scripts\" 2>nul
move *.json "Scripts\" 2>nul
move *.xml "Scripts\" 2>nul
move *.yaml "Scripts\" 2>nul
move *.yml "Scripts\" 2>nul
move *.sh "Scripts\" 2>nul
move *.ps1 "Scripts\" 2>nul
for %%F in (*.bat *.cmd) do (
    if /I not "%%F"=="%~nx0" move "%%F" "Scripts\" 2>nul
)

echo Done!
pause


echo.
echo Organization complete! 
pause
goto dir_menu
