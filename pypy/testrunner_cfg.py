# nightly test configuration for the paraller runner
import os

DIRS_SPLIT = [
    'translator/c', 'rlib',
    'memory/test', 'jit/metainterp',
    'jit/backend/arm', 'jit/backend/x86',
    'jit/backend/zarch', 'module/cpyext/test',
    'jit/backend/aarch64',
]

def collect_one_testdir(testdirs, reldir, tests):
    for dir in DIRS_SPLIT:
        if reldir.startswith(dir):
            testdirs.extend(tests)
            break
    else:
        testdirs.append(reldir)


_cherrypick = os.getenv('PYPYCHERRYPICK', '')
if _cherrypick:
    cherrypick = _cherrypick.split(':')
