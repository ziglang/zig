"""
Some of the files in this repo are used also by PyPy tests, which run on
python2.7.

This script tries to import all of them: it does not check any behavior, just
that they are importable and thus are not using any py3-specific syntax.

This script assumes that pathlib and pytest are installed (because the modules
try to import them).
"""

from __future__ import print_function
import sys
import traceback
import py

ROOT = py.path.local(__file__).join('..', '..')
TEST_DIRS = [ROOT / 'test', ROOT / 'test' / 'debug']

# PyPy does NOT import these files using py2
PY3_ONLY = ['test_support.py', 'test_handles.py']

def try_import(name):
    try:
        if isinstance(name, py.path.local):
            print('Trying to import %s... ' % ROOT.bestrelpath(name), end='')
            name.pyimport()
        else:
            print('Trying to import %s... ' % name, end='')
            __import__(name)
    except:
        print('ERROR!')
        print()
        traceback.print_exc(file=sys.stdout)
        print()
        return False
    else:
        print('OK')
        return True

def try_import_hpy_devel():
    """
    To import hpy.devel we need to create an empty hpy/__init__.py, because
    python2.7 does not support namespace packages.

    Return the number of failed imports.
    """
    failed = 0
    init_py = ROOT.join('hpy', '__init__.py')
    assert init_py.check(exists=False)
    try:
        init_py.write('') # create an empty __init__.py
        if not try_import('hpy.devel'):
            failed += 1
    finally:
        init_py.remove()
    return failed

def try_import_tests(dirs):
    failed = 0
    for d in dirs:
        for t in d.listdir('test_*.py'):
            if t.basename in PY3_ONLY:
                continue
            if not try_import(t):
                failed += 1
    return failed


def main():
    if sys.version_info[:2] != (2, 7):
        print('ERROR: this script should be run on top of python 2.7')
        sys.exit(1)

    sys.path.insert(0, str(ROOT))
    failed = 0
    failed += try_import_hpy_devel()
    failed += try_import_tests(TEST_DIRS)
    print()
    if failed == 0:
        print('Everything ok!')
    else:
        print('%d failed imports :(' % failed)
        sys.exit(1)

if __name__ == '__main__':
    main()
