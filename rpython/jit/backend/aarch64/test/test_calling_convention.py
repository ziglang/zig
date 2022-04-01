import py

from rpython.rtyper.annlowlevel import llhelper
from rpython.jit.metainterp.history import JitCellToken
from rpython.jit.backend.test.calling_convention_test import CallingConvTests, parse
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.codewriter.effectinfo import EffectInfo

from rpython.jit.backend.aarch64.codebuilder import InstrBuilder
from rpython.jit.backend.aarch64 import registers as r
from rpython.jit.backend.aarch64.test.test_runner import boxfloat, constfloat
from rpython.jit.metainterp.resoperation import rop, InputArgInt, InputArgFloat
from rpython.jit.metainterp.history import JitCellToken

boxint = InputArgInt
boxfloat = InputArgFloat.fromfloat

class TestARMCallingConvention(CallingConvTests):
    # ../../test/calling_convention_test.py

    def make_function_returning_stack_pointer(self):
        mc = InstrBuilder()
        mc.MOV_rr(r.x0.value, r.sp.value)
        mc.RET_r(r.lr.value)
        return mc.materialize(self.cpu, [])

    def get_alignment_requirements(self):
        return 16
