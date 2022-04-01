import pytest
from ctypes import *
import struct

@pytest.mark.pypy_only
def test_get_ffi_argtype():
    P = POINTER(c_int)
    ffitype = P.get_ffi_argtype()
    assert P.get_ffi_argtype() is ffitype
    assert ffitype.deref_pointer() is c_int.get_ffi_argtype()

@pytest.mark.parametrize("c_type, py_type", [
    (c_byte, int),
    (c_ubyte, int),
    (c_short,  int),
    (c_ushort, int),
    (c_int, int),
    (c_uint, int),
    (c_long, int),
    (c_ulong, int),
    (c_longlong, int),
    (c_ulonglong, int),
    (c_double, float),
    (c_float, float),
])
def test_byref(c_type, py_type):
    i = c_type(42)
    p = byref(i)
    assert type(p._obj) is c_type
    assert p._obj.value == 42

def test_pointer_to_pointer():
    x = c_int(32)
    y = c_int(42)
    p1 = pointer(x)
    p2 = pointer(p1)
    assert p2.contents.contents.value == 32
    p2.contents.contents = y
    assert p2.contents.contents.value == 42
    assert p1.contents.value == 42

def test_c_char_p_byref(dll):
    TwoOutArgs = dll.TwoOutArgs
    TwoOutArgs.restype = None
    TwoOutArgs.argtypes = [c_int, c_void_p, c_int, c_void_p]
    a = c_int(3)
    b = c_int(4)
    c = c_int(5)
    d = c_int(6)
    TwoOutArgs(a, byref(b), c, byref(d))
    assert b.value == 7
    assert d.value == 11

def test_byref_cannot_be_bound():
    class A(object):
        _byref = byref
    A._byref(c_int(5))

def test_byref_with_offset():
    c = c_int()
    d = byref(c)
    base = cast(d, c_void_p).value
    for i in [0, 1, 4, 1444, -10293]:
        assert cast(byref(c, i), c_void_p).value == base + i

@pytest.mark.pypy_only
def test_issue2813_fix():
    class C(Structure):
        pass
    POINTER(C)
    C._fields_ = [('x', c_int)]
    ffitype = C.get_ffi_argtype()
    assert C.get_ffi_argtype() is ffitype
    assert ffitype.sizeof() == sizeof(c_int)

@pytest.mark.pypy_only
def test_issue2813_cant_change_fields_after_get_ffi_argtype():
    class C(Structure):
        pass
    ffitype = C.get_ffi_argtype()
    with pytest.raises(NotImplementedError):
        C._fields_ = [('x', c_int)]

def test_memoryview():
    x = c_int(32)
    p1 = pointer(x)
    p2 = pointer(p1)

    m1 = memoryview(p1)
    assert struct.unpack('P', m1)[0] == addressof(x)
    m2 = memoryview(p2)
    assert struct.unpack('P', m2)[0] == addressof(p1)

def test_pointer_from_array():
    A = c_ubyte * 4
    a = A(19, 72, 0, 23)
    P = POINTER(c_ubyte)
    p = P(a)
    for i in range(len(a)):
        assert p[i] == a[i]
