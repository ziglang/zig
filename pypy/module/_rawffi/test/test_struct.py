import sys
from pypy.module._rawffi.structure import size_alignment_pos
from pypy.module._rawffi.interp_rawffi import TYPEMAP, letter2tp

sizeof = lambda x : size_alignment_pos(x)[0]

def unpack(desc):
    return [('x', letter2tp('space', i), 0) for i in desc]

def test_sizeof():
    s_c = sizeof(unpack('c'))
    s_l = sizeof(unpack('l'))
    s_q = sizeof(unpack('q'))
    alignment_of_q = TYPEMAP['q'].c_alignment
    assert alignment_of_q >= 4
    assert sizeof(unpack('cl')) == 2*s_l
    assert sizeof(unpack('cq')) == alignment_of_q + s_q
    assert sizeof(unpack('ccq')) == alignment_of_q + s_q
    assert sizeof(unpack('cccq')) == alignment_of_q + s_q
    assert sizeof(unpack('ccccq')) == alignment_of_q + s_q
    assert sizeof(unpack('qc')) == s_q + alignment_of_q
    assert sizeof(unpack('qcc')) == s_q + alignment_of_q
    assert sizeof(unpack('qccc')) == s_q + alignment_of_q
    assert sizeof(unpack('qcccc')) == s_q + alignment_of_q

def test_bitsizes():
    fields = [("A", 'i', 1),
              ("B", 'i', 2),
              ("C", 'i', 3),
              ("D", 'i', 4),
              ("E", 'i', 5),
              ("F", 'i', 6),
              ("G", 'i', 7),
              ("H", 'i', 8),
              ("I", 'i', 9),

              ("M", 'h', 1),
              ("N", 'h', 2),
              ("O", 'h', 3),
              ("P", 'h', 4),
              ("Q", 'h', 5),
              ("R", 'h', 6),
              ("S", 'h', 7)]
    size, alignment, pos, bitsizes = size_alignment_pos(
        [(name, letter2tp('space', t), size)
         for (name, t, size) in fields])
    assert size == 12

    import ctypes
    class X(ctypes.Structure):
        _fields_ = [(name, {'i':ctypes.c_int, 'h': ctypes.c_short}[t], size)
                    for (name, t, size) in fields]

    assert pos      == [getattr(X, name).offset for (name, _, _) in fields]
    assert bitsizes == [getattr(X, name).size   for (name, _, _) in fields]

def test_bitsizes_longlong():
    fields = [("a", 'q', 1),
              ("b", 'q', 62),
              ("c", 'q', 1)]
    size, alignment, pos, bitsizes = size_alignment_pos(
        [(name, letter2tp('space', t), size)
         for (name, t, size) in fields])
    assert size == 8
    assert pos == [0, 0, 0]
    if sys.byteorder == 'little':
        assert bitsizes == [0x10000, 0x3e0001, 0x1003f]
    else:
        assert bitsizes == [0x1003f, 0x3e0001, 0x10000]
