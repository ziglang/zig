import py, sys, math
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.jit.backend.llgraph import runner
from rpython.jit.metainterp.warmspot import ll_meta_interp, get_stats
from rpython.jit.metainterp.warmspot import reset_stats
from rpython.jit.metainterp.warmstate import unspecialize_value
from rpython.jit.metainterp.optimizeopt import ALL_OPTS_DICT
from rpython.jit.metainterp import pyjitpl, history, jitexc
from rpython.jit.codewriter.policy import JitPolicy
from rpython.jit.codewriter import codewriter, longlong
from rpython.jit.backend.llsupport.vector_ext import VectorExt
from rpython.rlib.jit import ENABLE_ALL_OPTS
from rpython.translator.backendopt.all import backend_optimizations


def _get_jitcodes(testself, CPUClass, func, values,
                  supports_floats=True,
                  supports_longlong=False,
                  supports_singlefloats=False,
                  translationoptions={},
                  backendopt_inline_threshold=0, **kwds):
    from rpython.jit.codewriter import support

    class FakeJitCell(object):
        __product_token = None
        def get_procedure_token(self):
            return self.__product_token
        def set_procedure_token(self, token):
            self.__product_token = token

    class FakeWarmRunnerState(object):
        def attach_procedure_to_interp(self, greenkey, procedure_token):
            assert greenkey == []
            self._cell.set_procedure_token(procedure_token)

        def helper_func(self, FUNCPTR, func):
            from rpython.rtyper.annlowlevel import llhelper
            return llhelper(FUNCPTR, func)

        def get_unique_id(self, *args):
            return 0

        def get_location_str(self, args):
            return 'location'

        class JitCell:
            @staticmethod
            def get_jit_cell_at_key(greenkey):
                assert greenkey == []
                return FakeWarmRunnerState._cell
        _cell = FakeJitCell()

        trace_limit = sys.maxint
        enable_opts = ALL_OPTS_DICT
        vec = True

    if kwds.pop('disable_optimizations', False):
        FakeWarmRunnerState.enable_opts = {}

    func._jit_unroll_safe_ = True
    rtyper = support.annotate(func, values, inline=backendopt_inline_threshold,
                              translationoptions=translationoptions)
    graphs = rtyper.annotator.translator.graphs
    testself.all_graphs = graphs
    result_kind = history.getkind(graphs[0].getreturnvar().concretetype)[0]


    class FakeJitDriver:
        name = 'fakejitdriver'

    class FakeJitDriverSD:
        num_green_args = 0
        portal_graph = graphs[0]
        virtualizable_info = None
        greenfield_info = None
        result_type = result_kind
        portal_runner_ptr = "???"
        vec = False
        jitdriver = FakeJitDriver()

    stats = history.Stats(None)
    cpu = CPUClass(rtyper, stats, None, False)
    cw = codewriter.CodeWriter(cpu, [FakeJitDriverSD()])
    cw.debug = True
    testself.cw = cw
    if supports_floats and not cpu.supports_floats:
        py.test.skip("this test requires supports_floats=True")
    if supports_longlong and not cpu.supports_longlong:
        py.test.skip("this test requires supports_longlong=True")
    if supports_singlefloats and not cpu.supports_singlefloats:
        py.test.skip("this test requires supports_singlefloats=True")
    policy = JitPolicy()
    policy.set_supports_floats(supports_floats)
    policy.set_supports_longlong(supports_longlong)
    policy.set_supports_singlefloats(supports_singlefloats)
    graphs = cw.find_all_graphs(policy)
    if kwds.get("backendopt"):
        backend_optimizations(rtyper.annotator.translator, graphs=graphs)
    #
    testself.warmrunnerstate = FakeWarmRunnerState()
    testself.warmrunnerstate.cpu = cpu
    FakeJitDriverSD.warmstate = testself.warmrunnerstate
    if hasattr(testself, 'finish_setup_for_interp_operations'):
        testself.finish_setup_for_interp_operations()
    #
    cw.make_jitcodes(verbose=True)
    return stats

