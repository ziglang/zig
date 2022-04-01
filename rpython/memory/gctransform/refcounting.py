from rpython.memory.gctransform.transform import GCTransformer, mallocHelpers
from rpython.memory.gctransform.support import find_gc_ptrs_in_type, \
     get_rtti, _static_deallocator_body_for_type, LLTransformerOp, ll_call_destructor
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.translator.backendopt.support import var_needsgc
from rpython.rtyper import rmodel
from rpython.memory.gcheader import GCHeaderBuilder
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rtyper.rbuiltin import gen_cast
import sys

counts = {}


ADDRESS_VOID_FUNC = lltype.FuncType([llmemory.Address], lltype.Void)

class RefcountingGCTransformer(GCTransformer):
    malloc_zero_filled = True

    HDR = lltype.Struct("header", ("refcount", lltype.Signed))

    def __init__(self, translator):
        super(RefcountingGCTransformer, self).__init__(translator, inline=True)
        self.gcheaderbuilder = GCHeaderBuilder(self.HDR)
        gc_header_offset = self.gcheaderbuilder.size_gc_header
        self.deallocator_graphs_needing_transforming = []

        # create incref, etc  graph

        memoryError = MemoryError()
        HDRPTR = lltype.Ptr(self.HDR)

        def ll_incref(adr):
            if adr:
                gcheader = llmemory.cast_adr_to_ptr(adr - gc_header_offset, HDRPTR)
                gcheader.refcount = gcheader.refcount + 1
        def ll_decref(adr, dealloc):
            if adr:
                gcheader = llmemory.cast_adr_to_ptr(adr - gc_header_offset, HDRPTR)
                refcount = gcheader.refcount - 1
                gcheader.refcount = refcount
                if refcount == 0:
                    dealloc(adr)
        def ll_decref_simple(adr):
            if adr:
                gcheader = llmemory.cast_adr_to_ptr(adr - gc_header_offset, HDRPTR)
                refcount = gcheader.refcount - 1
                if refcount == 0:
                    llop.gc_free(lltype.Void, adr)
                else:
                    gcheader.refcount = refcount
        def ll_no_pointer_dealloc(adr):
            llop.gc_free(lltype.Void, adr)

        mh = mallocHelpers(gckind='gc')
        mh.allocate = llmemory.raw_malloc
        def ll_malloc_fixedsize(size):
            size = gc_header_offset + size
            result = mh._ll_malloc_fixedsize(size)
            llmemory.raw_memclear(result, size)
            result += gc_header_offset
            return result
        def ll_malloc_varsize_no_length(length, size, itemsize):
            try:
                fixsize = gc_header_offset + size
                varsize = ovfcheck(itemsize * length)
                tot_size = ovfcheck(fixsize + varsize)
            except OverflowError:
                raise MemoryError()
            result = mh._ll_malloc_fixedsize(tot_size)
            llmemory.raw_memclear(result, tot_size)
            result += gc_header_offset
            return result
        mh.ll_malloc_varsize_no_length = ll_malloc_varsize_no_length
        ll_malloc_varsize = mh.ll_malloc_varsize

        def ll_identityhash(addr):
            h = llmemory.cast_adr_to_int(addr)
            return h

        if self.translator:
            self.increfptr = self.inittime_helper(
                ll_incref, [llmemory.Address], lltype.Void)
            self.decref_ptr = self.inittime_helper(
                ll_decref, [llmemory.Address, lltype.Ptr(ADDRESS_VOID_FUNC)],
                lltype.Void)
            self.decref_simple_ptr = self.inittime_helper(
                ll_decref_simple, [llmemory.Address], lltype.Void)
            self.no_pointer_dealloc_ptr = self.inittime_helper(
                ll_no_pointer_dealloc, [llmemory.Address], lltype.Void)
            self.malloc_fixedsize_ptr = self.inittime_helper(
                ll_malloc_fixedsize, [lltype.Signed], llmemory.Address)
            self.malloc_varsize_no_length_ptr = self.inittime_helper(
                ll_malloc_varsize_no_length, [lltype.Signed]*3, llmemory.Address)
            self.malloc_varsize_ptr = self.inittime_helper(
                ll_malloc_varsize, [lltype.Signed]*4, llmemory.Address)
            self.identityhash_ptr = self.inittime_helper(
                ll_identityhash, [llmemory.Address], lltype.Signed,
                inline=False)
            self.mixlevelannotator.finish()
            self.mixlevelannotator.backend_optimize()
        # cache graphs:
        self.decref_funcptrs = {}
        self.static_deallocator_funcptrs = {}
        self.dynamic_deallocator_funcptrs = {}
        self.queryptr2dynamic_deallocator_funcptr = {}

    def finish_helpers(self, **kwds):
        GCTransformer.finish_helpers(self, **kwds)
        from rpython.translator.backendopt.malloc import remove_mallocs
        seen = {}
        graphs = []
        for fptr in self.static_deallocator_funcptrs.itervalues():
            graph = fptr._obj.graph
            if graph in seen:
                continue
            seen[graph] = True
            graphs.append(graph)
        remove_mallocs(self.translator, graphs)

    def var_needs_set_transform(self, var):
        return var_needsgc(var)

    def push_alive(self, var, llops):
        v_adr = gen_cast(llops, llmemory.Address, var)
        llops.genop("direct_call", [self.increfptr, v_adr])

    def pop_alive(self, var, llops):
        PTRTYPE = var.concretetype
        v_adr = gen_cast(llops, llmemory.Address, var)

        dealloc_fptr = self.dynamic_deallocation_funcptr_for_type(PTRTYPE.TO)
        if dealloc_fptr is self.no_pointer_dealloc_ptr.value:
            # simple case
            llops.genop("direct_call", [self.decref_simple_ptr, v_adr])
        else:
            cdealloc_fptr = rmodel.inputconst(
                lltype.typeOf(dealloc_fptr), dealloc_fptr)
            llops.genop("direct_call", [self.decref_ptr, v_adr, cdealloc_fptr])

    def gct_fv_gc_malloc(self, hop, flags, TYPE, c_size):
        v_raw = hop.genop("direct_call", [self.malloc_fixedsize_ptr, c_size],
                          resulttype=llmemory.Address)
        return v_raw

    def gct_fv_gc_malloc_varsize(self, hop, flags, TYPE, v_length, c_const_size, c_item_size,
                                                                   c_offset_to_length):
        if c_offset_to_length is None:
            v_raw = hop.genop("direct_call",
                               [self.malloc_varsize_no_length_ptr, v_length,
                                c_const_size, c_item_size],
                               resulttype=llmemory.Address)
        else:
            v_raw = hop.genop("direct_call",
                               [self.malloc_varsize_ptr, v_length,
                                c_const_size, c_item_size, c_offset_to_length],
                               resulttype=llmemory.Address)
        return v_raw

    def gct_gc_deallocate(self, hop):
        TYPE = hop.spaceop.args[0].value
        v_addr = hop.spaceop.args[1]
        dealloc_fptr = self.dynamic_deallocation_funcptr_for_type(TYPE)
        cdealloc_fptr = rmodel.inputconst(
            lltype.typeOf(dealloc_fptr), dealloc_fptr)
        hop.genop("direct_call", [cdealloc_fptr, v_addr])

    def consider_constant(self, TYPE, value):
        if value is not lltype.top_container(value):
                return
        if isinstance(TYPE, (lltype.GcStruct, lltype.GcArray)):
            p = value._as_ptr()
            if not self.gcheaderbuilder.get_header(p):
                hdr = self.gcheaderbuilder.new_header(p)
                hdr.refcount = sys.maxint // 2

    def static_deallocation_funcptr_for_type(self, TYPE):
        if TYPE in self.static_deallocator_funcptrs:
            return self.static_deallocator_funcptrs[TYPE]
        #print_call_chain(self)

        rtti = get_rtti(TYPE)
        if rtti is not None and hasattr(rtti._obj, 'destructor_funcptr'):
            destrptr = rtti._obj.destructor_funcptr
            DESTR_ARG = lltype.typeOf(destrptr).TO.ARGS[0]
        else:
            destrptr = None
            DESTR_ARG = None

        if destrptr is None and not find_gc_ptrs_in_type(TYPE):
            p = self.no_pointer_dealloc_ptr.value
            self.static_deallocator_funcptrs[TYPE] = p
            return p

        if destrptr is not None:
            body = '\n'.join(_static_deallocator_body_for_type('v', TYPE, 3))
            src = """
def ll_deallocator(addr):
    exc_instance = llop.gc_fetch_exception(EXC_INSTANCE_TYPE)
    try:
        v = cast_adr_to_ptr(addr, PTR_TYPE)
        gcheader = cast_adr_to_ptr(addr - gc_header_offset, HDRPTR)
        # refcount is at zero, temporarily bump it to 1:
        gcheader.refcount = 1
        destr_v = cast_pointer(DESTR_ARG, v)
        ll_call_destructor(destrptr, destr_v, %r)
        refcount = gcheader.refcount - 1
        gcheader.refcount = refcount
        if refcount == 0:
%s
            llop.%s_free(lltype.Void, addr)
    except:
        pass
    llop.gc_restore_exception(lltype.Void, exc_instance)
    pop_alive(exc_instance)
    # XXX layering of exceptiontransform versus gcpolicy

""" % (TYPE.__name__, body, TYPE._gckind)
        else:
            call_del = None
            body = '\n'.join(_static_deallocator_body_for_type('v', TYPE))
            src = ('def ll_deallocator(addr):\n    v = cast_adr_to_ptr(addr, PTR_TYPE)\n' +
                   body + '\n    llop.%s_free(lltype.Void, addr)\n' % (TYPE._gckind,))
        d = {'pop_alive': LLTransformerOp(self.pop_alive),
             'llop': llop,
             'lltype': lltype,
             'destrptr': destrptr,
             'gc_header_offset': self.gcheaderbuilder.size_gc_header,
             'cast_adr_to_ptr': llmemory.cast_adr_to_ptr,
             'cast_pointer': lltype.cast_pointer,
             'PTR_TYPE': lltype.Ptr(TYPE),
             'DESTR_ARG': DESTR_ARG,
             'EXC_INSTANCE_TYPE': self.translator.rtyper.exceptiondata.lltype_of_exception_value,
             'll_call_destructor': ll_call_destructor,
             'HDRPTR':lltype.Ptr(self.HDR)}
        exec(src, d)
        this = d['ll_deallocator']
        fptr = self.annotate_finalizer(this, [llmemory.Address], lltype.Void)
        self.static_deallocator_funcptrs[TYPE] = fptr
        for p in find_gc_ptrs_in_type(TYPE):
            self.static_deallocation_funcptr_for_type(p.TO)
        return fptr

    def dynamic_deallocation_funcptr_for_type(self, TYPE):
        if TYPE in self.dynamic_deallocator_funcptrs:
            return self.dynamic_deallocator_funcptrs[TYPE]
        #print_call_chain(self)

        rtti = get_rtti(TYPE)
        if rtti is None:
            p = self.static_deallocation_funcptr_for_type(TYPE)
            self.dynamic_deallocator_funcptrs[TYPE] = p
            return p

        queryptr = rtti._obj.query_funcptr
        if queryptr._obj in self.queryptr2dynamic_deallocator_funcptr:
            return self.queryptr2dynamic_deallocator_funcptr[queryptr._obj]

        RTTI_PTR = lltype.Ptr(lltype.RuntimeTypeInfo)
        QUERY_ARG_TYPE = lltype.typeOf(queryptr).TO.ARGS[0]
        gc_header_offset = self.gcheaderbuilder.size_gc_header
        HDRPTR = lltype.Ptr(self.HDR)
        def ll_dealloc(addr):
            # bump refcount to 1
            gcheader = llmemory.cast_adr_to_ptr(addr - gc_header_offset, HDRPTR)
            gcheader.refcount = 1
            v = llmemory.cast_adr_to_ptr(addr, QUERY_ARG_TYPE)
            rtti = queryptr(v)
            gcheader.refcount = 0
            llop.gc_call_rtti_destructor(lltype.Void, rtti, addr)
        fptr = self.annotate_helper(ll_dealloc, [llmemory.Address], lltype.Void)
        self.dynamic_deallocator_funcptrs[TYPE] = fptr
        self.queryptr2dynamic_deallocator_funcptr[queryptr._obj] = fptr
        return fptr

    def gct_gc_identityhash(self, hop):
        v_obj = hop.spaceop.args[0]
        v_adr = hop.genop("cast_ptr_to_adr", [v_obj],
                          resulttype=llmemory.Address)
        hop.genop("direct_call", [self.identityhash_ptr, v_adr],
                  resultvar=hop.spaceop.result)

    def gcheader_initdata(self, obj):
        top = lltype.top_container(obj)
        return self.gcheaderbuilder.header_of_object(top)._obj
