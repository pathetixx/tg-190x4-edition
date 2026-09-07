"""Finds mod code that still uses identifiers upstream deleted.

Git merges an upstream deletion and a mod usage without a conflict, so the
only signal is a compile error two hours into the build. Comparing what the
range removed against what the mod references catches it in seconds.
"""

from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
MOD_PATH = "Telegram/SourceFiles/ayu"
SEARCH_PATHS = ("Telegram/SourceFiles", "Telegram/Resources")
IDENTIFIER = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]{4,}\b")


def git(*args):
    result = subprocess.run(
        ("git",) + args,
        cwd=ROOT,
        capture_output=True,
        text=True)
    return result.stdout


def removed_identifiers(base, upstream):
    diff = git("diff", "-U0", base, upstream, "--", *SEARCH_PATHS)
    removed, added = set(), set()
    for line in diff.splitlines():
        if line.startswith("-") and not line.startswith("---"):
            removed |= set(IDENTIFIER.findall(line))
        elif line.startswith("+") and not line.startswith("+++"):
            added |= set(IDENTIFIER.findall(line))
    return removed - added


def mod_identifiers():
    listing = git("grep", "-hIo", "-E", IDENTIFIER.pattern, "--", MOD_PATH)
    return set(listing.split())


def main():
    if len(sys.argv) != 3:
        print("usage: check_removed_symbols.py <base-ref> <upstream-ref>")
        return 2
    base, upstream = sys.argv[1], sys.argv[2]

    suspects = sorted(removed_identifiers(base, upstream) & mod_identifiers())
    orphans = []
    for name in suspects:
        files = git("grep", "-l", "--", name, *SEARCH_PATHS).split()
        if not [path for path in files if f"{MOD_PATH}/" not in path]:
            orphans.append(name)

    print(f"identifiers removed upstream and referenced by the mod: {len(suspects)}")
    if orphans:
        for name in orphans:
            print(f"[ERROR] {name} is used only by mod code and defined nowhere")
        return 1
    print("every one of them still resolves outside the mod")
    return 0


if __name__ == "__main__":
    sys.exit(main())
