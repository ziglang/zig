"""
Support for 'long long' on 32-bits: this is done by casting all floats
to long longs, and using long longs systematically.

On 64-bit platforms, we use float directly to avoid the cost of
converting them back and forth.
"""

import sys
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import rarithmetic, longlong2float
from rpython.rlib.objectmodel import compute_hash


if sys.maxint > 2147483647:
    # ---------- 64-bit platform ----------
    # the type FloatStorage is just a float


    is_64_bit = True
    supports_longlong = False
    r_float_storage = float
    FLOATSTORAGE = lltype.Float

    getfloatstorage = lambda x: x
    getrealfloat    = lambda x: x
    gethash         = compute_hash
    gethash_fast    = longlong2float.float2longlong
    extract_bits    = longlong2float.float2longlong
    is_longlong     = lambda TYPE: False

    # -------------------------------------
else:
    # ---------- 32-bit platform ----------
    # the type FloatStorage is r_longlong, and conversion is needed

    is_64_bit = False
    supports_longlong = True
    r_float_storage = rarithmetic.r_longlong
    FLOATSTORAGE = lltype.SignedLongLong

    getfloatstorage = longlong2float.float2longlong
    getrealfloat    = longlong2float.longlong2float
    gethash         = lambda xll: rarithmetic.intmask(xll - (xll >> 32))
    gethash_fast    = gethash
    extract_bits    = lambda x: x
    is_longlong     = lambda TYPE: (TYPE is lltype.SignedLongLong or
                                    TYPE is lltype.UnsignedLongLong)

    # -------------------------------------

ZEROF = getfloatstorage(0.0)

# ____________________________________________________________

def int2singlefloat(x):
    x = rffi.r_uint(x)
    return longlong2float.uint2singlefloat(x)

def singlefloat2int(x):
    x = longlong2float.singlefloat2uint(x)
    return rffi.cast(lltype.Signed, x)
