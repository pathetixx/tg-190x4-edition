@echo off
setlocal enabledelayedexpansion

echo ==================================================
echo AyuGram Desktop Auto-Builder
echo ==================================================

:: 1. Find Visual Studio 2022 using vswhere
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "!VSWHERE!" (
    set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
)

if not exist "!VSWHERE!" (
    echo [ERROR] Could not find vswhere.exe. Please ensure Visual Studio 2022 is installed.
    pause
    exit /b 1
)

:: Find installation path
for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -version [17.0^,18.0^) -property installationPath`) do (
    set "VS_PATH=%%i"
)

if "!VS_PATH!"=="" (
    echo [ERROR] Visual Studio 2022 installation path not found.
    pause
    exit /b 1
)

echo Found Visual Studio 2022 at: !VS_PATH!

:: 2. Load x64 Native Tools Environment
set "VSDEV_CMD=!VS_PATH!\Common7\Tools\VsDevCmd.bat"
set "VCVARS=!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat"

echo Loading VS Developer Environment...
if exist "!VSDEV_CMD!" (
    call "!VSDEV_CMD!" -arch=x64 -host_arch=x64
) else if exist "!VCVARS!" (
    call "!VCVARS!"
) else (
    set "VCVARS=!VS_PATH!\VC\Auxiliary\Build\vcvarsall.bat"
    if not exist "!VCVARS!" (
        echo [ERROR] Could not find VsDevCmd.bat, vcvars64.bat or vcvarsall.bat.
        pause
        exit /b 1
    )
    call "!VCVARS!" x64
)
if errorlevel 1 (
    echo [ERROR] Failed to load the Visual Studio developer environment.
    pause
    exit /b 1
)
set "Platform=x64"

:: 3. Find Python and add to PATH if not already present
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Python not found in system PATH. Searching standard folders...
    for /d %%d in ("%LocalAppData%\Programs\Python\Python*") do (
        if exist "%%d\python.exe" (
            set "PATH=%%d;%%d\Scripts;!PATH!"
            echo Added Python to build PATH: %%d
        )
    )
)

:: Re-verify Python presence
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python not found. Please install Python and add it to PATH.
    pause
    exit /b 1
)

:: 4. Run Win.bat dependency preparation in silent mode
echo ==================================================
echo Preparing dependencies (silent mode)...
echo ==================================================
call Telegram\build\prepare\win.bat silent
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Dependency preparation failed.
    pause
    exit /b %ERRORLEVEL%
)

:: 5. Configure project
echo ==================================================
echo Configuring AyuGram...
echo ==================================================
call Telegram\configure.bat x64 -D TDESKTOP_API_ID=2040 -D TDESKTOP_API_HASH=b18441a1ff607e10a989891a5462e627
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Configuration failed.
    pause
    exit /b %ERRORLEVEL%
)

:: 6. Build project
echo ==================================================
echo Building AyuGram (Release)...
echo ==================================================
cmake --build out --config Release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed.
    pause
    exit /b %ERRORLEVEL%
)

echo ==================================================
echo AyuGram compiled successfully!
echo The executable is located at: out\Release\AyuGram.exe
echo ==================================================
pause