def _run_with_blackhole(testself, args):
    from rpython.jit.metainterp.blackhole import BlackholeInterpBuilder
    cw = testself.cw
    blackholeinterpbuilder = BlackholeInterpBuilder(cw)
    blackholeinterp = blackholeinterpbuilder.acquire_interp()
    count_i = count_r = count_f = 0
    for value in args:
        T = lltype.typeOf(value)
        if T == lltype.Signed:
            blackholeinterp.setarg_i(count_i, value)
            count_i += 1
        elif T == llmemory.GCREF:
            blackholeinterp.setarg_r(count_r, value)
            count_r += 1
        elif T == lltype.Float:
            value = longlong.getfloatstorage(value)
            blackholeinterp.setarg_f(count_f, value)
            count_f += 1
        else:
            raise TypeError(T)
    [jitdriver_sd] = cw.callcontrol.jitdrivers_sd
    blackholeinterp.setposition(jitdriver_sd.mainjitcode, 0)
    blackholeinterp.run()
    return blackholeinterp._final_result_anytype()

def _run_with_pyjitpl(testself, args, stats):
    cw = testself.cw
    opt = history.Options(listops=True)
    metainterp_sd = pyjitpl.MetaInterpStaticData(cw.cpu, opt)
    stats.metainterp_sd = metainterp_sd
    metainterp_sd.finish_setup(cw)
    metainterp_sd.finish_setup_descrs()

    [jitdriver_sd] = metainterp_sd.jitdrivers_sd
    metainterp = pyjitpl.MetaInterp(metainterp_sd, jitdriver_sd)
    testself.metainterp = metainterp
    try:
        metainterp.compile_and_run_once(jitdriver_sd, *args)
    except (jitexc.DoneWithThisFrameInt,
            jitexc.DoneWithThisFrameRef,
            jitexc.DoneWithThisFrameFloat) as e:
        return e.result
    else:
        raise Exception("FAILED")

def _run_with_machine_code(testself, args):
    metainterp = testself.metainterp
    num_green_args = metainterp.jitdriver_sd.num_green_args
    procedure_token = metainterp.get_procedure_token(args[:num_green_args])
    # a loop was successfully created by _run_with_pyjitpl(); call it
    cpu = metainterp.cpu
    args1 = []
    for i in range(len(args) - num_green_args):
        x = args[num_green_args + i]
        args1.append(unspecialize_value(x))
    deadframe = cpu.execute_token(procedure_token, *args1)
    faildescr = cpu.get_latest_descr(deadframe)
    assert faildescr.__class__.__name__.startswith('DoneWithThisFrameDescr')
    if metainterp.jitdriver_sd.result_type == history.INT:
        return deadframe, cpu.get_int_value(deadframe, 0)
    elif metainterp.jitdriver_sd.result_type == history.REF:
        return deadframe, cpu.get_ref_value(deadframe, 0)
    elif metainterp.jitdriver_sd.result_type == history.FLOAT:
        return deadframe, cpu.get_float_value(deadframe, 0)
    else:
        return deadframe, None


