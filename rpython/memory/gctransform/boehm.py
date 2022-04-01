from rpython.memory.gctransform.transform import GCTransformer, mallocHelpers
from rpython.memory.gctransform.support import (get_rtti,
    _static_deallocator_body_for_type, LLTransformerOp, ll_call_destructor,
    ll_report_finalizer_error)
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.flowspace.model import Constant
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper import rmodel


class BoehmGCTransformer(GCTransformer):
    malloc_zero_filled = True
    FINALIZER_PTR = lltype.Ptr(lltype.FuncType([llmemory.GCREF], lltype.Void))

    def __init__(self, translator, inline=False):
        super(BoehmGCTransformer, self).__init__(translator, inline=inline)
        self.finalizer_funcptrs = {}

        atomic_mh = mallocHelpers(gckind='gc')
        atomic_mh.allocate = lambda size: llop.boehm_malloc_atomic(llmemory.GCREF, size)
        ll_malloc_fixedsize_atomic = atomic_mh._ll_malloc_fixedsize

        mh = mallocHelpers(gckind='gc')
        mh.allocate = lambda size: llop.boehm_malloc(llmemory.GCREF, size)
        ll_malloc_fixedsize = mh._ll_malloc_fixedsize

        # XXX, do we need/want an atomic version of this function?
        ll_malloc_varsize_no_length = mh.ll_malloc_varsize_no_length
        ll_malloc_varsize = mh.ll_malloc_varsize

        fields = []
        if translator and translator.config.translation.reverse_debugger:
            fields.append(("hash", lltype.Signed))
            fields.append(("uid", lltype.SignedLongLong))
        hints = {'hints': {'gcheader': True}}
        self.HDR = lltype.Struct("header", *fields, **hints)

        if self.translator:
            self.malloc_fixedsize_ptr = self.inittime_helper(
                ll_malloc_fixedsize, [lltype.Signed], llmemory.GCREF)
            self.malloc_fixedsize_atomic_ptr = self.inittime_helper(
                ll_malloc_fixedsize_atomic, [lltype.Signed], llmemory.GCREF)
            self.malloc_varsize_no_length_ptr = self.inittime_helper(
                ll_malloc_varsize_no_length, [lltype.Signed]*3, llmemory.GCREF, inline=False)
            self.malloc_varsize_ptr = self.inittime_helper(
                ll_malloc_varsize, [lltype.Signed]*4, llmemory.GCREF, inline=False)
            if self.translator.config.translation.rweakref:
                (ll_weakref_create, ll_weakref_deref,
                 self.WEAKLINK, self.convert_weakref_to
                        ) = build_weakref(self.translator.config)
                self.weakref_create_ptr = self.inittime_helper(
                    ll_weakref_create, [llmemory.GCREF], llmemory.WeakRefPtr,
                    inline=False)
                self.weakref_deref_ptr = self.inittime_helper(
                    ll_weakref_deref, [llmemory.WeakRefPtr], llmemory.GCREF)

            if not translator.config.translation.reverse_debugger:
                def ll_identityhash(addr):
                    h = ~llmemory.cast_adr_to_int(addr)
                    return h
                self.identityhash_ptr = self.inittime_helper(
                    ll_identityhash, [llmemory.Address], lltype.Signed,
                    inline=False)
                self.NO_HEADER = True

            self.mixlevelannotator.finish()   # for now
            self.mixlevelannotator.backend_optimize()

        self.finalizer_triggers = []
        self.finalizer_queue_indexes = {}    # {fq: index}

    def gct_fv_gc_malloc(self, hop, flags, TYPE, c_size):
        # XXX same behavior for zero=True: in theory that's wrong
        if TYPE._is_atomic():
            funcptr = self.malloc_fixedsize_atomic_ptr
            opname = 'boehm_malloc_atomic'
        else:
            funcptr = self.malloc_fixedsize_ptr
            opname = 'boehm_malloc'
        tr = self.translator
        if tr and tr.config.translation.reverse_debugger:
            # Don't check for NULLs after the operation (it crashes anyway
            # with an explicit error message in case of out-of-memory).
            # Avoiding a direct_call lets _RPY_REVDB_PRUID() prints the
            # right file/line, at least for fixed-size mallocs.
            v_raw = hop.genop(opname, [c_size], resulttype=llmemory.GCREF)
        else:
            v_raw = hop.genop("direct_call",
                              [funcptr, c_size],
                              resulttype=llmemory.GCREF)
        finalizer_ptr = self.finalizer_funcptr_for_type(TYPE)
        if finalizer_ptr:
            c_finalizer_ptr = Constant(finalizer_ptr, self.FINALIZER_PTR)
            hop.genop("boehm_register_finalizer", [v_raw, c_finalizer_ptr])
        return v_raw

    def gct_fv_gc_malloc_varsize(self, hop, flags, TYPE, v_length, c_const_size, c_item_size,
                                                                   c_offset_to_length):
        # XXX same behavior for zero=True: in theory that's wrong
        if c_offset_to_length is None:
            v_raw = hop.genop("direct_call",
                               [self.malloc_varsize_no_length_ptr, v_length,
                                c_const_size, c_item_size],
                               resulttype=llmemory.GCREF)
        else:
            v_raw = hop.genop("direct_call",
                               [self.malloc_varsize_ptr, v_length,
                                c_const_size, c_item_size, c_offset_to_length],
                               resulttype=llmemory.GCREF)
        return v_raw

    def finalizer_funcptr_for_type(self, TYPE):
        if TYPE in self.finalizer_funcptrs:
            return self.finalizer_funcptrs[TYPE]

        rtti = get_rtti(TYPE)
        if rtti is not None and hasattr(rtti._obj, 'destructor_funcptr'):
            destrptr = rtti._obj.destructor_funcptr
            DESTR_ARG = lltype.typeOf(destrptr).TO.ARGS[0]
        else:
            destrptr = None
            DESTR_ARG = None

        if destrptr:
            EXC_INSTANCE_TYPE = self.translator.rtyper.exceptiondata.lltype_of_exception_value
            typename = TYPE.__name__
            revdb = self.translator.config.translation.reverse_debugger
            def ll_finalizer(gcref):
                exc_instance = llop.gc_fetch_exception(EXC_INSTANCE_TYPE)
                if revdb:
                    llop.revdb_call_destructor(lltype.Void, gcref)
                v = lltype.cast_opaque_ptr(DESTR_ARG, gcref)
                ll_call_destructor(destrptr, v, typename)
                llop.gc_restore_exception(lltype.Void, exc_instance)
            fptr = self.annotate_finalizer(ll_finalizer, [llmemory.GCREF], lltype.Void)
        else:
            fptr = lltype.nullptr(self.FINALIZER_PTR.TO)

        self.finalizer_funcptrs[TYPE] = fptr
        return fptr

    def get_finalizer_queue_index(self, hop):
        fq_tag = hop.spaceop.args[0].value
        assert 'FinalizerQueue TAG' in fq_tag.expr
        fq = fq_tag.default
        try:
            index = self.finalizer_queue_indexes[fq]
        except KeyError:
            index = len(self.finalizer_queue_indexes)
            assert index == len(self.finalizer_triggers)
            #
            def ll_finalizer_trigger():
                try:
                    fq.finalizer_trigger()
                except Exception as e:
                    ll_report_finalizer_error(e)
            ll_trigger = self.annotate_finalizer(ll_finalizer_trigger, [],
                                                 lltype.Void)
            self.finalizer_triggers.append(ll_trigger)
            self.finalizer_queue_indexes[fq] = index
        return index

    def gct_gc_fq_register(self, hop):
        index = self.get_finalizer_queue_index(hop)
        c_index = rmodel.inputconst(lltype.Signed, index)
        v_ptr = hop.spaceop.args[1]
        hop.genop("boehm_fq_register", [c_index, v_ptr])

    def gct_gc_fq_next_dead(self, hop):
        index = self.get_finalizer_queue_index(hop)
        c_index = rmodel.inputconst(lltype.Signed, index)
        hop.genop("boehm_fq_next_dead", [c_index],
                  resultvar = hop.spaceop.result)

    def gct_weakref_create(self, hop):
        v_instance, = hop.spaceop.args
        v_gcref = hop.genop("cast_opaque_ptr", [v_instance],
                            resulttype=llmemory.GCREF)
        v_wref = hop.genop("direct_call",
                           [self.weakref_create_ptr, v_gcref],
                           resulttype=llmemory.WeakRefPtr)
        hop.cast_result(v_wref)

    def gct_zero_everything_inside(self, hop):
        pass

    def gct_zero_gc_pointers_inside(self, hop):
        pass

    def gct_weakref_deref(self, hop):
        v_wref, = hop.spaceop.args
        v_gcref = hop.genop("direct_call",
                            [self.weakref_deref_ptr, v_wref],
                            resulttype=llmemory.GCREF)
        hop.cast_result(v_gcref)

    def gct_gc_writebarrier_before_copy(self, hop):
        # no write barrier needed
        op = hop.spaceop
        hop.genop("same_as",
                  [rmodel.inputconst(lltype.Bool, True)],
                  resultvar=op.result)

    def gct_gc_identityhash(self, hop):
        v_obj = hop.spaceop.args[0]
        if not self.translator.config.translation.reverse_debugger:
            v_addr = hop.genop("cast_ptr_to_adr", [v_obj],
                               resulttype=llmemory.Address)
            hop.genop("direct_call", [self.identityhash_ptr, v_addr],
                      resultvar=hop.spaceop.result)
        else:
            hop.genop("revdb_identityhash", [v_obj],
                      resultvar=hop.spaceop.result)

    def gct_gc_id(self, hop):
        # this is the logic from the HIDE_POINTER macro in <gc/gc.h>
        v_int = hop.genop('cast_ptr_to_int', [hop.spaceop.args[0]],
                          resulttype = lltype.Signed)
        hop.genop('int_invert', [v_int], resultvar=hop.spaceop.result)

    def gcheader_initdata(self, obj):
        if not self.translator.config.translation.reverse_debugger:
            return GCTransform.gcheader_initdata(self, obj)
        hdr = lltype.malloc(self.HDR, immortal=True, zero=True)
        return hdr._obj


