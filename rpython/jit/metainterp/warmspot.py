import sys, py

from rpython.tool.sourcetools import func_with_new_name
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.annlowlevel import (llhelper, MixLevelHelperAnnotator,
    hlstr, cast_instance_to_gcref, cast_gcref_to_instance)
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rtyper.rclass import OBJECTPTR
from rpython.annotator import model as annmodel
from rpython.rtyper.llinterp import LLException
from rpython.rtyper.test.test_llinterp import get_interpreter, clear_tcache
from rpython.flowspace.model import SpaceOperation, Variable, Constant
from rpython.flowspace.model import checkgraph, Link, copygraph
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.debug import fatalerror
from rpython.rlib.rstackovf import StackOverflow
from rpython.translator.backendopt import removenoops
from rpython.translator.unsimplify import call_final_function

from rpython.jit.metainterp import history, pyjitpl, gc, memmgr, jitexc
from rpython.jit.metainterp.pyjitpl import MetaInterpStaticData
from rpython.jit.metainterp.jitprof import Profiler, EmptyProfiler
from rpython.jit.metainterp.jitdriver import JitDriverStaticData
from rpython.jit.codewriter import support, codewriter
from rpython.jit.codewriter.policy import JitPolicy
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp.optimizeopt import ALL_OPTS_NAMES
from rpython.rlib.entrypoint import all_jit_entrypoints,\
     annotated_jit_entrypoints


# ____________________________________________________________
# Bootstrapping

def apply_jit(translator, backend_name="auto", inline=False,
              vec=False, enable_opts=ALL_OPTS_NAMES, **kwds):
    if 'CPUClass' not in kwds:
        from rpython.jit.backend.detect_cpu import getcpuclass
        kwds['CPUClass'] = getcpuclass(backend_name)
    ProfilerClass = Profiler
    # Always use Profiler here, which should have a very low impact.
    # Otherwise you can try with ProfilerClass = EmptyProfiler.
    warmrunnerdesc = WarmRunnerDesc(translator,
                                    translate_support_code=True,
                                    listops=True,
                                    no_stats=True,
                                    ProfilerClass=ProfilerClass,
                                    **kwds)
    if len(warmrunnerdesc.jitdrivers_sd) == 1:
        jd = warmrunnerdesc.jitdrivers_sd[0]
        jd.jitdriver.is_recursive = True
    else:
        count_recursive = 0
        invalid = 0
        for jd in warmrunnerdesc.jitdrivers_sd:
            count_recursive += jd.jitdriver.is_recursive
            invalid += (jd.jitdriver.has_unique_id and
                           not jd.jitdriver.is_recursive)
        if count_recursive == 0:
            raise Exception("if you have more than one jitdriver, at least"
                " one of them has to be marked with is_recursive=True,"
                " none found")
        if invalid > 0:
            raise Exception("found %d jitdriver(s) with 'get_unique_id=...' "
                            "specified but without 'is_recursive=True'" %
                            (invalid,))
    for jd in warmrunnerdesc.jitdrivers_sd:
        jd.warmstate.set_param_inlining(inline)
        jd.warmstate.set_param_vec(vec)
        jd.warmstate.set_param_enable_opts(enable_opts)
    warmrunnerdesc.finish()
    translator.warmrunnerdesc = warmrunnerdesc    # for later debugging

def ll_meta_interp(function, args, backendopt=False,
                   listcomp=False, translationoptions={}, **kwds):
    if listcomp:
        extraconfigopts = {'translation.list_comprehension_operations': True}
    else:
        extraconfigopts = {}
    for key, value in translationoptions.items():
        extraconfigopts['translation.' + key] = value
    interp, graph = get_interpreter(function, args,
                                    backendopt=False,  # will be done below
                                    **extraconfigopts)
    clear_tcache()
    return jittify_and_run(interp, graph, args, backendopt=backendopt, **kwds)

def jittify_and_run(interp, graph, args, repeat=1, graph_and_interp_only=False,
                    backendopt=False, trace_limit=sys.maxint, inline=False,
                    loop_longevity=0, retrace_limit=5, function_threshold=4,
                    disable_unrolling=sys.maxint,
                    enable_opts=ALL_OPTS_NAMES, max_retrace_guards=15,
                    max_unroll_recursion=7, vec=0, vec_all=0, vec_cost=0,
                    **kwds):
    from rpython.config.config import ConfigError
    translator = interp.typer.annotator.translator
    try:
        translator.config.translation.gc = "boehm"
    except (ConfigError, TypeError):
        pass
    try:
        translator.config.translation.list_comprehension_operations = True
    except ConfigError:
        pass
    warmrunnerdesc = WarmRunnerDesc(translator, backendopt=backendopt, **kwds)
    for jd in warmrunnerdesc.jitdrivers_sd:
        jd.warmstate.set_param_threshold(3)          # for tests
        jd.warmstate.set_param_function_threshold(function_threshold)
        jd.warmstate.set_param_trace_eagerness(2)    # for tests
        jd.warmstate.set_param_trace_limit(trace_limit)
        jd.warmstate.set_param_inlining(inline)
        jd.warmstate.set_param_loop_longevity(loop_longevity)
        jd.warmstate.set_param_retrace_limit(retrace_limit)
        jd.warmstate.set_param_max_retrace_guards(max_retrace_guards)
        jd.warmstate.set_param_enable_opts(enable_opts)
        jd.warmstate.set_param_max_unroll_recursion(max_unroll_recursion)
        jd.warmstate.set_param_disable_unrolling(disable_unrolling)
        jd.warmstate.set_param_vec(vec)
        jd.warmstate.set_param_vec_all(vec_all)
        jd.warmstate.set_param_vec_cost(vec_cost)
    warmrunnerdesc.finish()
    if graph_and_interp_only:
        return interp, graph
    res = interp.eval_graph(graph, args)
    if not kwds.get('translate_support_code', False):
        warmrunnerdesc.metainterp_sd.jitlog.finish()
        warmrunnerdesc.metainterp_sd.profiler.finish()
        warmrunnerdesc.metainterp_sd.cpu.finish_once()
    print '~~~ return value:', repr(res)
    while repeat > 1:
        print '~' * 79
        res1 = interp.eval_graph(graph, args)
        if isinstance(res, int):
            assert res1 == res
        repeat -= 1
    return res

