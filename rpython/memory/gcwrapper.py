from rpython.translator.backendopt.finalizer import FinalizerAnalyzer
from rpython.rtyper.lltypesystem import lltype, llmemory, llheap
from rpython.rtyper import llinterp, rclass
from rpython.rtyper.annlowlevel import llhelper, cast_nongc_instance_to_adr
from rpython.memory import gctypelayout
from rpython.flowspace.model import Constant


class GCManagedHeap(object):

    def __init__(self, llinterp, flowgraphs, gc_class, GC_PARAMS={}):
        translator = llinterp.typer.annotator.translator
        config = translator.config.translation
        self.gc = gc_class(config,
                           chunk_size      = 10,
                           translated_to_c = False,
                           **GC_PARAMS)
        self.translator = translator
        self.gc.set_root_walker(LLInterpRootWalker(self))
        self.gc.DEBUG = True
        self.llinterp = llinterp
        self.prepare_graphs(flowgraphs)
        self.gc.setup()
        self.has_write_barrier_from_array = hasattr(self.gc,
                                                    'write_barrier_from_array')

    def prepare_graphs(self, flowgraphs):
        lltype2vtable = self.llinterp.typer.lltype2vtable
        layoutbuilder = DirectRunLayoutBuilder(self.gc.__class__,
                                               lltype2vtable,
                                               self.llinterp)
        self.get_type_id = layoutbuilder.get_type_id
        gcdata = layoutbuilder.initialize_gc_query_function(self.gc)
        self.gcdata = gcdata

        self.finalizer_queue_indexes = {}
        self.finalizer_handlers = []
        self.update_finalizer_handlers()

        constants = collect_constants(flowgraphs)
        for obj in constants:
            TYPE = lltype.typeOf(obj)
            layoutbuilder.consider_constant(TYPE, obj, self.gc)

        self.constantroots = layoutbuilder.addresses_of_static_ptrs
        self.constantrootsnongc = layoutbuilder.addresses_of_static_ptrs_in_nongc
        self.prepare_custom_trace_funcs(gcdata)
        self._all_prebuilt_gc = layoutbuilder.all_prebuilt_gc

    def prepare_custom_trace_funcs(self, gcdata):
        custom_trace_funcs = self.llinterp.typer.custom_trace_funcs

        def custom_trace(obj, typeid, callback, arg):
            for TP, func in custom_trace_funcs:
                if typeid == self.get_type_id(TP):
                    func(self.gc, obj, callback, arg)
                    return
            else:
                assert False
        
        for TP, func in custom_trace_funcs:
            gcdata._has_got_custom_trace(self.get_type_id(TP))

        self.gc.custom_trace_dispatcher = custom_trace

    # ____________________________________________________________
    #
    # Interface for the llinterp
    #
    def malloc(self, TYPE, n=None, flavor='gc', zero=False,
               track_allocation=True):
        if flavor == 'gc':
            typeid = self.get_type_id(TYPE)
            addr = self.gc.malloc(typeid, n, zero=zero)
            result = llmemory.cast_adr_to_ptr(addr, lltype.Ptr(TYPE))
            if not self.gc.malloc_zero_filled:
                gctypelayout.zero_gc_pointers(result)
            return result
        else:
            return lltype.malloc(TYPE, n, flavor=flavor, zero=zero,
                                 track_allocation=track_allocation)

    def gettypeid(self, obj):
        return self.get_type_id(lltype.typeOf(obj).TO)

    def add_memory_pressure(self, size, adr):
        if hasattr(self.gc, 'raw_malloc_memory_pressure'):
            self.gc.raw_malloc_memory_pressure(size, adr)

    def shrink_array(self, p, smallersize):
        if hasattr(self.gc, 'shrink_array'):
            addr = llmemory.cast_ptr_to_adr(p)
            return self.gc.shrink_array(addr, smallersize)
        return False

    def free(self, TYPE, flavor='gc', track_allocation=True):
        assert flavor != 'gc'
        return lltype.free(TYPE, flavor=flavor,
                           track_allocation=track_allocation)

    def setfield(self, obj, fieldname, fieldvalue):
        STRUCT = lltype.typeOf(obj).TO
        addr = llmemory.cast_ptr_to_adr(obj)
        addr += llmemory.offsetof(STRUCT, fieldname)
        self.setinterior(obj, addr, getattr(STRUCT, fieldname), fieldvalue)

    def setarrayitem(self, array, index, newitem):
        ARRAY = lltype.typeOf(array).TO
        addr = llmemory.cast_ptr_to_adr(array)
        addr += llmemory.itemoffsetof(ARRAY, index)
        self.setinterior(array, addr, ARRAY.OF, newitem, (index,))

    def setinterior(self, toplevelcontainer, inneraddr, INNERTYPE, newvalue,
                    offsets=()):
        if (lltype.typeOf(toplevelcontainer).TO._gckind == 'gc' and
            isinstance(INNERTYPE, lltype.Ptr) and INNERTYPE.TO._gckind == 'gc'):
            #
            wb = True
            if self.has_write_barrier_from_array:
                for index in offsets:
                    if type(index) is not str:
                        assert (type(index) is int    # <- fast path
                                or lltype.typeOf(index) == lltype.Signed)
                        self.gc.write_barrier_from_array(
                            llmemory.cast_ptr_to_adr(toplevelcontainer),
                            index)
                        wb = False
                        break
            #
            if wb:
                self.gc.write_barrier(
                    llmemory.cast_ptr_to_adr(toplevelcontainer))
        llheap.setinterior(toplevelcontainer, inneraddr, INNERTYPE, newvalue)

    def collect(self, *gen):
        self.gc.collect(*gen)

    def can_move(self, addr):
        return self.gc.can_move(addr)

    def pin(self, addr):
        return self.gc.pin(addr)

    def unpin(self, addr):
        self.gc.unpin(addr)

    def _is_pinned(self, addr):
        return self.gc._is_pinned(addr)

    def weakref_create_getlazy(self, objgetter):
        # we have to be lazy in reading the llinterp variable containing
        # the 'obj' pointer, because the gc.malloc() call below could
        # move it around
        type_id = self.get_type_id(gctypelayout.WEAKREF)
        addr = self.gc.malloc(type_id, None, zero=False)
        result = llmemory.cast_adr_to_ptr(addr, gctypelayout.WEAKREFPTR)
        result.weakptr = llmemory.cast_ptr_to_adr(objgetter())
        return llmemory.cast_ptr_to_weakrefptr(result)
    
    def weakref_deref(self, PTRTYPE, obj):
        addr = gctypelayout.ll_weakref_deref(obj)
        return llmemory.cast_adr_to_ptr(addr, PTRTYPE)

    def gc_id(self, ptr):
        ptr = lltype.cast_opaque_ptr(llmemory.GCREF, ptr)
        return self.gc.id(ptr)

    def writebarrier_before_copy(self, source, dest,
                                 source_start, dest_start, length):
        if self.gc.needs_write_barrier:
            source_addr = llmemory.cast_ptr_to_adr(source)
            dest_addr   = llmemory.cast_ptr_to_adr(dest)
            return self.gc.writebarrier_before_copy(source_addr, dest_addr,
                                                    source_start, dest_start,
                                                    length)
        else:
            return True

    def writebarrier_before_move(self, array):
        if self.gc.needs_write_barrier:
            array_addr = llmemory.cast_ptr_to_adr(array)
            return self.gc.writebarrier_before_move(array_addr)

    def gcflag_extra(self, subopnum, *args):
        if subopnum == 1:      # has_gcflag_extra
            assert len(args) == 0
            return self.gc.gcflag_extra != 0
        assert len(args) == 1
        addr = llmemory.cast_ptr_to_adr(args[0])
        hdr = self.gc.header(addr)
        if subopnum == 3:      # toggle_gcflag_extra
            if hdr.tid & self.gc.gcflag_extra:
                hdr.tid &= ~self.gc.gcflag_extra
            else:
                hdr.tid |= self.gc.gcflag_extra
        elif subopnum == 4:      # get_gcflag_dummy
            # returns always False if gc.gcflag_dummy == 0
            return (hdr.tid & self.gc.gcflag_dummy) != 0
        return (hdr.tid & self.gc.gcflag_extra) != 0

    def thread_run(self):
        pass

    def _get_finalizer_trigger(self, fq):
        graph = self.translator._graphof(fq.finalizer_trigger.im_func)
        def ll_trigger():
            try:
                self.llinterp.eval_graph(graph, [None], recursive=True)
            except llinterp.LLException:
                raise RuntimeError(
                    "finalizer_trigger() raised an exception, shouldn't happen")
        return ll_trigger

    def update_finalizer_handlers(self):
        handlers = self.finalizer_handlers
        ll_handlers = lltype.malloc(gctypelayout.FIN_HANDLER_ARRAY,
                                    len(handlers), immortal=True)
        for i in range(len(handlers)):
            fq, deque = handlers[i]
            ll_handlers[i].deque = cast_nongc_instance_to_adr(deque)
            ll_handlers[i].trigger = llhelper(
                lltype.Ptr(gctypelayout.FIN_TRIGGER_FUNC),
                self._get_finalizer_trigger(fq))
        self.gcdata.finalizer_handlers = llmemory.cast_ptr_to_adr(ll_handlers)

    def get_finalizer_queue_index(self, fq_tag):
        assert 'FinalizerQueue TAG' in fq_tag.expr
        fq = fq_tag.default
        try:
            index = self.finalizer_queue_indexes[fq]
        except KeyError:
            index = len(self.finalizer_handlers)
            self.finalizer_queue_indexes[fq] = index
            deque = self.gc.AddressDeque()
            self.finalizer_handlers.append((fq, deque))
            self.update_finalizer_handlers()
        return index

    def gc_fq_next_dead(self, fq_tag):
        index = self.get_finalizer_queue_index(fq_tag)
        deque = self.finalizer_handlers[index][1]
        if deque.non_empty():
            obj = deque.popleft()
        else:
            obj = llmemory.NULL
        return llmemory.cast_adr_to_ptr(obj, llmemory.GCREF)

    def gc_fq_register(self, fq_tag, ptr):
        index = self.get_finalizer_queue_index(fq_tag)
        assert lltype.typeOf(ptr) == llmemory.GCREF
        self.gc.register_finalizer(index, ptr)

