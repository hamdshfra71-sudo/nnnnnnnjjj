@echo off
echo ==========================================
echo      KSOS iOS Project Uploader (Fixed)
echo ==========================================
echo.
echo Using Git from absolute path...
set "GIT_PATH=C:\Program Files\Git\cmd\git.exe"

"%GIT_PATH%" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Git executable not found at "%GIT_PATH%"
    echo Please install Git manually or restart your computer.
    pause
    exit /b
)

echo.
echo Cleaning up previous attempts...
if exist .git (
    echo Removing old git history...
    rmdir /s /q .git
)

echo.
echo Securing sensitive files...
echo assets/nnnnnn-7793e-firebase-adminsdk-fbsvc-a58e16ec79.json >> .gitignore
echo google-services.json >> .gitignore

echo.
echo Configuring Git identity...
"%GIT_PATH%" config --global user.email "auto@ksos.app"
"%GIT_PATH%" config --global user.name "KSOS Uploader"

echo.
echo Initializing repository...
"%GIT_PATH%" init
"%GIT_PATH%" add .
"%GIT_PATH%" commit -m "Upload project for iOS build (Clean)"
"%GIT_PATH%" branch -M main

echo.
echo Adding remote server...
"%GIT_PATH%" remote add origin https://github.com/hamdshfra71-sudo/nnnnnnnjjj.git

echo.
echo ==========================================
echo PUSHING TO GITHUB...
echo ==========================================
echo.
echo NOTE: A browser window or login prompt may appear.
echo Please sign in to approve the upload.
echo.
"%GIT_PATH%" push -u --force origin main

echo.
if %errorlevel% equ 0 (
    echo SUCCESS! Project uploaded successfully.
    echo Now go to Codemagic.io and build your iOS app.
) else (
    echo Upload failed. Please check your internet or login details.
)
pause
