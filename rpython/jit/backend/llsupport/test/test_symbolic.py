import py
from rpython.jit.backend.llsupport.symbolic import *
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.memory.lltypelayout import convert_offset_to_int


WORD = rffi.sizeof(lltype.Signed)
PTRWORD = rffi.sizeof(llmemory.GCREF)

S = lltype.GcStruct('S', ('x', lltype.Signed),
                         ('y', lltype.Signed),
                         ('z', lltype.Signed))

def convert1(symb):
    if isinstance(symb, int):
        return symb
    return convert_offset_to_int(symb)

def convert(symbs):
    if isinstance(symbs, tuple):
        return map(convert1, symbs)
    else:
        return convert1(symbs)    


def test_field_token():
    for translate_support_code in (True, False):
        ofs_x, size_x = convert(get_field_token(S, 'x', translate_support_code))
        ofs_y, size_y = convert(get_field_token(S, 'y', translate_support_code))
        ofs_z, size_z = convert(get_field_token(S, 'z', translate_support_code))
        # ofs_x might be 0 or not, depending on how we count the headers
        assert size_x == size_y == size_z == WORD
        assert ofs_x >= 0
        assert ofs_y == ofs_x + WORD
        assert ofs_z == ofs_y + WORD

def test_struct_size():
    for translate_support_code in (True, False):    
        ofs_z, size_z = convert(get_field_token(S, 'z', translate_support_code))
        totalsize = convert(get_size(S, translate_support_code))
        assert totalsize == ofs_z + WORD

def test_primitive_size():
    for translate_support_code in (True, False):    
        assert convert(get_size(lltype.Signed, translate_support_code)) == WORD
        assert convert(get_size(lltype.Char, translate_support_code)) == 1
        sz = get_size(lltype.Ptr(S), translate_support_code)
        assert convert(sz) == PTRWORD

def test_array_token():
    for translate_support_code in (True, False):        
        A = lltype.GcArray(lltype.Char)
        arraytok = get_array_token(A, translate_support_code)
        basesize, itemsize, ofs_length = convert(arraytok)
        assert basesize >= WORD # at least the 'length', maybe some gc headers
        assert itemsize == 1
        assert ofs_length == basesize - WORD
        A = lltype.GcArray(lltype.Signed)
        arraytok = get_array_token(A, translate_support_code)
        basesize, itemsize, ofs_length = convert(arraytok)
        assert basesize >= WORD # at least the 'length', maybe some gc headers
        assert itemsize == WORD
        assert ofs_length == basesize - WORD
        A = rffi.CArray(lltype.Signed)
        arraytok = get_array_token(A, translate_support_code)
        basesize, itemsize, ofs_length = convert(arraytok)
        assert basesize == 0
        assert itemsize == WORD
        assert ofs_length == -1

def test_varsized_struct_size():    
    S1 = lltype.GcStruct('S1', ('parent', S),
                               ('extra', lltype.Signed),
                               ('chars', lltype.Array(lltype.Char)))
    for translate_support_code in (True, False):
        size_parent = convert(get_size(S, translate_support_code))
        fldtok = get_field_token(S1, 'extra', translate_support_code)
        ofs_extra, size_extra = convert(fldtok)
        arraytok = get_array_token(S1, translate_support_code)
        basesize, itemsize, ofs_length = convert(arraytok)        
        assert size_parent == ofs_extra
        assert size_extra == WORD
        assert ofs_length == ofs_extra + WORD
        assert basesize == ofs_length + WORD
        assert itemsize == 1

def test_string():
    STR = lltype.GcStruct('String', ('hash', lltype.Signed),
                                    ('chars', lltype.Array(lltype.Char)))
    for translate_support_code in (True, False):
        rstrtok = get_array_token(STR, translate_support_code)
        basesize, itemsize, ofs_length = convert(rstrtok)
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
