# derived from test_random_things.py
import pytest

from ctypes import *

_rawffi = pytest.importorskip('_rawffi')

#
# This test makes sure the exception types *and* the exception
# value is printed correctly.

@pytest.mark.skipif("sys.flags.inspect")
def test_SystemExit(monkeypatch, capsys):
    """
    When an exception is raised in a ctypes callback function, the C
    code prints a traceback. When SystemExit is raised, the interpreter
    normally exits immediately.
    """
    def callback_func(arg):
        raise SystemExit(42)
    def custom_exit(value):
        raise Exception("<<<exit(%r)>>>" % (value,))
    monkeypatch.setattr(_rawffi, 'exit', custom_exit)
    cb = CFUNCTYPE(c_int, c_int)(callback_func)
    cb2 = cast(cast(cb, c_void_p), CFUNCTYPE(c_int, c_int))
    out, err = capsys.readouterr()
    assert not err
    cb2(0)
    out, err = capsys.readouterr()
    assert err.splitlines()[-1] == "Exception: <<<exit(42)>>>"
    #
    cb = CFUNCTYPE(c_int, c_int)(callback_func)
    cb(0)
    out, err = capsys.readouterr()
    assert err.splitlines()[-1] == "Exception: <<<exit(42)>>>"
