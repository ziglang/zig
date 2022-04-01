#!/usr/bin/env python2
# PYTHON_ARGCOMPLETE_OK
"""
pytest: unit and functional testing with Python.
"""
__all__ = [
    'main',
    'UsageError',
    'cmdline',
    'hookspec',
    'hookimpl',
    '__version__',
]

if __name__ == '__main__': # if run as a script or by 'python -m pytest'
    # we trigger the below "else" condition by the following import
    import pytest
    import sys
    if sys.platform == 'win32':
        #Try to avoid opeing a dialog box if one of the tests causes a system error
        import ctypes
        winapi = ctypes.windll.kernel32
        SetErrorMode = winapi.SetErrorMode
        SetErrorMode.argtypes=[ctypes.c_int]

        SEM_FAILCRITICALERRORS = 1
        SEM_NOGPFAULTERRORBOX  = 2
        SEM_NOOPENFILEERRORBOX = 0x8000
        flags = SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX
        #Since there is no GetErrorMode, do a double Set
        old_mode = SetErrorMode(flags)
        SetErrorMode(old_mode | flags)
    raise SystemExit(pytest.main())

# else we are imported

from _pytest.config import (
    main, UsageError, _preloadplugins, cmdline,
    hookspec, hookimpl
)
from _pytest import __version__

_preloadplugins() # to populate pytest.* namespace so help(pytest) works

