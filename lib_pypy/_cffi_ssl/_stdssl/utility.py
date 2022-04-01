import sys
from _pypy_openssl import ffi
from _pypy_openssl import lib

def _string_from_asn1(asn1):
    data = lib.ASN1_STRING_data(asn1)
    length = lib.ASN1_STRING_length(asn1)
    return _str_with_len(ffi.cast("char*",data), length)

def _str_with_len(char_ptr, length):
    return ffi.buffer(char_ptr, length)[:].decode('utf-8').strip('\n')

def _bytes_with_len(char_ptr, length):
    return ffi.buffer(char_ptr, length)[:]

def _str_to_ffi_buffer(view):
    if isinstance(view, str):
        return ffi.from_buffer(view.encode())
    elif isinstance(view, memoryview):
        # NOTE pypy limitation StringBuffer does not allow
        # to get a raw address to the string!
        view = view.tobytes()
    # dont call call ffi.from_buffer(bytes(view)), arguments
    # like ints/bools should result in a TypeError
    return ffi.from_buffer(view)

def _str_from_buf(buf):
    return ffi.string(buf).decode('utf-8')

def _cstr_decode_fs(buf):
    if buf == ffi.NULL:
        return None
    return ffi.string(buf).decode(sys.getfilesystemencoding())

