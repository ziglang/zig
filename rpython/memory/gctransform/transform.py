from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.flowspace.model import (
    SpaceOperation, Variable, Constant, checkgraph)
from rpython.translator.unsimplify import insert_empty_block
from rpython.translator.unsimplify import insert_empty_startblock
from rpython.translator.unsimplify import starts_with_empty_block
from rpython.translator.backendopt.support import var_needsgc
from rpython.translator.backendopt import inline
from rpython.translator.backendopt.canraise import RaiseAnalyzer
from rpython.translator.backendopt.ssa import DataFlowFamilyBuilder
from rpython.translator.backendopt.constfold import constant_fold_graph
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rtyper import rmodel
from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
from rpython.rtyper.rtyper import LowLevelOpList
from rpython.rtyper.rbuiltin import gen_cast
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.translator.simplify import cleanup_graph
from rpython.memory.gctransform.log import log

class GCTransformError(Exception):
    pass

class GcHighLevelOp(object):
    def __init__(self, gct, op, index, llops):
        self.gctransformer = gct
        self.spaceop = op
        self.index = index
        self.llops = llops

    def livevars_after_op(self):
        gct = self.gctransformer
        return [
            var for var in gct.livevars
                if gct.var_last_needed_in[var] > self.index]

    def current_op_keeps_alive(self):
        gct = self.gctransformer
        return [
            var for var in self.spaceop.args
                if gct.var_last_needed_in.get(var) == self.index]

    def dispatch(self):
        gct = self.gctransformer
        opname = self.spaceop.opname
        v_result = self.spaceop.result

        meth = getattr(gct, 'gct_' + opname, gct.default)
        meth(self)

        if var_needsgc(v_result):
            gct.livevars.append(v_result)
            if opname not in ('direct_call', 'indirect_call'):
                gct.push_alive(v_result, self.llops)

    def rename(self, newopname):
        self.llops.append(
            SpaceOperation(newopname, self.spaceop.args, self.spaceop.result))

    def inputargs(self):
        return self.spaceop.args

    def genop(self, opname, args, resulttype=None, resultvar=None):
        assert resulttype is None or resultvar is None
        if resultvar is None:
            return self.llops.genop(opname, args,
                                    resulttype=resulttype)
        else:
            newop = SpaceOperation(opname, args, resultvar)
            self.llops.append(newop)
            return resultvar

    def cast_result(self, var):
        v_result = self.spaceop.result
        resulttype = v_result.concretetype
        curtype = var.concretetype
        if curtype == resulttype:
            self.genop('same_as', [var], resultvar=v_result)
        else:
            v_new = gen_cast(self.llops, resulttype, var)
            assert v_new != var
            self.llops[-1].result = v_result

# ________________________________________________________________

