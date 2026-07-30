#!/usr/bin/env python3
"""Apply narrowly scoped CI fixes to Telegram's dependency pipeline."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PREPARE = ROOT / "Telegram" / "build" / "prepare" / "prepare.py"
WRAPPER = ROOT / "tools" / "build_libvpx_win_ci.sh"

OLD = '''win:
depends:patches/build_libvpx_win.sh
    bash --login ../patches/build_libvpx_win.sh
'''


def replacement() -> str:
    wrapper = str(WRAPPER)
    return f'''win:
depends:patches/build_libvpx_win.sh
    copy /Y "{wrapper}" ..\\patches\\build_libvpx_win_ci.sh >nul
    if errorlevel 1 exit /b 1
    SET "NUMBER_OF_PROCESSORS=1"
    bash --login ../patches/build_libvpx_win_ci.sh
'''


def main() -> int:
    if not PREPARE.is_file():
        print(f"[ERROR] Missing prepare script: {PREPARE}", file=sys.stderr)
        return 1
    if not WRAPPER.is_file():
        print(f"[ERROR] Missing libvpx CI wrapper: {WRAPPER}", file=sys.stderr)
        return 1

    text = PREPARE.read_text(encoding="utf-8")
    new = replacement()
    if new in text:
        print("libvpx single-node MSBuild patch is already applied.")
        return 0

    occurrences = text.count(OLD)
    if occurrences != 1:
        print(
            "[ERROR] Refusing to patch prepare.py: expected exactly one "
            f"libvpx marker, found {occurrences}.",
            file=sys.stderr,
        )
        return 1

    patched = text.replace(OLD, new, 1)
    with PREPARE.open("w", encoding="utf-8", newline="\n") as output:
        output.write(patched)

    print(
        "Applied libvpx CI fix: make uses one worker and generated MSBuild "
        "is forced to one project node."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
