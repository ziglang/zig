import pytest
from ctypes import *

def test_slice():
    values = list(range(5))
    numarray = c_int * 5

    na = numarray(*(c_int(x) for x in values))

    assert list(na[0:0]) == []
    assert list(na[:])   == values
    assert list(na[:10]) == values

def test_init_again():
    sz = (c_char * 3)()
    addr1 = addressof(sz)
    sz.__init__(*b"foo")
    addr2 = addressof(sz)
    assert addr1 == addr2

def test_array_of_structures():
    class X(Structure):
        _fields_ = [('x', c_int), ('y', c_int)]

    Y = X * 2
    y = Y()
    x = X()
    x.y = 3
    y[1] = x
    assert y[1].y == 3

def test_output_simple():
    A = c_char * 10
    TP = POINTER(A)
    x = TP(A())
    assert x[0] != b''

    A = c_wchar * 10
    TP = POINTER(A)
    x = TP(A())
    assert x[0] != b''

def test_output_simple_array():
    A = c_char * 10
    AA = A * 10
    aa = AA()
    assert aa[0] != b''

def test_output_complex_test():
    class Car(Structure):
        _fields_ = [("brand", c_char * 10),
                    ("speed", c_float),
                    ("owner", c_char * 10)]

    assert isinstance(Car(b"abcdefghi", 42.0, b"12345").brand, bytes)
    assert Car(b"abcdefghi", 42.0, b"12345").brand == b"abcdefghi"
    assert Car(b"abcdefghio", 42.0, b"12345").brand == b"abcdefghio"
    with pytest.raises(ValueError):
        Car(b"abcdefghiop", 42.0, b"12345")

    A = Car._fields_[2][1]
    TP = POINTER(A)
    x = TP(A())
    assert x[0] != b''

def test_non_int():
    class Index():
        def __index__(self):
            return 42

    t0 = c_int * 42
    t1 = c_int * Index()
    assert t0 == t1
    with pytest.raises(TypeError) as exc:
        c_int * 4.5
    assert 'non-int of type float' in str(exc.value)
