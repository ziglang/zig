from rpython.jit.backend.x86.regloc import *
from rpython.jit.metainterp.history import ConstFloat
from rpython.jit.metainterp.history import INT, FLOAT
from rpython.rtyper.lltypesystem import llmemory, rffi
from rpython.jit.backend.detect_cpu import getcpuclass 
from rpython.jit.codewriter import longlong
import ctypes
import py

ACTUAL_CPU = getcpuclass()
if not hasattr(ACTUAL_CPU, 'NUM_REGS'):
    py.test.skip('unsupported CPU')

class FakeCPU:
    rtyper = None
    supports_floats = True
    NUM_REGS = ACTUAL_CPU.NUM_REGS

    class gc_ll_descr:
        kind = "boehm"

    def fielddescrof(self, STRUCT, name):
        return 42

    def get_fail_descr_from_number(self, num):
        assert num == 0x1C3
        return FakeFailDescr()

class FakeMC:
    def __init__(self):
        self.content = []
    def writechar(self, char):
        self.content.append(ord(char))

class FakeFailDescr:
    def hide(self, cpu):
        return rffi.cast(llmemory.GCREF, 123)

# ____________________________________________________________

class TestRegallocPushPop(object):

    def do_test(self, callback):
        from rpython.jit.backend.x86.regalloc import X86FrameManager
        from rpython.jit.backend.x86.regalloc import X86XMMRegisterManager
        class FakeToken:
            class compiled_loop_token:
                asmmemmgr_blocks = None
        cpu = ACTUAL_CPU(None, None)
        cpu.setup()
        if cpu.HAS_CODEMAP:
            cpu.codemap.setup()
        looptoken = FakeToken()
        asm = cpu.assembler
        asm.setup_once()
        asm.setup(looptoken)
        self.xrm = X86XMMRegisterManager(None, assembler=asm)
        callback(asm)
        asm.mc.RET()
        rawstart = asm.materialize_loop(looptoken)
        #
        F = ctypes.CFUNCTYPE(ctypes.c_long)
        fn = ctypes.cast(rawstart, F)
        res = fn()
        return res

    def test_simple(self):
        def callback(asm):
            asm.mov(imm(42), edx)
            asm.regalloc_push(edx)
            asm.regalloc_pop(eax)
        res = self.do_test(callback)
        assert res == 42

    def test_simple_xmm(self):
        def callback(asm):
            c = ConstFloat(longlong.getfloatstorage(-42.5))
            loc = self.xrm.convert_to_imm(c)
            asm.mov(loc, xmm5)
            asm.regalloc_push(xmm5)
            asm.regalloc_pop(xmm0)
            asm.mc.CVTTSD2SI(eax, xmm0)
        res = self.do_test(callback)
        assert res == -42

    def test_xmm_pushes_8_bytes(self):
        def callback(asm):
            asm.regalloc_push(xmm5)
            asm.mc.ADD(esp, imm(8))
        self.do_test(callback)
