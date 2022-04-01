import pytest

import math
from ctypes import *
from .support import BaseCTypesTestChecker

functypes = [CFUNCTYPE]
try:
    functypes.append(WINFUNCTYPE)
except NameError:
    pass


def callback(*args):
    callback.got_args = args
    return args[-1]

unwrapped_types = {
    c_float: (float,),
    c_double: (float,),
    c_char: (bytes,),
    c_char_p: (bytes,),
    c_uint: (int,),
    c_ulong: (int,),
    }

@pytest.mark.parametrize("typ, arg", [
    (c_byte, 42),
    (c_byte, -42),
    (c_ubyte, 42),
    (c_short, 42),
    (c_short, -42),
    (c_ushort, 42),
    (c_int, 42),
    (c_int, -42),
    (c_uint, 42),
    (c_long, 42),
    (c_long, -42),
    (c_ulong, 42),
    (c_longlong, 42),
    (c_longlong, -42),
    (c_ulonglong, 42),
    (c_float, math.e),  # only almost equal: double -> float -> double
    (c_float, -math.e),
    (c_double, 3.14),
    (c_double, -3.14),
    (c_char, b"x"),
    (c_char, b"a"),
])
@pytest.mark.parametrize('functype', functypes)
def test_types(typ, arg, functype):
    PROTO = functype(typ, typ)
    cfunc = PROTO(callback)
    result = cfunc(arg)
    if typ == c_float:
        assert abs(result - arg) < 0.000001
    else:
        assert callback.got_args == (arg,)
        assert result == arg

    result2 = cfunc(typ(arg))
    assert type(result2) in unwrapped_types.get(typ, (int,))

    PROTO = functype(typ, c_byte, typ)
    result = PROTO(callback)(-3, arg)
    if typ == c_float:
        assert abs(result - arg) < 0.000001
    else:
        assert callback.got_args == (-3, arg)
        assert result == arg

@pytest.mark.parametrize('functype', functypes)
def test_unsupported_restype_1(functype):
    # Only "fundamental" result types are supported for callback
    # functions, the type must have a non-NULL stgdict->setfunc.
    # POINTER(c_double), for example, is not supported.

    prototype = functype(POINTER(c_double))
    # The type is checked when the prototype is called
    with pytest.raises(TypeError):
        prototype(lambda: None)


def test_callback_with_struct_argument():
    class RECT(Structure):
        _fields_ = [("left", c_int), ("top", c_int),
                    ("right", c_int), ("bottom", c_int)]

    proto = CFUNCTYPE(c_int, RECT)

    def callback(point):
        point.left *= -1
        return point.left + point.top + point.right + point.bottom

    cbp = proto(callback)
    rect = RECT(-1000, 100, 10, 1)
    res = cbp(rect)
    assert res == 1111
    assert rect.left == -1000   # must not have been changed!

def test_callback_from_c_with_struct_argument(dll):
    class RECT(Structure):
        _fields_ = [("left", c_long), ("top", c_long),
                    ("right", c_long), ("bottom", c_long)]

    proto = CFUNCTYPE(c_int, RECT)

    def callback(point):
        return point.left + point.top + point.right + point.bottom

    cbp = proto(callback)
    rect = RECT(1000, 100, 10, 1)

    call_callback_with_rect = dll.call_callback_with_rect
    call_callback_with_rect.restype = c_int
    call_callback_with_rect.argtypes = [proto, RECT]
    res = call_callback_with_rect(cbp, rect)
    assert res == 1111

def test_callback_unsupported_return_struct():
    class RECT(Structure):
        _fields_ = [("left", c_int), ("top", c_int),
                    ("right", c_int), ("bottom", c_int)]

    proto = CFUNCTYPE(RECT, c_int)
    with pytest.raises(TypeError):
        proto(lambda r: 0)


def test_qsort(dll):
    PI = POINTER(c_int)
    A = c_int*5
    a = A()
    for i in range(5):
        a[i] = 5-i

    assert a[0] == 5 # sanity

    def comp(a, b):
        a = a.contents.value
        b = b.contents.value
        if a < b:
            return -1
        elif a > b:
            return 1
        else:
            return 0
    qs = dll.my_qsort
    qs.restype = None
    CMP = CFUNCTYPE(c_int, PI, PI)
    qs.argtypes = (PI, c_size_t, c_size_t, CMP)

    qs(cast(a, PI), 5, sizeof(c_int), CMP(comp))

    res = list(a)

    assert res == [1,2,3,4,5]

def test_pyobject_as_opaque(dll):
    def callback(arg):
        return arg()

    CTP = CFUNCTYPE(c_int, py_object)
    cfunc = dll._testfunc_callback_opaque
    cfunc.argtypes = [CTP, py_object]
    cfunc.restype = c_int
    res = cfunc(CTP(callback), lambda : 3)
    assert res == 3

def test_callback_void(capsys, dll):
    def callback():
        pass

    CTP = CFUNCTYPE(None)
    cfunc = dll._testfunc_callback_void
    cfunc.argtypes = [CTP]
    cfunc.restype = int
    cfunc(CTP(callback))
    out, err = capsys.readouterr()
    assert (out, err) == ("", "")


def test_callback_pyobject():
    def callback(obj):
        return obj

    FUNC = CFUNCTYPE(py_object, py_object)
    cfunc = FUNC(callback)
    param = c_int(42)
    assert cfunc(param) is param

def test_raise_argumenterror():
    def callback(x):
        pass
    FUNC = CFUNCTYPE(None, c_void_p)
    cfunc = FUNC(callback)
    param = c_uint(42)
    with pytest.raises(ArgumentError):
        cfunc(param)
