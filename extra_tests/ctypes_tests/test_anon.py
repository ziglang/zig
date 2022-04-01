import pytest
from ctypes import *

@pytest.mark.pypy_only
def test_nested():
    class ANON_S(Structure):
        _fields_ = [("a", c_int)]

    class ANON_U(Union):
        _fields_ = [("_", ANON_S),
                    ("b", c_int)]
        _anonymous_ = ["_"]

    class Y(Structure):
        _fields_ = [("x", c_int),
                    ("_", ANON_U),
                    ("y", c_int)]
        _anonymous_ = ["_"]

    assert Y.x.offset == 0
    assert Y.a.offset == sizeof(c_int)
    assert Y.b.offset == sizeof(c_int)
    assert Y._.offset == sizeof(c_int)
    assert Y.y.offset == sizeof(c_int) * 2

    assert Y._names_ == ['x', 'a', 'b', 'y']

def test_anonymous_fields_on_instance():
    # this is about the *instance-level* access of anonymous fields,
    # which you'd guess is the most common, but used not to work
    # (issue #2230)

    class B(Structure):
        _fields_ = [("x", c_int), ("y", c_int), ("z", c_int)]
    class A(Structure):
        _anonymous_ = ["b"]
        _fields_ = [("b", B)]

    a = A()
    a.x = 5
    assert a.x == 5
    assert a.b.x == 5
    a.b.x += 1
    assert a.x == 6

    class C(Structure):
        _anonymous_ = ["a"]
        _fields_ = [("v", c_int), ("a", A)]

    c = C()
    c.v = 3
    c.y = -8
    assert c.v == 3
    assert c.y == c.a.y == c.a.b.y == -8
    assert not hasattr(c, 'b')
