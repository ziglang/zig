import pytest

from ctypes import *

def test_cast_functype(dll):
    # make sure we can cast function type
    my_sqrt = dll.my_sqrt
    saved_objects = my_sqrt._objects.copy()
    sqrt = cast(cast(my_sqrt, c_void_p), CFUNCTYPE(c_double, c_double))
    assert sqrt(4.0) == 2.0
    assert not cast(0, CFUNCTYPE(c_int))
    #
    assert sqrt._objects is my_sqrt._objects   # on CPython too
    my_sqrt._objects.clear()
    my_sqrt._objects.update(saved_objects)

def test_cast_argumenterror():
    param = c_uint(42)
    with pytest.raises(ArgumentError):
        cast(param, c_void_p)

def test_c_bool():
    x = c_bool(42)
    assert x.value is True
    x = c_bool(0.0)
    assert x.value is False
    x = c_bool("")
    assert x.value is False
    x = c_bool(['yadda'])
    assert x.value is True

def test_cast_array():
    import sys
    data = b'data'
    ubyte = c_ubyte * len(data)
    byteslike = ubyte.from_buffer_copy(data)
    m = memoryview(byteslike)
    if sys.version_info > (3, 3):
        b = m.cast('B')
        assert bytes(b) == data
