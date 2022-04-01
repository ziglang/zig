from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import rgc
from rpython.rlib.rvmprof import traceback

from pypy.interpreter.pycode import PyCode
from pypy.module.faulthandler.cintf import pypy_faulthandler_write
from pypy.module.faulthandler.cintf import pypy_faulthandler_write_uint


MAX_STRING_LENGTH = 500

global_buf = lltype.malloc(rffi.CCHARP.TO, MAX_STRING_LENGTH, flavor='raw',
                           immortal=True, zero=True)

def _dump(fd, s):
    assert isinstance(s, str)
    l = len(s)
    if l >= MAX_STRING_LENGTH:
        l = MAX_STRING_LENGTH - 1
    i = 0
    while i < l:
        global_buf[i] = s[i]
        i += 1
    global_buf[l] = '\x00'
    pypy_faulthandler_write(fd, global_buf)

def _dump_nonneg_int(fd, i):
    pypy_faulthandler_write_uint(fd, rffi.cast(lltype.Unsigned, i),
                                 rffi.cast(rffi.INT, 1))


def dump_code(pycode, loc, fd):
    if pycode is None:
        _dump(fd, "  File ???")
    else:
        _dump(fd, '  File "')
        _dump(fd, pycode.co_filename)
        _dump(fd, '", line ')
        _dump_nonneg_int(fd, pycode.co_firstlineno)
        _dump(fd, " in ")
        _dump(fd, pycode.co_name)
    if loc == traceback.LOC_JITTED:
        _dump(fd, " [jitted]")
    elif loc == traceback.LOC_JITTED_INLINED:
        _dump(fd, " [jit inlined]")
    _dump(fd, "\n")


@rgc.no_collect
def _dump_callback(fd, array_p, array_length):
    """We are as careful as we can reasonably be here (i.e. not 100%,
    but hopefully close enough).  In particular, this is written as
    RPython but shouldn't allocate anything.
    """
    traceback.walk_traceback(PyCode, dump_code, fd, array_p, array_length)
