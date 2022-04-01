""" This file provides some support for things like standard_c_lib and
errno access, as portable as possible
"""

import ctypes
import ctypes.util
import sys

# __________ the standard C library __________

if sys.platform == 'win32':
    import _ffi
    standard_c_lib = ctypes.CDLL('msvcrt', handle=_ffi.get_libc())
elif sys.platform == 'cygwin':
    standard_c_lib = ctypes.CDLL(ctypes.util.find_library('cygwin'))
else:
    standard_c_lib = ctypes.CDLL(ctypes.util.find_library('c'))

if sys.platform == 'win32':
    standard_c_lib._errno.restype = ctypes.POINTER(ctypes.c_int)
    standard_c_lib._errno.argtypes = None
    def _where_is_errno():
        return standard_c_lib._errno()

elif sys.platform in ('linux', 'freebsd6'):
    standard_c_lib.__errno_location.restype = ctypes.POINTER(ctypes.c_int)
    standard_c_lib.__errno_location.argtypes = None
    def _where_is_errno():
        return standard_c_lib.__errno_location()

elif sys.platform == 'darwin' or sys.platform.startswith('freebsd'):
    standard_c_lib.__error.restype = ctypes.POINTER(ctypes.c_int)
    standard_c_lib.__error.argtypes = None
    def _where_is_errno():
        return standard_c_lib.__error()

def get_errno():
    errno_p = _where_is_errno()
    return errno_p.contents.value

def set_errno(value):
    errno_p = _where_is_errno()
    errno_p.contents.value = value
