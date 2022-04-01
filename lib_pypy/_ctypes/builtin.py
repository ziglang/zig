
import _rawffi, sys
try:
    from _thread import _local as local
except ImportError:
    class local(object):    # no threads
        pass

class ConvMode:
    encoding = 'ascii'
    errors = 'strict'

_memmove_addr = _rawffi.get_libc().getaddressindll('memmove')
_memset_addr = _rawffi.get_libc().getaddressindll('memset')

def _string_at_addr(addr, lgt):
    # address here can be almost anything
    import ctypes
    cobj = ctypes.c_void_p.from_param(addr)
    arg = cobj._get_buffer_value()
    return _rawffi.charp2rawstring(arg, lgt)

def set_conversion_mode(encoding, errors):
    old_cm = ConvMode.encoding, ConvMode.errors
    ConvMode.errors = errors
    ConvMode.encoding = encoding
    return old_cm

def _wstring_at_addr(addr, lgt):
    import ctypes
    cobj = ctypes.c_void_p.from_param(addr)
    arg = cobj._get_buffer_value()
    return _rawffi.wcharp2rawunicode(arg, lgt)

_err = local()

def get_errno():
    return getattr(_err, "errno", 0)

def set_errno(errno):
    old_errno = get_errno()
    _err.errno = errno
    return old_errno

def get_last_error():
    return getattr(_err, "winerror", 0)

def set_last_error(winerror):
    old_winerror = get_last_error()
    _err.winerror = winerror
    return old_winerror
