'''
This file is part of Telegram Desktop,
the official desktop application for the Telegram messaging service.

For license and copyright information please follow this link:
https://github.com/telegramdesktop/tdesktop/blob/master/LEGAL
'''

# Finds merge results that git produced without a conflict but that do not
# compile. Both sides adding the same declaration is the usual case: git keeps
# both copies and the duplicate is only reported by the compiler, after an hour
# of building.

import argparse
import collections
import subprocess
import sys

TRIVIAL = ('{', '}', '};', '', 'return;', 'break;', 'continue;')


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit('failed: ' + ' '.join(args) + '\n' + result.stderr)
    return result.stdout


def changed_files(base, ref):
    return set(run('git', 'diff', '--name-only', base, ref).splitlines())


def added_lines(base, ref, path):
    diff = run('git', 'diff', '--unified=0', base, ref, '--', path)
    return [line[1:] for line in diff.splitlines()
            if line.startswith('+') and not line.startswith('+++')]


def interesting(line):
    stripped = line.strip()
    if len(stripped) < 12 or stripped in TRIVIAL:
        return False
    return not (stripped.startswith('//')
                or stripped.startswith('*')
                or stripped.startswith('#include'))


def main():
    parser = argparse.ArgumentParser(
        description='Report lines both sides of a merge added to one file.')
    parser.add_argument('ours', help='the fork side, usually main')
    parser.add_argument('theirs', help='the upstream side, usually a tag')
    parser.add_argument(
        '--max-copies',
        type=int,
        default=3,
        help='ignore lines repeated more than this, they are boilerplate')
    parser.add_argument(
        '--extensions',
        default='.h,.hpp,.cpp,.cmake,.txt,.strings',
        help='comma separated list of file suffixes to check')
    arguments = parser.parse_args()

    suffixes = tuple(arguments.extensions.split(','))
    base = run('git', 'merge-base', arguments.ours, arguments.theirs).strip()
    both = sorted(
        path for path in changed_files(base, arguments.ours)
        & changed_files(base, arguments.theirs)
        if path.endswith(suffixes))

    findings = []
    for path in both:
        ours = set(filter(interesting, added_lines(base, arguments.ours, path)))
        if not ours:
            continue
        shared = ours & set(added_lines(base, arguments.theirs, path))
        if not shared:
            continue
        try:
            with open(path, encoding='utf-8') as opened:
                counts = collections.Counter(opened.read().splitlines())
        except OSError:
            continue
        for line in sorted(shared):
            if 1 < counts[line] <= arguments.max_copies:
                findings.append((path, counts[line], line.strip()))

    print('files touched by both sides: ' + str(len(both)))
    if not findings:
        print('no duplicated additions found')
        return 0

    print('duplicated additions: ' + str(len(findings)))
    for path, count, line in findings:
        print('  ' + path + ' (' + str(count) + ' copies)')
        print('    ' + line)
    print('')
    print('Each of these was added by both sides and now appears more than')
    print('once. Check whether the merge left a duplicate declaration.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
