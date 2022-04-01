
from rpython.jit.metainterp.history import BasicFinalDescr,\
     JitCellToken, ConstInt, ConstFloat
from rpython.jit.metainterp.resoperation import rop, InputArgInt, InputArgFloat
from rpython.jit.metainterp.support import ptr2int
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.tool.oparser import parse
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.annlowlevel import llhelper
from rpython.jit.codewriter import longlong
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.backend.test.runner_test import Runner
import py
import sys
import platform

def boxfloat(x):
    return InputArgFloat(longlong.getfloatstorage(x))

def constfloat(x):
    return ConstFloat(longlong.getfloatstorage(x))

class FakeStats(object):
    pass

class CallingConvTests(Runner):
    Ptr = lltype.Ptr
    FuncType = lltype.FuncType

    def setup_class(cls):
        cls.cpu = getcpuclass()(rtyper=None, stats=FakeStats())
        cls.cpu.setup_once()

    def _prepare_args(self, args, floats, ints):
        local_floats = list(floats)
        local_ints = list(ints)
        expected_result = 0.0
        arguments = []
        for i in range(len(args)):
            x = args[i]
            if x[0] == 'f':
                x = local_floats.pop()
                t = longlong.getfloatstorage(x)
                arguments.append(t)
            else:
                x = local_ints.pop()
                arguments.append(x)
            expected_result += x
        return arguments, expected_result

    @classmethod
    def get_funcbox(cls, cpu, func_ptr):
        return ConstInt(ptr2int(func_ptr))

    def test_call_aligned_with_spilled_values(self):
        cpu = self.cpu
        if not cpu.supports_floats:
            py.test.skip('requires floats')


        def func(*args):
            return float(sum(args))

        F = lltype.Float
        I = lltype.Signed
        floats = [0.7, 5.8, 0.1, 0.3, 0.9, -2.34, -3.45, -4.56]
        ints = [7, 11, 23, 13, -42, 1111, 95, 1]
        for case in range(256):
            local_floats = list(floats)
            local_ints = list(ints)
            args = []
            spills = []
            funcargs = []
            float_count = 0
            int_count = 0
            for i in range(8):
                if case & (1<<i):
                    args.append('f%d' % float_count)
                    spills.append('force_spill(f%d)' % float_count)
                    float_count += 1
                    funcargs.append(F)
                else:
                    args.append('i%d' % int_count)
                    spills.append('force_spill(i%d)' % int_count)
                    int_count += 1
                    funcargs.append(I)

            arguments = ', '.join(args)
            spill_ops = '\n'.join(spills)

            FUNC = self.FuncType(funcargs, F)
            FPTR = self.Ptr(FUNC)
            func_ptr = llhelper(FPTR, func)
            calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                        EffectInfo.MOST_GENERAL)
            funcbox = self.get_funcbox(cpu, func_ptr)

            ops = '[%s]\n' % arguments
            ops += '%s\n' % spill_ops
            ops += 'f99 = call_f(ConstClass(func_ptr), %s, descr=calldescr)\n' % arguments
            ops += 'i99 = same_as_i(0)\n'
            ops += 'guard_true(i99) [f99, %s]\n' % arguments
            ops += 'finish()\n'

            loop = parse(ops, namespace=locals())
            looptoken = JitCellToken()
            self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
            argvals, expected_result = self._prepare_args(args, floats, ints)

            deadframe = self.cpu.execute_token(looptoken, *argvals)
            x = longlong.getrealfloat(cpu.get_float_value(deadframe, 0))
            assert abs(x - expected_result) < 0.0001

    def test_call_aligned_with_imm_values(self):
        cpu = self.cpu
        if not cpu.supports_floats:
            py.test.skip('requires floats')


        def func(*args):
            return float(sum(args))

        F = lltype.Float
        I = lltype.Signed
        floats = [0.7, 5.8, 0.1, 0.3, 0.9, -2.34, -3.45, -4.56]
        ints = [7, 11, 23, 13, -42, 1111, 95, 1]
        for case in range(256):
            result = 0.0
            args = []
            argslist = []
            local_floats = list(floats)
            local_ints = list(ints)
            for i in range(8):
                if case & (1<<i):
                    args.append(F)
                    arg = local_floats.pop()
                    result += arg
                    argslist.append(constfloat(arg))
                else:
                    args.append(I)
                    arg = local_ints.pop()
                    result += arg
                    argslist.append(ConstInt(arg))
            FUNC = self.FuncType(args, F)
            FPTR = self.Ptr(FUNC)
            func_ptr = llhelper(FPTR, func)
            calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                        EffectInfo.MOST_GENERAL)
            funcbox = self.get_funcbox(cpu, func_ptr)

            res = self.execute_operation(rop.CALL_F,
                                         [funcbox] + argslist,
                                         'float', descr=calldescr)
            res = longlong.getrealfloat(res)
            assert abs(res - result) < 0.0001

    def test_call_aligned_with_args_on_the_stack(self):
        cpu = self.cpu
        if not cpu.supports_floats:
            py.test.skip('requires floats')


        def func(*args):
            return float(sum(args))

        F = lltype.Float
        I = lltype.Signed
        floats = [0.7, 5.8, 0.1, 0.3, 0.9, -2.34, -3.45, -4.56]
        ints = [7, 11, 23, 13, -42, 1111, 95, 1]
        for case in range(256):
            result = 0.0
            args = []
            argslist = []
            local_floats = list(floats)
            local_ints = list(ints)
            for i in range(8):
                if case & (1<<i):
                    args.append(F)
                    arg = local_floats.pop()
                    result += arg
                    argslist.append(boxfloat(arg))
                else:
                    args.append(I)
                    arg = local_ints.pop()
                    result += arg
                    argslist.append(InputArgInt(arg))
            FUNC = self.FuncType(args, F)
            FPTR = self.Ptr(FUNC)
            func_ptr = llhelper(FPTR, func)
            calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                        EffectInfo.MOST_GENERAL)
            funcbox = self.get_funcbox(cpu, func_ptr)

            res = self.execute_operation(rop.CALL_F,
                                         [funcbox] + argslist,
                                         'float', descr=calldescr)
            res = longlong.getrealfloat(res)
            assert abs(res - result) < 0.0001

    def test_call_alignment_call_assembler(self):
        cpu = self.cpu
        if not cpu.supports_floats:
            py.test.skip('requires floats')

        fdescr3 = BasicFinalDescr(3)
        fdescr4 = BasicFinalDescr(4)

        def assembler_helper(failindex, virtualizable):
            assert 0, 'should not be called, but was with failindex (%d)' % failindex
            return 13

        FUNCPTR = lltype.Ptr(lltype.FuncType([lltype.Signed, llmemory.GCREF],
                                             lltype.Signed))
        class FakeJitDriverSD:
            index_of_virtualizable = -1
            _assembler_helper_ptr = llhelper(FUNCPTR, assembler_helper)
            assembler_helper_adr = llmemory.cast_ptr_to_adr(
                _assembler_helper_ptr)

        floats = [0.7, 5.8, 0.1, 0.3, 0.9, -2.34, -3.45, -4.56]
        ints = [7, 11, 23, 42, -42, 1111, 95, 1]

        for case in range(256):
            float_count = 0
            int_count = 0
            args = []
            called_ops = ''
            total_index = -1
            for i in range(8):
                if case & (1<<i):
                    args.append('f%d' % float_count)
                else:
                    args.append('i%d' % int_count)
                    called_ops += 'f%d = cast_int_to_float(i%d)\n' % (
                        float_count, int_count)
                    int_count += 1
                if total_index == -1:
                    total_index = float_count
                    float_count += 1
                else:
                    called_ops += 'f%d = float_add(f%d, f%d)\n' % (
                        float_count + 1, total_index, float_count)
                    total_index = float_count + 1
                    float_count += 2
            arguments = ', '.join(args)
            called_ops = '[%s]\n' % arguments + called_ops
            called_ops += 'finish(f%d, descr=fdescr3)\n' % total_index
            # compile called loop
            called_loop = parse(called_ops, namespace=locals())
            called_looptoken = JitCellToken()
            called_looptoken.outermost_jitdriver_sd = FakeJitDriverSD()
            done_descr = called_loop.operations[-1].getdescr()
            self.cpu.compile_loop(called_loop.inputargs, called_loop.operations, called_looptoken)

            argvals, expected_result = self._prepare_args(args, floats, ints)
            deadframe = cpu.execute_token(called_looptoken, *argvals)
            assert cpu.get_latest_descr(deadframe) == fdescr3
            t = longlong.getrealfloat(cpu.get_float_value(deadframe, 0))
            assert abs(t - expected_result) < 0.0001

            ARGS = []
            RES = lltype.Float
            for x in args:
                if x[0] == 'f':
                    ARGS.append(lltype.Float)
                else:
                    ARGS.append(lltype.Signed)
            FakeJitDriverSD.portal_calldescr = self.cpu.calldescrof(
                lltype.Ptr(lltype.FuncType(ARGS, RES)), ARGS, RES,
                EffectInfo.MOST_GENERAL)
            ops = '''
            [%s]
            f99 = call_assembler_f(%s, descr=called_looptoken)
            guard_not_forced()[]
            finish(f99, descr=fdescr4)
            ''' % (arguments, arguments)
            loop = parse(ops, namespace=locals())
            # we want to take the fast path
            self.cpu.done_with_this_frame_descr_float = done_descr
            try:
                othertoken = JitCellToken()
                self.cpu.compile_loop(loop.inputargs, loop.operations, othertoken)

                # prepare call to called_loop
                argvals, _ = self._prepare_args(args, floats, ints)
                deadframe = cpu.execute_token(othertoken, *argvals)
                x = longlong.getrealfloat(
                    cpu.get_float_value(deadframe, 0))
                assert cpu.get_latest_descr(deadframe) == fdescr4
                assert abs(x - expected_result) < 0.0001
            finally:
                del self.cpu.done_with_this_frame_descr_float


    def test_call_with_imm_values_bug_constint0(self):
        cpu = self.cpu

        I = lltype.Signed
        ints = [7, 11, 23, 13, -42, 0, 0, 9]

        def func(*args):
            for i in range(len(args)):
                assert args[i] == ints[i]
            return sum(args)

        result = sum(ints)
        args = [I] * len(ints)
        argslist = [ConstInt(i) for i in ints]
        FUNC = self.FuncType(args, I)
        FPTR = self.Ptr(FUNC)
        func_ptr = llhelper(FPTR, func)
        calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT, EffectInfo.MOST_GENERAL)
        funcbox = self.get_funcbox(cpu, func_ptr)

        res = self.execute_operation(rop.CALL_I,
                                     [funcbox] + argslist,
                                     'int', descr=calldescr)
        assert res == result


    def test_call_with_singlefloats(self):
        cpu = self.cpu
        if not cpu.supports_floats or not cpu.supports_singlefloats:
            py.test.skip('requires floats and singlefloats')

        import random
        from rpython.rlib.rarithmetic import r_singlefloat

        def func(*args):
            res = 0.0
            for i, x in enumerate(args):
                res += (i + 1.1) * float(x)
            return res

        F = lltype.Float
        S = lltype.SingleFloat
        I = lltype.Signed
        floats = [random.random() - 0.5 for i in range(20)]
        singlefloats = [r_singlefloat(random.random() - 0.5) for i in range(20)]
        ints = [random.randrange(-99, 99) for i in range(20)]
        for repeat in range(100):
            args = []
            argvalues = []
            argslist = []
            local_floats = list(floats)
            local_singlefloats = list(singlefloats)
            local_ints = list(ints)
            for i in range(random.randrange(4, 20)):
                case = random.randrange(0, 6)
                if case & 1: boxme = InputArgInt
                else:        boxme = ConstInt
                if case < 2:
                    args.append(F)
                    arg = arg1 = local_floats.pop()
                    if case & 1: boxme = boxfloat
                    else:        boxme = constfloat
                elif case < 4:
                    args.append(S)
                    arg = local_singlefloats.pop()
                    arg1 = longlong.singlefloat2int(arg)
                else:
                    args.append(I)
                    arg = arg1 = local_ints.pop()
                argslist.append(boxme(arg1))
                argvalues.append(arg)
            FUNC = self.FuncType(args, F)
            FPTR = self.Ptr(FUNC)
            func_ptr = llhelper(FPTR, func)
            calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                        EffectInfo.MOST_GENERAL)
            funcbox = self.get_funcbox(cpu, func_ptr)

            res = self.execute_operation(rop.CALL_F,
                                         [funcbox] + argslist,
                                         'float', descr=calldescr)
            expected = func(*argvalues)
            res = longlong.getrealfloat(res)
            assert abs(res - expected) < 0.0001


    def make_function_returning_stack_pointer(self):
        raise NotImplementedError

    def get_alignment_requirements(self):
        raise NotImplementedError

    def test_call_aligned_explicit_check(self):
        if (not platform.machine().startswith('arm') and
                sys.maxint == 2 ** 31 - 1): # XXX is still necessary on x86?
            py.test.skip("libffi on 32bit is broken")
        cpu = self.cpu
        if not cpu.supports_floats:
            py.test.skip('requires floats')

        func_addr = self.make_function_returning_stack_pointer()

        F = lltype.Float
        I = lltype.Signed
        floats = [0.7, 5.8, 0.1, 0.3, 0.9, -2.34, -3.45, -4.56]
        ints = [7, 11, 23, 13, -42, 1111, 95, 1]
        for case in range(256):
            args = []
            funcargs = []
            float_count = 0
            int_count = 0
            for i in range(8):
                if case & (1<<i):
                    args.append('f%d' % float_count)
                    float_count += 1
                    funcargs.append(F)
                else:
                    args.append('i%d' % int_count)
                    int_count += 1
                    funcargs.append(I)

            arguments = ', '.join(args)

            FUNC = self.FuncType(funcargs, I)
            calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                        EffectInfo.MOST_GENERAL)

            ops = '[%s]\n' % arguments
            ops += 'i99 = call_i(%d, %s, descr=calldescr)\n' % (func_addr,
                                                              arguments)
            ops += 'finish(i99)\n'

            loop = parse(ops, namespace=locals())
            looptoken = JitCellToken()
            self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
            argvals, expected_result = self._prepare_args(args, floats, ints)

            deadframe = self.cpu.execute_token(looptoken, *argvals)
            x = cpu.get_int_value(deadframe, 0)
            align_req = self.get_alignment_requirements()
            assert x % align_req == 0
