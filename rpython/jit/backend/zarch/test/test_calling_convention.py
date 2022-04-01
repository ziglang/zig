from rpython.jit.backend.test.calling_convention_test import CallingConvTests
from rpython.jit.backend.zarch.codebuilder import InstrBuilder
from rpython.rtyper.lltypesystem import lltype, rffi
import rpython.jit.backend.zarch.registers as r
import rpython.jit.backend.zarch.conditions as c


class TestZARCHCallingConvention(CallingConvTests):
    # ../../test/calling_convention_test.py

    def make_function_returning_stack_pointer(self):
        mc = InstrBuilder()
        mc.LGR(r.r2, r.SP)
        mc.BCR(c.ANY, r.r14)
        return rffi.cast(lltype.Signed, mc.get_assembler_function())

    def get_alignment_requirements(self):
        return 2 # two byte alignment
