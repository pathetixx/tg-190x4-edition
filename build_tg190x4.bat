@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo ==================================================
echo TG 190x4 EDITION Builder
echo ==================================================

if not defined TG190X4_PREPARE_ONLY (
    if not defined TDESKTOP_API_ID (
        echo [ERROR] TDESKTOP_API_ID is not set.
        exit /b 2
    )
    if not defined TDESKTOP_API_HASH (
        echo [ERROR] TDESKTOP_API_HASH is not set.
        exit /b 2
    )
)

set "BUILD_PARALLEL=!TG190X4_BUILD_PARALLEL!"
if "!BUILD_PARALLEL!"=="" set "BUILD_PARALLEL=4"
set "ENABLE_AUTOUPDATE=!TG190X4_ENABLE_AUTOUPDATE!"
if "!ENABLE_AUTOUPDATE!"=="" set "ENABLE_AUTOUPDATE=OFF"

if /I not "!ENABLE_AUTOUPDATE!"=="ON" if /I not "!ENABLE_AUTOUPDATE!"=="OFF" (
    echo [ERROR] TG190X4_ENABLE_AUTOUPDATE must be ON or OFF.
    exit /b 2
)

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "!VSWHERE!" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "!VSWHERE!" (
    echo [ERROR] Could not find vswhere.exe.
    exit /b 1
)

for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -version [17.0^,18.0^) -property installationPath`) do set "VS_PATH=%%i"
if "!VS_PATH!"=="" (
    for %%p in (
        "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
        "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools"
    ) do (
        if "!VS_PATH!"=="" if exist "%%~p\Common7\Tools\VsDevCmd.bat" set "VS_PATH=%%~p"
    )
)
if "!VS_PATH!"=="" (
    echo [ERROR] Visual Studio 2022 installation path not found.
    exit /b 1
)

set "VSDEV_CMD=!VS_PATH!\Common7\Tools\VsDevCmd.bat"
set "VCVARS=!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat"
echo Loading Visual Studio developer environment...
if exist "!VSDEV_CMD!" (
    call "!VSDEV_CMD!" -arch=x64 -host_arch=x64
) else if exist "!VCVARS!" (
    call "!VCVARS!"
) else (
    set "VCVARS=!VS_PATH!\VC\Auxiliary\Build\vcvarsall.bat"
    if not exist "!VCVARS!" (
        echo [ERROR] Could not find a Visual Studio developer environment script.
        exit /b 1
    )
    call "!VCVARS!" x64
)
if errorlevel 1 (
    echo [ERROR] Failed to load the Visual Studio developer environment.
    exit /b 1
)
set "Platform=x64"

where python >nul 2>&1
if errorlevel 1 (
    for /d %%d in ("%LocalAppData%\Programs\Python\Python*") do (
        if exist "%%d\python.exe" set "PATH=%%d;%%d\Scripts;!PATH!"
    )
)
where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python was not found.
    exit /b 1
)

if not defined TG190X4_SKIP_PREPARE (
    echo Preparing dependencies using the existing cache...
    call Telegram\build\prepare\win.bat silent
    if errorlevel 1 (
        echo [ERROR] Dependency preparation failed.
        exit /b 1
    )
)

if defined TG190X4_PREPARE_ONLY (
    echo Dependencies are ready, stopping before the build as requested.
    exit /b 0
)

set "UPDATE_DEFINE=-DDESKTOP_APP_DISABLE_AUTOUPDATE=ON"
if /I "!ENABLE_AUTOUPDATE!"=="ON" (
    if not defined TG190X4_UPDATE_PREFIX (
        echo [ERROR] TG190X4_UPDATE_PREFIX is required when auto-update is enabled.
        exit /b 2
    )
    if "!TG190X4_UPDATE_PREFIX:~-1!" == "/" (
        echo [ERROR] TG190X4_UPDATE_PREFIX must not end with a slash.
        echo         The client appends /current4 and the package path itself.
        exit /b 2
    )
    call python tools\verify_private_fork.py --require-autoupdate
    if errorlevel 1 (
        echo [ERROR] Auto-update source verification failed.
        exit /b 2
    )
    set "UPDATE_DEFINE=-DDESKTOP_APP_DISABLE_AUTOUPDATE=OFF -DTG190X4_UPDATE_PREFIX=!TG190X4_UPDATE_PREFIX! -DTG190X4_BUILD_PACKER=ON"
)

echo Configuring TG 190x4 EDITION...
call Telegram\configure.bat x64 -DTDESKTOP_API_ID=!TDESKTOP_API_ID! -DTDESKTOP_API_HASH=!TDESKTOP_API_HASH! !UPDATE_DEFINE! !TG190X4_EXTRA_DEFINES!
if errorlevel 1 (
    echo [ERROR] Configuration failed.
    exit /b 1
)

echo Building Release with !BUILD_PARALLEL! parallel build slots...
cmake --build out --config Release --target Telegram --parallel !BUILD_PARALLEL!
if errorlevel 1 (
    echo [ERROR] Build failed.
    exit /b 1
)

if not exist "out\Release\TG190x4.exe" (
    echo [ERROR] Build finished, but out\Release\TG190x4.exe was not produced.
    exit /b 3
)
if /I "!ENABLE_AUTOUPDATE!"=="ON" if not exist "out\Release\Updater.exe" (
    echo [ERROR] Auto-update was enabled, but Updater.exe was not produced.
    exit /b 3
)

echo ==================================================
echo TG 190x4 EDITION compiled successfully.
echo Executable: out\Release\TG190x4.exe
echo Auto-update: !ENABLE_AUTOUPDATE!
echo ==================================================
exit /b 0
