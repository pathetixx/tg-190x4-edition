#!/usr/bin/env python3
"""Apply narrowly scoped CI fixes to Telegram's generated dependency pipeline."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PREPARE = ROOT / "Telegram" / "build" / "prepare" / "prepare.py"

OLD = '''win:
depends:patches/build_libvpx_win.sh
    bash --login ../patches/build_libvpx_win.sh
'''
NEW = '''win:
depends:patches/build_libvpx_win.sh
    SET "NUMBER_OF_PROCESSORS=1"
    bash --login ../patches/build_libvpx_win.sh
'''


def main() -> int:
    if not PREPARE.is_file():
        print(f"[ERROR] Missing prepare script: {PREPARE}", file=sys.stderr)
        return 1

    text = PREPARE.read_text(encoding="utf-8")
    if NEW in text:
        print("libvpx CI serialization patch is already applied.")
        return 0

    occurrences = text.count(OLD)
    if occurrences != 1:
        print(
            "[ERROR] Refusing to patch prepare.py: expected exactly one "
            f"libvpx marker, found {occurrences}.",
            file=sys.stderr,
        )
        return 1

    patched = text.replace(OLD, NEW, 1)
    with PREPARE.open("w", encoding="utf-8", newline="\n") as output:
        output.write(patched)

    print(
        "Applied libvpx CI fix: Debug and Release MSBuild invocations "
        "will run sequentially."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
