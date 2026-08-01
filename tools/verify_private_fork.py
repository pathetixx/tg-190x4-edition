from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8")


def version_values():
    build_version = read("Telegram/build/version")
    version_header = read("Telegram/SourceFiles/core/version.h")
    build_number = re.search(r"^AppVersion\s+(\d+)$", build_version, re.MULTILINE)
    build_string = re.search(r"^AppVersionStr\s+([^\s]+)$", build_version, re.MULTILINE)
    header_number = re.search(r"AppVersion\s*=\s*(\d+)", version_header)
    header_string = re.search(r'AppVersionStr\s*=\s*"([^"]+)"', version_header)
    if not all((build_number, build_string, header_number, header_string)):
        return None
    return {
        "build_number": build_number.group(1),
        "build_string": build_string.group(1),
        "header_number": header_number.group(1),
        "header_string": header_string.group(1),
    }


def main():
    require_autoupdate = "--require-autoupdate" in sys.argv[1:]
    errors = []
    setup = read("Telegram/build/setup.iss")
    build_script = read("build_ayugram.bat")
    cmake = read("Telegram/CMakeLists.txt")
    updater_source = read("Telegram/SourceFiles/_other/updater_win.cpp")
    config = read("Telegram/SourceFiles/config.h")
    localstorage = read("Telegram/SourceFiles/storage/localstorage.cpp")
    packer = read("Telegram/SourceFiles/_other/packer.cpp")
    app_resource = read("Telegram/Resources/winrc/Telegram.rc")
    updater_resource = read("Telegram/Resources/winrc/Updater.rc")

    required_setup = (
        ('#define MyAppName "AyuGram Desktop"', "installer name"),
        ('#define MyAppExeName "AyuGram.exe"', "installer executable"),
        ('{#ReleasePath}\\{#MyAppExeName}', "installer source executable"),
        ('UninstallDisplayIcon={app}\\{#MyAppExeName}', "uninstaller icon"),
    )
    for needle, label in required_setup:
        if needle not in setup:
            errors.append(f"Missing {label}: {needle}")
    if '{#ReleasePath}\\Telegram.exe' in setup:
        errors.append("Installer still packages Telegram.exe")

    if 'set(output_name "AyuGram")' not in cmake:
        errors.append("CMake output name is not AyuGram")
    if 'VALUE "ProductName", "AyuGram Desktop"' not in app_resource:
        errors.append("Windows application ProductName is not AyuGram Desktop")
    if 'VALUE "FileDescription", "AyuGram Desktop"' not in app_resource:
        errors.append("Windows application FileDescription is not AyuGram Desktop")
    if 'VALUE "ProductName", "AyuGram Desktop"' not in updater_resource:
        errors.append("Updater ProductName is not AyuGram Desktop")
    if "{53F49750-6209-4FBF-9CA8-7A333C87D666}_is1" not in updater_source:
        errors.append("Updater registry identity does not match the AyuGram installer")
    if 'L"AyuGram Desktop"' not in updater_source:
        errors.append("Updater fallback directory is not AyuGram Desktop")
    if "D1ED" in updater_source or 'L"Telegram Desktop"' in updater_source:
        errors.append("Updater still contains the Telegram installer identity")

    if re.search(r"TDESKTOP_API_(?:ID|HASH)=\s*(?:2040|b18441a1ff607e10a989891a5462e627)", build_script, re.IGNORECASE):
        errors.append("Build script contains the public Telegram bootstrap credentials")

    if require_autoupdate:
        if "update.ayugram.one" in localstorage:
            errors.append("Auto-update still points to the legacy AyuGram endpoint")
        official_key_marker = "MIGJAoGBAOIENxe1sfT2t7b+HUMpnT6RnN/sCqY0JjK7/1A/59daDc6i/K4023jw"
        if official_key_marker in config or official_key_marker in packer:
            errors.append("Auto-update still uses the official Telegram signing key")

    versions = version_values()
    if versions is None:
        errors.append("Could not parse the generated version files")
    elif versions["build_number"] != versions["header_number"]:
        errors.append("AppVersion differs between Telegram/build/version and core/version.h")
    elif versions["build_string"] != versions["header_string"]:
        errors.append("AppVersionStr differs between Telegram/build/version and core/version.h")

    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        return 1
    print("Private fork checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
