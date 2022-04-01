from ctypes import *

def test_a_string(dll):
    """
    A testcase which accesses *values* in a dll.
    """
    a_string = (c_char * 16).in_dll(dll, "a_string")
    assert a_string.raw == b"0123456789abcdef"
    a_string[15:16] = b'$'
    assert dll.get_a_string_char(15) == ord('$')
