"""Checks that the update manifest is published under the name clients ask for.

The client requests "<prefix>/current" + Platform::AutoUpdateVersion(), which
lives in lib_base and moved from 4 to 6 in the 7.2.x range. Publishing only
the old name leaves every client silently stuck on its installed version:
the request 404s and the checker reports no update.
"""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
PUBLISH = ROOT / "scripts/publish_update.ps1"
INFO = ROOT / "Telegram/lib_base/base/platform/win/base_info_win.cpp"


def main():
    listed = re.search(r"\$manifestVersions = @\(([^)]*)\)", PUBLISH.read_text())
    if not listed:
        print(f"[ERROR] no $manifestVersions list in {PUBLISH.name}")
        return 1
    names = {int(item) for item in re.findall(r"\d+", listed.group(1))}

    if not INFO.exists():
        print(f"lib_base is not checked out, published names: {sorted(names)}")
        return 0

    asked = re.search(
        r"int AutoUpdateVersion\(\)\s*\{\s*return\s+(\d+)\s*;",
        INFO.read_text())
    if not asked:
        print(f"[ERROR] no AutoUpdateVersion() in {INFO.name}")
        return 1
    version = int(asked.group(1))
    if version not in names:
        print(f"[ERROR] clients ask for current{version}, "
              f"publish_update.ps1 writes {sorted(names)}")
        return 1
    print(f"clients ask for current{version}, published: {sorted(names)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