########## weakrefs ##########
# Boehm: weakref objects are small structures containing only a Boehm
# disappearing link.  We don't have to hide the link's value with
# HIDE_POINTER(), because we explicitly use GC_MALLOC_ATOMIC().

def build_weakref(config):
    revdb = config.translation.reverse_debugger
    if not revdb:
        WEAKLINK = lltype.Struct('WEAKLINK',
                                 ('addr', llmemory.Address))
    else:
        # keep in sync with 'struct WEAKLINK' in revdb.c
        WEAKLINK = lltype.Struct('REVDB_WEAKLINK',
                                 ('addr', llmemory.Address),
                                 ('off_prev', lltype.SignedLongLong))
    sizeof_weakreflink = llmemory.sizeof(WEAKLINK)
    empty_weaklink = lltype.malloc(WEAKLINK, immortal=True, zero=True)

    def ll_weakref_create(target_gcref):
        if revdb:
            plink = llop.revdb_weakref_create(lltype.Ptr(WEAKLINK),
                                              target_gcref)
        else:
            link = llop.boehm_malloc_atomic(llmemory.Address,
                                            sizeof_weakreflink)
            if not link:
                raise MemoryError
            plink = llmemory.cast_adr_to_ptr(link, lltype.Ptr(WEAKLINK))
            plink.addr = llmemory.cast_ptr_to_adr(target_gcref)
            llop.boehm_disappearing_link(lltype.Void, link, target_gcref)
        return llmemory.cast_ptr_to_weakrefptr(plink)

    def ll_weakref_deref(wref):
        plink = llmemory.cast_weakrefptr_to_ptr(lltype.Ptr(WEAKLINK), wref)
        if revdb:
            result = llop.revdb_weakref_deref(llmemory.GCREF, plink)
        else:
            result = llmemory.cast_adr_to_ptr(plink.addr, llmemory.GCREF)
        return result

    def convert_weakref_to(targetptr):
        # Prebuilt weakrefs don't really need to be weak at all,
        # but we need to emulate the structure expected by ll_weakref_deref().
        # This is essentially the same code as in ll_weakref_create(), but I'm
        # not sure trying to share it is worth the hassle...
        if not targetptr:
            return empty_weaklink
        else:
            plink = lltype.malloc(WEAKLINK, immortal=True, zero=True)
            plink.addr = llmemory.cast_ptr_to_adr(targetptr)
            return plink

    return ll_weakref_create, ll_weakref_deref, WEAKLINK, convert_weakref_to
