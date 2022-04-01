"""
CFFI based implementation of the _crypt module
"""

import sys
import cffi
import _thread
_lock = _thread.allocate_lock()

try: from __pypy__ import builtinify
except ImportError: builtinify = lambda f: f

if sys.platform == 'win32':
    raise ImportError("The crypt module is not supported on Windows")

ffi = cffi.FFI()
ffi.cdef('char *crypt(char *word, char *salt);')

try:
    lib = ffi.dlopen('crypt')
except OSError:
    raise ModuleNotFoundError('crypt not available', name='crypt')


@builtinify
def crypt(word, salt):
    # Both arguments must be str on CPython, but are interpreted as
    # utf-8 bytes.  The result is also a str.  For backward
    # compatibility with previous versions of the logic here
    # we also accept directly bytes (and then return bytes).
    with _lock:
        arg_is_str = isinstance(word, str)
        if arg_is_str:
            word = word.encode('utf-8')
        if isinstance(salt, str):
            salt = salt.encode('utf-8')
        res = lib.crypt(word, salt)
        if not res:
            return None
        res = ffi.string(res)
        if arg_is_str:
            res = res.decode('utf-8')
        return res