def rpython_ll_meta_interp(function, args, backendopt=True, **kwds):
    return ll_meta_interp(function, args, backendopt=backendopt,
                          translate_support_code=True, **kwds)

def _find_jit_marker(graphs, marker_name, check_driver=True):
    results = []
    for graph in graphs:
        for block in graph.iterblocks():
            for i in range(len(block.operations)):
                op = block.operations[i]
                if (op.opname == 'jit_marker' and
                    op.args[0].value == marker_name and
                    (not check_driver or op.args[1].value is None or
                     op.args[1].value.active)):   # the jitdriver
                    results.append((graph, block, i))
    return results

def _find_jit_markers(graphs, marker_names):
    results = []
    for graph in graphs:
        for block in graph.iterblocks():
            for i in range(len(block.operations)):
                op = block.operations[i]
                if (op.opname == 'jit_marker' and
                    op.args[0].value in marker_names):
                    results.append((graph, block, i))
    return results

def find_can_enter_jit(graphs):
    return _find_jit_marker(graphs, 'can_enter_jit')

def find_loop_headers(graphs):
    return _find_jit_marker(graphs, 'loop_header')

def find_jit_merge_points(graphs):
    results = _find_jit_marker(graphs, 'jit_merge_point')
    if not results:
        raise Exception("no jit_merge_point found!")
    seen = set([graph for graph, block, pos in results])
    assert len(seen) == len(results), (
        "found several jit_merge_points in the same graph")
    return results

def find_access_helpers(graphs):
    return _find_jit_marker(graphs, 'access_helper', False)

def locate_jit_merge_point(graph):
    [(graph, block, pos)] = find_jit_merge_points([graph])
    return block, pos, block.operations[pos]

def find_set_param(graphs):
    return _find_jit_marker(graphs, 'set_param')

def find_force_quasi_immutable(graphs):
    results = []
    for graph in graphs:
        for block in graph.iterblocks():
            for i in range(len(block.operations)):
                op = block.operations[i]
                if op.opname == 'jit_force_quasi_immutable':
                    results.append((graph, block, i))
    return results

def get_stats():
    return pyjitpl._warmrunnerdesc.stats

def reset_stats():
    pyjitpl._warmrunnerdesc.stats.clear()

def reset_jit():
    """Helper for some tests (see micronumpy/test/test_zjit.py)"""
    reset_stats()
    pyjitpl._warmrunnerdesc.memory_manager.alive_loops.clear()
    pyjitpl._warmrunnerdesc.jitcounter._clear_all()

def get_translator():
    return pyjitpl._warmrunnerdesc.translator

def debug_checks():
    stats = get_stats()
    stats.maybe_view()
    stats.check_consistency()

# ____________________________________________________________
# always disabled hooks interface

from rpython.rlib.jit import JitHookInterface

class NoHooksInterface(JitHookInterface):
    def are_hooks_enabled(self):
        return False

# ____________________________________________________________

