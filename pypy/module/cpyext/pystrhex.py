import sys
from pypy.module.cpyext.api import cts
from rpython.rlib.rstring import StringBuilder

@cts.decl("PyObject * _Py_strhex(const char* argbuf, const Py_ssize_t arglen)")
def _Py_strhex(space, argbuf, arglen):
    s = strhex(argbuf, arglen)
    return space.newutf8(s, len(s))    # contains ascii only

@cts.decl("PyObject * _Py_strhex_bytes(const char* argbuf, const Py_ssize_t arglen)")
def _Py_strhex_bytes(space, argbuf, arglen):
    s = strhex(argbuf, arglen)
    return space.newbytes(s)

hexdigits = "0123456789abcdef"

def strhex(argbuf, arglen):
    assert arglen >= 0
    if arglen > sys.maxint / 2:
        raise MemoryError
    builder = StringBuilder(arglen * 2)
    for i in range(arglen):
        b = ord(argbuf[i])
        builder.append(hexdigits[(b >> 4) & 0xf])
        builder.append(hexdigits[b & 0xf])
    return builder.build()
