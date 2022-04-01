import pytest
from ctypes import *


def test_restype_setattr(dll):
    func = dll._testfunc_p_p
    with pytest.raises(TypeError):
        setattr(func, 'restype', 20)

def test_argtypes_setattr(dll):
    func = dll._testfunc_p_p
    with pytest.raises(TypeError):
        setattr(func, 'argtypes', 20)
    with pytest.raises(TypeError):
        setattr(func, 'argtypes', [20])

    func = CFUNCTYPE(c_long, c_void_p, c_long)(lambda: None)
    assert func.argtypes == (c_void_p, c_long)

def test_paramflags_setattr():
    func = CFUNCTYPE(c_long, c_void_p, c_long)(lambda: None)
    with pytest.raises(TypeError):
        setattr(func, 'paramflags', 'spam')
    with pytest.raises(ValueError):
        setattr(func, 'paramflags', (1, 2, 3, 4))
    with pytest.raises(TypeError):
        setattr(func, 'paramflags', ((1,), ('a',)))
    func.paramflags = (1,), (1|4,)

def test_kwargs(dll):
    proto = CFUNCTYPE(c_char_p, c_char_p, c_int)
    paramflags = (1, 'text', b"tavino"), (1, 'letter', ord('v'))
    func = proto(('my_strchr', dll), paramflags)
    assert func.argtypes == (c_char_p, c_int)
    assert func.restype == c_char_p

    result = func(b"abcd", ord('b'))
    assert result == b"bcd"

    result = func()
    assert result == b"vino"

    result = func(b"grapevine")
    assert result == b"vine"

    result = func(text=b"grapevine")
    assert result == b"vine"

    result = func(letter=ord('i'))
    assert result == b"ino"

    result = func(letter=ord('p'), text=b"impossible")
    assert result == b"possible"

    result = func(text=b"impossible", letter=ord('p'))
    assert result == b"possible"

def test_array_to_ptr_wrongtype(dll):
    ARRAY = c_byte * 8
    func = dll._testfunc_ai8
    func.restype = POINTER(c_int)
    func.argtypes = [c_int * 8]
    array = ARRAY(1, 2, 3, 4, 5, 6, 7, 8)
    with pytest.raises(ArgumentError):
        func(array)
