import pytest
from ctypes import *

unsigned_types = [c_ubyte, c_ushort, c_uint, c_ulong]
signed_types = [c_byte, c_short, c_int, c_long, c_longlong]

float_types = [c_double, c_float, c_longdouble]

try:
    c_ulonglong
    c_longlong
except NameError:
    pass
else:
    unsigned_types.append(c_ulonglong)
    signed_types.append(c_longlong)

################################################################

@pytest.mark.parametrize('t', signed_types + unsigned_types + float_types)
def test_init_again(t):
    parm = t()
    addr1 = addressof(parm)
    parm.__init__(0)
    addr2 = addressof(parm)
    assert addr1 == addr2

def test_subclass():
    class enum(c_int):
        def __new__(cls, value):
            dont_call_me
    class S(Structure):
        _fields_ = [('t', enum)]
    assert isinstance(S().t, enum)

#@pytest.mark.xfail("'__pypy__' not in sys.builtin_module_names")
@pytest.mark.xfail
def test_no_missing_shape_to_ffi_type():
    # whitebox test
    "re-enable after adding 'g' to _shape_to_ffi_type.typemap, "
    "which I think needs fighting all the way up from "
    "rpython.rlib.libffi"
    from _ctypes.basics import _shape_to_ffi_type
    from _rawffi import Array
    for i in range(1, 256):
        try:
            Array(chr(i))
        except ValueError:
            pass
        else:
            assert chr(i) in _shape_to_ffi_type.typemap

@pytest.mark.xfail
def test_pointer_to_long_double():
    import ctypes
    ctypes.POINTER(ctypes.c_longdouble)
