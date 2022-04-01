import sys

import py
import pytest

from rpython.tool.udir import udir
from pypy import pypydir
from pypy.interpreter.error import OperationError
from pypy.interpreter.gateway import unwrap_spec, interp2app_temp, WrappedDefault
from pypy.module.posix.interp_posix import convert_seconds, path_or_fd, Path


class TestPexpect(object):
    # XXX replace with AppExpectTest class as soon as possible
    def setup_class(cls):
        try:
            import pexpect
        except ImportError:
            pytest.skip("pexpect not found")

    def _spawn(self, *args, **kwds):
        import pexpect
        kwds.setdefault('timeout', 600)
        print 'SPAWN:', args, kwds
        child = pexpect.spawn(*args, maxread=5000, **kwds)
        child.logfile = sys.stdout
        return child

    def spawn(self, argv):
        py_py = py.path.local(pypydir).join('bin', 'pyinteractive.py')
        return self._spawn(sys.executable, [str(py_py), '-S'] + argv)

    def test_ttyname(self):
        source = py.code.Source("""
        import os, sys
        assert os.ttyname(sys.stdin.fileno())
        print('ok!')
        """)
        f = udir.join("test_ttyname.py")
        f.write(source)
        child = self.spawn([str(f)])
        child.expect('ok!')


def test_convert_seconds_simple(space):
    w_time = space.wrap(123.456)
    assert convert_seconds(space, w_time) == (123, 456000000)

def test_convert_seconds_full(space):
    try:
        from hypothesis import given
        from hypothesis.strategies import integers
    except ImportError:
        pytest.skip("hypothesis not found")

    @given(s=integers(min_value=-2**30, max_value=2**30),
           ns=integers(min_value=0, max_value=10**9))
    def _test_convert_seconds_full(space, s, ns):
        w_time = space.wrap(s + ns * 1e-9)
        sec, nsec = convert_seconds(space, w_time)
        assert 0 <= nsec < 1e9
        MAX_ERR = 1e9 / 2**23 + 1  # nsec has 53 - 30 = 23 bits of precisin
        err = (sec * 10**9 + nsec) - (s * 10**9 + ns)
        assert -MAX_ERR < err < MAX_ERR
    _test_convert_seconds_full(space)

def test_path_or_fd_nullable(space):
    @unwrap_spec(p=path_or_fd(allow_fd=False, nullable=True))
    def f(space, p=None):
        return p.w_path
    w_f = space.wrap(interp2app_temp(f))
    res = space.call_function(w_f, space.w_None)
    assert res is space.w_None
    res = space.call_function(w_f)
    assert res is space.w_None

    @unwrap_spec(p=path_or_fd(allow_fd=False))
    def g(space, p):
        return p
    w_g = space.wrap(interp2app_temp(g))
    with pytest.raises(OperationError) as exc:
        res = space.call_function(w_g, space.w_None)
    assert exc.value.match(space, space.w_TypeError)
