@echo off
setlocal enabledelayedexpansion

echo ==================================================
echo AyuGram Desktop Private Fork Builder
echo ==================================================

:: Never commit API credentials. Provide them for the current shell:
::   set TDESKTOP_API_ID=123456
::   set TDESKTOP_API_HASH=0123456789abcdef0123456789abcdef
if not defined TDESKTOP_API_ID (
    echo [ERROR] TDESKTOP_API_ID is not set.
    exit /b 2
)
if not defined TDESKTOP_API_HASH (
    echo [ERROR] TDESKTOP_API_HASH is not set.
    exit /b 2
)

:: 1. Find Visual Studio 2022 using vswhere
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "!VSWHERE!" (
    set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
)

if not exist "!VSWHERE!" (
    echo [ERROR] Could not find vswhere.exe. Please ensure Visual Studio 2022 is installed.
    exit /b 1
)

:: Find installation path
for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -version [17.0^,18.0^) -property installationPath`) do (
    set "VS_PATH=%%i"
)

if "!VS_PATH!"=="" (
    echo [ERROR] Visual Studio 2022 installation path not found.
    exit /b 1
)

echo Found Visual Studio 2022 at: !VS_PATH!

:: 2. Load x64 Native Tools Environment
set "VCVARS=!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat"
if not exist "!VCVARS!" (
    set "VCVARS=!VS_PATH!\VC\Auxiliary\Build\vcvarsall.bat"
    set "VCVARS_ARGS=x64"
)

if not exist "!VCVARS!" (
    echo [ERROR] Could not find vcvars64.bat or vcvarsall.bat in Visual Studio installation.
    exit /b 1
)

echo Loading VS Developer Environment...
if "!VCVARS_ARGS!"=="" (
    call "!VCVARS!"
) else (
    call "!VCVARS!" !VCVARS_ARGS!
)
if errorlevel 1 exit /b %ERRORLEVEL%

:: 3. Find Python and add to PATH if not already present
where python >nul 2>&1
if errorlevel 1 (
    echo Python not found in system PATH. Searching standard folders...
    for /d %%d in ("%LocalAppData%\Programs\Python\Python*") do (
        if exist "%%d\python.exe" (
            set "PATH=%%d;%%d\Scripts;!PATH!"
            echo Added Python to build PATH: %%d
        )
    )
)

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found. Please install Python and add it to PATH.
    exit /b 1
)

:: 4. Verify fork identity before spending time on dependencies.
python tools\verify_private_fork.py
if errorlevel 1 exit /b %ERRORLEVEL%

:: Serialize libvpx Debug/Release builds. Its generated make target starts both
:: MSBuild configurations concurrently and can corrupt a shared NASM object on
:: a hosted runner.
python tools\patch_prepare_for_ci.py
if errorlevel 1 exit /b %ERRORLEVEL%

:: 5. Prepare dependencies
echo ==================================================
echo Preparing dependencies...
echo ==================================================
call Telegram\build\prepare\win.bat silent
if errorlevel 1 (
    echo [ERROR] Dependency preparation failed.
    exit /b %ERRORLEVEL%
)

:: 6. Configure. Auto-update stays disabled until this fork owns its
:: update endpoint and signing key.
echo ==================================================
echo Configuring AyuGram private fork...
echo ==================================================
call Telegram\configure.bat x64 ^
  -D TDESKTOP_API_ID=!TDESKTOP_API_ID! ^
  -D TDESKTOP_API_HASH=!TDESKTOP_API_HASH! ^
  -D DESKTOP_APP_DISABLE_AUTOUPDATE=ON
if errorlevel 1 (
    echo [ERROR] Configuration failed.
    exit /b %ERRORLEVEL%
)

:: 7. Build
echo ==================================================
echo Building AyuGram (Release)...
echo ==================================================
cmake --build out --config Release --target Telegram
if errorlevel 1 (
    echo [ERROR] Build failed.
    exit /b %ERRORLEVEL%
)

if not exist "out\Release\AyuGram.exe" (
    echo [ERROR] Build finished, but out\Release\AyuGram.exe was not produced.
    exit /b 3
)

echo ==================================================
echo AyuGram compiled successfully.
echo Executable: out\Release\AyuGram.exe
echo Auto-update: disabled
echo ==================================================
exit /b 0
