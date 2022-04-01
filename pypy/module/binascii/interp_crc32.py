from pypy.interpreter.gateway import unwrap_spec
from rpython.rlib.rarithmetic import r_uint
from rpython.rlib import rzipfile

@unwrap_spec(data='bufferstr', oldcrc='truncatedint_w')
def crc32(space, data, oldcrc=0):
    "Compute the CRC-32 incrementally."
    crc = rzipfile.crc32(data, r_uint(oldcrc))
    return space.newint(crc)