# ____________________________________________________________

class LLInterpRootWalker:
    _alloc_flavor_ = 'raw'

    def __init__(self, gcheap):
        self.gcheap = gcheap

    def walk_roots(self, collect_stack_root,
                   collect_static_in_prebuilt_nongc,
                   collect_static_in_prebuilt_gc,
                   is_minor=False):
        gcheap = self.gcheap
        gc = gcheap.gc
        if collect_static_in_prebuilt_gc:
            for addrofaddr in gcheap.constantroots:
                if self.gcheap.gc.points_to_valid_gc_object(addrofaddr):
                    collect_static_in_prebuilt_gc(gc, addrofaddr)
        if collect_static_in_prebuilt_nongc:
            for addrofaddr in gcheap.constantrootsnongc:
                if self.gcheap.gc.points_to_valid_gc_object(addrofaddr):
                    collect_static_in_prebuilt_nongc(gc, addrofaddr)
        if collect_stack_root:
            for addrofaddr in gcheap.llinterp.find_roots(is_minor):
                if self.gcheap.gc.points_to_valid_gc_object(addrofaddr):
                    collect_stack_root(gc, addrofaddr)

    def _walk_prebuilt_gc(self, collect):    # debugging only!  not RPython
        for obj in self.gcheap._all_prebuilt_gc:
            collect(llmemory.cast_ptr_to_adr(obj._as_ptr()))

    def finished_minor_collection(self):
        pass


