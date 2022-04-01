from ctypes import *

import pytest
import sys


def test_subclass_initializer():
    class POINT(Structure):
        _fields_ = [("x", c_int), ("y", c_int)]

    class POSITION(POINT):
        # A subclass without _fields_
        pass
    pos = POSITION(1, 2)
    assert (pos.x, pos.y) == (1, 2)
    # Try a second time, result may be different (cf. issue1498)
    pos = POSITION(1, 2)
    assert (pos.x, pos.y) == (1, 2)

def test_fields_is_a_tuple():
    class Person(Structure):
        _fields_ = (("name", c_char*6),
                    ("age", c_int))

    # short enough
    p = Person(b"123456", 6)
    assert p.name == b"123456"
    assert p.age == 6

def test___init__():
    class Person(Structure):
        _fields_ = (("name", c_char*10),
                    ("age", c_int))
        def __init__(self, name, surname, age):
            self.name = name + b' ' + surname
            self.age = age

    p = Person(b"John", b"Doe", 25)
    assert p.name == b"John Doe"
    assert p.age == 25

def test_setattr():
    class X(Structure):
        _fields_ = [("a", c_int)]

    x = X()
    x.other = 42
    assert x.other == 42

def test_withslots():
    class X(Structure):
        _fields_ = [("a", c_int * 2)]
        __slots__ = ['a']

    x = X()
    x.a = (42, 43)
    assert tuple(x.a) == (42, 43)

def test_getattr_recursion():
    # Structure.__getattr__ used to call itself recursively
    # and hit the recursion limit.
    import sys
    events = []

    def tracefunc(frame, event, arg):
        funcname = frame.f_code.co_name
        if 'getattr' in funcname:
            events.append(funcname)

    oldtrace = sys.settrace(tracefunc)
    try:
        class X(Structure):
            _fields_ = [("a", c_int)]

        assert len(events) < 20
    finally:
        sys.settrace(oldtrace)
        events = None

def test_large_fields():
    # make sure that large fields are not "confused" with bitfields
    # (because the bitfields use the higher bits of the "size" attribute)
    Array = c_long * 8192
    class X(Structure):
        _fields_ = [('items', Array)]
    obj = X()
    assert isinstance(obj.items, Array)

def test_b_base():
    # _b_base_ used to be None here in PyPy
    class X(Structure):
        _fields_ = [('x', c_int)]
    obj = X()
    p = pointer(obj)
    assert p.contents._b_base_ is p

def test_swapped_bytes():
    import sys

    for i in [c_short, c_int, c_long, c_longlong,
                c_float, c_double, c_ushort, c_uint,
                c_ulong, c_ulonglong]:
        FIELDS = [
            ('n', i)
        ]

        class Native(Structure):
            _fields_ = FIELDS

        class Big(BigEndianStructure):
            _fields_ = FIELDS

        class Little(LittleEndianStructure):
            _fields_ = FIELDS

        def dostruct(c):
            ba = create_string_buffer(sizeof(c))
            ms = c.from_buffer(ba)
            ms.n = 0xff00
            return repr(ba[:])

        nstruct = dostruct(Native)
        if sys.byteorder == 'little':
            assert nstruct == dostruct(Little)
            assert nstruct != dostruct(Big)
            assert Big._fields_[0][1] is not i
        else:
            assert nstruct == dostruct(Big)
            assert nstruct != dostruct(Little)
            assert Little._fields_[0][1] is not i

def test_from_buffer_copy():
    from array import array

    class S(Structure):
        _fields_ = [('i', c_int)]
        def __init__(self, some, unused, arguments):
            pass
    a = array('i', [1234567])
    s1 = S.from_buffer(a)
    s2 = S.from_buffer_copy(a)
    assert s1.i == 1234567
    assert s2.i == 1234567
    a[0] = -7654321
    assert s1.i == -7654321
    assert s2.i == 1234567


def test_nonfinal_struct():
    class X(Structure):
        pass
    assert sizeof(X) == 0
    X._fields_ = [("a", c_int),]
    with pytest.raises(AttributeError):
        X._fields_ = []

    class X(Structure):
        pass
    X()
    with pytest.raises(AttributeError):
        X._fields_ = []

    class X(Structure):
        pass
    class Y(X):
        pass
    with pytest.raises(AttributeError):
        X._fields_ = []
    Y.__fields__ = []


def test_structure_overloading_getattr():
    class X(Structure):
        _fields_ = [('x', c_int)]

        def __getattr__(self, name):
            raise AttributeError(name)

    x = X()
    assert x.x == 0

def test_duplicate_names():
    class S(Structure):
        _fields_ = [('a', c_int),
                    ('b', c_int),
                    ('a', c_byte)]
    s = S(260, -123)
    assert sizeof(s) == 3 * sizeof(c_int)
    assert s.a == 4     # 256 + 4
    assert s.b == -123

def test_memoryview():
    class S(Structure):
        _fields_ = [('a', c_int16),
                    ('b', c_int16),
                   ]

    S3 = S * 3
    c_array = (2 * S3)(
        S3(S(a=0, b=1), S(a=2, b=3), S(a=4,  b=5)),
        S3(S(a=6, b=7), S(a=8, b=9), S(a=10, b=11)),
        )

    mv = memoryview(c_array)
    if sys.byteorder == 'little':
        assert mv.format == 'T{<h:a:<h:b:}'
    else:
        assert mv.format == 'T{>h:a:>h:b:}'
    assert mv.shape == (2, 3)
    assert mv.itemsize == 4

def test_memoryview_endian():
    class LES(LittleEndianStructure):
        _pack_ = 1
        _fields_ = [
            ('a', c_ubyte * 16),
            ('i', c_uint64)
        ]
    c_les = LES()
    mv = memoryview(c_les)
    assert mv.format == 'B'

def test_deepcopy_struct():
    # issue 3022: missing __new__ on StructureInstanceAutoFree
    import copy

    class struct_a(Structure):
        pass
        
    class struct_b(Structure):
        pass
        
    struct_a._fields_ = [('first',struct_b)]

    a = struct_a()
    b = copy.deepcopy(a)
    assert isinstance(b.first, struct_b)