class WarmRunnerDesc(object):

    def __init__(self, translator, policy=None, backendopt=True, CPUClass=None,
                 ProfilerClass=EmptyProfiler, **kwds):
        pyjitpl._warmrunnerdesc = self   # this is a global for debugging only!
        self.set_translator(translator)
        self.memory_manager = memmgr.MemoryManager()
        self.build_cpu(CPUClass, **kwds)
        self.inline_inlineable_portals()
        self.find_portals()
        self.codewriter = codewriter.CodeWriter(self.cpu, self.jitdrivers_sd)
        if policy is None:
            policy = JitPolicy()
        policy.set_supports_floats(self.cpu.supports_floats)
        policy.set_supports_longlong(self.cpu.supports_longlong)
        policy.set_supports_singlefloats(self.cpu.supports_singlefloats)
        graphs = self.codewriter.find_all_graphs(policy)
        policy.dump_unsafe_loops()
        self.check_access_directly_sanity(graphs)
        if backendopt:
            self.prejit_optimizations(policy, graphs)
        elif self.opt.listops:
            self.prejit_optimizations_minimal_inline(policy, graphs)

        self.build_meta_interp(ProfilerClass,
                             translator.config.translation.jit_opencoder_model)
        self.make_args_specifications()
        #
        from rpython.jit.metainterp.virtualref import VirtualRefInfo
        vrefinfo = VirtualRefInfo(self)
        self.codewriter.setup_vrefinfo(vrefinfo)
        #
        from rpython.jit.metainterp import counter
        if self.cpu.translate_support_code:
            self.jitcounter = counter.JitCounter(translator=translator)
        else:
            self.jitcounter = counter.DeterministicJitCounter()
        #
        self.make_hooks(policy.jithookiface)
        self.make_virtualizable_infos()
        self.make_driverhook_graphs()
        self.make_enter_functions()
        self.rewrite_jit_merge_points(policy)

        verbose = False # not self.cpu.translate_support_code
        self.rewrite_access_helpers()
        self.create_jit_entry_points()
        jitcodes = self.codewriter.make_jitcodes(verbose=verbose)
        self.metainterp_sd.jitcodes = jitcodes
        self.rewrite_can_enter_jits()
        self.rewrite_set_param_and_get_stats()
        self.rewrite_force_virtual(vrefinfo)
        self.rewrite_jitcell_accesses()
        self.rewrite_force_quasi_immutable()
        self.add_finish()
        self.metainterp_sd.finish_setup(self.codewriter)

    def finish(self):
        vinfos = set([jd.virtualizable_info for jd in self.jitdrivers_sd])
        for vinfo in vinfos:
            if vinfo is not None:
                vinfo.finish()
        self.metainterp_sd.finish_setup_descrs()
        if self.cpu.translate_support_code:
            self.annhelper.finish()

    def _freeze_(self):
        return True

    def set_translator(self, translator):
        self.translator = translator
        self.rtyper = translator.rtyper
        self.gcdescr = gc.get_description(translator.config)

    def inline_inlineable_portals(self):
        """
        Find all the graphs which have been decorated with @jitdriver.inline
        and inline them in the callers, making them JIT portals. Then, create
        a fresh copy of the jitdriver for each of those new portals, because
        they cannot share the same one.  See
        test_ajit::test_inline_jit_merge_point
        """
        from rpython.translator.backendopt.inline import (
            inlinable_static_callers, auto_inlining)

        jmp_calls = {}
        def get_jmp_call(graph, _inline_jit_merge_point_):
            # there might be multiple calls to the @inlined function: the
            # first time we see it, we remove the call to the jit_merge_point
            # and we remember the corresponding op. Then, we create a new call
            # to it every time we need a new one (i.e., for each callsite
            # which becomes a new portal)
            try:
                op, jmp_graph = jmp_calls[graph]
            except KeyError:
                op, jmp_graph = fish_jmp_call(graph, _inline_jit_merge_point_)
                jmp_calls[graph] = op, jmp_graph
            #
            # clone the op
            newargs = op.args[:]
            newresult = Variable()
            newresult.concretetype = op.result.concretetype
            op = SpaceOperation(op.opname, newargs, newresult)
            return op, jmp_graph

        def fish_jmp_call(graph, _inline_jit_merge_point_):
            # graph is function which has been decorated with
            # @jitdriver.inline, so its very first op is a call to the
            # function which contains the actual jit_merge_point: fish it!
            jmp_block, op_jmp_call = next(callee.iterblockops())
            msg = ("The first operation of an _inline_jit_merge_point_ graph must be "
                   "a direct_call to the function passed to @jitdriver.inline()")
            assert op_jmp_call.opname == 'direct_call', msg
            jmp_funcobj = op_jmp_call.args[0].value._obj
            assert jmp_funcobj._callable is _inline_jit_merge_point_, msg
            jmp_block.operations.remove(op_jmp_call)
            return op_jmp_call, jmp_funcobj.graph

        # find all the graphs which call an @inline_in_portal function
        callgraph = inlinable_static_callers(self.translator.graphs, store_calls=True)
        new_callgraph = []
        new_portals = set()
        inlined_jit_merge_points = set()
        for caller, block, op_call, callee in callgraph:
            func = getattr(callee, 'func', None)
            _inline_jit_merge_point_ = getattr(func, '_inline_jit_merge_point_', None)
            if _inline_jit_merge_point_:
                _inline_jit_merge_point_._always_inline_ = True
                inlined_jit_merge_points.add(_inline_jit_merge_point_)
                op_jmp_call, jmp_graph = get_jmp_call(callee, _inline_jit_merge_point_)
                #
                # now we move the op_jmp_call from callee to caller, just
                # before op_call. We assume that the args passed to
                # op_jmp_call are the very same which are received by callee
                # (i.e., the one passed to op_call)
                assert len(op_call.args) == len(op_jmp_call.args)
                op_jmp_call.args[1:] = op_call.args[1:]
                idx = block.operations.index(op_call)
                block.operations.insert(idx, op_jmp_call)
                #
                # finally, we signal that we want to inline op_jmp_call into
                # caller, so that finally the actuall call to
                # driver.jit_merge_point will be seen there
                new_callgraph.append((caller, jmp_graph))
                new_portals.add(caller)

        # inline them!
        inline_threshold = 0.1 # we rely on the _always_inline_ set above
        auto_inlining(self.translator, inline_threshold, new_callgraph)
        # clean up _always_inline_ = True, it can explode later
        for item in inlined_jit_merge_points:
            del item._always_inline_

        # make a fresh copy of the JitDriver in all newly created
        # jit_merge_points
        self.clone_inlined_jit_merge_points(new_portals)

    def clone_inlined_jit_merge_points(self, graphs):
        """
        Find all the jit_merge_points in the given graphs, and replace the
        original JitDriver with a fresh clone.
        """
        if not graphs:
            return
        for graph, block, pos in find_jit_merge_points(graphs):
            op = block.operations[pos]
            v_driver = op.args[1]
            driver = v_driver.value
            if not driver.inline_jit_merge_point:
                continue
            new_driver = driver.clone()
            c_new_driver = Constant(new_driver, v_driver.concretetype)
            op.args[1] = c_new_driver

    def find_portals(self):
        self.jitdrivers_sd = []
        graphs = self.translator.graphs
        for graph, block, pos in find_jit_merge_points(graphs):
            support.autodetect_jit_markers_redvars(graph)
            self.split_graph_and_record_jitdriver(graph, block, pos)
        #
        assert (len(set([jd.jitdriver for jd in self.jitdrivers_sd])) ==
                len(self.jitdrivers_sd)), \
                "there are multiple jit_merge_points with the same jitdriver"

    def split_graph_and_record_jitdriver(self, graph, block, pos):
        op = block.operations[pos]
        jd = JitDriverStaticData()
        jd._jit_merge_point_in = graph
        args = op.args[2:]
        s_binding = self.translator.annotator.binding
        jd._portal_args_s = [s_binding(v) for v in args]
        graph = copygraph(graph)
        [jmpp] = find_jit_merge_points([graph])
        graph.startblock = support.split_before_jit_merge_point(*jmpp)
        # XXX this is incredibly obscure, but this is sometimes necessary
        #     so we don't explode in checkgraph. for reasons unknown this
        #     is not contained within simplify_graph
        removenoops.remove_same_as(graph)
        # a crash in the following checkgraph() means that you forgot
        # to list some variable in greens=[] or reds=[] in JitDriver,
        # or that a jit_merge_point() takes a constant as an argument.
        checkgraph(graph)
        for v in graph.getargs():
            assert isinstance(v, Variable)
        assert len(dict.fromkeys(graph.getargs())) == len(graph.getargs())
        self.translator.graphs.append(graph)
        jd.portal_graph = graph
        # it's a bit unbelievable to have a portal without func
        assert hasattr(graph, "func")
        graph.func._dont_inline_ = True
        graph.func._jit_unroll_safe_ = True
        jd.jitdriver = block.operations[pos].args[1].value
        jd.vec = jd.jitdriver.vec
        jd.portal_runner_ptr = "<not set so far>"
        jd.result_type = history.getkind(jd.portal_graph.getreturnvar()
                                         .concretetype)[0]
        self.jitdrivers_sd.append(jd)

    def check_access_directly_sanity(self, graphs):
        from rpython.translator.backendopt.inline import collect_called_graphs
        jit_graphs = set(graphs)
        for graph in collect_called_graphs(self.translator.entry_point_graph,
                                           self.translator):
            if graph in jit_graphs:
                continue
            assert not getattr(graph, 'access_directly', False)

    def prejit_optimizations(self, policy, graphs):
        from rpython.translator.backendopt.all import backend_optimizations
        backend_optimizations(self.translator,
                              graphs=graphs,
                              merge_if_blocks=True,
                              constfold=True,
                              remove_asserts=True,
                              really_remove_asserts=True,
                              replace_we_are_jitted=False)

    def prejit_optimizations_minimal_inline(self, policy, graphs):
        from rpython.translator.backendopt.inline import auto_inline_graphs
        auto_inline_graphs(self.translator, graphs, 0.01)

    def build_cpu(self, CPUClass, translate_support_code=False,
                  no_stats=False, no_stats_history=False, supports_floats=True,
                  supports_longlong=True, supports_singlefloats=True,
                  **kwds):
        assert CPUClass is not None
        self.opt = history.Options(**kwds)
        if no_stats:
            stats = history.NoStats()
        else:
            stats = history.Stats(None)
            if no_stats_history:
                stats.set_history = lambda history: None
                # ^^^ for test_jitiface.test_memmgr_release_all.  otherwise,
                # stats.history attribute keeps the most recent loop alive
        self.stats = stats
        if translate_support_code:
            self.annhelper = MixLevelHelperAnnotator(self.translator.rtyper)
        cpu = CPUClass(self.translator.rtyper, self.stats, self.opt,
                       translate_support_code, gcdescr=self.gcdescr)
        if not supports_floats:
            cpu.supports_floats = False
        if not supports_longlong:
            cpu.supports_longlong = False
        if not supports_singlefloats:
            cpu.supports_singlefloats = False
        self.cpu = cpu

    def build_meta_interp(self, ProfilerClass, opencoder_model):
        from rpython.jit.metainterp.opencoder import Model, BigModel
        self.metainterp_sd = MetaInterpStaticData(self.cpu,
                                                  self.opt,
                                                  ProfilerClass=ProfilerClass,
                                                  warmrunnerdesc=self)
        if opencoder_model == 'big':
            self.metainterp_sd.opencoder_model = BigModel
        else:
            self.metainterp_sd.opencoder_model = Model
        self.stats.metainterp_sd = self.metainterp_sd

    def make_hooks(self, hooks):
        if hooks is None:
            # interface not overridden, use a special one that is never enabled
            hooks = NoHooksInterface()
        self.hooks = hooks

    def make_virtualizable_infos(self):
        vinfos = {}
        for jd in self.jitdrivers_sd:
            #
            jd.greenfield_info = None
            for name in jd.jitdriver.greens:
                if '.' in name:
                    from rpython.jit.metainterp.greenfield import GreenFieldInfo
                    jd.greenfield_info = GreenFieldInfo(self.cpu, jd)
                    break
            #
            if not jd.jitdriver.virtualizables:
                jd.virtualizable_info = None
                jd.index_of_virtualizable = -1
                continue
            else:
                assert jd.greenfield_info is None, "XXX not supported yet"
            #
            jitdriver = jd.jitdriver
            assert len(jitdriver.virtualizables) == 1    # for now
            [vname] = jitdriver.virtualizables
            # XXX skip the Voids here too
            jd.index_of_virtualizable = jitdriver.reds.index(vname)
            #
            index = jd.num_green_args + jd.index_of_virtualizable
            VTYPEPTR = jd._JIT_ENTER_FUNCTYPE.ARGS[index]
            if VTYPEPTR not in vinfos:
                from rpython.jit.metainterp.virtualizable import VirtualizableInfo
                vinfos[VTYPEPTR] = VirtualizableInfo(self, VTYPEPTR)
            jd.virtualizable_info = vinfos[VTYPEPTR]

    def make_enter_functions(self):
        for jd in self.jitdrivers_sd:
            self.make_enter_function(jd)

    def make_enter_function(self, jd):
        from rpython.jit.metainterp.warmstate import WarmEnterState
        state = WarmEnterState(self, jd)
        maybe_compile_and_run, EnterJitAssembler = state.make_entry_point()
        jd.warmstate = state

        def crash_in_jit(e):
            tb = not we_are_translated() and sys.exc_info()[2]
            try:
                raise e
            except jitexc.JitException:
                raise     # go through
            except MemoryError:
                raise     # go through
            except StackOverflow:
                raise     # go through
            except Exception as e:
                if not we_are_translated():
                    print "~~~ Crash in JIT!"
                    print '~~~ %s: %s' % (e.__class__, e)
                    if sys.stdout == sys.__stdout__:
                        import pdb; pdb.post_mortem(tb)
                    raise e.__class__, e, tb
                fatalerror('~~~ Crash in JIT! %s' % (e,))
        crash_in_jit._dont_inline_ = True

        def maybe_enter_jit(*args):
            try:
                maybe_compile_and_run(state.increment_threshold, *args)
            except Exception as e:
                crash_in_jit(e)
        maybe_enter_jit._always_inline_ = True
        jd._maybe_enter_jit_fn = maybe_enter_jit
        jd._maybe_compile_and_run_fn = maybe_compile_and_run
        jd._EnterJitAssembler = EnterJitAssembler

    def make_driverhook_graphs(self):
        #
        annhelper = MixLevelHelperAnnotator(self.translator.rtyper)
        for jd in self.jitdrivers_sd:
            jd._get_printable_location_ptr = self._make_hook_graph(jd,
                annhelper, jd.jitdriver.get_printable_location,
                annmodel.SomeString())
            jd._get_unique_id_ptr = self._make_hook_graph(jd,
                annhelper, jd.jitdriver.get_unique_id, annmodel.SomeInteger())
            jd._confirm_enter_jit_ptr = self._make_hook_graph(jd,
                annhelper, jd.jitdriver.confirm_enter_jit, annmodel.s_Bool,
                onlygreens=False)
            jd._can_never_inline_ptr = self._make_hook_graph(jd,
                annhelper, jd.jitdriver.can_never_inline, annmodel.s_Bool)
            jd._should_unroll_one_iteration_ptr = self._make_hook_graph(jd,
                annhelper, jd.jitdriver.should_unroll_one_iteration,
                annmodel.s_Bool)
            #
            items = []
            types = ()
            pos = ()
            if jd.jitdriver.get_location:
                assert hasattr(jd.jitdriver.get_location, '_loc_types'), """
                You must decorate your get_location function:

                from rpython.rlib.rjitlog import rjitlog as jl
                @jl.returns(jl.MP_FILENAME, jl.MP_XXX, ...)
                def get_loc(your, green, keys):
                    name = "x.txt" # extract it from your green keys
                    return (name, ...)
                """
                types = jd.jitdriver.get_location._loc_types
                del jd.jitdriver.get_location._loc_types
                #
                for _,type in types:
                    if type == 's':
                        items.append(annmodel.SomeString())
                    elif type == 'i':
                        items.append(annmodel.SomeInteger())
                    else:
                        raise NotImplementedError
            s_Tuple = annmodel.SomeTuple(items)
            jd._get_location_ptr = self._make_hook_graph(jd,
                annhelper, jd.jitdriver.get_location, s_Tuple)
            jd._get_loc_types = types
        annhelper.finish()

    def _make_hook_graph(self, jitdriver_sd, annhelper, func,
                         s_result, s_first_arg=None, onlygreens=True):
        if func is None:
            return None
        #
        if not onlygreens:
            assert not jitdriver_sd.jitdriver.autoreds, (
                "reds='auto' is not compatible with JitDriver hooks such as "
                "confirm_enter_jit")
        extra_args_s = []
        if s_first_arg is not None:
            extra_args_s.append(s_first_arg)
        #
        args_s = jitdriver_sd._portal_args_s
        if onlygreens:
            args_s = args_s[:len(jitdriver_sd._green_args_spec)]
        graph = annhelper.getgraph(func, extra_args_s + args_s, s_result)
        funcptr = annhelper.graph2delayed(graph)
        return funcptr

    def make_args_specifications(self):
        for jd in self.jitdrivers_sd:
            self.make_args_specification(jd)

    def make_args_specification(self, jd):
        graph = jd._jit_merge_point_in
        _, _, op = locate_jit_merge_point(graph)
        greens_v, reds_v = support.decode_hp_hint_args(op)
        ALLARGS = [v.concretetype for v in (greens_v + reds_v)]
        jd._green_args_spec = [v.concretetype for v in greens_v]
        jd.red_args_types = [history.getkind(v.concretetype) for v in reds_v]
        jd.num_green_args = len(jd._green_args_spec)
        jd.num_red_args = len(jd.red_args_types)
        RESTYPE = graph.getreturnvar().concretetype
        jd._JIT_ENTER_FUNCTYPE = lltype.FuncType(ALLARGS, lltype.Void)
        jd._PTR_JIT_ENTER_FUNCTYPE = lltype.Ptr(jd._JIT_ENTER_FUNCTYPE)
        jd._PORTAL_FUNCTYPE = lltype.FuncType(ALLARGS, RESTYPE)
        jd._PTR_PORTAL_FUNCTYPE = lltype.Ptr(jd._PORTAL_FUNCTYPE)
        #
        if jd.result_type == 'v':
            ASMRESTYPE = lltype.Void
        elif jd.result_type == history.INT:
            ASMRESTYPE = lltype.Signed
        elif jd.result_type == history.REF:
            ASMRESTYPE = llmemory.GCREF
        elif jd.result_type == history.FLOAT:
            ASMRESTYPE = lltype.Float
        else:
            assert False
        jd._PTR_ASSEMBLER_HELPER_FUNCTYPE = lltype.Ptr(lltype.FuncType(
            [llmemory.GCREF, llmemory.GCREF], ASMRESTYPE))

    def rewrite_jitcell_accesses(self):
        jitdrivers_by_name = {}
        for jd in self.jitdrivers_sd:
            name = jd.jitdriver.name
            if name != 'jitdriver':
                jitdrivers_by_name[name] = jd
        m = _find_jit_markers(self.translator.graphs,
                              ('get_jitcell_at_key', 'trace_next_iteration',
                               'dont_trace_here', 'trace_next_iteration_hash'))
        accessors = {}

        def get_accessor(name, jitdriver_name, function, ARGS, green_arg_spec):
            a = accessors.get((name, jitdriver_name))
            if a:
                return a
            d = {'function': function,
                 'cast_instance_to_gcref': cast_instance_to_gcref,
                 'lltype': lltype}
            arg_spec = ", ".join([("arg%d" % i) for i in range(len(ARGS))])
            arg_converters = []
            for i, spec in enumerate(green_arg_spec):
                if isinstance(spec, lltype.Ptr):
                    arg_converters.append("arg%d = lltype.cast_opaque_ptr(type%d, arg%d)" % (i, i, i))
                    d['type%d' % i] = spec
            convert = ";".join(arg_converters)
            if name == 'get_jitcell_at_key':
                exec py.code.Source("""
                def accessor(%s):
                    %s
                    return cast_instance_to_gcref(function(%s))
                """ % (arg_spec, convert, arg_spec)).compile() in d
                FUNC = lltype.Ptr(lltype.FuncType(ARGS, llmemory.GCREF))
            elif name == "trace_next_iteration_hash":
                exec py.code.Source("""
                def accessor(arg0):
                    function(arg0)
                """).compile() in d
                FUNC = lltype.Ptr(lltype.FuncType([lltype.Unsigned],
                                                  lltype.Void))
            else:
                exec py.code.Source("""
                def accessor(%s):
                    %s
                    function(%s)
                """ % (arg_spec, convert, arg_spec)).compile() in d
                FUNC = lltype.Ptr(lltype.FuncType(ARGS, lltype.Void))
            func = d['accessor']
            ll_ptr = self.helper_func(FUNC, func)
            accessors[(name, jitdriver_name)] = ll_ptr
            return ll_ptr

        for graph, block, index in m:
            op = block.operations[index]
            jitdriver_name = op.args[1].value
            JitCell = jitdrivers_by_name[jitdriver_name].warmstate.JitCell
            ARGS = [x.concretetype for x in op.args[2:]]
            if op.args[0].value == 'get_jitcell_at_key':
                func = JitCell.get_jitcell
            elif op.args[0].value == 'dont_trace_here':
                func = JitCell.dont_trace_here
            elif op.args[0].value == 'trace_next_iteration_hash':
                func = JitCell.trace_next_iteration_hash
            else:
                func = JitCell._trace_next_iteration
            argspec = jitdrivers_by_name[jitdriver_name]._green_args_spec
            accessor = get_accessor(op.args[0].value,
                                    jitdriver_name, func,
                                    ARGS, argspec)
            v_result = op.result
            c_accessor = Constant(accessor, concretetype=lltype.Void)
            newop = SpaceOperation('direct_call', [c_accessor] + op.args[2:],
                                   v_result)
            block.operations[index] = newop

    def rewrite_can_enter_jits(self):
        sublists = {}
        for jd in self.jitdrivers_sd:
            sublists[jd.jitdriver] = jd, []
            jd.no_loop_header = True
        #
        loop_headers = find_loop_headers(self.translator.graphs)
        for graph, block, index in loop_headers:
            op = block.operations[index]
            jitdriver = op.args[1].value
            assert jitdriver in sublists, \
                   "loop_header with no matching jit_merge_point"
            jd, sublist = sublists[jitdriver]
            jd.no_loop_header = False
        #
        can_enter_jits = find_can_enter_jit(self.translator.graphs)
        for graph, block, index in can_enter_jits:
            op = block.operations[index]
            jitdriver = op.args[1].value
            assert jitdriver in sublists, \
                   "can_enter_jit with no matching jit_merge_point"
            assert not jitdriver.autoreds, (
                   "can_enter_jit not supported with a jitdriver that "
                   "has reds='auto'")
            jd, sublist = sublists[jitdriver]
            origportalgraph = jd._jit_merge_point_in
            if graph is not origportalgraph:
                sublist.append((graph, block, index))
                jd.no_loop_header = False
            else:
                pass   # a 'can_enter_jit' before the 'jit-merge_point', but
                       # originally in the same function: we ignore it here
                       # see e.g. test_jitdriver.test_simple
        for jd in self.jitdrivers_sd:
            _, sublist = sublists[jd.jitdriver]
            self.rewrite_can_enter_jit(jd, sublist)

    def rewrite_can_enter_jit(self, jd, can_enter_jits):
        FUNCPTR = jd._PTR_JIT_ENTER_FUNCTYPE
        jit_enter_fnptr = self.helper_func(FUNCPTR, jd._maybe_enter_jit_fn)

        if len(can_enter_jits) == 0:
            # see test_warmspot.test_no_loop_at_all
            operations = jd.portal_graph.startblock.operations
            op1 = operations[0]
            assert (op1.opname == 'jit_marker' and
                    op1.args[0].value == 'jit_merge_point')
            op0 = SpaceOperation(
                'jit_marker',
                [Constant('can_enter_jit', lltype.Void)] + op1.args[1:],
                None)
            operations.insert(0, op0)
            can_enter_jits = [(jd.portal_graph, jd.portal_graph.startblock, 0)]

        for graph, block, index in can_enter_jits:
            if graph is jd._jit_merge_point_in:
                continue

            op = block.operations[index]
            greens_v, reds_v = support.decode_hp_hint_args(op)
            args_v = greens_v + reds_v

            vlist = [Constant(jit_enter_fnptr, FUNCPTR)] + args_v

            v_result = Variable()
            v_result.concretetype = lltype.Void
            newop = SpaceOperation('direct_call', vlist, v_result)
            block.operations[index] = newop

    def helper_func(self, FUNCPTR, func):
        if not self.cpu.translate_support_code:
            return llhelper(FUNCPTR, func)
        FUNC = FUNCPTR.TO
        args_s = [lltype_to_annotation(ARG) for ARG in FUNC.ARGS]
        s_result = lltype_to_annotation(FUNC.RESULT)
        graph = self.annhelper.getgraph(func, args_s, s_result)
        return self.annhelper.graph2delayed(graph, FUNC)

    def rewrite_access_helpers(self):
        ah = find_access_helpers(self.translator.graphs)
        for graph, block, index in ah:
            op = block.operations[index]
            self.rewrite_access_helper(op)

    def create_jit_entry_points(self):
        for func, args, result in all_jit_entrypoints:
            self.helper_func(lltype.Ptr(lltype.FuncType(args, result)), func)
            annotated_jit_entrypoints.append((func, None))

    def rewrite_access_helper(self, op):
        # make sure we make a copy of function so it no longer belongs
        # to extregistry
        func = op.args[1].value
        if func.__name__.startswith('stats_'):
            # get special treatment since we rewrite it to a call that accepts
            # jit driver
            assert len(op.args) >= 3, ("%r must have a first argument "
                                       "(which is None)" % (func,))
            func = func_with_new_name(func, func.__name__ + '_compiled')

            def new_func(ignored, *args):
                return func(self, *args)
            ARGS = [lltype.Void] + [arg.concretetype for arg in op.args[3:]]
        else:
            ARGS = [arg.concretetype for arg in op.args[2:]]
            new_func = func_with_new_name(func, func.__name__ + '_compiled')
        RESULT = op.result.concretetype
        FUNCPTR = lltype.Ptr(lltype.FuncType(ARGS, RESULT))
        ptr = self.helper_func(FUNCPTR, new_func)
        op.opname = 'direct_call'
        op.args = [Constant(ptr, FUNCPTR)] + op.args[2:]

    def rewrite_jit_merge_points(self, policy):
        for jd in self.jitdrivers_sd:
            self.rewrite_jit_merge_point(jd, policy)

    def rewrite_jit_merge_point(self, jd, policy):
        #
        # Mutate the original portal graph from this:
        #
        #       def original_portal(..):
        #           stuff
        #           while 1:
        #               jit_merge_point(*args)
        #               more stuff
        #
        # to that:
        #
        #       def original_portal(..):
        #           stuff
        #           return portal_runner(*args)
        #
        #       def portal_runner(*args):
        #           while 1:
        #               try:
        #                   return portal(*args)
        #               except JitException, e:
        #                   return handle_jitexception(e)
        #
        #       def portal(*args):
        #           while 1:
        #               more stuff
        #
        origportalgraph = jd._jit_merge_point_in
        portalgraph = jd.portal_graph
        PORTALFUNC = jd._PORTAL_FUNCTYPE

        # ____________________________________________________________
        # Prepare the portal_runner() helper
        #
        from rpython.jit.metainterp.warmstate import specialize_value
        from rpython.jit.metainterp.warmstate import unspecialize_value
        portal_ptr = lltype.functionptr(
            PORTALFUNC, 'portal', graph=portalgraph)
        jd._portal_ptr = portal_ptr
        #
        portalfunc_ARGS = []
        nums = {}
        for i, ARG in enumerate(PORTALFUNC.ARGS):
            kind = history.getkind(ARG)
            assert kind != 'void'
            if i < len(jd.jitdriver.greens):
                color = 'green'
            else:
                color = 'red'
            attrname = '%s_%s' % (color, kind)
            count = nums.get(attrname, 0)
            nums[attrname] = count + 1
            portalfunc_ARGS.append((ARG, attrname, count))
        portalfunc_ARGS = unrolling_iterable(portalfunc_ARGS)
        #
        rtyper = self.translator.rtyper
        RESULT = PORTALFUNC.RESULT
        result_kind = history.getkind(RESULT)
        assert result_kind.startswith(jd.result_type)
        state = jd.warmstate
        maybe_compile_and_run = jd._maybe_compile_and_run_fn
        EnterJitAssembler = jd._EnterJitAssembler

        def ll_portal_runner(*args):
            try:
                # maybe enter from the function's start.
                maybe_compile_and_run(
                    state.increment_function_threshold, *args)
                #
                # then run the normal portal function, i.e. the
                # interpreter's main loop.  It might enter the jit
                # via maybe_enter_jit(), which typically ends with
                # handle_fail() being called, which raises on the
                # following exceptions --- catched here, because we
                # want to interrupt the whole interpreter loop.
                return support.maybe_on_top_of_llinterp(rtyper,
                                                  portal_ptr)(*args)
            except jitexc.JitException as e:
                result = handle_jitexception(e)
                if result_kind != 'void':
                    result = specialize_value(RESULT, result)
                return result

        def handle_jitexception(e):
            # XXX there are too many exceptions all around...
            while True:
                if isinstance(e, EnterJitAssembler):
                    try:
                        return e.execute()
                    except jitexc.JitException as e:
                        continue
                #
                if isinstance(e, jitexc.ContinueRunningNormally):
                    args = ()
                    for ARGTYPE, attrname, count in portalfunc_ARGS:
                        x = getattr(e, attrname)[count]
                        x = specialize_value(ARGTYPE, x)
                        args = args + (x,)
                    try:
                        result = support.maybe_on_top_of_llinterp(rtyper,
                                                            portal_ptr)(*args)
                    except jitexc.JitException as e:
                        continue
                    if result_kind != 'void':
                        result = unspecialize_value(result)
                    return result
                #
                if result_kind == 'void':
                    if isinstance(e, jitexc.DoneWithThisFrameVoid):
                        return None
                if result_kind == 'int':
                    if isinstance(e, jitexc.DoneWithThisFrameInt):
                        return e.result
                if result_kind == 'ref':
                    if isinstance(e, jitexc.DoneWithThisFrameRef):
                        return e.result
                if result_kind == 'float':
                    if isinstance(e, jitexc.DoneWithThisFrameFloat):
                        return e.result
                #
                if isinstance(e, jitexc.ExitFrameWithExceptionRef):
                    if not we_are_translated():
                        value = lltype.cast_opaque_ptr(OBJECTPTR, e.value)
                        raise LLException(value.typeptr, value)
                    else:
                        value = cast_gcref_to_instance(Exception, e.value)
                        assert value is not None
                        raise value
                #
                raise AssertionError("all cases should have been handled")

        jd._ll_portal_runner = ll_portal_runner # for debugging
        jd.portal_runner_ptr = self.helper_func(jd._PTR_PORTAL_FUNCTYPE,
                                                ll_portal_runner)
        jd.portal_runner_adr = llmemory.cast_ptr_to_adr(jd.portal_runner_ptr)
        jd.portal_calldescr = self.cpu.calldescrof(
            jd._PTR_PORTAL_FUNCTYPE.TO,
            jd._PTR_PORTAL_FUNCTYPE.TO.ARGS,
            jd._PTR_PORTAL_FUNCTYPE.TO.RESULT,
            EffectInfo.MOST_GENERAL)

        vinfo = jd.virtualizable_info

        def assembler_call_helper(deadframe, virtualizableref):
            fail_descr = self.cpu.get_latest_descr(deadframe)
            try:
                fail_descr.handle_fail(deadframe, self.metainterp_sd, jd)
            except jitexc.JitException as e:
                return handle_jitexception(e)
            else:
                assert 0, "should have raised"

        jd._assembler_call_helper = assembler_call_helper # for debugging
        jd._assembler_helper_ptr = self.helper_func(
            jd._PTR_ASSEMBLER_HELPER_FUNCTYPE,
            assembler_call_helper)
        jd.assembler_helper_adr = llmemory.cast_ptr_to_adr(
            jd._assembler_helper_ptr)
        if vinfo is not None:
            jd.vable_token_descr = vinfo.vable_token_descr

        def handle_jitexception_from_blackhole(bhcaller, e):
            result = handle_jitexception(e)
            if result_kind == 'void':
                pass
            elif result_kind == 'int':
                bhcaller._setup_return_value_i(result)
            elif result_kind == 'ref':
                bhcaller._setup_return_value_r(result)
            elif result_kind == 'float':
                bhcaller._setup_return_value_f(result)
            else:
                assert False
        jd.handle_jitexc_from_bh = handle_jitexception_from_blackhole

        # ____________________________________________________________
        # Now mutate origportalgraph to end with a call to portal_runner_ptr
        #
        origblock, origindex, op = locate_jit_merge_point(origportalgraph)
        assert op.opname == 'jit_marker'
        assert op.args[0].value == 'jit_merge_point'
        greens_v, reds_v = support.decode_hp_hint_args(op)
        vlist = [Constant(jd.portal_runner_ptr, jd._PTR_PORTAL_FUNCTYPE)]
        vlist += greens_v
        vlist += reds_v
        v_result = Variable()
        v_result.concretetype = PORTALFUNC.RESULT
        newop = SpaceOperation('direct_call', vlist, v_result)
        del origblock.operations[origindex:]
        origblock.operations.append(newop)
        origblock.exitswitch = None
        origblock.recloseblock(Link([v_result], origportalgraph.returnblock))
        # the origportal now can raise (even if it did not raise before),
        # which means that we cannot inline it anywhere any more, but that's
        # fine since any forced inlining has been done before
        #
        checkgraph(origportalgraph)

    def add_finish(self):
        def finish():
            if self.metainterp_sd.profiler.initialized:
                self.metainterp_sd.profiler.finish()
            self.metainterp_sd.cpu.finish_once()

        if self.cpu.translate_support_code:
            call_final_function(self.translator, finish,
                                annhelper=self.annhelper)

    def rewrite_set_param_and_get_stats(self):
        from rpython.rtyper.lltypesystem.rstr import STR

        closures = {}
        graphs = self.translator.graphs
        SET_PARAM_FUNC = lltype.Ptr(lltype.FuncType(
            [lltype.Signed], lltype.Void))
        SET_PARAM_STR_FUNC = lltype.Ptr(lltype.FuncType(
            [lltype.Ptr(STR)], lltype.Void))
        def make_closure(jd, fullfuncname, is_string):
            if jd is None:
                def closure(i):
                    if is_string:
                        i = hlstr(i)
                    for jd in self.jitdrivers_sd:
                        getattr(jd.warmstate, fullfuncname)(i)
            else:
                state = jd.warmstate
                def closure(i):
                    if is_string:
                        i = hlstr(i)
                    getattr(state, fullfuncname)(i)
            if is_string:
                TP = SET_PARAM_STR_FUNC
            else:
                TP = SET_PARAM_FUNC
            funcptr = self.helper_func(TP, closure)
            return Constant(funcptr, TP)
        #
        for graph, block, i in find_set_param(graphs):

            op = block.operations[i]
            if op.args[1].value is not None:
                for jd in self.jitdrivers_sd:
                    if jd.jitdriver is op.args[1].value:
                        break
                else:
                    assert 0, "jitdriver of set_param() not found"
            else:
                jd = None
            funcname = op.args[2].value
            key = jd, funcname
            if key not in closures:
                closures[key] = make_closure(jd, 'set_param_' + funcname,
                                             funcname == 'enable_opts')
            op.opname = 'direct_call'
            op.args[:3] = [closures[key]]

    def rewrite_force_virtual(self, vrefinfo):
        all_graphs = self.translator.graphs
        vrefinfo.replace_force_virtual_with_call(all_graphs)

    def replace_force_quasiimmut_with_direct_call(self, op):
        ARG = op.args[0].concretetype
        mutatefieldname = op.args[1].value
        key = (ARG, mutatefieldname)
        if key in self._cache_force_quasiimmed_funcs:
            cptr = self._cache_force_quasiimmed_funcs[key]
        else:
            from rpython.jit.metainterp import quasiimmut
            func = quasiimmut.make_invalidation_function(ARG, mutatefieldname)
            FUNC = lltype.Ptr(lltype.FuncType([ARG], lltype.Void))
            llptr = self.helper_func(FUNC, func)
            cptr = Constant(llptr, FUNC)
            self._cache_force_quasiimmed_funcs[key] = cptr
        op.opname = 'direct_call'
        op.args = [cptr, op.args[0]]

    def rewrite_force_quasi_immutable(self):
        self._cache_force_quasiimmed_funcs = {}
        graphs = self.translator.graphs
        for graph, block, i in find_force_quasi_immutable(graphs):
            self.replace_force_quasiimmut_with_direct_call(block.operations[i])