class BaseGCTransformer(object):
    finished_helpers = False
    curr_block = None

    def __init__(self, translator, inline=False):
        self.translator = translator
        self.seen_graphs = set()
        self.prepared = False
        self.minimal_transform = set()
        if translator:
            self.mixlevelannotator = MixLevelHelperAnnotator(translator.rtyper)
        else:
            self.mixlevelannotator = None
        self.inline = inline
        if translator and inline:
            self.lltype_to_classdef = translator.rtyper.lltype_to_classdef_mapping()
            self.raise_analyzer = RaiseAnalyzer(translator)
        self.graphs_to_inline = {}
        self.graph_dependencies = {}
        self.ll_finalizers_ptrs = []
        if self.MinimalGCTransformer:
            self.minimalgctransformer = self.MinimalGCTransformer(self)
        else:
            self.minimalgctransformer = None

    def get_lltype_of_exception_value(self):
        exceptiondata = self.translator.rtyper.exceptiondata
        return exceptiondata.lltype_of_exception_value

    def need_minimal_transform(self, graph):
        self.seen_graphs.add(graph)
        self.minimal_transform.add(graph)

    def inline_helpers_into(self, graph):
        from rpython.translator.backendopt.inline import iter_callsites
        to_enum = []
        for called, block, i in iter_callsites(graph, None):
            if called in self.graphs_to_inline:
                to_enum.append(called)
        any_inlining = False
        for inline_graph in to_enum:
            try:
                inline.inline_function(self.translator, inline_graph, graph,
                                       self.lltype_to_classdef,
                                       self.raise_analyzer,
                                       cleanup=False)
                any_inlining = True
            except inline.CannotInline as e:
                print 'CANNOT INLINE:', e
                print '\t%s into %s' % (inline_graph, graph)
                raise      # for now, make it a fatal error
        cleanup_graph(graph)
        if any_inlining:
            constant_fold_graph(graph)
        return any_inlining

    def inline_helpers_and_postprocess(self, graphs):
        next_dot = 0
        for graph in graphs:
            any_inlining = self.inline and self.inline_helpers_into(graph)
            self.postprocess_graph(graph, any_inlining)
            #
            next_dot -= 1
            if next_dot <= 0:
                log.dot()
                next_dot = 50

    def postprocess_graph(self, graph, any_inlining):
        pass

    def compute_borrowed_vars(self, graph):
        # the input args are borrowed, and stay borrowed for as long as they
        # are not merged with other values.
        var_families = DataFlowFamilyBuilder(graph).get_variable_families()
        borrowed_reps = {}
        for v in graph.getargs():
            borrowed_reps[var_families.find_rep(v)] = True
        # no support for returning borrowed values so far
        retvar = graph.getreturnvar()

        def is_borrowed(v1):
            return (var_families.find_rep(v1) in borrowed_reps
                    and v1 is not retvar)
        return is_borrowed

    def transform_block(self, block, is_borrowed):
        llops = LowLevelOpList()
        self.curr_block = block
        self.livevars = [var for var in block.inputargs
                    if var_needsgc(var) and not is_borrowed(var)]
        allvars = [var for var in block.getvariables() if var_needsgc(var)]
        self.var_last_needed_in = dict.fromkeys(allvars, 0)
        for i, op in enumerate(block.operations):
            for var in op.args:
                if not var_needsgc(var):
                    continue
                self.var_last_needed_in[var] = i
        for link in block.exits:
            for var in link.args:
                if not var_needsgc(var):
                    continue
                self.var_last_needed_in[var] = len(block.operations) + 1

        for i, op in enumerate(block.operations):
            hop = GcHighLevelOp(self, op, i, llops)
            hop.dispatch()

        if len(block.exits) != 0: # i.e not the return block
            assert not block.canraise

            deadinallexits = set(self.livevars)
            for link in block.exits:
                deadinallexits.difference_update(set(link.args))

            for var in deadinallexits:
                self.pop_alive(var, llops)

            for link in block.exits:
                livecounts = dict.fromkeys(set(self.livevars) - deadinallexits, 1)
                for v, v2 in zip(link.args, link.target.inputargs):
                    if is_borrowed(v2):
                        continue
                    if v in livecounts:
                        livecounts[v] -= 1
                    elif var_needsgc(v):
                        # 'v' is typically a Constant here, but it can be
                        # a borrowed variable going into a non-borrowed one
                        livecounts[v] = -1
                self.links_to_split[link] = livecounts

            block.operations[:] = llops
        self.livevars = None
        self.var_last_needed_in = None
        self.curr_block = None

    def transform_graph(self, graph):
        if graph in self.minimal_transform:
            if self.minimalgctransformer:
                self.minimalgctransformer.transform_graph(graph)
            self.minimal_transform.remove(graph)
            return
        if graph in self.seen_graphs:
            return
        self.seen_graphs.add(graph)

        self.links_to_split = {} # link -> vars to pop_alive across the link

        # for sanity, we need an empty block at the start of the graph
        inserted_empty_startblock = False
        if not starts_with_empty_block(graph):
            insert_empty_startblock(graph)
            inserted_empty_startblock = True
        is_borrowed = self.compute_borrowed_vars(graph)

        try:
            for block in graph.iterblocks():
                self.transform_block(block, is_borrowed)
        except GCTransformError as e:
            e.args = ('[function %s]: %s' % (graph.name, e.message),)
            raise

        for link, livecounts in self.links_to_split.iteritems():
            llops = LowLevelOpList()
            for var, livecount in livecounts.iteritems():
                for i in range(livecount):
                    self.pop_alive(var, llops)
                for i in range(-livecount):
                    self.push_alive(var, llops)
            if llops:
                if link.prevblock.exitswitch is None:
                    link.prevblock.operations.extend(llops)
                else:
                    insert_empty_block(link, llops)

        # remove the empty block at the start of the graph, which should
        # still be empty (but let's check)
        if starts_with_empty_block(graph) and inserted_empty_startblock:
            old_startblock = graph.startblock
            graph.startblock = graph.startblock.exits[0].target

        checkgraph(graph)

        self.links_to_split = None
        v = Variable('vanishing_exc_value')
        v.concretetype = self.get_lltype_of_exception_value()
        llops = LowLevelOpList()
        self.pop_alive(v, llops)
        graph.exc_cleanup = (v, list(llops))
        return is_borrowed    # xxx for tests only

    def annotate_helper(self, ll_helper, ll_args, ll_result, inline=False):
        assert not self.finished_helpers
        args_s = map(lltype_to_annotation, ll_args)
        s_result = lltype_to_annotation(ll_result)
        graph = self.mixlevelannotator.getgraph(ll_helper, args_s, s_result)
        # the produced graphs does not need to be fully transformed
        self.need_minimal_transform(graph)
        if inline:
            self.graphs_to_inline[graph] = True
        FUNCTYPE = lltype.FuncType(ll_args, ll_result)
        return self.mixlevelannotator.graph2delayed(graph, FUNCTYPE=FUNCTYPE)

    def inittime_helper(self, ll_helper, ll_args, ll_result, inline=True):
        ptr = self.annotate_helper(ll_helper, ll_args, ll_result, inline=inline)
        return Constant(ptr, lltype.typeOf(ptr))

    def annotate_finalizer(self, ll_finalizer, ll_args, ll_result):
        fptr = self.annotate_helper(ll_finalizer, ll_args, ll_result)
        self.ll_finalizers_ptrs.append(fptr)
        return fptr

    def finish_helpers(self, backendopt=True):
        if self.translator is not None:
            self.mixlevelannotator.finish_annotate()
        if self.translator is not None:
            self.mixlevelannotator.finish_rtype()
            if backendopt:
                self.mixlevelannotator.backend_optimize()
        self.finished_helpers = True
        # Make sure that the database also sees all finalizers now.
        # It is likely that the finalizers need special support there
        newgcdependencies = self.ll_finalizers_ptrs
        return newgcdependencies

    def get_finish_helpers(self):
        return self.finish_helpers

    def finish_tables(self):
        pass

    def get_finish_tables(self):
        return self.finish_tables

    def finish(self, backendopt=True):
        self.finish_helpers(backendopt=backendopt)
        self.finish_tables()

    def transform_generic_set(self, hop):
        opname = hop.spaceop.opname
        v_new = hop.spaceop.args[-1]
        v_old = hop.genop('g' + opname[1:],
                          hop.inputargs()[:-1],
                          resulttype=v_new.concretetype)
        self.push_alive(v_new, hop.llops)
        hop.rename('bare_' + opname)
        self.pop_alive(v_old, hop.llops)

    def push_alive(self, var, llops):
        pass

    def pop_alive(self, var, llops):
        pass

    def var_needs_set_transform(self, var):
        return False

    def default(self, hop):
        hop.llops.append(hop.spaceop)

    def gct_setfield(self, hop):
        if self.var_needs_set_transform(hop.spaceop.args[-1]):
            self.transform_generic_set(hop)
        else:
            hop.rename('bare_' + hop.spaceop.opname)
    gct_setarrayitem = gct_setfield
    gct_setinteriorfield = gct_setfield
    gct_raw_store = gct_setfield

    gct_getfield = default

    def gct_zero_gc_pointers_inside(self, hop):
        pass

    def gct_gc_writebarrier_before_copy(self, hop):
        # We take the conservative default and return False here, meaning
        # that rgc.ll_arraycopy() will do the copy by hand (i.e. with a
        # 'for' loop).  Subclasses that have their own logic, or that don't
        # need any kind of write barrier, may return True.
        op = hop.spaceop
        hop.genop("same_as",
                  [rmodel.inputconst(lltype.Bool, False)],
                  resultvar=op.result)

    def gct_gc_writebarrier_before_move(self, hop):
        pass

    def gct_gc_pin(self, hop):
        op = hop.spaceop
        hop.genop("same_as",
                    [rmodel.inputconst(lltype.Bool, False)],
                    resultvar=op.result)

    def gct_gc_unpin(self, hop):
        pass

    def gct_gc__is_pinned(self, hop):
        op = hop.spaceop
        hop.genop("same_as",
                  [rmodel.inputconst(lltype.Bool, False)],
                  resultvar=op.result)

    def gct_gc_identityhash(self, hop):
        # must be implemented in the various GCs
        raise NotImplementedError

    def gct_gc_id(self, hop):
        # this assumes a non-moving GC.  Moving GCs need to override this
        hop.rename('cast_ptr_to_int')

    def gct_gc_heap_stats(self, hop):
        from rpython.memory.gc.base import ARRAY_TYPEID_MAP

        return hop.cast_result(rmodel.inputconst(lltype.Ptr(ARRAY_TYPEID_MAP),
                                        lltype.nullptr(ARRAY_TYPEID_MAP)))


