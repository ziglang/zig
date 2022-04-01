import sys
import importlib
import pytest

# This is a workaround for a dubious feature of CPython's test suite: it skips
# tests silently if importing a module fails.  This makes some partial sense
# for CPython itself when testing C extension modules directly, because very
# often (but not always) a C extension module is either completely absent or
# imports successfully.  But for PyPy it's a mess because it can hide mistakes
# very easily, and it did.  So the list we build here should contain the names
# of every module that CPython's tests import with test.support.import_module()
# but that should really be present on the running platform.


expected_modules = []

# ----- everywhere -----
expected_modules += [
    '_opcode',
    'asyncio',
    'bz2',
    'code',
    'ctypes.test',
    'gzip',
    '_hashlib',
    'lzma',
    'mmap',
    '_multiprocessing',
    'multiprocessing.synchronize',
    'select',
    '_sqlite3',
    'ssl',
    '_thread',
    'threading',
    'zlib',
]

# ----- non-Windows -----
if sys.platform != 'win32':
    expected_modules += [
        'curses',
        'curses.ascii',
        'curses.textpad',
        'dbm',
        'dbm.gnu',
        'fcntl',
        'grp',
        'posix',
        'pty',
        'pwd',
        'readline',
        'resource',
        'syslog',
        'termios',
    ]
else:
    # ----- Windows only -----
    expected_modules += [
        'winreg',
    ]

# ----- Linux only -----
if sys.platform.startswith('linux'):
    expected_modules += [
        'crypt',
    ]


# ------------------------------------------------

@pytest.fixture(scope="module", params=expected_modules)
def modname(request):
    return request.param

def test_expected_modules(modname):
    importlib.import_module(modname)