class DirectRunLayoutBuilder(gctypelayout.TypeLayoutBuilder):

    def __init__(self, GCClass, lltype2vtable, llinterp):
        self.llinterp = llinterp
        super(DirectRunLayoutBuilder, self).__init__(GCClass, lltype2vtable)

    def make_destructor_funcptr_for_type(self, TYPE):
        from rpython.memory.gctransform.support import get_rtti
        rtti = get_rtti(TYPE)
        if rtti is not None and hasattr(rtti._obj, 'destructor_funcptr'):
            destrptr = rtti._obj.destructor_funcptr
            DESTR_ARG = lltype.typeOf(destrptr).TO.ARGS[0]
            destrgraph = destrptr._obj.graph
        else:
            return None, False

        t = self.llinterp.typer.annotator.translator
        is_light = not FinalizerAnalyzer(t).analyze_light_finalizer(destrgraph)

        def ll_destructor(addr):
            try:
                v = llmemory.cast_adr_to_ptr(addr, DESTR_ARG)
                self.llinterp.eval_graph(destrgraph, [v], recursive=True)
            except llinterp.LLException:
                raise RuntimeError(
                    "a destructor raised an exception, shouldn't happen")
        return (llhelper(gctypelayout.GCData.CUSTOM_FUNC_PTR, ll_destructor),
                is_light)

    def make_custom_trace_funcptr_for_type(self, TYPE):
        from rpython.memory.gctransform.support import get_rtti
        rtti = get_rtti(TYPE)
        if rtti is not None and hasattr(rtti._obj, 'custom_trace_funcptr'):
            return rtti._obj.custom_trace_funcptr
        else:
            return None


def collect_constants(graphs):
    constants = {}
    def collect_args(args):
        for arg in args:
            if (isinstance(arg, Constant) and
                arg.concretetype is not lltype.Void):
                reccollect(constants, arg.value)
    for graph in graphs:
        for block in graph.iterblocks():
            collect_args(block.inputargs)
            for op in block.operations:
                collect_args(op.args)
        for link in graph.iterlinks():
            collect_args(link.args)
            if hasattr(link, "llexitcase"):
                reccollect(constants, link.llexitcase)
    return constants

def reccollect(constants, llvalue):
    if (isinstance(llvalue, lltype._abstract_ptr)
        and llvalue._obj is not None and llvalue._obj not in constants
        and not isinstance(llvalue._obj, int)):
        TYPE = llvalue._T
        constants[llvalue._obj] = True
        if isinstance(TYPE, lltype.Struct):
            for name in TYPE._names:
                reccollect(constants, getattr(llvalue, name))
        elif isinstance(TYPE, lltype.Array):
            for llitem in llvalue:
                reccollect(constants, llitem)
        parent, parentindex = lltype.parentlink(llvalue._obj)
        if parent is not None:
            reccollect(constants, parent._as_ptr())

def prepare_graphs_and_create_gc(llinterp, GCClass, GC_PARAMS={}):
    flowgraphs = llinterp.typer.annotator.translator.graphs[:]
    llinterp.heap = GCManagedHeap(llinterp, flowgraphs, GCClass, GC_PARAMS)
