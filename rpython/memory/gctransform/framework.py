from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import SomeAddress, SomePtr
from rpython.rlib import rgc
from rpython.rlib.objectmodel import specialize
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper import rmodel, annlowlevel
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, llgroup
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.memory import gctypelayout
from rpython.memory.gctransform.log import log
from rpython.memory.gctransform.support import get_rtti, ll_call_destructor
from rpython.memory.gctransform.support import ll_report_finalizer_error
from rpython.memory.gctransform.transform import GCTransformer
from rpython.memory.gctypelayout import ll_weakref_deref, WEAKREF, WEAKREFPTR
from rpython.memory.gctypelayout import FIN_TRIGGER_FUNC, FIN_HANDLER_ARRAY
from rpython.tool.sourcetools import func_with_new_name
from rpython.translator.backendopt.collectanalyze import CollectAnalyzer
from rpython.translator.backendopt.finalizer import FinalizerAnalyzer
from rpython.translator.backendopt.support import var_needsgc
import types


TYPE_ID = llgroup.HALFWORD


def propagate_no_write_barrier_needed(result, block, mallocvars,
                                      collect_analyzer, entrymap,
                                      startindex=0):
    # We definitely know that no write barrier is needed in the 'block'
    # for any of the variables in 'mallocvars'.  Propagate this information
    # forward.  Note that "definitely know" implies that we just did either
    # a fixed-size malloc (variable-size might require card marking), or
    # that we just did a full write barrier (not just for card marking).
    if 1:       # keep indentation
        for i, op in enumerate(block.operations):
            if i < startindex:
                continue
            if op.opname in ("cast_pointer", "same_as"):
                if op.args[0] in mallocvars:
                    mallocvars[op.result] = True
            elif op.opname in ("setfield", "setarrayitem", "setinteriorfield"):
                TYPE = op.args[-1].concretetype
                if (op.args[0] in mallocvars and
                    isinstance(TYPE, lltype.Ptr) and
                    TYPE.TO._gckind == "gc"):
                    result.add(op)
            else:
                if collect_analyzer.analyze(op):
                    return
        for exit in block.exits:
            if len(entrymap[exit.target]) != 1:
                continue
            newmallocvars = {}
            for i, var in enumerate(exit.args):
                if var in mallocvars:
                    newmallocvars[exit.target.inputargs[i]] = True
            if newmallocvars:
                propagate_no_write_barrier_needed(result, exit.target,
                                                  newmallocvars,
                                                  collect_analyzer, entrymap)

def find_initializing_stores(collect_analyzer, graph, entrymap):
    # a bit of a hackish analysis: if a block contains a malloc and check that
    # the result is not zero, then the block following the True link will
    # usually initialize the newly allocated object
    result = set()
    mallocnum = 0
    blockset = set(graph.iterblocks())
    while blockset:
        block = blockset.pop()
        if len(block.operations) < 2:
            continue
        mallocop = block.operations[-2]
        checkop = block.operations[-1]
        if not (mallocop.opname == "malloc" and
                checkop.opname == "ptr_nonzero" and
                mallocop.result is checkop.args[0] and
                block.exitswitch is checkop.result):
            continue
        rtti = get_rtti(mallocop.args[0].value)
        if rtti is not None and hasattr(rtti._obj, 'destructor_funcptr'):
            continue
        exits = [exit for exit in block.exits if exit.llexitcase]
        if len(exits) != 1:
            continue
        exit = exits[0]
        if len(entrymap[exit.target]) != 1:
            continue
        try:
            index = exit.args.index(mallocop.result)
        except ValueError:
            continue
        target = exit.target
        mallocvars = {target.inputargs[index]: True}
        mallocnum += 1
        propagate_no_write_barrier_needed(result, target, mallocvars,
                                          collect_analyzer, entrymap)
    #if result:
    #    print "found %s initializing stores in %s" % (len(result), graph.name)
    return result

def find_clean_setarrayitems(collect_analyzer, graph):
    result = set()
    for block in graph.iterblocks():
        cache = set()
        for op in block.operations:
            if op.opname == 'getarrayitem':
                cache.add((op.args[0], op.result))
            elif op.opname == 'setarrayitem':
                if (op.args[0], op.args[2]) in cache:
                    result.add(op)
            elif collect_analyzer.analyze(op):
                cache = set()
    return result

