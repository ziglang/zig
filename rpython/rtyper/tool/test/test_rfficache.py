
from rpython.rtyper.tool.rfficache import *
from rpython.rtyper.lltypesystem import rffi
from rpython.tool.udir import udir

def test_sizeof_c_type():
    sizeofchar = sizeof_c_type('char')
    assert sizeofchar == 1

def test_types_present():
    for name in rffi.TYPES:
        if name.startswith('unsigned'):
            name = 'u' + name[9:]
        name = name.replace(' ', '')
        assert hasattr(rffi, 'r_' + name)
        assert hasattr(rffi, name.upper())

def test_signof_c_type():
    assert signof_c_type('signed char') == True
    assert signof_c_type('unsigned char') == False
    assert signof_c_type('long long') == True
    assert signof_c_type('unsigned long long') == False
    #
    assert (sizeof_c_type('wchar_t'), signof_c_type('wchar_t')) in [
        (2, False),
        (4, False),
        (4, True)]
