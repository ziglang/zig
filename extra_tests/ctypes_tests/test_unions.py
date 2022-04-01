import sys
from ctypes import *

def test_getattr():
    class Stuff(Union):
        _fields_ = [('x', c_char), ('y', c_int)]

    stuff = Stuff()
    stuff.y = ord('x') | (ord('z') << 24)
    if sys.byteorder == 'little':
        assert stuff.x == b'x'
    else:
        assert stuff.x == b'z'

def test_union_of_structures():
    class Stuff(Structure):
        _fields_ = [('x', c_int)]

    class Stuff2(Structure):
        _fields_ = [('x', c_int)]

    class UnionofStuff(Union):
        _fields_ = [('one', Stuff),
                    ('two', Stuff2)]

    u = UnionofStuff()
    u.one.x = 3
    assert u.two.x == 3
