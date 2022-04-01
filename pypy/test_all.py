#! /usr/bin/env python
"""
PyPy Test runner interface
--------------------------

Running pytest.py starts py.test, the testing tool
we use in PyPy.  It is distributed along with PyPy,
but you may get more information about it at
http://pytest.org/.

Note that it makes no sense to run all tests at once.
You need to pick a particular subdirectory and run

    cd pypy/.../test
    ../../../pytest.py [options]

For more information, use test_all.py -h.
"""
import sys, os
import shutil


if __name__ == '__main__':
    if len(sys.argv) == 1 and os.path.dirname(sys.argv[0]) in '.':
        print >> sys.stderr, __doc__
        sys.exit(2)
    toplevel = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    # Add toplevel repository dir to sys.path
    sys.path.insert(0, toplevel)
    import pytest
    if sys.platform == 'win32':
        #Try to avoid opening a dialog box if one of the tests causes a system error
        # We do this in runner.py, but buildbots run twisted which ruins inheritance
        # in windows subprocesses.
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

    sys.exit(pytest.main())
