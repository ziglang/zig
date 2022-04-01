# Assumes that _resource_cffi is there already
from __future__ import absolute_import
import os
import py
import sys
from pypy.module.test_lib_pypy import test_resource   # side-effect: skip()


from lib_pypy import _pypy_wait

def test_os_wait3():
    wait3 = _pypy_wait.wait3
    exit_status = 0x33
    child = os.fork()
    if child == 0: # in child
        os._exit(exit_status)
    else:
        pid, status, rusage = wait3(0)
        assert child == pid
        assert os.WIFEXITED(status)
        assert os.WEXITSTATUS(status) == exit_status
        assert isinstance(rusage.ru_utime, float)
        assert isinstance(rusage.ru_maxrss, int)

def test_os_wait4():
    wait4 = _pypy_wait.wait4
    exit_status = 0x33
    child = os.fork()
    if child == 0: # in child
        os._exit(exit_status)
    else:
        pid, status, rusage = wait4(child, 0)
        assert child == pid
        assert os.WIFEXITED(status)
        assert os.WEXITSTATUS(status) == exit_status
        assert isinstance(rusage.ru_utime, float)
        assert isinstance(rusage.ru_maxrss, int)

def test_errors():
    # MacOS ignores invalid options
    if sys.platform != 'darwin':
        py.test.raises(OSError, _pypy_wait.wait3, -999)
    py.test.raises(OSError, _pypy_wait.wait4, -999, -999)
