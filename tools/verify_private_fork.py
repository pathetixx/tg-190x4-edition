#!/usr/bin/env python3
"""Fail fast when an upstream merge restores official Telegram identity.

This intentionally validates only the unpackaged desktop/Inno build.
The UWP/AppX manifest is still upstream-owned and must not be shipped
until a separate package identity and publisher certificate exist.
"""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

checks: list[tuple[str, str, bool]] = [
    ("Telegram/SourceFiles/core/version.h", 'AppId = "{53F49750-6209-4FBF-9CA8-7A333C87D666}"', True),
    ("Telegram/SourceFiles/core/version.h", 'AppName = "AyuGram Desktop"', True),
    ("Telegram/SourceFiles/core/version.h", 'AppFile = "AyuGram"', True),
    ("Telegram/SourceFiles/core/version.h", 'AppVersionStr = "7.0.6"', True),
    ("Telegram/build/setup.iss", '#define MyAppExeName "AyuGram.exe"', True),
    ("Telegram/build/setup.iss", r'Source: "{#ReleasePath}\{#MyAppExeName}"', True),
    ("Telegram/build/setup.iss", r'UninstallDisplayIcon={app}\{#MyAppExeName}', True),
    ("Telegram/Resources/winrc/Telegram.rc", '"CompanyName", "Radolyn Labs"', True),
    ("Telegram/Resources/winrc/Telegram.rc", '"ProductName", "AyuGram Desktop"', True),
    ("Telegram/Resources/winrc/Updater.rc", '"FileDescription", "AyuGram Desktop Updater"', True),
    ("build_ayugram.bat", "DESKTOP_APP_DISABLE_AUTOUPDATE=ON", True),
    ("build_ayugram.bat", "TDESKTOP_API_ID=2040", False),
    ("build_ayugram.bat", "TDESKTOP_API_HASH=b18441a1ff607e10a989891a5462e627", False),
    ("Telegram/build/setup.iss", r'Source: "{#ReleasePath}\Telegram.exe"', False),
]

errors: list[str] = []
for relative, needle, should_exist in checks:
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"{relative}: file is missing")
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    found = needle in text
    if should_exist and not found:
        errors.append(f"{relative}: required marker missing: {needle}")
    elif not should_exist and found:
        errors.append(f"{relative}: forbidden marker present: {needle}")

appx = ROOT / "Telegram/Resources/uwp/AppX/AppxManifest.xml"
if appx.is_file():
    appx_text = appx.read_text(encoding="utf-8", errors="replace")
    if "TelegramMessengerLLP.TelegramDesktop" in appx_text:
        print(
            "[WARN] AppX manifest still has the official Telegram Store identity. "
            "Do not build or distribute AppX/MSIX from this tree.",
            file=sys.stderr,
        )

if errors:
    print("Private-fork verification FAILED:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    raise SystemExit(1)

print("Private-fork verification passed.")
