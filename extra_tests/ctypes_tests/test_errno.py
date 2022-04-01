import pytest

import ctypes
_rawffi = pytest.importorskip('_rawffi')  # PyPy-only

def test_errno_saved_and_restored():
    def check():
        assert _rawffi.get_errno() == 42
        assert ctypes.get_errno() == old
    check.free_temp_buffers = lambda *args: None
    f = ctypes._CFuncPtr()
    old = _rawffi.get_errno()
    f._flags_ = _rawffi.FUNCFLAG_USE_ERRNO
    ctypes.set_errno(42)
    f._call_funcptr(check)
    assert _rawffi.get_errno() == old
    ctypes.set_errno(0)

# see also test_functions.test_errno
