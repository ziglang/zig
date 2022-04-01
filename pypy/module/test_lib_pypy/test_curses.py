import pytest
import sys
if sys.platform == 'win32':
    #This module does not exist in windows
    pytest.skip('no curses on windows')

# Check that lib_pypy.cffi finds the correct version of _cffi_backend.
# Otherwise, the test is skipped.  It should never be skipped when run
# with "pypy py.test -A" and _curses_build.py has been run with pypy.
try:
    from lib_pypy import _curses_cffi
except ImportError:
    # On CPython, "pip install cffi".  On old PyPy's, no chance
    pytest.skip("install cffi and run lib_pypy/_curses_build.py manually first")

from lib_pypy import _curses


lib = _curses.lib


def test_color_content(monkeypatch):
    class patched:
        OK = lib.OK
        ERR = lib.ERR
        def color_content(self, color, r, g, b):
            r[0], g[0], b[0] = 42, 43, 44
            return lib.OK
    monkeypatch.setattr(_curses, '_ensure_initialised_color', lambda: None)
    monkeypatch.setattr(_curses, 'lib', patched())

    assert _curses.color_content(None) == (42, 43, 44)


def test_setupterm(monkeypatch):
    class make_setupterm:
        OK = lib.OK
        ERR = lib.ERR
        def __init__(self, err_no):
            self.err_no = err_no
        def setupterm(self, term, fd, err):
            err[0] = self.err_no
            return lib.ERR

    monkeypatch.setattr(_curses, '_initialised_setupterm', False)
    monkeypatch.setattr(_curses, 'lib', make_setupterm(0))

    with pytest.raises(Exception) as exc_info:
        _curses.setupterm()

    assert "could not find terminal" in exc_info.value.args[0]

    monkeypatch.setattr(_curses, 'lib', make_setupterm(-1))

    with pytest.raises(Exception) as exc_info:
        _curses.setupterm()

    assert "could not find terminfo database" in exc_info.value.args[0]

    monkeypatch.setattr(_curses, 'lib', make_setupterm(42))

    with pytest.raises(Exception) as exc_info:
        _curses.setupterm()

    assert "unknown error" in exc_info.value.args[0]