class MinimalGCTransformer(BaseGCTransformer):
    def __init__(self, parenttransformer):
        BaseGCTransformer.__init__(self, parenttransformer.translator)
        self.parenttransformer = parenttransformer

    def push_alive(self, var, llops):
        pass

    def pop_alive(self, var, llops):
        pass

    def gct_malloc(self, hop):
        flags = hop.spaceop.args[1].value
        flavor = flags['flavor']
        assert flavor == 'raw'
        assert not flags.get('zero')
        return self.parenttransformer.gct_malloc(hop)

    def gct_malloc_varsize(self, hop):
        flags = hop.spaceop.args[1].value
        flavor = flags['flavor']
        assert flavor == 'raw'
        assert not flags.get('zero')
        return self.parenttransformer.gct_malloc_varsize(hop)

    def gct_free(self, hop):
        flags = hop.spaceop.args[1].value
        flavor = flags['flavor']
        assert flavor == 'raw'
        return self.parenttransformer.gct_free(hop)

BaseGCTransformer.MinimalGCTransformer = MinimalGCTransformer
MinimalGCTransformer.MinimalGCTransformer = None

# ________________________________________________________________

def mallocHelpers(gckind):
    class _MallocHelpers(object):
        def _freeze_(self):
            return True
    mh = _MallocHelpers()

    def _ll_malloc_fixedsize(size):
        result = mh.allocate(size)
        if not result:
            raise MemoryError()
        return result
    mh._ll_malloc_fixedsize = _ll_malloc_fixedsize

    def _ll_malloc_fixedsize_zero(size):
        result = mh.allocate(size, zero=True)
        if not result:
            raise MemoryError()
        return result
    mh._ll_malloc_fixedsize_zero = _ll_malloc_fixedsize_zero

    def _ll_compute_size(length, size, itemsize):
        try:
            varsize = ovfcheck(itemsize * length)
            tot_size = ovfcheck(size + varsize)
        except OverflowError:
            raise MemoryError()
        return tot_size
    _ll_compute_size._always_inline_ = True

    def _ll_malloc_varsize_no_length(length, size, itemsize):
        tot_size = _ll_compute_size(length, size, itemsize)
        result = mh.allocate(tot_size)
        if not result:
            raise MemoryError()
        return result
    mh._ll_malloc_varsize_no_length = _ll_malloc_varsize_no_length
    mh.ll_malloc_varsize_no_length = _ll_malloc_varsize_no_length

    if gckind == 'raw':
        llopstore = llop.raw_store
    elif gckind == 'gc':
        llopstore = llop.gc_store
    else:
        raise AssertionError(gckind)


    def ll_malloc_varsize(length, size, itemsize, lengthoffset):
        result = mh.ll_malloc_varsize_no_length(length, size, itemsize)
        llopstore(lltype.Void, result, lengthoffset, length)
        return result
    mh.ll_malloc_varsize = ll_malloc_varsize

    def _ll_malloc_varsize_no_length_zero(length, size, itemsize):
        tot_size = _ll_compute_size(length, size, itemsize)
        result = mh.allocate(tot_size, zero=True)
        if not result:
            raise MemoryError()
        return result
    mh.ll_malloc_varsize_no_length_zero = _ll_malloc_varsize_no_length_zero

    return mh

