from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.annlowlevel import llhelper
from rpython.rlib.objectmodel import specialize
from rpython.rlib.debug import ll_assert
from rpython.rlib.objectmodel import enforceargs
from rpython.rlib import rgc

SIZEOFSIGNED = rffi.sizeof(lltype.Signed)
IS_32BIT = (SIZEOFSIGNED == 4)

# this is an info that only depends on the assembler executed, copied from
# compiled loop token (in fact we could use this as a compiled loop token
# XXX do this

GCMAP = lltype.Array(lltype.Unsigned)
NULLGCMAP = lltype.nullptr(GCMAP)

@enforceargs(None, int, int)
def jitframeinfo_update_depth(jfi, base_ofs, new_depth):
    if new_depth > jfi.jfi_frame_depth:
        jfi.jfi_frame_depth = new_depth
        jfi.jfi_frame_size = base_ofs + new_depth * SIZEOFSIGNED

def jitframeinfo_clear(jfi):
    jfi.jfi_frame_size = 0
    jfi.jfi_frame_depth = 0

JITFRAMEINFO_SIZE = 2 * SIZEOFSIGNED # make sure this stays correct

JITFRAMEINFO = lltype.Struct(
    'JITFRAMEINFO',
    # the depth of the frame
    ('jfi_frame_depth', lltype.Signed),
    # the total size of the frame, in bytes
    ('jfi_frame_size', lltype.Signed),
    adtmeths = {
        'update_frame_depth': jitframeinfo_update_depth,
        'clear': jitframeinfo_clear,
    },
)

NULLFRAMEINFO = lltype.nullptr(JITFRAMEINFO)
JITFRAMEINFOPTR = lltype.Ptr(JITFRAMEINFO)

# the JITFRAME that's stored on the heap. See backend/<backend>/arch.py for
# detailed explanation how it is on your architecture

def jitframe_allocate(frame_info):
    rgc.register_custom_trace_hook(JITFRAME, lambda_jitframe_trace)
    frame = lltype.malloc(JITFRAME, frame_info.jfi_frame_depth)
    frame.jf_frame_info = frame_info
    return frame

def jitframe_resolve(frame):
    while frame.jf_forward:
        frame = frame.jf_forward
    return frame

JITFRAME = lltype.GcForwardReference()

JITFRAME.become(lltype.GcStruct(
    'JITFRAME',
    ('jf_frame_info', lltype.Ptr(JITFRAMEINFO)),
    # Once the execute_token() returns, the field 'jf_descr' stores the
    # descr of the last executed operation (either a GUARD, or FINISH).
    # This field is also set immediately before doing CALL_MAY_FORCE
    # or CALL_ASSEMBLER.
    ('jf_descr', llmemory.GCREF),
    # guard_not_forced descr
    ('jf_force_descr', llmemory.GCREF),
    # a map of GC pointers
    ('jf_gcmap', lltype.Ptr(GCMAP)),
    # For the front-end: a GCREF for the savedata
    ('jf_savedata', llmemory.GCREF),
    # For GUARD_(NO)_EXCEPTION and GUARD_NOT_FORCED: the exception we
    # got.  (Note that in case of a regular FINISH generated from
    # RPython code that finishes the function with an exception, the
    # exception is not stored there, but is simply kept as a variable there)
    ('jf_guard_exc', llmemory.GCREF),
    # in case the frame got reallocated, we have to forward it somewhere
    ('jf_forward', lltype.Ptr(JITFRAME)),
    # the actual frame
    ('jf_frame', lltype.Array(lltype.Signed)),
    # note that we keep length field, because it's crucial to have the data
    # about GCrefs here and not in frame info which might change
    adtmeths = {
        'allocate': jitframe_allocate,
        'resolve': jitframe_resolve,
    },
    rtti = True,
))

@specialize.memo()
def getofs(name):
    return llmemory.offsetof(JITFRAME, name)

GCMAPLENGTHOFS = llmemory.arraylengthoffset(GCMAP)
GCMAPBASEOFS = llmemory.itemoffsetof(GCMAP, 0)
BASEITEMOFS = llmemory.itemoffsetof(JITFRAME.jf_frame, 0)
LENGTHOFS = llmemory.arraylengthoffset(JITFRAME.jf_frame)
SIGN_SIZE = llmemory.sizeof(lltype.Signed)
UNSIGN_SIZE = llmemory.sizeof(lltype.Unsigned)

def jitframe_trace(gc, obj_addr, callback, arg):
    gc._trace_callback(callback, arg, obj_addr + getofs('jf_descr'))
    gc._trace_callback(callback, arg, obj_addr + getofs('jf_force_descr'))
    gc._trace_callback(callback, arg, obj_addr + getofs('jf_savedata'))
    gc._trace_callback(callback, arg, obj_addr + getofs('jf_guard_exc'))
    gc._trace_callback(callback, arg, obj_addr + getofs('jf_forward'))

    if IS_32BIT:
        MAX = 32
    else:
        MAX = 64
    gcmap = (obj_addr + getofs('jf_gcmap')).address[0]
    if not gcmap:
        return      # done
    gcmap_lgt = (gcmap + GCMAPLENGTHOFS).signed[0]
    no = 0
    while no < gcmap_lgt:
        cur = (gcmap + GCMAPBASEOFS + UNSIGN_SIZE * no).unsigned[0]
        bitindex = 0
        while bitindex < MAX:
            if cur & (1 << bitindex):
                # the 'bitindex' is set in 'cur'
                index = no * SIZEOFSIGNED * 8 + bitindex
                # sanity check
                frame_lgt = (obj_addr + getofs('jf_frame') + LENGTHOFS) \
                    .signed[0]
                ll_assert(index < frame_lgt, "bogus frame field get")
                gc._trace_callback(callback, arg,
                                   obj_addr + getofs('jf_frame') +
                                   BASEITEMOFS + SIGN_SIZE * index)
            bitindex += 1
        no += 1
lambda_jitframe_trace = lambda: jitframe_trace

JITFRAMEPTR = lltype.Ptr(JITFRAME)
