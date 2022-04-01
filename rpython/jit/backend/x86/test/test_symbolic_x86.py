import py
from rpython.jit.backend.llsupport.symbolic import *
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.jit.backend.x86.arch import WORD

# This test file is here and not in llsupport/test/ because it checks
# that we get correct numbers for a 32-bit machine.

class FakeStats(object):
    pass

S = lltype.GcStruct('S', ('x', lltype.Signed),
                         ('y', lltype.Signed),
                         ('z', lltype.Signed))


def test_field_token():
    ofs_x, size_x = get_field_token(S, 'x', False)
    ofs_y, size_y = get_field_token(S, 'y', False)
    ofs_z, size_z = get_field_token(S, 'z', False)
    # ofs_x might be 0 or not, depending on how we count the headers
    # but the rest should be as expected for a 386 machine
    assert size_x == size_y == size_z == WORD
    assert ofs_x >= 0
    assert ofs_y == ofs_x + WORD
    assert ofs_z == ofs_x + (WORD*2)

def test_struct_size():
    ofs_z, size_z = get_field_token(S, 'z', False)
    totalsize = get_size(S, False)
    assert totalsize == ofs_z + WORD

def test_primitive_size():
    assert get_size(lltype.Signed, False) == WORD
    assert get_size(lltype.Char, False) == 1
    assert get_size(lltype.Ptr(S), False) == WORD

def test_array_token():
    A = lltype.GcArray(lltype.Char)
    basesize, itemsize, ofs_length = get_array_token(A, False)
    assert basesize >= WORD    # at least the 'length', maybe some gc headers
    assert itemsize == 1
    assert ofs_length == basesize - WORD
    A = lltype.GcArray(lltype.Signed)
    basesize, itemsize, ofs_length = get_array_token(A, False)
    assert basesize >= WORD    # at least the 'length', maybe some gc headers
    assert itemsize == WORD
    assert ofs_length == basesize - WORD

def test_varsized_struct_size():
    S1 = lltype.GcStruct('S1', ('parent', S),
                               ('extra', lltype.Signed),
                               ('chars', lltype.Array(lltype.Char)))
    size_parent = get_size(S, False)
    ofs_extra, size_extra = get_field_token(S1, 'extra', False)
    basesize, itemsize, ofs_length = get_array_token(S1, False)
    assert size_parent == ofs_extra
    assert size_extra == WORD
    assert ofs_length == ofs_extra + WORD
    assert basesize == ofs_length + WORD
    assert itemsize == 1

def test_string():
    STR = lltype.GcStruct('String', ('hash', lltype.Signed),
                                    ('chars', lltype.Array(lltype.Char)))
    basesize, itemsize, ofs_length = get_array_token(STR, False)
    assert itemsize == 1
    s1 = lltype.malloc(STR, 4)
    s1.chars[0] = 's'
    s1.chars[1] = 'p'
    s1.chars[2] = 'a'
    s1.chars[3] = 'm'
    x = ll2ctypes.lltype2ctypes(s1)
    rawbytes = ctypes.cast(x, ctypes.POINTER(ctypes.c_char))
    assert rawbytes[basesize+0] == 's'
    assert rawbytes[basesize+1] == 'p'
    assert rawbytes[basesize+2] == 'a'
    assert rawbytes[basesize+3] == 'm'
    assert rawbytes[ofs_length+0] == chr(4)
    assert rawbytes[ofs_length+1] == chr(0)
    assert rawbytes[ofs_length+2] == chr(0)
    assert rawbytes[ofs_length+3] == chr(0)
