# custom test collection for the app-level testrunner
import platform

DIRS_SPLIT = {
    'arm': ['interpreter/astcompiler/test',
            'interpreter/pyparser/test',
            'interpreter/test',
            'module/test_lib_pypy',
            'objspace/std/test',
    ],
}


def get_arch():
    arch = platform.machine().lower()
    if arch.startswith('arm'):
        return 'arm'
    if arch.startswith('x86'):
        return 'x86'
    return arch


def collect_one_testdir(testdirs, reldir, tests):
    arch = get_arch()
    dirsplit = DIRS_SPLIT.get(arch, [])
    for dir in dirsplit:
        if reldir.startswith(dir):
            testdirs.extend(tests)
            break
    else:
        testdirs.append(reldir)