class BaseFrameworkGCTransformer(GCTransformer):
    root_stack_depth = None    # for tests to override

    def __init__(self, translator, gchooks=None):
        from rpython.memory.gc.base import choose_gc_from_config

        super(BaseFrameworkGCTransformer, self).__init__(translator,
                                                         inline=True)
        if hasattr(self, 'GC_PARAMS'):
            # for tests: the GC choice can be specified as class attributes
            GCClass = self.GCClass
            GC_PARAMS = self.GC_PARAMS
        else:
            # for regular translation: pick the GC from the config
            GCClass, GC_PARAMS = choose_gc_from_config(translator.config)
            self.GCClass = GCClass

        if hasattr(translator, '_jit2gc'):
            self.layoutbuilder = translator._jit2gc['layoutbuilder']
            finished_minor_collection = translator._jit2gc.get(
                'invoke_after_minor_collection', None)
        else:
            self.layoutbuilder = TransformerLayoutBuilder(translator, GCClass)
            finished_minor_collection = None
        self.layoutbuilder.transformer = self
        self.get_type_id = self.layoutbuilder.get_type_id

        # set up GCData with the llgroup from the layoutbuilder, which
        # will grow as more TYPE_INFO members are added to it
        gcdata = gctypelayout.GCData(self.layoutbuilder.type_info_group)

        # initialize the following two fields with a random non-NULL address,
        # to make the annotator happy.  The fields are patched in finish()
        # to point to a real array.
        foo = lltype.malloc(lltype.FixedSizeArray(llmemory.Address, 1),
                            immortal=True, zero=True)
        a_random_address = llmemory.cast_ptr_to_adr(foo)
        gcdata.static_root_start = a_random_address      # patched in finish()
        gcdata.static_root_nongcend = a_random_address   # patched in finish()
        gcdata.static_root_end = a_random_address        # patched in finish()
        gcdata.max_type_id = 13                          # patched in finish()
        gcdata.typeids_z = a_random_address              # patched in finish()
        gcdata.typeids_list = a_random_address           # patched in finish()
        gcdata.finalizer_handlers = a_random_address     # patched in finish()
        self.gcdata = gcdata
        self.malloc_fnptr_cache = {}
        self.finalizer_queue_indexes = {}
        self.finalizer_handlers = []

        gcdata.gc = GCClass(translator.config.translation, hooks=gchooks,
                            **GC_PARAMS)
        root_walker = self.build_root_walker()
        root_walker.finished_minor_collection_func = finished_minor_collection
        self.root_walker = root_walker
        gcdata.set_query_functions(gcdata.gc)
        gcdata.gc.set_root_walker(root_walker)
        self.num_pushs = 0
        self.write_barrier_calls = 0
        self.write_barrier_from_array_calls = 0

        def frameworkgc_setup():
            # run-time initialization code
            root_walker.setup_root_walker()
            gcdata.gc.setup()
            gcdata.gc.post_setup()

        def frameworkgc__teardown():
            # run-time teardown code for tests!
            gcdata.gc._teardown()

        bk = self.translator.annotator.bookkeeper
        r_typeid16 = rffi.platform.numbertype_to_rclass[TYPE_ID]
        s_typeid16 = annmodel.SomeInteger(knowntype=r_typeid16)

        # the point of this little dance is to not annotate
        # self.gcdata.static_root_xyz as constants. XXX is it still needed??
        data_classdef = bk.getuniqueclassdef(gctypelayout.GCData)
        data_classdef.generalize_attr('static_root_start', SomeAddress())
        data_classdef.generalize_attr('static_root_nongcend', SomeAddress())
        data_classdef.generalize_attr('static_root_end', SomeAddress())
        data_classdef.generalize_attr('max_type_id', annmodel.SomeInteger())
        data_classdef.generalize_attr('typeids_z', SomeAddress())
        data_classdef.generalize_attr('typeids_list', SomeAddress())
        data_classdef.generalize_attr('finalizer_handlers', SomeAddress())

        annhelper = annlowlevel.MixLevelHelperAnnotator(self.translator.rtyper)

        def getfn(ll_function, args_s, s_result, inline=False,
                  minimal_transform=True):
            graph = annhelper.getgraph(ll_function, args_s, s_result)
            if minimal_transform:
                self.need_minimal_transform(graph)
            if inline:
                assert minimal_transform, (
                    "%r has both inline=True and minimal_transform=False"
                    % (graph,))
                self.graphs_to_inline[graph] = True
            return annhelper.graph2const(graph)

        self.frameworkgc_setup_ptr = getfn(frameworkgc_setup, [],
                                           annmodel.s_None)
        # for tests
        self.frameworkgc__teardown_ptr = getfn(frameworkgc__teardown, [],
                                               annmodel.s_None)

        self.annotate_walker_functions(getfn)
        if translator.config.translation.rweakref:
            self.weakref_deref_ptr = self.inittime_helper(
                ll_weakref_deref, [llmemory.WeakRefPtr], llmemory.Address)

        classdef = bk.getuniqueclassdef(GCClass)
        s_gc = annmodel.SomeInstance(classdef)

        self._declare_functions(GCClass, getfn, s_gc, s_typeid16)

        # thread support
        if translator.config.translation.continuation:
            root_walker.stacklet_support = True
        if translator.config.translation.thread:
            root_walker.need_thread_support(self, getfn)
        if root_walker.stacklet_support:
            root_walker.need_stacklet_support(self, getfn)

        self.layoutbuilder.encode_type_shapes_now()
        self.create_custom_trace_funcs(gcdata.gc, translator.rtyper)

        annhelper.finish()   # at this point, annotate all mix-level helpers
        annhelper.backend_optimize()

        self.check_custom_trace_funcs(gcdata.gc, translator.rtyper)

        self.collect_analyzer = CollectAnalyzer(self.translator)
        self.collect_analyzer.analyze_all()

        s_gc = self.translator.annotator.bookkeeper.valueoftype(GCClass)
        r_gc = self.translator.rtyper.getrepr(s_gc)
        self.c_const_gc = rmodel.inputconst(r_gc, self.gcdata.gc)
        s_gc_data = self.translator.annotator.bookkeeper.valueoftype(
            gctypelayout.GCData)
        r_gc_data = self.translator.rtyper.getrepr(s_gc_data)
        self.c_const_gcdata = rmodel.inputconst(r_gc_data, self.gcdata)
        self.malloc_zero_filled = GCClass.malloc_zero_filled

        HDR = self.HDR = self.gcdata.gc.gcheaderbuilder.HDR

        size_gc_header = self.gcdata.gc.gcheaderbuilder.size_gc_header
        vtableinfo = (HDR, size_gc_header, self.gcdata.gc.typeid_is_in_field)
        self.c_vtableinfo = rmodel.inputconst(lltype.Void, vtableinfo)
        tig = self.layoutbuilder.type_info_group._as_ptr()
        self.c_type_info_group = rmodel.inputconst(lltype.typeOf(tig), tig)
        sko = llmemory.sizeof(gcdata.TYPE_INFO)
        self.c_vtinfo_skip_offset = rmodel.inputconst(lltype.typeOf(sko), sko)


    def _declare_functions(self, GCClass, getfn, s_gc, s_typeid16):
        from rpython.memory.gc.base import ARRAY_TYPEID_MAP
        from rpython.memory.gc import inspector

        s_gcref = SomePtr(llmemory.GCREF)
        gcdata = self.gcdata
        #use the GC flag to find which malloc method to use
        #malloc_zero_filled == Ture -> malloc_fixedsize/varsize_clear
        #malloc_zero_filled == Flase -> malloc_fixedsize/varsize
        malloc_fixedsize_meth = None
        if GCClass.malloc_zero_filled:
            malloc_fixedsize_clear_meth = GCClass.malloc_fixedsize_clear.im_func
            self.malloc_fixedsize_ptr = getfn(
                malloc_fixedsize_clear_meth,
                [s_gc, s_typeid16,
                annmodel.SomeInteger(nonneg=True),
                annmodel.SomeBool(),
                annmodel.SomeBool(),
                annmodel.SomeBool()], s_gcref,
                inline = False)
            self.malloc_varsize_ptr = getfn(
                    GCClass.malloc_varsize_clear.im_func,
                    [s_gc, s_typeid16]
                    + [annmodel.SomeInteger(nonneg=True) for i in range(4)], s_gcref)

        else:
            malloc_fixedsize_meth = GCClass.malloc_fixedsize.im_func
            self.malloc_fixedsize_ptr = getfn(
                malloc_fixedsize_meth,
                [s_gc, s_typeid16,
                 annmodel.SomeInteger(nonneg=True),
                 annmodel.SomeBool(),
                 annmodel.SomeBool(),
                 annmodel.SomeBool()], s_gcref,
                inline = False)
            self.malloc_varsize_ptr = getfn(
                    GCClass.malloc_varsize.im_func,
                    [s_gc, s_typeid16]
                    + [annmodel.SomeInteger(nonneg=True) for i in range(4)], s_gcref)

        self.collect_ptr = getfn(GCClass.collect.im_func,
            [s_gc, annmodel.SomeInteger()], annmodel.s_None)
        self.collect_step_ptr = getfn(GCClass.collect_step.im_func, [s_gc],
                                      annmodel.SomeInteger())
        self.enable_ptr = getfn(GCClass.enable.im_func, [s_gc], annmodel.s_None)
        self.disable_ptr = getfn(GCClass.disable.im_func, [s_gc], annmodel.s_None)
        self.isenabled_ptr = getfn(GCClass.isenabled.im_func, [s_gc],
                                   annmodel.s_Bool)
        self.can_move_ptr = getfn(GCClass.can_move.im_func,
                                  [s_gc, SomeAddress()],
                                  annmodel.SomeBool())

        if hasattr(GCClass, 'shrink_array'):
            self.shrink_array_ptr = getfn(
                GCClass.shrink_array.im_func,
                [s_gc, SomeAddress(),
                 annmodel.SomeInteger(nonneg=True)], annmodel.s_Bool)
        else:
            self.shrink_array_ptr = None

        if hasattr(GCClass, 'heap_stats'):
            self.heap_stats_ptr = getfn(GCClass.heap_stats.im_func,
                    [s_gc], SomePtr(lltype.Ptr(ARRAY_TYPEID_MAP)),
                    minimal_transform=False)
            self.get_member_index_ptr = getfn(
                GCClass.get_member_index.im_func,
                [s_gc, annmodel.SomeInteger(knowntype=llgroup.r_halfword)],
                annmodel.SomeInteger())

        self.gc_gettypeid_ptr = getfn(GCClass.get_type_id_cast,
                                       [s_gc, SomeAddress()],
                                       annmodel.SomeInteger())

        if hasattr(GCClass, 'writebarrier_before_copy'):
            self.wb_before_copy_ptr = \
                    getfn(GCClass.writebarrier_before_copy.im_func,
                    [s_gc] + [SomeAddress()] * 2 +
                    [annmodel.SomeInteger()] * 3, annmodel.SomeBool())
        elif GCClass.needs_write_barrier:
            raise NotImplementedError("GC needs write barrier, but does not provide writebarrier_before_copy functionality")

        if hasattr(GCClass, 'writebarrier_before_move'):
            self.wb_before_move_ptr = \
                    getfn(GCClass.writebarrier_before_move.im_func,
                    [s_gc, SomeAddress()], annmodel.s_None)
        elif GCClass.needs_write_barrier:
            raise NotImplementedError("GC needs write barrier, but does not provide writebarrier_before_move functionality")

        # in some GCs we can inline the common case of
        # malloc_fixedsize(typeid, size, False, False, False)
        if getattr(GCClass, 'inline_simple_malloc', False):
            # make a copy of this function so that it gets annotated
            # independently and the constants are folded inside
            if malloc_fixedsize_meth is None:
                malloc_fast_meth = malloc_fixedsize_clear_meth
                self.malloc_fast_is_clearing = True
            else:
                malloc_fast_meth = malloc_fixedsize_meth
                self.malloc_fast_is_clearing = False
            malloc_fast = func_with_new_name(
                malloc_fast_meth,
                "malloc_fast")
            s_False = annmodel.SomeBool()
            s_False.const = False
            self.malloc_fast_ptr = getfn(
                malloc_fast,
                [s_gc, s_typeid16,
                 annmodel.SomeInteger(nonneg=True),
                 s_False, s_False, s_False], s_gcref,
                inline = True)
        else:
            self.malloc_fast_ptr = None

        # in some GCs we can also inline the common case of
        # malloc_varsize(typeid, length, (3 constant sizes), True, False)
        self.malloc_varsize_fast_ptr = None
        if getattr(GCClass, 'inline_simple_malloc_varsize', False):
            # make a copy of this function so that it gets annotated
            # independently and the constants are folded inside
            if hasattr(GCClass, 'malloc_varsize'):
                malloc_varsize_fast = func_with_new_name(
                    GCClass.malloc_varsize.im_func,
                    "malloc_varsize_fast")
            elif hasattr(GCClass, 'malloc_varsize_clear'):
                 malloc_varsize_fast = func_with_new_name(
                    GCClass.malloc_varsize_clear.im_func,
                    "malloc_varsize_clear_fast")
            s_False = annmodel.SomeBool()
            s_False.const = False
            self.malloc_varsize_fast_ptr = getfn(
                malloc_varsize_fast,
                [s_gc, s_typeid16,
                annmodel.SomeInteger(nonneg=True),
                annmodel.SomeInteger(nonneg=True),
                annmodel.SomeInteger(nonneg=True),
                annmodel.SomeInteger(nonneg=True)], s_gcref,
                inline = True)

        if getattr(GCClass, 'raw_malloc_memory_pressure', False):
            def raw_malloc_memory_pressure_varsize(length, itemsize, adr):
                totalmem = length * itemsize
                if totalmem > 0:
                    gcdata.gc.raw_malloc_memory_pressure(totalmem, adr)
                #else: probably an overflow -- the following rawmalloc
                #      will fail then
            def raw_malloc_memory_pressure(sizehint, adr):
                gcdata.gc.raw_malloc_memory_pressure(sizehint, adr)
            self.raw_malloc_memory_pressure_varsize_ptr = getfn(
                raw_malloc_memory_pressure_varsize,
                [annmodel.SomeInteger(), annmodel.SomeInteger(),
                 SomeAddress()],
                annmodel.s_None, minimal_transform = False)
            self.raw_malloc_memory_pressure_ptr = getfn(
                raw_malloc_memory_pressure,
                [annmodel.SomeInteger(), SomeAddress()],
                annmodel.s_None, minimal_transform = False)

        if getattr(GCClass, 'get_stats', False):
            def get_stats(stats_no):
                return gcdata.gc.get_stats(stats_no)
            self.get_stats_ptr = getfn(get_stats, [annmodel.SomeInteger()],
                annmodel.SomeInteger())


        self.identityhash_ptr = getfn(GCClass.identityhash.im_func,
                                      [s_gc, s_gcref],
                                      annmodel.SomeInteger(),
                                      minimal_transform=False)
        if getattr(GCClass, 'obtain_free_space', False):
            self.obtainfreespace_ptr = getfn(GCClass.obtain_free_space.im_func,
                                             [s_gc, annmodel.SomeInteger()],
                                             SomeAddress())

        if GCClass.moving_gc:
            self.id_ptr = getfn(GCClass.id.im_func,
                                [s_gc, s_gcref], annmodel.SomeInteger(),
                                minimal_transform = False)
        else:
            self.id_ptr = None

        self.get_rpy_roots_ptr = getfn(inspector.get_rpy_roots,
                                       [s_gc],
                                       rgc.s_list_of_gcrefs(),
                                       minimal_transform=False)
        self.get_rpy_referents_ptr = getfn(inspector.get_rpy_referents,
                                           [s_gc, s_gcref],
                                           rgc.s_list_of_gcrefs(),
                                           minimal_transform=False)
        self.get_rpy_memory_usage_ptr = getfn(inspector.get_rpy_memory_usage,
                                              [s_gc, s_gcref],
                                              annmodel.SomeInteger(),
                                              minimal_transform=False)
        self.get_rpy_type_index_ptr = getfn(inspector.get_rpy_type_index,
                                            [s_gc, s_gcref],
                                            annmodel.SomeInteger(),
                                            minimal_transform=False)
        self.is_rpy_instance_ptr = getfn(inspector.is_rpy_instance,
                                         [s_gc, s_gcref],
                                         annmodel.SomeBool(),
                                         minimal_transform=False)
        self.dump_rpy_heap_ptr = getfn(inspector.dump_rpy_heap,
                                       [s_gc, annmodel.SomeInteger()],
                                       annmodel.s_Bool,
                                       minimal_transform=False)
        self.get_typeids_z_ptr = getfn(inspector.get_typeids_z,
                                       [s_gc],
                                       SomePtr(lltype.Ptr(rgc.ARRAY_OF_CHAR)),
                                       minimal_transform=False)
        self.get_typeids_list_ptr = getfn(inspector.get_typeids_list,
                                       [s_gc],
                                       SomePtr(lltype.Ptr(
                                           lltype.Array(llgroup.HALFWORD))),
                                       minimal_transform=False)

        self.set_max_heap_size_ptr = getfn(GCClass.set_max_heap_size.im_func,
                                           [s_gc,
                                            annmodel.SomeInteger(nonneg=True)],
                                           annmodel.s_None)

        if hasattr(GCClass, 'rawrefcount_init'):
            self.rawrefcount_init_ptr = getfn(
                GCClass.rawrefcount_init,
                [s_gc, SomePtr(GCClass.RAWREFCOUNT_DEALLOC_TRIGGER)],
                annmodel.s_None)
            self.rawrefcount_create_link_pypy_ptr = getfn(
                GCClass.rawrefcount_create_link_pypy,
                [s_gc, s_gcref, SomeAddress()],
                annmodel.s_None)
            self.rawrefcount_create_link_pyobj_ptr = getfn(
                GCClass.rawrefcount_create_link_pyobj,
                [s_gc, s_gcref, SomeAddress()],
                annmodel.s_None)
            self.rawrefcount_mark_deallocating = getfn(
                GCClass.rawrefcount_mark_deallocating,
                [s_gc, s_gcref, SomeAddress()],
                annmodel.s_None)
            self.rawrefcount_from_obj_ptr = getfn(
                GCClass.rawrefcount_from_obj, [s_gc, s_gcref], SomeAddress(),
                inline = True)
            self.rawrefcount_to_obj_ptr = getfn(
                GCClass.rawrefcount_to_obj, [s_gc, SomeAddress()], s_gcref,
                inline = True)
            self.rawrefcount_next_dead_ptr = getfn(
                GCClass.rawrefcount_next_dead, [s_gc], SomeAddress(),
                inline = True)

        if GCClass.can_usually_pin_objects:
            self.pin_ptr = getfn(GCClass.pin,
                                 [s_gc, SomeAddress()],
                                 annmodel.SomeBool())

            self.unpin_ptr = getfn(GCClass.unpin,
                                   [s_gc, SomeAddress()],
                                   annmodel.s_None)

            self._is_pinned_ptr = getfn(GCClass._is_pinned,
                                        [s_gc, SomeAddress()],
                                        annmodel.SomeBool())

        self.write_barrier_ptr = None
        self.write_barrier_from_array_ptr = None
        if GCClass.needs_write_barrier:
            self.write_barrier_ptr = getfn(GCClass.write_barrier.im_func,
                                           [s_gc, SomeAddress()],
                                           annmodel.s_None,
                                           inline=True)
            func = getattr(gcdata.gc, 'remember_young_pointer', None)
            if func is not None:
                # func should not be a bound method, but a real function
                assert isinstance(func, types.FunctionType)
                self.write_barrier_failing_case_ptr = getfn(func,
                                               [SomeAddress()],
                                               annmodel.s_None)
            func = getattr(GCClass, 'write_barrier_from_array', None)
            if func is not None:
                self.write_barrier_from_array_ptr = getfn(func.im_func,
                                           [s_gc, SomeAddress(),
                                            annmodel.SomeInteger()],
                                           annmodel.s_None,
                                           inline=True)
                func = getattr(gcdata.gc,
                               'jit_remember_young_pointer_from_array',
                               None)
                if func is not None:
                    # func should not be a bound method, but a real function
                    assert isinstance(func, types.FunctionType)
                    self.write_barrier_from_array_failing_case_ptr = \
                                             getfn(func,
                                                   [SomeAddress()],
                                                   annmodel.s_None)
        self.malloc_nonmovable_ptr = getfn(
            GCClass.malloc_fixed_or_varsize_nonmovable,
            [s_gc, s_typeid16, annmodel.SomeInteger()],
            s_gcref)

        self.register_finalizer_ptr = getfn(GCClass.register_finalizer,
                                            [s_gc,
                                             annmodel.SomeInteger(),
                                             s_gcref],
                                            annmodel.s_None)

        self.ignore_finalizer_ptr = None
        if hasattr(GCClass, 'ignore_finalizer'):
            self.ignore_finalizer_ptr = getfn(GCClass.ignore_finalizer,
                                              [s_gc, SomeAddress()],
                                              annmodel.s_None)

        self.move_out_of_nursery_ptr = None
        if hasattr(GCClass, 'move_out_of_nursery'):
            self.move_out_of_nursery_ptr = getfn(GCClass.move_out_of_nursery,
                                              [s_gc, SomeAddress()],
                                              SomeAddress())
        if hasattr(self.root_walker, 'build_increase_root_stack_depth_ptr'):
            self.root_walker.build_increase_root_stack_depth_ptr(getfn)


    def create_custom_trace_funcs(self, gc, rtyper):
        custom_trace_funcs = tuple(rtyper.custom_trace_funcs)
        rtyper.custom_trace_funcs = custom_trace_funcs
        # too late to register new custom trace functions afterwards

        custom_trace_funcs_unrolled = unrolling_iterable(
            [(self.get_type_id(TP), func) for TP, func in custom_trace_funcs])

        @specialize.arg(2)
        def custom_trace_dispatcher(obj, typeid, callback, arg):
            for type_id_exp, func in custom_trace_funcs_unrolled:
                if (llop.combine_ushort(lltype.Signed, typeid, 0) ==
                    llop.combine_ushort(lltype.Signed, type_id_exp, 0)):
                    func(gc, obj, callback, arg)
                    return
            else:
                assert False

        gc.custom_trace_dispatcher = custom_trace_dispatcher

        for TP, func in custom_trace_funcs:
            self.gcdata._has_got_custom_trace(self.get_type_id(TP))
            specialize.arg(2)(func)

    def check_custom_trace_funcs(self, gc, rtyper):
        # detect if one of the custom trace functions uses the GC
        # (it must not!)
        for TP, func in rtyper.custom_trace_funcs:
            def no_op_callback(obj, arg):
                pass
            def ll_check_no_collect(obj):
                func(gc, obj, no_op_callback, None)
            annhelper = annlowlevel.MixLevelHelperAnnotator(rtyper)
            graph1 = annhelper.getgraph(ll_check_no_collect, [SomeAddress()],
                                        annmodel.s_None)
            annhelper.finish()
            collect_analyzer = CollectAnalyzer(self.translator)
            if collect_analyzer.analyze_direct_call(graph1):
                raise Exception(
                    "the custom trace hook %r for %r can cause "
                    "the GC to be called!" % (func, TP))

    def postprocess_graph(self, graph, any_inlining):
        self.root_walker.postprocess_graph(self, graph, any_inlining)

    def consider_constant(self, TYPE, value):
        self.layoutbuilder.consider_constant(TYPE, value, self.gcdata.gc)

    #def get_type_id(self, TYPE):
    #    this method is attached to the instance and redirects to
    #    layoutbuilder.get_type_id().

    def special_funcptr_for_type(self, TYPE):
        return self.layoutbuilder.special_funcptr_for_type(TYPE)

    def finish_tables(self):
        group = self.layoutbuilder.close_table()
        log.info("assigned %s typeids" % (len(group.members), ))
        log.info("added %s push/pop stack root instructions" % (
                     self.num_pushs, ))
        if self.write_barrier_ptr:
            log.info("inserted %s write barrier calls" % (
                         self.write_barrier_calls, ))
        if self.write_barrier_from_array_ptr:
            log.info("inserted %s write_barrier_from_array calls" % (
                         self.write_barrier_from_array_calls, ))

        # XXX because we call inputconst already in replace_malloc, we can't
        # modify the instance, we have to modify the 'rtyped instance'
        # instead.  horrors.  is there a better way?

        s_gcdata = self.translator.annotator.bookkeeper.immutablevalue(
            self.gcdata)
        r_gcdata = self.translator.rtyper.getrepr(s_gcdata)
        ll_instance = rmodel.inputconst(r_gcdata, self.gcdata).value

        addresses_of_static_ptrs = (
            self.layoutbuilder.addresses_of_static_ptrs_in_nongc +
            self.layoutbuilder.addresses_of_static_ptrs)
        if len(addresses_of_static_ptrs) == 1:
            log.info("found 1 static root")
        else:
            log.info("found %s static roots" % (len(addresses_of_static_ptrs), ))
        ll_static_roots_inside = lltype.malloc(lltype.Array(llmemory.Address),
                                               len(addresses_of_static_ptrs),
                                               immortal=True)

        for i in range(len(addresses_of_static_ptrs)):
            ll_static_roots_inside[i] = addresses_of_static_ptrs[i]
        ll_instance.inst_static_root_start = llmemory.cast_ptr_to_adr(ll_static_roots_inside) + llmemory.ArrayItemsOffset(lltype.Array(llmemory.Address))
        ll_instance.inst_static_root_nongcend = ll_instance.inst_static_root_start + llmemory.sizeof(llmemory.Address) * len(self.layoutbuilder.addresses_of_static_ptrs_in_nongc)
        ll_instance.inst_static_root_end = ll_instance.inst_static_root_start + llmemory.sizeof(llmemory.Address) * len(addresses_of_static_ptrs)
        newgcdependencies = []
        newgcdependencies.append(ll_static_roots_inside)
        ll_instance.inst_max_type_id = len(group.members)
        #
        typeids_z, typeids_list = self.write_typeid_list()
        ll_typeids_z = lltype.malloc(rgc.ARRAY_OF_CHAR,
                                     len(typeids_z),
                                     immortal=True)
        for i in range(len(typeids_z)):
            ll_typeids_z[i] = typeids_z[i]
        ll_instance.inst_typeids_z = llmemory.cast_ptr_to_adr(ll_typeids_z)
        newgcdependencies.append(ll_typeids_z)
        #
        ll_typeids_list = lltype.malloc(lltype.Array(llgroup.HALFWORD),
                                        len(typeids_list),
                                        immortal=True)
        for i in range(len(typeids_list)):
            ll_typeids_list[i] = typeids_list[i]
        ll_instance.inst_typeids_list= llmemory.cast_ptr_to_adr(ll_typeids_list)
        newgcdependencies.append(ll_typeids_list)
        #
        handlers = self.finalizer_handlers
        ll_handlers = lltype.malloc(FIN_HANDLER_ARRAY, len(handlers),
                                    immortal=True)
        for i in range(len(handlers)):
            ll_handlers[i].deque = handlers[i][0]
            ll_handlers[i].trigger = handlers[i][1]
        ll_instance.inst_finalizer_handlers = llmemory.cast_ptr_to_adr(
            ll_handlers)
        newgcdependencies.append(ll_handlers)
        #
        return newgcdependencies

    def enum_type_info_members(self):
        # We must first make sure that the type_info_group's members
        # are all followed.  Do it repeatedly while new members show up.
        # Once it is really done, do finish_tables().
        seen = 0
        while seen < len(self.layoutbuilder.type_info_group.members):
            curtotal = len(self.layoutbuilder.type_info_group.members)
            yield self.layoutbuilder.type_info_group.members[seen:curtotal]
            seen = curtotal

    def get_finish_helpers(self):
        for dep in self.enum_type_info_members():
            yield dep
        yield self.finish_helpers()

    def get_finish_tables(self):
        for dep in self.enum_type_info_members():
            yield dep
        yield self.finish_tables()

    def write_typeid_list(self):
        """write out the list of type ids together with some info"""
        from rpython.tool.udir import udir
        # XXX not ideal since it is not per compilation, but per run
        # XXX argh argh, this only gives the member index but not the
        #     real typeid, which is a complete mess to obtain now...
        all_ids = self.layoutbuilder.id_of_type.items()
        list_data = []
        ZERO = rffi.cast(llgroup.HALFWORD, 0)
        for _, typeinfo in all_ids:
            while len(list_data) <= typeinfo.index:
                list_data.append(ZERO)
            list_data[typeinfo.index] = typeinfo
        #
        all_ids = [(typeinfo.index, TYPE) for (TYPE, typeinfo) in all_ids]
        all_ids = dict(all_ids)
        f = udir.join("typeids.txt").open("w")
        for index in range(len(self.layoutbuilder.type_info_group.members)):
            f.write("member%-4d %s\n" % (index, all_ids.get(index, '?')))
        f.close()
        try:
            import zlib
            z_data = zlib.compress(udir.join("typeids.txt").read(), 9)
        except ImportError:
            z_data = ''
        return z_data, list_data

    def transform_graph(self, graph):
        func = getattr(graph, 'func', None)
        if func and getattr(func, '_gc_no_collect_', False):
            if self.collect_analyzer.analyze_direct_call(graph):
                print '!'*79
                ca = CollectAnalyzer(self.translator)
                ca.verbose = True
                ca.analyze_direct_call(graph)
                # ^^^ for the dump of which operation in which graph actually
                # causes it to return True
                raise Exception("'no_collect' function can trigger collection:"
                                " %s" % func)

        if self.write_barrier_ptr:
            from rpython.flowspace.model import mkentrymap
            self._entrymap = mkentrymap(graph)
            self.clean_sets = (
                find_initializing_stores(self.collect_analyzer, graph,
                                         self._entrymap))
            if self.gcdata.gc.can_optimize_clean_setarrayitems():
                self.clean_sets = self.clean_sets.union(
                    find_clean_setarrayitems(self.collect_analyzer, graph))
        super(BaseFrameworkGCTransformer, self).transform_graph(graph)
        if self.write_barrier_ptr:
            self.clean_sets = None

    def gct_direct_call(self, hop):
        if self.collect_analyzer.analyze(hop.spaceop):
            livevars = self.push_roots(hop)
            self.default(hop)
            self.pop_roots(hop, livevars)
        else:
            if hop.spaceop.opname == "direct_call":
                self.mark_call_cannotcollect(hop, hop.spaceop.args[0])
            self.default(hop)

    def mark_call_cannotcollect(self, hop, name):
        pass

    gct_indirect_call = gct_direct_call

    def gct_fv_gc_malloc(self, hop, flags, TYPE, *args):
        op = hop.spaceop
        PTRTYPE = op.result.concretetype
        assert PTRTYPE.TO == TYPE
        type_id = self.get_type_id(TYPE)

        c_type_id = rmodel.inputconst(TYPE_ID, type_id)
        info = self.layoutbuilder.get_info(type_id)
        c_size = rmodel.inputconst(lltype.Signed, info.fixedsize)
        fptrs = self.special_funcptr_for_type(TYPE)
        has_finalizer = "destructor" in fptrs or "old_style_finalizer" in fptrs
        has_light_finalizer = "destructor" in fptrs
        c_has_finalizer = rmodel.inputconst(lltype.Bool, has_finalizer)
        c_has_light_finalizer = rmodel.inputconst(lltype.Bool,
                                                  has_light_finalizer)

        is_varsize = op.opname.endswith('_varsize') or flags.get('varsize')

        if flags.get('nonmovable'):
            if not is_varsize:
                v_length = rmodel.inputconst(lltype.Signed, 0)
            else:
                v_length = op.args[-1]
            malloc_ptr = self.malloc_nonmovable_ptr
            args = [self.c_const_gc, c_type_id, v_length]
        elif not is_varsize:
            zero = flags.get('zero', False)
            if (self.malloc_fast_ptr is not None and
                not c_has_finalizer.value and
                (self.malloc_fast_is_clearing or not zero)):
                malloc_ptr = self.malloc_fast_ptr
            else:
                malloc_ptr = self.malloc_fixedsize_ptr
            args = [self.c_const_gc, c_type_id, c_size,
                    c_has_finalizer, c_has_light_finalizer,
                    rmodel.inputconst(lltype.Bool, False)]
        else:
            assert not c_has_finalizer.value
            info_varsize = self.layoutbuilder.get_info_varsize(type_id)
            v_length = op.args[-1]
            c_ofstolength = rmodel.inputconst(lltype.Signed,
                                              info_varsize.ofstolength)
            c_varitemsize = rmodel.inputconst(lltype.Signed,
                                              info_varsize.varitemsize)
            if self.malloc_varsize_fast_ptr is not None:
                malloc_ptr = self.malloc_varsize_fast_ptr
            else:
                malloc_ptr = self.malloc_varsize_ptr
            args = [self.c_const_gc, c_type_id, v_length, c_size,
                    c_varitemsize, c_ofstolength]
        livevars = self.push_roots(hop)
        v_result = hop.genop("direct_call", [malloc_ptr] + args,
                             resulttype=llmemory.GCREF)
        self.pop_roots(hop, livevars)
        return v_result

    gct_fv_gc_malloc_varsize = gct_fv_gc_malloc

    def gct_gc_add_memory_pressure(self, hop):
        def _find_correct_type(TP):
            T = TP.TO
            while 'special_memory_pressure' not in T._flds:
                T = T._flds['super']
            return T

        if hasattr(self, 'raw_malloc_memory_pressure_ptr'):
            op = hop.spaceop
            size = op.args[0]
            if len(op.args) == 2:
                v_fld = rmodel.inputconst(lltype.Void, "special_memory_pressure")
                T = _find_correct_type(op.args[1].concretetype)
                v_inst = hop.genop("cast_pointer", [op.args[1]],
                    resulttype=lltype.Ptr(T))
                hop.genop("bare_setfield", [v_inst, v_fld, size])
                v_adr = hop.genop("cast_ptr_to_adr", [op.args[1]],
                    resulttype=llmemory.Address)
            else:
                v_adr = rmodel.inputconst(llmemory.Address, llmemory.NULL)
            hop.genop("direct_call", [self.raw_malloc_memory_pressure_ptr,
                               size, v_adr])


    def gct_gc_get_stats(self, hop):
        if hasattr(self, 'get_stats_ptr'):
            return hop.genop("direct_call",
                [self.get_stats_ptr, hop.spaceop.args[0]],
                resultvar=hop.spaceop.result)
        hop.genop("same_as", [rmodel.inputconst(lltype.Signed, 0)],
            resultvar=hop.spaceop.result)


    def gct_gc__collect(self, hop):
        op = hop.spaceop
        if len(op.args) == 1:
            v_gen = op.args[0]
        else:
            # pick a number larger than expected different gc gens :-)
            v_gen = rmodel.inputconst(lltype.Signed, 9)
        livevars = self.push_roots(hop)
        hop.genop("direct_call", [self.collect_ptr, self.c_const_gc, v_gen],
                  resultvar=op.result)
        self.pop_roots(hop, livevars)

    def gct_gc__collect_step(self, hop):
        op = hop.spaceop
        livevars = self.push_roots(hop)
        hop.genop("direct_call", [self.collect_step_ptr, self.c_const_gc],
                  resultvar=op.result)
        self.pop_roots(hop, livevars)

    def gct_gc__enable(self, hop):
        op = hop.spaceop
        hop.genop("direct_call", [self.enable_ptr, self.c_const_gc],
                  resultvar=op.result)

    def gct_gc__disable(self, hop):
        op = hop.spaceop
        hop.genop("direct_call", [self.disable_ptr, self.c_const_gc],
                  resultvar=op.result)

    def gct_gc__isenabled(self, hop):
        op = hop.spaceop
        hop.genop("direct_call", [self.isenabled_ptr, self.c_const_gc],
                  resultvar=op.result)

    def gct_gc_can_move(self, hop):
        op = hop.spaceop
        v_addr = hop.genop('cast_ptr_to_adr',
                           [op.args[0]], resulttype=llmemory.Address)
        hop.genop("direct_call", [self.can_move_ptr, self.c_const_gc, v_addr],
                  resultvar=op.result)

    def gct_shrink_array(self, hop):
        if self.shrink_array_ptr is None:
            return GCTransformer.gct_shrink_array(self, hop)
        op = hop.spaceop
        v_addr = hop.genop('cast_ptr_to_adr',
                           [op.args[0]], resulttype=llmemory.Address)
        v_length = op.args[1]
        hop.genop("direct_call", [self.shrink_array_ptr, self.c_const_gc,
                                  v_addr, v_length],
                  resultvar=op.result)

    def gct_gc_gettypeid(self, hop):
        op = hop.spaceop
        v_addr = op.args[0]
        if v_addr.concretetype != llmemory.Address:
            v_addr = hop.genop("cast_ptr_to_adr", [v_addr],
                               resulttype=llmemory.Address)
        hop.genop("direct_call", [self.gc_gettypeid_ptr, self.c_const_gc,
                                  v_addr],
                         resultvar=op.result)

    def gct_gc_writebarrier(self, hop):
        if self.write_barrier_ptr is None:
            return
        op = hop.spaceop
        v_addr = op.args[0]
        if v_addr.concretetype != llmemory.Address:
            v_addr = hop.genop('cast_ptr_to_adr',
                               [v_addr], resulttype=llmemory.Address)
        hop.genop("direct_call", [self.write_barrier_ptr,
                                  self.c_const_gc, v_addr])

    def gct_gc_heap_stats(self, hop):
        if not hasattr(self, 'heap_stats_ptr'):
            return GCTransformer.gct_gc_heap_stats(self, hop)
        op = hop.spaceop
        livevars = self.push_roots(hop)
        hop.genop("direct_call", [self.heap_stats_ptr, self.c_const_gc],
                  resultvar=op.result)
        self.pop_roots(hop, livevars)

    def gct_get_member_index(self, hop):
        op = hop.spaceop
        v_typeid = op.args[0]
        hop.genop("direct_call", [self.get_member_index_ptr, self.c_const_gc,
                                  v_typeid], resultvar=op.result)

    def _gc_adr_of_gc_attr(self, hop, attrname):
        if getattr(self.gcdata.gc, attrname, None) is None:
            raise NotImplementedError("gc_adr_of_%s only for generational gcs"
                                      % (attrname,))
        op = hop.spaceop
        ofs = llmemory.offsetof(self.c_const_gc.concretetype.TO,
                                'inst_' + attrname)
        c_ofs = rmodel.inputconst(lltype.Signed, ofs)
        v_gc_adr = hop.genop('cast_ptr_to_adr', [self.c_const_gc],
                             resulttype=llmemory.Address)
        hop.genop('adr_add', [v_gc_adr, c_ofs], resultvar=op.result)

    def gct_gc_adr_of_nursery_free(self, hop):
        self._gc_adr_of_gc_attr(hop, 'nursery_free')
    def gct_gc_adr_of_nursery_top(self, hop):
        self._gc_adr_of_gc_attr(hop, 'nursery_top')

    def _gc_adr_of_gcdata_attr(self, hop, attrname):
        op = hop.spaceop
        ofs = llmemory.offsetof(self.c_const_gcdata.concretetype.TO,
                                'inst_' + attrname)
        c_ofs = rmodel.inputconst(lltype.Signed, ofs)
        v_gcdata_adr = hop.genop('cast_ptr_to_adr', [self.c_const_gcdata],
                                 resulttype=llmemory.Address)
        hop.genop('adr_add', [v_gcdata_adr, c_ofs], resultvar=op.result)

    def gct_gc_adr_of_root_stack_base(self, hop):
        self._gc_adr_of_gcdata_attr(hop, 'root_stack_base')
    def gct_gc_adr_of_root_stack_top(self, hop):
        self._gc_adr_of_gcdata_attr(hop, 'root_stack_top')

    def gct_gc_modified_shadowstack(self, hop):
        # for stacklet
        hop.genop("direct_call", [self.root_walker.gc_modified_shadowstack_ptr])

    def gct_do_malloc_fixedsize(self, hop):
        # used by the JIT (see rpython.jit.backend.llsupport.gc)
        op = hop.spaceop
        [v_typeid, v_size,
         v_has_finalizer, v_has_light_finalizer, v_contains_weakptr] = op.args
        livevars = self.push_roots(hop)
        hop.genop("direct_call",
                  [self.malloc_fixedsize_ptr, self.c_const_gc,
                   v_typeid, v_size,
                   v_has_finalizer, v_has_light_finalizer,
                   v_contains_weakptr],
                  resultvar=op.result)
        self.pop_roots(hop, livevars)

    def gct_do_malloc_fixedsize_clear(self, hop):
        # used by the JIT (see rpython.jit.backend.llsupport.gc)
        self.gct_do_malloc_fixedsize(hop)
        if not self.malloc_zero_filled:
            op = hop.spaceop
            v_size = op.args[1]
            c_after_header = rmodel.inputconst(lltype.Signed,
                llmemory.sizeof(self.HDR))
            v_a = op.result
            v_clear_size = hop.genop('int_sub', [v_size, c_after_header],
                                     resulttype=lltype.Signed)
            self.emit_raw_memclear(hop.llops, v_clear_size, None,
                                   c_after_header, v_a)

    def gct_do_malloc_varsize(self, hop):
        # used by the JIT (see rpython.jit.backend.llsupport.gc)
        op = hop.spaceop
        [v_typeid, v_length, v_size, v_itemsize,
         v_offset_to_length] = op.args
        livevars = self.push_roots(hop)
        hop.genop("direct_call",
                  [self.malloc_varsize_ptr, self.c_const_gc,
                   v_typeid, v_length, v_size, v_itemsize,
                   v_offset_to_length],
                  resultvar=op.result)
        self.pop_roots(hop, livevars)

    def gct_do_malloc_varsize_clear(self, hop):
        # used by the JIT (see rpython.jit.backend.llsupport.gc)
        self.gct_do_malloc_varsize(hop)
        if not self.malloc_zero_filled:
            op = hop.spaceop
            v_num_elem = op.args[1]
            c_basesize = op.args[2]
            c_itemsize = op.args[3]
            c_length_ofs = op.args[4]
            v_a = op.result
            # Clear the fixed-size part, which is everything after the
            # GC header and before the length field.  This might be 0
            # bytes long.
            c_after_header = rmodel.inputconst(lltype.Signed,
                llmemory.sizeof(self.HDR))
            v_clear_size = hop.genop('int_sub', [c_length_ofs, c_after_header],
                                     resulttype=lltype.Signed)
            self.emit_raw_memclear(hop.llops, v_clear_size, None,
                                   c_after_header, v_a)
            # Clear the variable-size part
            self.emit_raw_memclear(hop.llops, v_num_elem, c_itemsize,
                                   c_basesize, v_a)

    def gct_get_write_barrier_failing_case(self, hop):
        op = hop.spaceop
        hop.genop("same_as",
                  [self.write_barrier_failing_case_ptr],
                  resultvar=op.result)

    def gct_get_write_barrier_from_array_failing_case(self, hop):
        op = hop.spaceop
        null = lltype.nullptr(op.result.concretetype.TO)
        c_null = rmodel.inputconst(op.result.concretetype, null)
        v = getattr(self, 'write_barrier_from_array_failing_case_ptr', c_null)
        hop.genop("same_as", [v], resultvar=op.result)

    def gct_zero_gc_pointers_inside(self, hop):
        if not self.malloc_zero_filled:
            v_ob = hop.spaceop.args[0]
            TYPE = v_ob.concretetype.TO
            self.gen_zero_gc_pointers(TYPE, v_ob, hop.llops)

    def gct_zero_everything_inside(self, hop):
        if not self.malloc_zero_filled:
            v_ob = hop.spaceop.args[0]
            TYPE = v_ob.concretetype.TO
            self.gen_zero_gc_pointers(TYPE, v_ob, hop.llops, everything=True)

    def gct_gc_writebarrier_before_copy(self, hop):
        op = hop.spaceop
        if not hasattr(self, 'wb_before_copy_ptr'):
            # no write barrier needed in that case
            hop.genop("same_as",
                      [rmodel.inputconst(lltype.Bool, True)],
                      resultvar=op.result)
            return
        source_addr = hop.genop('cast_ptr_to_adr', [op.args[0]],
                                resulttype=llmemory.Address)
        dest_addr = hop.genop('cast_ptr_to_adr', [op.args[1]],
                                resulttype=llmemory.Address)
        hop.genop('direct_call', [self.wb_before_copy_ptr, self.c_const_gc,
                                  source_addr, dest_addr] + op.args[2:],
                  resultvar=op.result)

    def gct_gc_writebarrier_before_move(self, hop):
        op = hop.spaceop
        if not hasattr(self, 'wb_before_move_ptr'):
            # no need to do anything in that case
            return
        array_addr = hop.genop('cast_ptr_to_adr', [op.args[0]],
                               resulttype=llmemory.Address)
        hop.genop('direct_call', [self.wb_before_move_ptr, self.c_const_gc,
                                  array_addr],
                  resultvar=op.result)

    def gct_weakref_create(self, hop):
        op = hop.spaceop

        type_id = self.get_type_id(WEAKREF)

        c_type_id = rmodel.inputconst(TYPE_ID, type_id)
        info = self.layoutbuilder.get_info(type_id)
        c_size = rmodel.inputconst(lltype.Signed, info.fixedsize)
        malloc_ptr = self.malloc_fixedsize_ptr
        c_false = rmodel.inputconst(lltype.Bool, False)
        c_has_weakptr = rmodel.inputconst(lltype.Bool, True)
        args = [self.c_const_gc, c_type_id, c_size,
                c_false, c_false, c_has_weakptr]

        # push and pop the current live variables *including* the argument
        # to the weakref_create operation, which must be kept alive and
        # moved if the GC needs to collect
        livevars = self.push_roots(hop, keep_current_args=True)
        v_result = hop.genop("direct_call", [malloc_ptr] + args,
                             resulttype=llmemory.GCREF)
        v_result = hop.genop("cast_opaque_ptr", [v_result],
                            resulttype=WEAKREFPTR)
        self.pop_roots(hop, livevars)
        # cast_ptr_to_adr must be done after malloc, as the GC pointer
        # might have moved just now.
        v_instance, = op.args
        v_addr = hop.genop("cast_ptr_to_adr", [v_instance],
                           resulttype=llmemory.Address)
        hop.genop("bare_setfield",
                  [v_result, rmodel.inputconst(lltype.Void, "weakptr"), v_addr])
        v_weakref = hop.genop("cast_ptr_to_weakrefptr", [v_result],
                              resulttype=llmemory.WeakRefPtr)
        hop.cast_result(v_weakref)

    def gct_weakref_deref(self, hop):
        v_wref, = hop.spaceop.args
        v_addr = hop.genop("direct_call",
                           [self.weakref_deref_ptr, v_wref],
                           resulttype=llmemory.Address)
        hop.cast_result(v_addr)

    def gct_gc_identityhash(self, hop):
        livevars = self.push_roots(hop)
        [v_ptr] = hop.spaceop.args
        v_ptr = hop.genop("cast_opaque_ptr", [v_ptr],
                          resulttype=llmemory.GCREF)
        hop.genop("direct_call",
                  [self.identityhash_ptr, self.c_const_gc, v_ptr],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_id(self, hop):
        if self.id_ptr is not None:
            livevars = self.push_roots(hop)
            [v_ptr] = hop.spaceop.args
            v_ptr = hop.genop("cast_opaque_ptr", [v_ptr],
                              resulttype=llmemory.GCREF)
            hop.genop("direct_call", [self.id_ptr, self.c_const_gc, v_ptr],
                      resultvar=hop.spaceop.result)
            self.pop_roots(hop, livevars)
        else:
            hop.rename('cast_ptr_to_int')     # works nicely for non-moving GCs

    def gct_gc_obtain_free_space(self, hop):
        livevars = self.push_roots(hop)
        [v_number] = hop.spaceop.args
        hop.genop("direct_call",
                  [self.obtainfreespace_ptr, self.c_const_gc, v_number],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_set_max_heap_size(self, hop):
        [v_size] = hop.spaceop.args
        hop.genop("direct_call", [self.set_max_heap_size_ptr,
                                  self.c_const_gc,
                                  v_size])

    def gct_gc_pin(self, hop):
        if not hasattr(self, 'pin_ptr'):
            c_false = rmodel.inputconst(lltype.Bool, False)
            hop.genop("same_as", [c_false], resultvar=hop.spaceop.result)
            return
        op = hop.spaceop
        v_addr = hop.genop('cast_ptr_to_adr', [op.args[0]],
            resulttype=llmemory.Address)
        hop.genop("direct_call", [self.pin_ptr, self.c_const_gc, v_addr],
                  resultvar=op.result)

    def gct_gc_unpin(self, hop):
        if not hasattr(self, 'unpin_ptr'):
            return
        op = hop.spaceop
        v_addr = hop.genop('cast_ptr_to_adr', [op.args[0]],
            resulttype=llmemory.Address)
        hop.genop("direct_call", [self.unpin_ptr, self.c_const_gc, v_addr],
                  resultvar=op.result)

    def gct_gc__is_pinned(self, hop):
        if not hasattr(self, '_is_pinned_ptr'):
            c_false = rmodel.inputconst(lltype.Bool, False)
            hop.genop("same_as", [c_false], resultvar=hop.spaceop.result)
            return
        op = hop.spaceop
        v_addr = hop.genop('cast_ptr_to_adr', [op.args[0]],
            resulttype=llmemory.Address)
        hop.genop("direct_call", [self._is_pinned_ptr, self.c_const_gc, v_addr],
                  resultvar=op.result)

    def gct_gc_thread_run(self, hop):
        if (self.translator.config.translation.thread and
                hasattr(self.root_walker, 'thread_run_ptr')):
            livevars = self.push_roots(hop)
            assert not livevars, "live GC var around %s!" % (hop.spaceop,)
            hop.genop("direct_call", [self.root_walker.thread_run_ptr])
            self.pop_roots(hop, livevars)
        else:
            hop.rename("gc_thread_run")     # keep it around for c/gc.py,
                                            # unless handled specially above

    def gct_gc_thread_start(self, hop):
        assert self.translator.config.translation.thread
        # There is no 'thread_start_ptr' any more for now, so the following
        # line is always false.
        if hasattr(self.root_walker, 'thread_start_ptr'):
            # Note that this is actually called after
            # the first gc_thread_run() in the new thread.
            hop.genop("direct_call", [self.root_walker.thread_start_ptr])

    def gct_gc_thread_die(self, hop):
        assert self.translator.config.translation.thread
        if hasattr(self.root_walker, 'thread_die_ptr'):
            livevars = self.push_roots(hop)
            assert not livevars, "live GC var around %s!" % (hop.spaceop,)
            hop.genop("direct_call", [self.root_walker.thread_die_ptr])
            self.pop_roots(hop, livevars)
        hop.rename("gc_thread_die")     # keep it around for c/gc.py

    def gct_gc_thread_before_fork(self, hop):
        if (self.translator.config.translation.thread
            and hasattr(self.root_walker, 'thread_before_fork_ptr')):
            hop.genop("direct_call", [self.root_walker.thread_before_fork_ptr],
                      resultvar=hop.spaceop.result)
        else:
            c_null = rmodel.inputconst(llmemory.Address, llmemory.NULL)
            hop.genop("same_as", [c_null],
                      resultvar=hop.spaceop.result)

    def gct_gc_thread_after_fork(self, hop):
        if (self.translator.config.translation.thread
            and hasattr(self.root_walker, 'thread_after_fork_ptr')):
            livevars = self.push_roots(hop)
            hop.genop("direct_call", [self.root_walker.thread_after_fork_ptr]
                                     + hop.spaceop.args)
            self.pop_roots(hop, livevars)

    def gct_gc_get_type_info_group(self, hop):
        return hop.cast_result(self.c_type_info_group)

    def gct_gc_get_rpy_roots(self, hop):
        livevars = self.push_roots(hop)
        hop.genop("direct_call",
                  [self.get_rpy_roots_ptr, self.c_const_gc],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_get_rpy_referents(self, hop):
        livevars = self.push_roots(hop)
        [v_ptr] = hop.spaceop.args
        hop.genop("direct_call",
                  [self.get_rpy_referents_ptr, self.c_const_gc, v_ptr],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_get_rpy_memory_usage(self, hop):
        livevars = self.push_roots(hop)
        [v_ptr] = hop.spaceop.args
        hop.genop("direct_call",
                  [self.get_rpy_memory_usage_ptr, self.c_const_gc, v_ptr],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_get_rpy_type_index(self, hop):
        livevars = self.push_roots(hop)
        [v_ptr] = hop.spaceop.args
        hop.genop("direct_call",
                  [self.get_rpy_type_index_ptr, self.c_const_gc, v_ptr],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_is_rpy_instance(self, hop):
        livevars = self.push_roots(hop)
        [v_ptr] = hop.spaceop.args
        hop.genop("direct_call",
                  [self.is_rpy_instance_ptr, self.c_const_gc, v_ptr],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_dump_rpy_heap(self, hop):
        livevars = self.push_roots(hop)
        [v_fd] = hop.spaceop.args
        hop.genop("direct_call",
                  [self.dump_rpy_heap_ptr, self.c_const_gc, v_fd],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_typeids_z(self, hop):
        livevars = self.push_roots(hop)
        hop.genop("direct_call",
                  [self.get_typeids_z_ptr, self.c_const_gc],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_typeids_list(self, hop):
        livevars = self.push_roots(hop)
        hop.genop("direct_call",
                  [self.get_typeids_list_ptr, self.c_const_gc],
                  resultvar=hop.spaceop.result)
        self.pop_roots(hop, livevars)

    def gct_gc_rawrefcount_init(self, hop):
        [v_fnptr] = hop.spaceop.args
        assert v_fnptr.concretetype == self.GCClass.RAWREFCOUNT_DEALLOC_TRIGGER
        hop.genop("direct_call",
                  [self.rawrefcount_init_ptr, self.c_const_gc, v_fnptr])

    def gct_gc_rawrefcount_create_link_pypy(self, hop):
        [v_gcobj, v_pyobject] = hop.spaceop.args
        assert v_gcobj.concretetype == llmemory.GCREF
        assert v_pyobject.concretetype == llmemory.Address
        hop.genop("direct_call",
                  [self.rawrefcount_create_link_pypy_ptr, self.c_const_gc,
                   v_gcobj, v_pyobject])

    def gct_gc_rawrefcount_create_link_pyobj(self, hop):
        [v_gcobj, v_pyobject] = hop.spaceop.args
        assert v_gcobj.concretetype == llmemory.GCREF
        assert v_pyobject.concretetype == llmemory.Address
        hop.genop("direct_call",
                  [self.rawrefcount_create_link_pyobj_ptr, self.c_const_gc,
                   v_gcobj, v_pyobject])

    def gct_gc_rawrefcount_mark_deallocating(self, hop):
        [v_gcobj, v_pyobject] = hop.spaceop.args
        assert v_gcobj.concretetype == llmemory.GCREF
        assert v_pyobject.concretetype == llmemory.Address
        hop.genop("direct_call",
                  [self.rawrefcount_mark_deallocating, self.c_const_gc,
                   v_gcobj, v_pyobject])

    def gct_gc_rawrefcount_from_obj(self, hop):
        [v_gcobj] = hop.spaceop.args
        assert v_gcobj.concretetype == llmemory.GCREF
        assert hop.spaceop.result.concretetype == llmemory.Address
        hop.genop("direct_call",
                  [self.rawrefcount_from_obj_ptr, self.c_const_gc, v_gcobj],
                  resultvar=hop.spaceop.result)

    def gct_gc_rawrefcount_to_obj(self, hop):
        [v_pyobject] = hop.spaceop.args
        assert v_pyobject.concretetype == llmemory.Address
        assert hop.spaceop.result.concretetype == llmemory.GCREF
        hop.genop("direct_call",
                  [self.rawrefcount_to_obj_ptr, self.c_const_gc, v_pyobject],
                  resultvar=hop.spaceop.result)

    def gct_gc_rawrefcount_next_dead(self, hop):
        assert hop.spaceop.result.concretetype == llmemory.Address
        hop.genop("direct_call",
                  [self.rawrefcount_next_dead_ptr, self.c_const_gc],
                  resultvar=hop.spaceop.result)

    def _set_into_gc_array_part(self, op):
        if op.opname == 'setarrayitem':
            return op.args[1]
        if op.opname == 'setinteriorfield':
            for v in op.args[1:-1]:
                if v.concretetype is not lltype.Void:
                    return v
        return None

    def transform_generic_set(self, hop):
        from rpython.flowspace.model import Constant
        opname = hop.spaceop.opname
        v_struct = hop.spaceop.args[0]
        v_newvalue = hop.spaceop.args[-1]
        assert opname in ('setfield', 'setarrayitem', 'setinteriorfield',
                          'raw_store')
        assert isinstance(v_newvalue.concretetype, lltype.Ptr)
        # XXX for some GCs the skipping if the newvalue is a constant won't be
        # ok
        if (self.write_barrier_ptr is not None
            and not isinstance(v_newvalue, Constant)
            and v_struct.concretetype.TO._gckind == "gc"
            and hop.spaceop not in self.clean_sets):
            v_structaddr = hop.genop("cast_ptr_to_adr", [v_struct],
                                     resulttype = llmemory.Address)
            if (self.write_barrier_from_array_ptr is not None and
                    self._set_into_gc_array_part(hop.spaceop) is not None):
                self.write_barrier_from_array_calls += 1
                v_index = self._set_into_gc_array_part(hop.spaceop)
                assert v_index.concretetype == lltype.Signed
                hop.genop("direct_call", [self.write_barrier_from_array_ptr,
                                          self.c_const_gc,
                                          v_structaddr,
                                          v_index])
            else:
                self.write_barrier_calls += 1
                hop.genop("direct_call", [self.write_barrier_ptr,
                                          self.c_const_gc,
                                          v_structaddr])
                # we just did a full write barrier here, so we can use
                # this helper to propagate this knowledge forward and
                # avoid to repeat the write barrier.
                if self.curr_block is not None:   # for tests
                    assert self.curr_block.operations[hop.index] is hop.spaceop
                    propagate_no_write_barrier_needed(self.clean_sets,
                                                      self.curr_block,
                                                      {v_struct: True},
                                                      self.collect_analyzer,
                                                      self._entrymap,
                                                      hop.index + 1)
        hop.rename('bare_' + opname)

    def transform_getfield_typeptr(self, hop):
        # this would become quite a lot of operations, even if it compiles
        # to C code that is just as efficient as "obj->typeptr".  To avoid
        # that, we just generate a single custom operation instead.
        hop.genop('gc_gettypeptr_group', [hop.spaceop.args[0],
                                          self.c_type_info_group,
                                          self.c_vtinfo_skip_offset,
                                          self.c_vtableinfo],
                  resultvar = hop.spaceop.result)

    def transform_setfield_typeptr(self, hop):
        # replace such a setfield with an assertion that the typeptr is right
        # (xxx not very useful right now, so disabled)
        if 0:
            v_new = hop.spaceop.args[2]
            v_old = hop.genop('gc_gettypeptr_group', [hop.spaceop.args[0],
                                                      self.c_type_info_group,
                                                      self.c_vtinfo_skip_offset,
                                                      self.c_vtableinfo],
                              resulttype = v_new.concretetype)
            v_eq = hop.genop("ptr_eq", [v_old, v_new],
                             resulttype = lltype.Bool)
            c_errmsg = rmodel.inputconst(lltype.Void,
                                         "setfield_typeptr: wrong type")
            hop.genop('debug_assert', [v_eq, c_errmsg])

    def gct_getfield(self, hop):
        if (hop.spaceop.args[1].value == 'typeptr' and
            hop.spaceop.args[0].concretetype.TO._hints.get('typeptr') and
            self.translator.config.translation.gcremovetypeptr):
            self.transform_getfield_typeptr(hop)
        else:
            GCTransformer.gct_getfield(self, hop)

    def gct_setfield(self, hop):
        if (hop.spaceop.args[1].value == 'typeptr' and
            hop.spaceop.args[0].concretetype.TO._hints.get('typeptr') and
            self.translator.config.translation.gcremovetypeptr):
            self.transform_setfield_typeptr(hop)
        else:
            GCTransformer.gct_setfield(self, hop)

    def var_needs_set_transform(self, var):
        return var_needsgc(var)

    def get_livevars_for_roots(self, hop, keep_current_args=False):
        if self.gcdata.gc.moving_gc and not keep_current_args:
            # moving GCs don't borrow, so the caller does not need to keep
            # the arguments alive
            livevars = hop.livevars_after_op()
        else:
            livevars = hop.livevars_after_op() + hop.current_op_keeps_alive()
        return livevars

    def compute_borrowed_vars(self, graph):
        # XXX temporary workaround, should be done more correctly
        if self.gcdata.gc.moving_gc:
            return lambda v: False
        return super(BaseFrameworkGCTransformer, self).compute_borrowed_vars(
                graph)

    def annotate_walker_functions(self, getfn):
        pass

    def build_root_walker(self):
        raise NotImplementedError

    def push_roots(self, hop, keep_current_args=False):
        raise NotImplementedError

    def pop_roots(self, hop, livevars):
        raise NotImplementedError

    def gen_zero_gc_pointers(self, TYPE, v, llops, previous_steps=None,
                             everything=False):
        if previous_steps is None:
            previous_steps = []
        if isinstance(TYPE, lltype.Struct):
            for name in TYPE._names:
                FIELD = getattr(TYPE, name)
                c_name = rmodel.inputconst(lltype.Void, name)
                if isinstance(FIELD, lltype.Struct):
                    # parent
                    self.gen_zero_gc_pointers(FIELD, v, llops,
                                              previous_steps + [c_name],
                                              everything=everything)
                    continue
                if isinstance(FIELD, lltype.Array):
                    if everything:
                        raise NotImplementedError(
                            "%s: Struct-containing-Array with everything=True"
                            % (TYPE,))
                    if gctypelayout.offsets_to_gc_pointers(FIELD.OF):
                        raise NotImplementedError(
                            "%s: Struct-containing-Array-with-gc-pointers"
                            % (TYPE,))
                    continue
                if ((isinstance(FIELD, lltype.Ptr) and FIELD._needsgc())
                    or everything):
                    c_null = rmodel.inputconst(FIELD, FIELD._defl())
                    if previous_steps:
                        llops.genop('bare_setinteriorfield',
                                [v] + previous_steps + [c_name, c_null])
                    else:
                        llops.genop('bare_setfield', [v, c_name, c_null])

            return
        elif isinstance(TYPE, lltype.Array):
            ITEM = TYPE.OF
            if everything or gctypelayout.offsets_to_gc_pointers(ITEM):
                v_size = llops.genop('getarraysize', [v],
                                     resulttype=lltype.Signed)
                c_size = rmodel.inputconst(lltype.Signed, llmemory.sizeof(ITEM))
                v_a = llops.genop('cast_ptr_to_adr', [v],
                                  resulttype=llmemory.Address)
                c_fixedofs = rmodel.inputconst(lltype.Signed,
                                              llmemory.itemoffsetof(TYPE))
                self.emit_raw_memclear(llops, v_size, c_size, c_fixedofs, v_a)
            return
        else:
            raise TypeError(TYPE)

    def emit_raw_memclear(self, llops, v_size, c_size, c_fixedofs, v_a):
        if c_size is None:
            v_totalsize = v_size
        else:
            v_totalsize = llops.genop('int_mul', [v_size, c_size],
                                      resulttype=lltype.Signed)
        v_adr = llops.genop('adr_add', [v_a, c_fixedofs],
                            resulttype=llmemory.Address)
        llops.genop('raw_memclear', [v_adr, v_totalsize])

    def gcheader_initdata(self, obj):
        o = lltype.top_container(obj)
        hdr = self.gcdata.gc.gcheaderbuilder.header_of_object(o)
        return hdr._obj

    def get_finalizer_queue_index(self, hop):
        fq_tag = hop.spaceop.args[0].value
        assert 'FinalizerQueue TAG' in fq_tag.expr
        fq = fq_tag.default
        try:
            index = self.finalizer_queue_indexes[fq]
        except KeyError:
            index = len(self.finalizer_queue_indexes)
            assert index == len(self.finalizer_handlers)
            deque = self.gcdata.gc.AddressDeque()
            #
            def ll_finalizer_trigger():
                try:
                    fq.finalizer_trigger()
                except Exception as e:
                    ll_report_finalizer_error(e)
            ll_trigger = self.annotate_finalizer(ll_finalizer_trigger, [],
                                                 lltype.Void)
            def ll_next_dead():
                if deque.non_empty():
                    return deque.popleft()
                else:
                    return llmemory.NULL
            ll_next_dead = self.annotate_finalizer(ll_next_dead, [],
                                                   llmemory.Address)
            c_ll_next_dead = rmodel.inputconst(lltype.typeOf(ll_next_dead),
                                               ll_next_dead)
            #
            s_deque = self.translator.annotator.bookkeeper.immutablevalue(deque)
            r_deque = self.translator.rtyper.getrepr(s_deque)
            ll_deque = r_deque.convert_const(deque)
            adr_deque = llmemory.cast_ptr_to_adr(ll_deque)
            #
            self.finalizer_handlers.append((adr_deque, ll_trigger,
                                            c_ll_next_dead))
            self.finalizer_queue_indexes[fq] = index
        return index

    def gct_gc_fq_register(self, hop):
        index = self.get_finalizer_queue_index(hop)
        c_index = rmodel.inputconst(lltype.Signed, index)
        v_ptr = hop.spaceop.args[1]
        assert v_ptr.concretetype == llmemory.GCREF
        hop.genop("direct_call", [self.register_finalizer_ptr, self.c_const_gc,
                                  c_index, v_ptr])

    def gct_gc_fq_next_dead(self, hop):
        index = self.get_finalizer_queue_index(hop)
        c_ll_next_dead = self.finalizer_handlers[index][2]
        v_adr = hop.genop("direct_call", [c_ll_next_dead],
                          resulttype=llmemory.Address)
        hop.genop("cast_adr_to_ptr", [v_adr],
                  resultvar = hop.spaceop.result)

    def gct_gc_ignore_finalizer(self, hop):
        if self.ignore_finalizer_ptr is not None:
            v_adr = hop.genop("cast_ptr_to_adr", [hop.spaceop.args[0]],
                              resulttype=llmemory.Address)
            hop.genop("direct_call", [self.ignore_finalizer_ptr,
                                      self.c_const_gc, v_adr])

    def gct_gc_move_out_of_nursery(self, hop):
        if self.move_out_of_nursery_ptr is not None:
            v_adr = hop.genop("cast_ptr_to_adr", [hop.spaceop.args[0]],
                              resulttype=llmemory.Address)
            v_ret = hop.genop("direct_call", [self.move_out_of_nursery_ptr,
                                      self.c_const_gc, v_adr],
                                      resulttype=llmemory.Address)
            hop.genop("cast_adr_to_ptr", [v_ret],
                      resultvar = hop.spaceop.result)
        else:
            hop.rename("same_as")

    def gct_gc_increase_root_stack_depth(self, hop):
        if not hasattr(self.root_walker, 'gc_increase_root_stack_depth_ptr'):
            return
        hop.genop("direct_call",
                  [self.root_walker.gc_increase_root_stack_depth_ptr,
                   hop.spaceop.args[0]])


class TransformerLayoutBuilder(gctypelayout.TypeLayoutBuilder):

    def __init__(self, translator, GCClass=None):
        if GCClass is None:
            from rpython.memory.gc.base import choose_gc_from_config
            GCClass, _ = choose_gc_from_config(translator.config)
        if translator.config.translation.gcremovetypeptr:
            lltype2vtable = translator.rtyper.lltype2vtable
        else:
            lltype2vtable = None
        self.translator = translator
        super(TransformerLayoutBuilder, self).__init__(GCClass, lltype2vtable)

    def is_dummy_struct(self, obj):
        # overrides the base method
        TYPE = lltype.typeOf(obj)
        try:
            dummy = self.translator.rtyper.cache_dummy_values[TYPE]
        except KeyError:
            return False
        return dummy._obj == obj

    def has_destructor(self, TYPE):
        rtti = get_rtti(TYPE)
        return rtti is not None and getattr(rtti._obj, 'destructor_funcptr',
                                            None)

    def has_custom_trace(self, TYPE):
        rtti = get_rtti(TYPE)
        return rtti is not None and getattr(rtti._obj, 'custom_trace_funcptr',
                                            None)

    def make_destructor_funcptr_for_type(self, TYPE):
        if not self.has_destructor(TYPE):
            return None, False
        rtti = get_rtti(TYPE)
        destrptr = rtti._obj.destructor_funcptr
        DESTR_ARG = lltype.typeOf(destrptr).TO.ARGS[0]
        typename = TYPE.__name__
        def ll_finalizer(addr):
            v = llmemory.cast_adr_to_ptr(addr, DESTR_ARG)
            ll_call_destructor(destrptr, v, typename)
        fptr = self.transformer.annotate_finalizer(ll_finalizer,
                [llmemory.Address], lltype.Void)
        try:
            g = destrptr._obj.graph
            light = not FinalizerAnalyzer(self.translator).analyze_light_finalizer(g)
        except lltype.DelayedPointer:
            light = False    # XXX bah, too bad
        return fptr, light

    def make_custom_trace_funcptr_for_type(self, TYPE):
        if not self.has_custom_trace(TYPE):
            return None
        rtti = get_rtti(TYPE)
        fptr = rtti._obj.custom_trace_funcptr
        if not hasattr(fptr._obj, 'graph'):
            ll_func = fptr._obj._callable
            fptr = self.transformer.annotate_finalizer(ll_func,
                    [llmemory.Address, llmemory.Address], llmemory.Address)
        return fptr

# ____________________________________________________________


sizeofaddr = llmemory.sizeof(llmemory.Address)


class BaseRootWalker(object):
    thread_setup = None
    finished_minor_collection_func = None

    def __init__(self, gctransformer):
        self.gcdata = gctransformer.gcdata
        self.gc = self.gcdata.gc
        self.stacklet_support = False

    def _freeze_(self):
        return True

    def setup_root_walker(self):
        if self.thread_setup is not None:
            self.thread_setup()

    def walk_roots(self, collect_stack_root,
                   collect_static_in_prebuilt_nongc,
                   collect_static_in_prebuilt_gc,
                   is_minor=False):
        gcdata = self.gcdata
        gc = self.gc
        if collect_static_in_prebuilt_nongc:
            addr = gcdata.static_root_start
            end = gcdata.static_root_nongcend
            while addr != end:
                result = addr.address[0]
                if gc.points_to_valid_gc_object(result):
                    collect_static_in_prebuilt_nongc(gc, result)
                addr += sizeofaddr
        if collect_static_in_prebuilt_gc:
            addr = gcdata.static_root_nongcend
            end = gcdata.static_root_end
            while addr != end:
                result = addr.address[0]
                if gc.points_to_valid_gc_object(result):
                    collect_static_in_prebuilt_gc(gc, result)
                addr += sizeofaddr
        if collect_stack_root:
            self.walk_stack_roots(collect_stack_root, is_minor)     # abstract

    def finished_minor_collection(self):
        func = self.finished_minor_collection_func
        if func is not None:
            func()

    def need_stacklet_support(self):
        raise Exception("%s does not support stacklets" % (
            self.__class__.__name__,))

    def need_thread_support(self, gctransformer, getfn):
        raise Exception("%s does not support threads" % (
            self.__class__.__name__,))
