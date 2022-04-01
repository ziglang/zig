import pytest
import sys
from ctypes import *

def test_buffer():
    b = create_string_buffer(32)
    assert len(b) == 32
    assert sizeof(b) == 32 * sizeof(c_char)
    assert type(b[0]) is bytes

    b = create_string_buffer(b"abc")
    assert len(b) == 4 # trailing nul char
    assert sizeof(b) == 4 * sizeof(c_char)
    assert type(b[0]) is bytes
    assert b[0] == b"a"
    assert b[:] == b"abc\0"

def test_from_buffer():
    b1 = bytearray(b"abcde")
    b = (c_char * 5).from_buffer(b1)
    assert b[2] == b"c"
    #
    b1 = bytearray(b"abcd")
    b = c_int.from_buffer(b1)
    assert b.value in (1684234849,   # little endian
                        1633837924)   # big endian

def test_from_buffer_keepalive():
    # Issue #2878
    b1 = bytearray(b"ab")
    array = (c_uint16 * 32)()
    array[6] = c_uint16.from_buffer(b1)
    # this is also what we get on CPython.  I don't think it makes
    # sense because the array contains just a copy of the number.
    assert array._objects == {'6': b1}

def normalize(fmt):
    if sys.byteorder == "big":
        return fmt.replace('<', '>')
    else:
        return fmt

s_long = {4: 'l', 8: 'q'}[sizeof(c_long)]
s_ulong = {4: 'L', 8: 'Q'}[sizeof(c_long)]

@pytest.mark.parametrize("tp, fmt", [
    ## simple types
    (c_char, "<c"),
    (c_byte, "<b"),
    (c_ubyte, "<B"),
    (c_short, "<h"),
    (c_ushort, "<H"),
    (c_long, f"<{s_long}"),
    (c_ulong, f"<{s_ulong}"),
    (c_float, "<f"),
    (c_double, "<d"),
    (c_bool, "<?"),
    (py_object, "<O"),
    ## pointers
    (POINTER(c_byte), "&<b"),
    (POINTER(POINTER(c_long)), f"&&<{s_long}"),
    ## arrays and pointers
    (c_double * 4, "<d"),
    (c_float * 4 * 3 * 2, "<f"),
    (POINTER(c_short) * 2, "&<h"),
    (POINTER(c_short) * 2 * 3, "&<h"),
    (POINTER(c_short * 2), "&(2)<h"),
])
def test_memoryview_format(tp, fmt):
    assert memoryview(tp()).format == normalize(fmt)
