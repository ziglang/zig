#
# A convenient read-write buffer.  Located here for want of a better place.
#

from rpython.rlib.buffer import ByteBuffer

from pypy.interpreter.buffer import SimpleView
from pypy.interpreter.gateway import unwrap_spec

@unwrap_spec(length=int)
def bytebuffer(space, length):
    return SimpleView(ByteBuffer(length)).wrap(space)
