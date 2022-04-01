from rpython.rlib import rgc
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.jit.backend.llsupport.symbolic import WORD


GCREFTRACER = lltype.GcStruct(
    'GCREFTRACER',
    ('array_base_addr', lltype.Signed),
    ('array_length', lltype.Signed),
    rtti=True)

def gcrefs_trace(gc, obj_addr, callback, arg):
    obj = llmemory.cast_adr_to_ptr(obj_addr, lltype.Ptr(GCREFTRACER))
    i = 0
    length = obj.array_length
    addr = obj.array_base_addr
    while i < length:
        p = rffi.cast(llmemory.Address, addr + i * WORD)
        gc._trace_callback(callback, arg, p)
        i += 1
lambda_gcrefs_trace = lambda: gcrefs_trace

def make_framework_tracer(array_base_addr, gcrefs):
    # careful about the order here: the allocation of the GCREFTRACER
    # can trigger a GC.  So we must write the gcrefs into the raw
    # array only afterwards...
    rgc.register_custom_trace_hook(GCREFTRACER, lambda_gcrefs_trace)
    length = len(gcrefs)
    tr = lltype.malloc(GCREFTRACER)
    # --no GC from here--
    tr.array_base_addr = array_base_addr
    tr.array_length = length
    i = 0
    while i < length:
        p = rffi.cast(rffi.SIGNEDP, array_base_addr + i * WORD)
        p[0] = rffi.cast(lltype.Signed, gcrefs[i])
        i += 1
    llop.gc_writebarrier(lltype.Void, tr)
    # --no GC until here--
    return tr

def make_boehm_tracer(array_base_addr, gcrefs):
    # copy the addresses, but return 'gcrefs' as the object that must be
    # kept alive
    for i in range(len(gcrefs)):
        p = rffi.cast(rffi.SIGNEDP, array_base_addr + i * WORD)
        p[0] = rffi.cast(lltype.Signed, gcrefs[i])
    return gcrefs
