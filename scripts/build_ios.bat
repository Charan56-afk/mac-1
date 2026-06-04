@echo off
REM iOS Build Script for Flutter - Appetize Ready (Windows)
REM This script builds the Flutter app for iOS simulator and creates a .zip file for Appetize

setlocal enabledelayedexpansion

echo.
echo ===================================
echo Flutter iOS Build Script - Windows
echo ===================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if errorlevel 1 (
    echo ERROR: Flutter is not installed. Please install Flutter first.
    pause
    exit /b 1
)

REM Parse arguments
set BUILD_TYPE=%1
if "%BUILD_TYPE%"=="" set BUILD_TYPE=simulator

set OUTPUT_DIR=%2
if "%OUTPUT_DIR%"=="" set OUTPUT_DIR=build\ios

echo Build Type: %BUILD_TYPE%
echo Output Directory: %OUTPUT_DIR%
echo.

REM Step 1: Clean previous builds
echo Cleaning previous builds...
call flutter clean
if errorlevel 1 (
    echo ERROR during flutter clean
    pause
    exit /b 1
)
echo Done!
echo.

REM Step 2: Get dependencies
echo Getting Flutter dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR during flutter pub get
    pause
    exit /b 1
)
echo Done!
echo.

REM Step 3: Build iOS app
echo Building iOS app...
echo.

if "%BUILD_TYPE%"=="simulator" (
    echo Building for iOS Simulator...
    REM Use ios-release which is compatible with simulators
    call flutter build ios --release --no-codesign
    if errorlevel 1 (
        echo ERROR during build
        pause
        exit /b 1
    )
    set APP_PATH=build\ios\Release-iphonesimulator
    set APP_NAME=Runner.app
    goto create_zip
)

if "%BUILD_TYPE%"=="device" (
    echo Building for iOS Device...
    call flutter build ios --release --no-codesign
    if errorlevel 1 (
        echo ERROR during build
        pause
        exit /b 1
    )
    set APP_PATH=build\ios\iphoneos
    set APP_NAME=Runner.app
    goto skip_zip
)

echo Unknown build type: %BUILD_TYPE%
echo Usage: build_ios.bat [simulator^|device]
pause
exit /b 1

:create_zip
echo.
echo Build completed successfully!
echo.

if exist "%APP_PATH%\%APP_NAME%" (
    echo App bundle found at: %APP_PATH%\%APP_NAME%
    echo.
    echo Creating Appetize-compatible .zip file...
    echo.
    
    REM Check if 7-Zip is installed
    where 7z >nul 2>nul
    if errorlevel 1 (
        echo WARNING: 7-Zip is not installed!
        echo Please install 7-Zip from: https://www.7-zip.org/download.html
        echo.
        echo After installing 7-Zip, run this command manually:
        echo cd %APP_PATH%
        echo 7z a -tzip %APP_NAME%.zip %APP_NAME%
        echo.
        pause
        goto skip_zip
    )
    
    REM Create the zip
    cd /d "%APP_PATH%"
    
    if exist "%APP_NAME%.zip" (
        echo Removing old zip file...
        del "%APP_NAME%.zip"
    )
    
    echo Creating zip: %APP_NAME%.zip
    7z a -tzip "%APP_NAME%.zip" "%APP_NAME%"
    
    if errorlevel 1 (
        echo ERROR: Failed to create zip file
        cd /d "%~dp0"
        pause
        exit /b 1
    )
    
    echo.
    echo SUCCESS! Zip file created!
    echo.
    echo File location: %APP_PATH%\%APP_NAME%.zip
    echo.
    echo Next steps:
    echo 1. Go to: https://appetize.io
    echo 2. Click "Upload an app"
    echo 3. Upload the zip file: %APP_PATH%\%APP_NAME%.zip
    echo 4. Wait for processing
    echo 5. Share the public link
    echo.
    
    cd /d "%~dp0"
    goto done
)

if not exist "%APP_PATH%\%APP_NAME%" (
    echo ERROR: App bundle not found at: %APP_PATH%\%APP_NAME%
    echo Please check the build logs above for errors.
    echo.
    echo Checking alternative paths...
    if exist "build\ios\Release-iphoneos\Runner.app" (
        echo Found: build\ios\Release-iphoneos\Runner.app
    )
    if exist "build\ios\Release-iphonesimulator\Runner.app" (
        echo Found: build\ios\Release-iphonesimulator\Runner.app
    )
    pause
    exit /b 1
)

:skip_zip
echo Build completed for device!
goto done

:done
echo.
echo ===================================
echo Build process finished!
echo ===================================
echo.
pause
