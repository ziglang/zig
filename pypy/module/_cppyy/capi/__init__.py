from rpython.rtyper.lltypesystem import rffi, lltype

from pypy.module._cppyy.capi.loadable_capi import *

from pypy.module._cppyy.capi.capi_types import C_OBJECT,\
    C_NULL_TYPE, C_NULL_OBJECT

def direct_ptradd(ptr, offset):
    offset = rffi.cast(rffi.SIZE_T, offset)
    jit.promote(offset)
    assert lltype.typeOf(ptr) == C_OBJECT
    address = rffi.cast(rffi.CCHARP, ptr)
    return rffi.cast(C_OBJECT, lltype.direct_ptradd(address, offset))
