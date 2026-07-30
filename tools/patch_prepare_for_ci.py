#!/usr/bin/env python3
"""Apply narrowly scoped CI fixes to Telegram's dependency pipeline."""

from __future__ import annotations

import ast
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
    # This text is embedded inside a Python triple-quoted string in prepare.py.
    # Windows backslashes therefore need a second level of escaping; otherwise
    # paths such as \a, \t and \b become control characters at prepare runtime.
    wrapper_for_python_source = str(WRAPPER).replace("\\", "\\\\")
    return f'''win:
depends:patches/build_libvpx_win.sh
    copy /Y "{wrapper_for_python_source}" ..\\\\patches\\\\build_libvpx_win_ci.sh >nul
    if errorlevel 1 exit /b 1
    SET "NUMBER_OF_PROCESSORS=1"
    bash --login ../patches/build_libvpx_win_ci.sh
'''


def validate_embedded_copy_command(source: str) -> bool:
    candidates = [
        line
        for line in source.splitlines()
        if 'copy /Y "' in line and "build_libvpx_win_ci.sh" in line
    ]
    if len(candidates) != 1:
        print(
            "[ERROR] Expected exactly one generated libvpx copy command, "
            f"found {len(candidates)}.",
            file=sys.stderr,
        )
        return False

    source_line = candidates[0]
    try:
        runtime_line = ast.literal_eval(f'"""{source_line}"""')
    except (SyntaxError, ValueError) as error:
        print(
            f"[ERROR] Generated copy command is not a valid Python string: {error}",
            file=sys.stderr,
        )
        return False

    expected = (
        f'    copy /Y "{WRAPPER}" '
        + r'..\patches\build_libvpx_win_ci.sh >nul'
    )
    if runtime_line != expected:
        print("[ERROR] Generated copy command changes after Python parsing.", file=sys.stderr)
        print(f"Expected: {expected!r}", file=sys.stderr)
        print(f"Actual:   {runtime_line!r}", file=sys.stderr)
        return False

    if any(ord(character) < 32 for character in runtime_line):
        print(
            "[ERROR] Generated copy command contains control characters.",
            file=sys.stderr,
        )
        return False

    return True


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
        if not validate_embedded_copy_command(text):
            return 1
        print("libvpx single-node MSBuild patch is already applied and valid.")
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
    if not validate_embedded_copy_command(patched):
        return 1

    with PREPARE.open("w", encoding="utf-8", newline="\n") as output:
        output.write(patched)

    print(
        "Applied libvpx CI fix: escaped wrapper path, make uses one worker, "
        "and generated MSBuild is forced to one project node."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
