from rpython.rtyper.lltypesystem import rffi
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.backend.llsupport import jitframe
from rpython.rlib.rarithmetic import r_uint
from rpython.jit.backend.llsupport.symbolic import WORD

def allocate_gcmap(assembler, frame_depth, fixed_size):
    size = frame_depth + fixed_size
    malloc_size = (size // WORD // 8 + 1) + 1
    rawgcmap = assembler.datablockwrapper.malloc_aligned(WORD * malloc_size,
                                                    WORD)
    # set the length field
    rffi.cast(rffi.CArrayPtr(lltype.Signed), rawgcmap)[0] = malloc_size - 1
    gcmap = rffi.cast(lltype.Ptr(jitframe.GCMAP), rawgcmap)
    # zero the area
    for i in range(malloc_size - 1):
        gcmap[i] = r_uint(0)
    return gcmap
