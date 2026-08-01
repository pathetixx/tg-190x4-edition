# Build instructions for Windows 64-bit

The build uses Visual Studio 2022 and the Windows 11 SDK. Keep the dependency folders outside the repository, for example `D:\TBuild\Libraries` and `D:\TBuild\ThirdParty`.

Install Python and Git, open an x64 Visual Studio developer command prompt, then prepare the dependencies once:

    git clone --recursive https://github.com/pathetixx/AyuGramDesktop.git tdesktop
    tdesktop\Telegram\build\prepare\win.bat

The preparation script uses cache keys. Re-running it after the first successful preparation should not rebuild unchanged dependencies.

## Build the project

From the repository root, provide your API credentials and run the Release builder:

    set TDESKTOP_API_ID=your_api_id
    set TDESKTOP_API_HASH=your_api_hash
    set AYUGRAM_BUILD_PARALLEL=4
    set AYUGRAM_ENABLE_AUTOUPDATE=OFF
    call build_ayugram.bat

The result is `out\Release\AyuGram.exe`. Keep `out` between builds so CMake can reuse object files. Remove it only when a genuinely clean build is required. Normal development uses Release only; Debug is intentionally not part of the regular builder because it creates a large second set of intermediate files.

Auto-update is intentionally fail-closed. Leave `AYUGRAM_ENABLE_AUTOUPDATE=OFF` until the fork has its own signed update channel. When it is ready, set `AYUGRAM_UPDATE_PREFIX` to a URL ending in `/`; the builder also checks that the legacy endpoint and official signing key have been replaced.

To package an already built Release without compiling again, install Inno Setup 6 and run:

    powershell -ExecutionPolicy Bypass -File scripts\package_windows.ps1

The package script creates an installer, a portable ZIP, and SHA-256 checksums under `artifacts`.
