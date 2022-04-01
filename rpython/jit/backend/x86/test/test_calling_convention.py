from rpython.jit.backend.test.calling_convention_test import CallingConvTests
from rpython.jit.backend.x86 import codebuf
from rpython.jit.backend.x86.arch import WORD
from rpython.jit.backend.x86.regloc import eax, esp

class TestCallingConv(CallingConvTests):

    def make_function_returning_stack_pointer(self):
        mc = codebuf.MachineCodeBlockWrapper()
        mc.MOV(eax, esp)
        mc.ADD_ri(eax.value, WORD)
        mc.RET()
        return mc.materialize(self.cpu, [])

    def get_alignment_requirements(self):
        return 16
