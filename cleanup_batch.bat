@echo off
setlocal EnableDelayedExpansion
title Bulk File/Folder Deleter
net session >nul 2>&1
if %errorLevel% == 0 (
    goto dir_menu
)

:admin_warning
cls
echo ========================================================
echo               ADMIN PRIVILEGES REQUIRED
echo ========================================================
echo This batch file is designed to bulk delete files/folders.
echo It is highly recommended to launch this script in 
echo Administrator mode to prevent access denial errors.
echo.
echo [1] Proceed anyway (May fail on some files/folders)
echo [2] Exit and restart the script as Administrator
echo ========================================================
set /p admin_choice="Choose an option (1-2): "

if "%admin_choice%"=="2" exit
if not "%admin_choice%"=="1" goto admin_warning

:dir_menu
set "TARGET_DIR="
cls
echo ========================================================
echo                 DIRECTORY SELECTION
echo ========================================================
echo Select a target directory for the current user: (%USERNAME%)
echo.
echo [0] Delete Folders (Folder Deletion Menu)
echo.
echo [1] Desktop
echo [2] Documents
echo [3] Downloads
echo [4] Music
echo [5] Pictures
echo [6] Videos
echo [7] Enter a Custom Directory Path
echo [8] Exit Script
echo ========================================================
set /p dir_choice="Selection (0-8): "

if "%dir_choice%"=="0" goto folder_setup_menu
if "%dir_choice%"=="1" set "TARGET_DIR=%USERPROFILE%\Desktop" & goto check_dir
if "%dir_choice%"=="2" set "TARGET_DIR=%USERPROFILE%\Documents" & goto check_dir
if "%dir_choice%"=="3" set "TARGET_DIR=%USERPROFILE%\Downloads" & goto check_dir
if "%dir_choice%"=="4" set "TARGET_DIR=%USERPROFILE%\Music" & goto check_dir
if "%dir_choice%"=="5" set "TARGET_DIR=%USERPROFILE%\Pictures" & goto check_dir
if "%dir_choice%"=="6" set "TARGET_DIR=%USERPROFILE%\Videos" & goto check_dir
if "%dir_choice%"=="7" goto custom_dir
if "%dir_choice%"=="8" exit
goto dir_menu


:folder_setup_menu
cls
echo ========================================================
echo                 FOLDER DELETION MODE
echo ========================================================
if defined TARGET_DIR (
    echo Target Directory: %TARGET_DIR%
) else (
    echo Target Directory: [NONE SELECTED]
)
echo.
echo [0] Enter the chosen directory
echo [1] Return
echo ========================================================
set /p fs_choice="Choose an option: "

if "%fs_choice%"=="0" goto folder_set_dir
if "%fs_choice%"=="1" goto dir_menu
goto folder_setup_menu

:folder_set_dir
echo.
set /p TARGET_DIR="Enter the full directory path (e.g., D:\Work): "
if not exist "%TARGET_DIR%\" (
    echo.
    echo [ERROR] Directory does not exist: %TARGET_DIR%
    set "TARGET_DIR="
    pause
    goto folder_setup_menu
)

goto folder_action_menu

:folder_action_menu
cls
echo ========================================================
echo                 FOLDER DELETION MODE
echo ========================================================
echo Target Directory: %TARGET_DIR%
echo.
echo [1] Delete specified folders in the current directory
echo [2] Delete ALL folders in the current directory
echo [3] Return to Main Menu
echo ========================================================
set /p fa_choice="Choose an option (1-3): "

if "%fa_choice%"=="1" goto folder_specific
if "%fa_choice%"=="2" goto folder_all
if "%fa_choice%"=="3" goto dir_menu
goto folder_action_menu

:folder_specific
echo.
echo Enter the folder names to delete (separated by spaces).
echo TIP: Use quotes for folder names with spaces (e.g., "Old Pics" Temp)
set /p FOLDER_LIST="Folders: "
set "DELETE_MODE=SPECIFIC"
goto folder_confirm

:folder_all
set "DELETE_MODE=ALL"
set "FOLDER_LIST=* [EVERY FOLDER INSIDE TARGET DIRECTORY]"
goto folder_confirm

:folder_confirm
cls
echo ========================================================
echo                     CONFIRMATION
echo ========================================================
echo WARNING: FOLDERS AND ALL THEIR CONTENTS WILL BE DELETED
echo PERMANENTLY, BYPASSING THE RECYCLE BIN!
echo.
echo DIRECTORY TO CLEAN : %TARGET_DIR%
echo FOLDERS TARGETED   : %FOLDER_LIST%
echo ========================================================
echo.
set /p final_f_choice="Are you sure you want to DELETE these folders? (Y/N): "

if /i "%final_f_choice%"=="Y" goto delete_folders_exec
if /i "%final_f_choice%"=="N" goto folder_action_menu
goto folder_confirm

:delete_folders_exec
echo.
echo Deleting folders...
cd /d "%TARGET_DIR%"

if "%DELETE_MODE%"=="ALL" goto delete_all_folders
goto delete_specific_folders