class JitMixin:
    basic = True
    enable_opts = ENABLE_ALL_OPTS


    # Basic terminology: the JIT produces "loops" and "bridges".
    # Bridges are always attached to failing guards.  Every loop is
    # the "trunk" of a tree of compiled code, which is formed by first
    # compiling a loop and then incrementally adding some number of
    # bridges to it.  Each loop and each bridge ends with either a
    # FINISH or a JUMP instruction (the name "loop" is not really
    # adapted any more).  The JUMP instruction jumps to any LABEL
    # pseudo-instruction, which can be anywhere, within the same tree
    # or another one.

    def check_resops(self, expected=None, **check):
        """Check the instructions in all loops and bridges, ignoring
        the ones that end in FINISH.  Either pass a dictionary (then
        the check must match exactly), or some keyword arguments (then
        the check is only about the instructions named)."""
        if self.enable_opts == ENABLE_ALL_OPTS:
            get_stats().check_resops(expected=expected, **check)

    def check_simple_loop(self, expected=None, **check):
        """Useful in the simplest case when we have only one loop
        ending with a jump back to itself and possibly a few bridges.
        Only the operations within the loop formed by that single jump
        will be counted; the bridges are all ignored.  If several loops
        were compiled, complains."""
        if self.enable_opts == ENABLE_ALL_OPTS:
            get_stats().check_simple_loop(expected=expected, **check)

    def check_trace_count(self, count): # was check_loop_count
        """Check the number of loops and bridges compiled."""
        if self.enable_opts == ENABLE_ALL_OPTS:
            assert get_stats().compiled_count == count

    def check_trace_count_at_most(self, count):
        """Check the number of loops and bridges compiled."""
        if self.enable_opts == ENABLE_ALL_OPTS:
            assert get_stats().compiled_count <= count

    def check_jitcell_token_count(self, count): # was check_tree_loop_count
        """This should check the number of independent trees of code.
        (xxx it is not 100% clear that the count is correct)"""
        if self.enable_opts == ENABLE_ALL_OPTS:
            assert len(get_stats().jitcell_token_wrefs) == count

    def check_target_token_count(self, count):
        """(xxx unknown)"""
        if self.enable_opts == ENABLE_ALL_OPTS:
            tokens = get_stats().get_all_jitcell_tokens()
            n = sum([len(t.target_tokens) for t in tokens])
            assert n == count

    def check_enter_count(self, count):
        """Check the number of times pyjitpl ran.  (Every time, it
        should have produced either one loop or one bridge, or aborted;
        but it is not 100% clear that this is still correct in the
        presence of unrolling.)"""
        if self.enable_opts == ENABLE_ALL_OPTS:
            assert get_stats().enter_count == count

    def check_enter_count_at_most(self, count):
        """Check the number of times pyjitpl ran."""
        if self.enable_opts == ENABLE_ALL_OPTS:
            assert get_stats().enter_count <= count

    def check_aborted_count(self, count):
        """Check the number of times pyjitpl was aborted."""
        if self.enable_opts == ENABLE_ALL_OPTS:
            assert get_stats().aborted_count == count

    def check_aborted_count_at_least(self, count):
        """Check the number of times pyjitpl was aborted."""
        if self.enable_opts == ENABLE_ALL_OPTS:
            assert get_stats().aborted_count >= count

    def meta_interp(self, *args, **kwds):
        kwds['CPUClass'] = self.CPUClass
        if "backendopt" not in kwds:
            kwds["backendopt"] = False
        if "enable_opts" not in kwds and hasattr(self, 'enable_opts'):
            kwds['enable_opts'] = self.enable_opts
        old = codewriter.CodeWriter.debug
        try:
            codewriter.CodeWriter.debug = True
            return ll_meta_interp(*args, **kwds)
        finally:
            codewriter.CodeWriter.debug = old

    def interp_operations(self, f, args, **kwds):
        # get the JitCodes for the function f
        stats = _get_jitcodes(self, self.CPUClass, f, args, **kwds)
        # try to run it with blackhole.py
        result1 = _run_with_blackhole(self, args)
        # try to run it with pyjitpl.py
        result2 = _run_with_pyjitpl(self, args, stats)
        assert result1 == result2 or math.isnan(result1) and math.isnan(result2)
        # try to run it by running the code compiled just before
        df, result3 = _run_with_machine_code(self, args)
        self._lastframe = df
        assert result1 == result3 or result3 == NotImplemented or math.isnan(result1) and math.isnan(result3)
        #
        if (longlong.supports_longlong and
            isinstance(result1, longlong.r_float_storage)):
            result1 = longlong.getrealfloat(result1)
        return result1

    def check_history(self, expected=None, **isns):
        # this can be used after calling meta_interp
        get_stats().check_history(expected, **isns)

    def check_operations_history(self, expected=None, **isns):
        # this can be used after interp_operations
        if expected is not None:
            expected = dict(expected)
            expected['finish'] = 1
        self.metainterp.staticdata.stats.check_history(expected, **isns)


class LLJitMixin(JitMixin):
    CPUClass = runner.LLGraphCPU

    def supports_vector_ext(self):
        return True

    @staticmethod
    def Ptr(T):
        return lltype.Ptr(T)

    @staticmethod
    def GcStruct(name, *fields, **kwds):
        S = lltype.GcStruct(name, *fields, **kwds)
        return S

    malloc = staticmethod(lltype.malloc)
    nullptr = staticmethod(lltype.nullptr)

    @staticmethod
    def malloc_immortal(T):
        return lltype.malloc(T, immortal=True)

    def _get_NODE(self):
        NODE = lltype.GcForwardReference()
        NODE.become(lltype.GcStruct('NODE', ('value', lltype.Signed),
                                            ('next', lltype.Ptr(NODE))))
        return NODE
# ____________________________________________________________

class _Foo:
    pass

def noConst(x):
    """Helper function for tests, returning 'x' as a BoxInt/BoxPtr
    even if it is a ConstInt/ConstPtr."""
    from rpython.rlib import jit
    return jit.hint(x, force_no_const=True)