class GCTransformer(BaseGCTransformer):

    def __init__(self, translator, inline=False):
        super(GCTransformer, self).__init__(translator, inline=inline)

        mh = mallocHelpers(gckind='raw')
        mh.allocate = llmemory.raw_malloc
        ll_raw_malloc_fixedsize = mh._ll_malloc_fixedsize
        ll_raw_malloc_fixedsize_zero = mh._ll_malloc_fixedsize_zero
        ll_raw_malloc_varsize_no_length = mh.ll_malloc_varsize_no_length
        ll_raw_malloc_varsize = mh.ll_malloc_varsize
        ll_raw_malloc_varsize_no_length_zero  = mh.ll_malloc_varsize_no_length_zero

        if self.translator:
            self.raw_malloc_fixedsize_ptr = self.inittime_helper(
                ll_raw_malloc_fixedsize, [lltype.Signed], llmemory.Address)
            self.raw_malloc_fixedsize_zero_ptr = self.inittime_helper(
                ll_raw_malloc_fixedsize_zero, [lltype.Signed], llmemory.Address)
            self.raw_malloc_varsize_no_length_ptr = self.inittime_helper(
                ll_raw_malloc_varsize_no_length, [lltype.Signed]*3, llmemory.Address, inline=False)
            self.raw_malloc_varsize_ptr = self.inittime_helper(
                ll_raw_malloc_varsize, [lltype.Signed]*4, llmemory.Address, inline=False)
            self.raw_malloc_varsize_no_length_zero_ptr = self.inittime_helper(
                ll_raw_malloc_varsize_no_length_zero, [lltype.Signed]*3, llmemory.Address, inline=False)

    def gct_malloc(self, hop, add_flags=None):
        TYPE = hop.spaceop.result.concretetype.TO
        if TYPE._hints.get('never_allocate'):
            raise GCTransformError(
                "struct %s was marked as @never_allocate but a call to malloc() "
                "was found. This probably means that the corresponding class is "
                "supposed to be constant-folded away, but for some reason it was not."
                % TYPE._name)
        assert not TYPE._is_varsize()
        flags = hop.spaceop.args[1].value
        flavor = flags['flavor']
        meth = getattr(self, 'gct_fv_%s_malloc' % flavor, None)
        assert meth, "%s has no support for malloc with flavor %r" % (self, flavor)
        c_size = rmodel.inputconst(lltype.Signed, llmemory.sizeof(TYPE))
        v_raw = meth(hop, flags, TYPE, c_size)
        hop.cast_result(v_raw)

    def gct_fv_raw_malloc(self, hop, flags, TYPE, c_size):
        if flags.get('zero'):
            ll_func = self.raw_malloc_fixedsize_zero_ptr
        else:
            ll_func = self.raw_malloc_fixedsize_ptr
        v_raw = hop.genop("direct_call", [ll_func, c_size],
                          resulttype=llmemory.Address)
        if flags.get('track_allocation', True):
            hop.genop("track_alloc_start", [v_raw])
        return v_raw

    def gct_malloc_varsize(self, hop, add_flags=None):
        flags = hop.spaceop.args[1].value
        if add_flags:
            flags.update(add_flags)
        flavor = flags['flavor']
        meth = getattr(self, 'gct_fv_%s_malloc_varsize' % flavor, None)
        assert meth, "%s has no support for malloc_varsize with flavor %r" % (self, flavor)
        return self.varsize_malloc_helper(hop, flags, meth, [])

    def gct_gc_add_memory_pressure(self, hop):
        pass

    def varsize_malloc_helper(self, hop, flags, meth, extraargs):
        def intconst(c): return rmodel.inputconst(lltype.Signed, c)
        op = hop.spaceop
        TYPE = op.result.concretetype.TO
        assert TYPE._is_varsize()
        if isinstance(TYPE, lltype.Struct):
            ARRAY = TYPE._flds[TYPE._arrayfld]
        else:
            ARRAY = TYPE
        assert isinstance(ARRAY, lltype.Array)
        c_const_size = intconst(llmemory.sizeof(TYPE, 0))
        c_item_size = intconst(llmemory.sizeof(ARRAY.OF))

        if ARRAY._hints.get("nolength", False):
            c_offset_to_length = None
        else:
            if isinstance(TYPE, lltype.Struct):
                offset_to_length = llmemory.FieldOffset(TYPE, TYPE._arrayfld) + \
                                   llmemory.ArrayLengthOffset(ARRAY)
            else:
                offset_to_length = llmemory.ArrayLengthOffset(ARRAY)
            c_offset_to_length = intconst(offset_to_length)

        args = [hop] + extraargs + [flags, TYPE,
                op.args[-1], c_const_size, c_item_size, c_offset_to_length]
        v_raw = meth(*args)
        hop.cast_result(v_raw)

    def gct_fv_raw_malloc_varsize(self, hop, flags, TYPE, v_length, c_const_size, c_item_size,
                                                                    c_offset_to_length):
        if flags.get('add_memory_pressure', False):
            if hasattr(self, 'raw_malloc_memory_pressure_varsize_ptr'):
                v_adr = rmodel.inputconst(llmemory.Address, llmemory.NULL)
                hop.genop("direct_call",
                          [self.raw_malloc_memory_pressure_varsize_ptr,
                           v_length, c_item_size, v_adr])
        if c_offset_to_length is None:
            if flags.get('zero'):
                fnptr = self.raw_malloc_varsize_no_length_zero_ptr
            else:
                fnptr = self.raw_malloc_varsize_no_length_ptr
            v_raw = hop.genop("direct_call",
                               [fnptr, v_length, c_const_size, c_item_size],
                               resulttype=llmemory.Address)
        else:
            if flags.get('zero'):
                raise NotImplementedError("raw zero varsize malloc with length field")
            v_raw = hop.genop("direct_call",
                               [self.raw_malloc_varsize_ptr, v_length,
                                c_const_size, c_item_size, c_offset_to_length],
                               resulttype=llmemory.Address)
        if flags.get('track_allocation', True):
            hop.genop("track_alloc_start", [v_raw])
        return v_raw

    def gct_free(self, hop):
        op = hop.spaceop
        flags = op.args[1].value
        flavor = flags['flavor']
        v = op.args[0]
        if flavor == 'raw':
            v = hop.genop("cast_ptr_to_adr", [v], resulttype=llmemory.Address)
            if flags.get('track_allocation', True):
                hop.genop("track_alloc_stop", [v])
            hop.genop('raw_free', [v])
        else:
            assert False, "%s has no support for free with flavor %r" % (self, flavor)

    def gct_gc_can_move(self, hop):
        return hop.cast_result(rmodel.inputconst(lltype.Bool, False))

    def gct_shrink_array(self, hop):
        return hop.cast_result(rmodel.inputconst(lltype.Bool, False))
