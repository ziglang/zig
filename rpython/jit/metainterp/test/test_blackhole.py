import py
from rpython.rlib.jit import JitDriver
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.metainterp.blackhole import BlackholeInterpBuilder
from rpython.jit.metainterp.blackhole import BlackholeInterpreter
from rpython.jit.metainterp.blackhole import convert_and_run_from_pyjitpl
from rpython.jit.metainterp import history, pyjitpl, jitexc, resoperation
from rpython.jit.codewriter.assembler import JitCode
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.llinterp import LLException


class FakeCodeWriter:
    pass
class FakeAssembler:
    pass
class FakeCPU:
    def bh_call_i(self, func, args_i, args_r, args_f, calldescr):
        assert func == 321
        assert calldescr == "<calldescr>"
        if args_i[0] < 0:
            raise LLException("etype", "evalue")
        return args_i[0] * 2

def getblackholeinterp(insns, descrs=[]):
    cw = FakeCodeWriter()
    cw.cpu = FakeCPU()
    cw.assembler = FakeAssembler()
    cw.assembler.insns = insns
    cw.assembler.descrs = descrs
    builder = BlackholeInterpBuilder(cw)
    return builder.acquire_interp()

def test_simple():
    jitcode = JitCode("test")
    jitcode.setup("\x00\x00\x01\x02"
                  "\x01\x02",
                  [])
    blackholeinterp = getblackholeinterp({'int_add/ii>i': 0,
                                          'int_return/i': 1})
    blackholeinterp.setposition(jitcode, 0)
    blackholeinterp.setarg_i(0, 40)
    blackholeinterp.setarg_i(1, 2)
    blackholeinterp.run()
    assert blackholeinterp._final_result_anytype() == 42

def test_simple_const():
    jitcode = JitCode("test")
    jitcode.setup("\x00\x30\x01\x02"
                  "\x01\x02",
                  [])
    blackholeinterp = getblackholeinterp({'int_sub/ci>i': 0,
                                          'int_return/i': 1})
    blackholeinterp.setposition(jitcode, 0)
    blackholeinterp.setarg_i(1, 6)
    blackholeinterp.run()
    assert blackholeinterp._final_result_anytype() == 42

def test_simple_bigconst():
    jitcode = JitCode("test")
    jitcode.setup("\x00\xFD\x01\x02"
                  "\x01\x02",
                  [666, 666, 10042, 666])
    blackholeinterp = getblackholeinterp({'int_sub/ii>i': 0,
                                          'int_return/i': 1})
    blackholeinterp.setposition(jitcode, 0)
    blackholeinterp.setarg_i(1, 10000)
    blackholeinterp.run()
    assert blackholeinterp._final_result_anytype() == 42

def test_simple_loop():
    jitcode = JitCode("test")
    jitcode.setup("\x00\x16\x02\x10\x00"  # L1: goto_if_not_int_gt %i0, 2, L2
                  "\x01\x17\x16\x17"      #     int_add %i1, %i0, %i1
                  "\x02\x16\x01\x16"      #     int_sub %i0, $1, %i0
                  "\x03\x00\x00"          #     goto L1
                  "\x04\x17",             # L2: int_return %i1
                  [])
    blackholeinterp = getblackholeinterp({'goto_if_not_int_gt/icL': 0,
                                          'int_add/ii>i': 1,
                                          'int_sub/ic>i': 2,
                                          'goto/L': 3,
                                          'int_return/i': 4})
    blackholeinterp.setposition(jitcode, 0)
    blackholeinterp.setarg_i(0x16, 6)    # %i0
    blackholeinterp.setarg_i(0x17, 100)  # %i1
    blackholeinterp.run()
    assert blackholeinterp._final_result_anytype() == 100+6+5+4+3

def test_simple_exception():
    jitcode = JitCode("test")
    jitcode.setup(    # residual_call_ir_i $<* fn g>, I[%i9], R[], <Descr>  %i8
                  "\x01\xFF\x01\x09\x00\x00\x00\x08"
                  "\x00\x0D\x00"          #     catch_exception L1
                  "\x02\x08"              #     int_return %i8
                  "\x03\x2A",             # L1: int_return $42
                  [321])   # <-- address of the function g
    blackholeinterp = getblackholeinterp({'catch_exception/L': 0,
                                          'residual_call_ir_i/iIRd>i': 1,
                                          'int_return/i': 2,
                                          'int_return/c': 3},
                                         ["<calldescr>"])
    #
    blackholeinterp.setposition(jitcode, 0)
    blackholeinterp.setarg_i(0x9, 100)
    blackholeinterp.run()
    assert blackholeinterp._final_result_anytype() == 200
    #
    blackholeinterp.setposition(jitcode, 0)
    blackholeinterp.setarg_i(0x9, -100)
    blackholeinterp.run()
    assert blackholeinterp._final_result_anytype() == 42

