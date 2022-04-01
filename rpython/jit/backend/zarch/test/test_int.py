from rpython.jit.backend.test.runner_test import LLtypeBackendTest
from rpython.jit.backend.zarch.runner import CPU_S390_64
from rpython.jit.tool.oparser import parse
from rpython.jit.metainterp.history import (AbstractFailDescr,
         AbstractDescr, BasicFailDescr, BasicFinalDescr, JitCellToken,
         TargetToken, ConstInt, ConstPtr, Const, ConstFloat)
from rpython.jit.metainterp.resoperation import InputArgInt, InputArgFloat
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.metainterp.resoperation import ResOperation, rop
import py

class FakeStats(object):
    pass

class TestIntResOpZARCH(object):
    cpu = CPU_S390_64(rtyper=None, stats=FakeStats())
    cpu.setup_once()

    def test_uint_rshift(self):
        code = """
        [i1]
        i11 = int_and(i1, 63)
        i10 = uint_rshift(18, i11)
        i1402 = int_is_true(i10)
        guard_false(i1402, descr=faildescr) [] # must NEVER exit with i1 == 0
        finish(i1402, descr=finishdescr)
        """
        finishdescr = BasicFinalDescr(1)
        faildescr = BasicFailDescr(2)
        loop = parse(code, namespace={'faildescr': faildescr,
                                      'finishdescr': finishdescr})
        looptoken = JitCellToken()
        self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
        deadframe = self.cpu.execute_token(looptoken, 19)
        fail = self.cpu.get_latest_descr(deadframe)
        assert fail == finishdescr # ensures that guard is not taken!

    @py.test.mark.parametrize('value', [2,3,15,2**16])
    def test_evenodd_pair_extensive(self, value):
        instrs = []
        failargs = []
        values = []
        j = 0
        mapping = (('int_mul_ovf', lambda x,y: x * y),)
        for i in range(20):
            name, func = mapping[j]
            instrs.append("i{d} = {i}(i0, {d})".format(d=i+1, i=name))
            values.append((name, func(value, i+1)))
            failargs.append("i" + str(i+1))
            j += 1
            if j >= len(mapping):
                j = 0
        code = """
        [i0]
        {instrs}
        i99 = int_add(i0, 1)
        i100 = int_eq(i0,i99)
        guard_true(i100) [{failargs}] # will always fail!!
        finish(i0, descr=faildescr)
        """.format(instrs=('\n' +' '*8).join(instrs), failargs=','.join(failargs))
        # the guard forces 3 spills because after 4 divisions
        # all even slots of the managed registers are full
        loop = parse(code, namespace={'faildescr': BasicFinalDescr(1)})
        looptoken = JitCellToken()
        self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
        deadframe = self.cpu.execute_token(looptoken, value)
        fail = self.cpu.get_latest_descr(deadframe)
        for i,(name, v) in enumerate(values):
            assert self.cpu.get_int_value(deadframe, i) == v

    @py.test.mark.parametrize('v1,v2', [
        (-32,3), (-32,4), (-32,1), (-32,199),
        (16236612,3), (-1201203,4), (-123101010023,1231), (-0,199),
    ])
    def test_int_mul_no_overflow(self, v1, v2):
        try:
            result = v1*v2
        except OverflowError:
            py.test.skip("this test is not made to check the overflow!")
        code = """
        [i0]
        i1 = int_mul_ovf(i0,{v})
        finish(i1, descr=faildescr)
        """.format(v=v2)
        loop = parse(code, namespace={"faildescr": BasicFinalDescr(1)})
        looptoken = JitCellToken()
        self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
        deadframe = self.cpu.execute_token(looptoken, v1)
        fail = self.cpu.get_latest_descr(deadframe)
        assert self.cpu.get_int_value(deadframe, 0) == result

    @py.test.mark.parametrize('v1,v2', [(-189,2),(189,-2)])
    def test_int_mul_no_overflow_var_var(self, v1, v2):
        try:
            result = v1*v2
        except OverflowError:
            py.test.skip("this test is not made to check the overflow!")
        code = """
        [i0,i2]
        i1 = int_mul_ovf(i0,i2)
        finish(i1, descr=faildescr)
        """.format()
        loop = parse(code, namespace={"faildescr": BasicFinalDescr(1)})
        looptoken = JitCellToken()
        self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
        deadframe = self.cpu.execute_token(looptoken, v1, v2)
        fail = self.cpu.get_latest_descr(deadframe)
        assert self.cpu.get_int_value(deadframe, 0) == result
