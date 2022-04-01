from rpython.rlib import _rffi_stacklet as _c
from rpython.rlib.debug import ll_assert
from rpython.rlib import rgc
from rpython.rtyper.annlowlevel import llhelper, MixLevelHelperAnnotator
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import lltype_to_annotation


#
# A GC wrapper around the C stacklet handles, with additionally a
# copy of the shadowstack (for all stacklets different than the main)
#
STACKLET = lltype.GcStruct('Stacklet',
                           ('s_handle', _c.handle),
                           ('s_sscopy', llmemory.Address),
                           rtti=True)
STACKLET_PTR = lltype.Ptr(STACKLET)
NULL_STACKLET = lltype.nullptr(STACKLET)


def complete_destrptr(gctransformer):
    translator = gctransformer.translator
    mixlevelannotator = MixLevelHelperAnnotator(translator.rtyper)
    args_s = [lltype_to_annotation(STACKLET_PTR)]
    s_result = annmodel.s_None
    destrptr = mixlevelannotator.delayedfunction(stacklet_destructor,
                                                 args_s, s_result)
    mixlevelannotator.finish()
    lltype.attachRuntimeTypeInfo(STACKLET, destrptr=destrptr)

# Note: it's important that this is a light finalizer, otherwise
# the GC will call it but still expect the object to stay around for
# a while---and it can't stay around, because s_sscopy points to
# freed nonsense and customtrace() will crash
@rgc.must_be_light_finalizer
def stacklet_destructor(stacklet):
    sscopy = stacklet.s_sscopy
    if sscopy:
        llmemory.raw_free(sscopy)
    h = stacklet.s_handle
    if h:
        _c.destroy(h)


SIZEADDR = llmemory.sizeof(llmemory.Address)

def customtrace(gc, obj, callback, arg):
    from rpython.memory.gctransform.shadowstack import walk_stack_root

    stacklet = llmemory.cast_adr_to_ptr(obj, STACKLET_PTR)
    sscopy = stacklet.s_sscopy
    if sscopy:
        length_bytes = sscopy.signed[0]
        walk_stack_root(gc._trace_callback, callback, arg,
                        sscopy + SIZEADDR, sscopy + SIZEADDR + length_bytes,
                        is_minor=False)
lambda_customtrace = lambda: customtrace

def sscopy_detach_shadow_stack():
    base = llop.gc_adr_of_root_stack_base(llmemory.Address).address[0]
    top = llop.gc_adr_of_root_stack_top(llmemory.Address).address[0]
    length_bytes = top - base
    result = llmemory.raw_malloc(SIZEADDR + length_bytes)
    if result:
        result.signed[0] = length_bytes
        llmemory.raw_memcopy(base, result + SIZEADDR, length_bytes)
        llop.gc_adr_of_root_stack_top(llmemory.Address).address[0] = base
    return result

def sscopy_attach_shadow_stack(sscopy):
    base = llop.gc_adr_of_root_stack_base(llmemory.Address).address[0]
    ll_assert(llop.gc_adr_of_root_stack_top(llmemory.Address).address[0]==base,
              "attach_shadow_stack: ss is not empty?")
    length_bytes = sscopy.signed[0]
    llmemory.raw_memcopy(sscopy + SIZEADDR, base, length_bytes)
    llop.gc_adr_of_root_stack_top(llmemory.Address).address[0] = (
        base + length_bytes)
    llop.gc_modified_shadowstack(lltype.Void)
    llmemory.raw_free(sscopy)

def alloc_stacklet():
    new_stacklet = lltype.malloc(STACKLET)
    new_stacklet.s_handle = _c.null_handle
    new_stacklet.s_sscopy = llmemory.NULL
    return new_stacklet

def attach_handle_on_stacklet(stacklet, h):
    ll_assert(stacklet.s_handle == _c.null_handle, "attach stacklet 1: garbage")
    ll_assert(stacklet.s_sscopy == llmemory.NULL,  "attach stacklet 2: garbage")
    if not h:
        raise MemoryError
    elif _c.is_empty_handle(h):
        ll_assert(gcrootfinder.sscopy == llmemory.NULL,
                  "empty_handle but sscopy != NULL")
        return NULL_STACKLET
    else:
        # This is a return that gave us a real handle.  Store it.
        stacklet.s_handle = h
        stacklet.s_sscopy = gcrootfinder.sscopy
        ll_assert(gcrootfinder.sscopy != llmemory.NULL,
                  "!empty_handle but sscopy == NULL")
        gcrootfinder.sscopy = llmemory.NULL
        llop.gc_writebarrier(lltype.Void, llmemory.cast_ptr_to_adr(stacklet))
        return stacklet

def consume_stacklet(stacklet):
    h = stacklet.s_handle
    ll_assert(bool(h), "consume_stacklet: null handle")
    stacklet.s_handle = _c.null_handle
    stacklet.s_sscopy = llmemory.NULL
    return h

def _new_callback(h, arg):
    # There is a fresh stacklet object waiting on the gcrootfinder,
    # so populate it with data that represents the parent suspended
    # stacklet and detach the stacklet object from gcrootfinder.
    stacklet = gcrootfinder.fresh_stacklet
    gcrootfinder.fresh_stacklet = NULL_STACKLET
    ll_assert(stacklet != NULL_STACKLET, "_new_callback: NULL #1")
    stacklet = attach_handle_on_stacklet(stacklet, h)
    ll_assert(stacklet != NULL_STACKLET, "_new_callback: NULL #2")
    #
    # Call the main function provided by the (RPython) user.
    stacklet = gcrootfinder.runfn(stacklet, arg)
    #
    # Here, 'stacklet' points to the target stacklet to which we want
    # to jump to next.  Read the 'handle' and forget about the
    # stacklet object.
    gcrootfinder.sscopy = llmemory.NULL
    return consume_stacklet(stacklet)

def _new(thread_handle, arg):
    # No shadowstack manipulation here (no usage of gc references)
    sscopy = sscopy_detach_shadow_stack()
    gcrootfinder.sscopy = sscopy
    if not sscopy:
        return _c.null_handle
    h = _c.new(thread_handle, llhelper(_c.run_fn, _new_callback), arg)
    sscopy_attach_shadow_stack(sscopy)
    return h
_new._dont_inline_ = True

def _switch(h):
    # No shadowstack manipulation here (no usage of gc references)
    sscopy = sscopy_detach_shadow_stack()
    gcrootfinder.sscopy = sscopy
    if not sscopy:
        return _c.null_handle
    h = _c.switch(h)
    sscopy_attach_shadow_stack(sscopy)
    return h
_switch._dont_inline_ = True


class StackletGcRootFinder(object):
    fresh_stacklet = NULL_STACKLET

    @staticmethod
    def new(thrd, callback, arg):
        rgc.register_custom_trace_hook(STACKLET, lambda_customtrace)
        result_stacklet = alloc_stacklet()
        gcrootfinder.fresh_stacklet = alloc_stacklet()
        gcrootfinder.runfn = callback
        thread_handle = thrd._thrd
        h = _new(thread_handle, arg)
        return attach_handle_on_stacklet(result_stacklet, h)

    @staticmethod
    def switch(stacklet):
        # 'stacklet' has a handle to target, i.e. where to switch to
        h = consume_stacklet(stacklet)
        h = _switch(h)
        return attach_handle_on_stacklet(stacklet, h)

    @staticmethod
    def is_empty_handle(stacklet):
        return not stacklet

    @staticmethod
    def get_null_handle():
        return NULL_STACKLET


gcrootfinder = StackletGcRootFinder()
