from rpython.jit.backend.test.calling_convention_test import CallingConvTests
from rpython.jit.backend.ppc.codebuilder import PPCBuilder
from rpython.rtyper.lltypesystem import lltype, rffi
import rpython.jit.backend.ppc.register as r


class TestPPCCallingConvention(CallingConvTests):
    # ../../test/calling_convention_test.py

    def make_function_returning_stack_pointer(self):
        mc = PPCBuilder()
        mc.mr(r.r3.value, r.r1.value)
        mc.blr()
        return rffi.cast(lltype.Signed, mc.get_assembler_function())

    def get_alignment_requirements(self):
        return 16