:delete_all_folders
for /d %%x in (*) do (
    rd /s /q "%%x" 2>nul
)
goto finish_folder_delete

:delete_specific_folders
for %%x in (%FOLDER_LIST%) do (
    if exist "%%~x\" (
        rd /s /q "%%~x" 2>nul
    ) else (
        echo [SKIP] Folder not found: %%~x
    )
)
goto finish_folder_delete

:finish_folder_delete
echo.
echo Folder deletion complete!
pause
goto dir_menu

:custom_dir
echo.
set /p TARGET_DIR="Enter the full directory path (e.g., D:\Work\OldFiles): "

:check_dir
if not exist "%TARGET_DIR%\" (
    echo.
    echo [ERROR] Directory does not exist: %TARGET_DIR%
    pause
    goto dir_menu
)
cd /d "%TARGET_DIR%"

:ext_menu
cls
echo ========================================================
echo                 FILE TYPE SELECTION
echo ========================================================
echo Target Directory: %TARGET_DIR%
echo.
echo Select the type of files you want to bulk delete:
echo.
echo --- Documents ---
echo [1] .txt (Text)         [4] .pdf (PDF Document)
echo [2] .doc / .docx (Word) [5] .ppt / .pptx (PowerPoint)
echo [3] .xls / .xlsx (Excel)
echo.
echo --- Media ---
echo [6] .jpg / .jpeg / .png / .gif (Images)
echo [7] .mp4 / .mkv / .avi / .mov (Videos)
echo [8] .mp3 / .wav / .flac (Audio)
echo.
echo --- Design / Work ---
echo [9] .psd (Photoshop)    [11] .prproj (Premiere)
echo [10] .ai (Illustrator)  [12] .blend (Blender)
echo.
echo --- Archives ---
echo [13] .zip / .rar / .7z
echo.
echo --- Other ---
echo [14] Enter a CUSTOM file extension
echo [15] Go back to Directory Selection
echo ========================================================
set /p ext_choice="Choose a file type category (1-15): "

if "%ext_choice%"=="1" set "EXT=*.txt" & goto confirm
if "%ext_choice%"=="2" set "EXT=*.doc *.docx" & goto confirm
if "%ext_choice%"=="3" set "EXT=*.xls *.xlsx" & goto confirm
if "%ext_choice%"=="4" set "EXT=*.pdf" & goto confirm
if "%ext_choice%"=="5" set "EXT=*.ppt *.pptx" & goto confirm
if "%ext_choice%"=="6" set "EXT=*.jpg *.jpeg *.png *.gif" & goto confirm
if "%ext_choice%"=="7" set "EXT=*.mp4 *.mkv *.avi *.mov" & goto confirm
if "%ext_choice%"=="8" set "EXT=*.mp3 *.wav *.flac" & goto confirm
if "%ext_choice%"=="9" set "EXT=*.psd" & goto confirm
if "%ext_choice%"=="10" set "EXT=*.ai" & goto confirm
if "%ext_choice%"=="11" set "EXT=*.prproj" & goto confirm
if "%ext_choice%"=="12" set "EXT=*.blend" & goto confirm
if "%ext_choice%"=="13" set "EXT=*.zip *.rar *.7z" & goto confirm
if "%ext_choice%"=="14" goto custom_ext
if "%ext_choice%"=="15" goto dir_menu
goto ext_menu

:custom_ext
echo.
echo Enter the file extension you want to delete (e.g., .log). 
echo You can enter multiple separated by spaces (e.g., .log .tmp)
set /p custom_input="Extension: "

echo %custom_input% | findstr /i "\.sys \.dll \.ini \.exe \.bat \.cmd \.boot" >nul
if %errorlevel%==0 (
    echo.
    echo [WARNING] YOU ARE ATTEMPTING TO DELETE SYSTEM OR EXECUTABLE FILES!
    echo Deleting these files can cause Windows or your applications to stop working.
    set /p sys_confirm="Are you ABSOLUTELY sure you want to target these? (Y/N): "
    if /i not "!sys_confirm!"=="Y" goto ext_menu
)

set "EXT="
for %%a in (%custom_input%) do (
    set "EXT=!EXT! *%%~a"
)
goto confirm

:confirm
cls
echo ========================================================
echo                     CONFIRMATION
echo ========================================================
echo WARNING: FILES DELETED THIS WAY BYPASS THE RECYCLE BIN 
echo AND ARE NOT EASILY RECOVERABLE!
echo.
echo DIRECTORY TO CLEAN : %TARGET_DIR%
echo FILE TYPE(S)       : %EXT%
echo ========================================================
echo.
set /p final_choice="Are you sure you want to DELETE these files? (Y/N): "

if /i "%final_choice%"=="Y" goto delete_files
if /i "%final_choice%"=="N" goto ext_menu
goto confirm

:delete_files
echo.
echo Deleting files...
for %%f in (%EXT%) do (
    del /s /f /q "%%f" 2>nul
)
echo.
echo Deletion complete!
pause
goto dir_menu
