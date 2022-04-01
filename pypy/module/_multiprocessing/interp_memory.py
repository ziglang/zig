from rpython.rtyper.lltypesystem import rffi

from pypy.interpreter.error import oefmt
from pypy.module.mmap.interp_mmap import W_MMap

def address_of_buffer(space, w_obj):
    if space.config.objspace.usemodules.mmap:
        mmap = space.interp_w(W_MMap, w_obj)
        address = rffi.cast(rffi.SIZE_T, mmap.mmap.data)
        return space.newtuple([space.newint(address),
                               space.newint(mmap.mmap.size)])
    else:
        raise oefmt(space.w_TypeError, "cannot get address of buffer")