def test_convert_and_run_from_pyjitpl():
    class MyMIFrame:
        jitcode = JitCode("test")
        jitcode.setup("\xFF"               # illegal instruction
                      "\x00\x00\x01\x02"   # int_add/ii>i
                      "\x01\x02",          # int_return/i
                      [],
                      num_regs_i=3, num_regs_r=0, num_regs_f=0)
        jitcode.jitdriver_sd = "foo" # not none
        pc = 1
        registers_i = [resoperation.InputArgInt(40), history.ConstInt(2), None]
    class MyMetaInterp:
        class staticdata:
            result_type = 'int'
            class profiler:
                @staticmethod
                def start_blackhole(): pass
                @staticmethod
                def end_blackhole(): pass
        last_exc_value = None
        framestack = [MyMIFrame()]
    MyMetaInterp.staticdata.blackholeinterpbuilder = getblackholeinterp(
        {'int_add/ii>i': 0, 'int_return/i': 1}).builder
    MyMetaInterp.staticdata.blackholeinterpbuilder.metainterp_sd = \
        MyMetaInterp.staticdata
    #
    d = py.test.raises(jitexc.DoneWithThisFrameInt,
                       convert_and_run_from_pyjitpl, MyMetaInterp())
    assert d.value.result == 42


class TestBlackhole(LLJitMixin):

    def test_blackholeinterp_cache_basic(self):
        class FakeJitcode:
            def num_regs_r(self):
                return 0
        interp1 = getblackholeinterp({})
        interp1.jitcode = FakeJitcode()
        builder = interp1.builder
        interp2 = builder.acquire_interp()
        builder.release_interp(interp1)
        interp3 = builder.acquire_interp()
        assert builder.num_interpreters == 2

    def test_blackholeinterp_cache_normal(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y'])
        def choices(x):
            if x == 0:       # <- this is the test that eventually succeeds,
                return 0     #    requiring a blackhole interp in a call stack
            return 34871     #    of two functions (hence num_interpreters==2)
        def f(x):
            y = 0
            cont = 1
            while cont:
                myjitdriver.can_enter_jit(x=x, y=y)
                myjitdriver.jit_merge_point(x=x, y=y)
                cont = choices(x)
                y += cont
                x -= 1
            return y
        #
        seen = []
        def my_copy_constants(self, *args):
            seen.append(1)
            return org_copy_constants(self, *args)
        org_copy_constants = BlackholeInterpreter.copy_constants
        BlackholeInterpreter.copy_constants = my_copy_constants
        try:
            res = self.meta_interp(f, [7], repeat=7)
        finally:
            BlackholeInterpreter.copy_constants = org_copy_constants
        #
        assert res == sum([choices(x) for x in range(1, 8)])
        builder = pyjitpl._warmrunnerdesc.metainterp_sd.blackholeinterpbuilder
        assert builder.num_interpreters == 2
        assert len(seen) == 2 * 3

    def test_blackholeinterp_cache_exc(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y'])
        class FooError(Exception):
            def __init__(self, num):
                self.num = num
        def choices(x):
            if x == 0:
                raise FooError(0)
            raise FooError(34871)
        def f(x):
            y = 0
            while True:
                myjitdriver.can_enter_jit(x=x, y=y)
                myjitdriver.jit_merge_point(x=x, y=y)
                try:
                    choices(x)
                except FooError as e:
                    if e.num == 0:
                        break
                    y += e.num
                x -= 1
            return y
        res = self.meta_interp(f, [7], repeat=7)
        assert res == sum([py.test.raises(FooError, choices, x).value.num
                           for x in range(1, 8)])
        builder = pyjitpl._warmrunnerdesc.metainterp_sd.blackholeinterpbuilder
        assert builder.num_interpreters == 2

def test_bad_shift():
    py.test.raises(ValueError, BlackholeInterpreter.bhimpl_int_lshift.im_func, 7, 100)
    py.test.raises(ValueError, BlackholeInterpreter.bhimpl_int_rshift.im_func, 7, 100)
    py.test.raises(ValueError, BlackholeInterpreter.bhimpl_uint_rshift.im_func, 7, 100)
    py.test.raises(ValueError, BlackholeInterpreter.bhimpl_int_lshift.im_func, 7, -1)
    py.test.raises(ValueError, BlackholeInterpreter.bhimpl_int_rshift.im_func, 7, -1)
    py.test.raises(ValueError, BlackholeInterpreter.bhimpl_uint_rshift.im_func, 7, -1)

    assert BlackholeInterpreter.bhimpl_int_lshift.im_func(100, 3) == 100<<3
    assert BlackholeInterpreter.bhimpl_int_rshift.im_func(100, 3) == 100>>3
    assert BlackholeInterpreter.bhimpl_uint_rshift.im_func(100, 3) == 100>>3

def test_debug_fatalerror():
    from rpython.rtyper.lltypesystem import lltype, llmemory, rstr
    from rpython.rtyper.llinterp import LLFatalError
    msg = rstr.mallocstr(1)
    msg.chars[0] = "!"
    msg = lltype.cast_opaque_ptr(llmemory.GCREF, msg)
    e = py.test.raises(LLFatalError,
                       BlackholeInterpreter.bhimpl_debug_fatalerror.im_func,
                       msg)
    assert str(e.value) == '!'
