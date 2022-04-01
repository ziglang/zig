import py

from rpython.rtyper.annlowlevel import llhelper
from rpython.jit.metainterp.history import JitCellToken
from rpython.jit.backend.test.calling_convention_test import CallingConvTests, parse
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.codewriter.effectinfo import EffectInfo

from rpython.jit.backend.arm.codebuilder import InstrBuilder
from rpython.jit.backend.arm import registers as r
from rpython.jit.backend.arm.test.support import skip_unless_run_slow_tests
from rpython.jit.backend.arm.test.test_runner import boxfloat, constfloat
from rpython.jit.metainterp.resoperation import rop, InputArgInt, InputArgFloat
from rpython.jit.metainterp.history import JitCellToken

skip_unless_run_slow_tests()

boxint = InputArgInt
boxfloat = InputArgFloat.fromfloat

class TestARMCallingConvention(CallingConvTests):
    # ../../test/calling_convention_test.py

    def make_function_returning_stack_pointer(self):
        mc = InstrBuilder()
        mc.MOV_rr(r.r0.value, r.sp.value)
        mc.MOV_rr(r.pc.value, r.lr.value)
        return mc.materialize(self.cpu, [])

    def get_alignment_requirements(self):
        return 8

    def test_call_argument_spilling(self):
        # bug when we have a value in r0, that is overwritten by an argument
        # and needed after the call, so that the register gets spilled after it
        # was overwritten with the argument to the call
        def func(a):
            return a + 16

        I = lltype.Signed
        FUNC = self.FuncType([I], I)
        FPTR = self.Ptr(FUNC)
        func_ptr = llhelper(FPTR, func)
        calldescr = self.cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT, EffectInfo.MOST_GENERAL)
        funcbox = self.get_funcbox(self.cpu, func_ptr)

        args = ', '.join(['i%d' % i for i in range(11)])
        ops = """
        [%s]
        i99 = call(ConstClass(func_ptr), 22, descr=calldescr)
        guard_true(i0) [%s, i99]
        finish()""" % (args, args)
        loop = parse(ops, namespace=locals())
        looptoken = JitCellToken()
        self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
        args = [x for x in range(11)]
        deadframe = self.cpu.execute_token(looptoken, *args)
        for x in range(11):
            assert self.cpu.get_int_value(deadframe, x) == x
        assert self.cpu.get_int_value(deadframe, 11) == 38


    def test_float_hf_call_mixed(self):
        if not self.cpu.supports_floats:
            py.test.skip("requires floats")
        cpu = self.cpu
        callargs = []
        def func(f0, f1, f2, f3, f4, f5, f6, i0, f7, i1, f8, f9):
            callargs.append(zip(range(12),
                        [f0, f1, f2, f3, f4, f5, f6, i0, f7, i1, f8, f9]))
            return f0 + f1 + f2 + f3 + f4 + f5 + f6 + float(i0 + i1) + f7 + f8 + f9
        F = lltype.Float
        I = lltype.Signed
        FUNC = self.FuncType([F] * 7 + [I] + [F] + [I] + [F]* 2, F)
        FPTR = self.Ptr(FUNC)
        func_ptr = llhelper(FPTR, func)
        calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                    EffectInfo.MOST_GENERAL)
        funcbox = self.get_funcbox(cpu, func_ptr)
        args = ([boxfloat(.1) for i in range(7)] +
                [boxint(1), boxfloat(.2), boxint(2), boxfloat(.3),
                 boxfloat(.4)])
        res = self.execute_operation(rop.CALL_F,
                                     [funcbox] + args,
                                     'float', descr=calldescr)
        for i,j in enumerate(callargs[0]):
            box = args[i]
            if box.type == 'f':
                assert (i, args[i].getfloat()) == j
            else:
                assert (i, args[i].getint()) == j
        assert abs(res.getfloat() - 4.6) < 0.0001

    def test_float_hf_call_float(self):
        if not self.cpu.supports_floats:
            py.test.skip("requires floats")
        cpu = self.cpu
        callargs = []
        def func(f0, f1, f2, f3, f4, f5, f6, f7, f8, f9):
            callargs.append(zip(range(10),
                        [f0, f1, f2, f3, f4, f5, f6, f7, f8, f9]))
            return f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9
        F = lltype.Float
        FUNC = self.FuncType([F] * 10, F)
        FPTR = self.Ptr(FUNC)
        func_ptr = llhelper(FPTR, func)
        calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                    EffectInfo.MOST_GENERAL)
        funcbox = self.get_funcbox(cpu, func_ptr)
        args = ([boxfloat(.1) for i in range(10)])
        res = self.execute_operation(rop.CALL_F,
                                     [funcbox] + args,
                                     'float', descr=calldescr)
        for i,j in enumerate(callargs[0]):
            assert (i, 0.1) == j
        assert abs(res.getfloat() - 1) < 0.0001

    def test_float_hf_call_int(self):
        cpu = self.cpu
        callargs = []
        def func(f0, f1, f2, f3, f4, f5, f6, f7, f8, f9):
            callargs.append(zip(range(10),
                        [f0, f1, f2, f3, f4, f5, f6, f7, f8, f9]))
            return f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9

        I = lltype.Signed
        FUNC = self.FuncType([I] * 10, I)
        FPTR = self.Ptr(FUNC)
        func_ptr = llhelper(FPTR, func)
        calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                    EffectInfo.MOST_GENERAL)
        funcbox = self.get_funcbox(cpu, func_ptr)
        args = ([boxint(1) for i in range(10)])
        res = self.execute_operation(rop.CALL_I,
                                     [funcbox] + args,
                                     'int', descr=calldescr)
        for i,j in enumerate(callargs[0]):
            assert (i, 1) == j
        assert res.getint() == 10
