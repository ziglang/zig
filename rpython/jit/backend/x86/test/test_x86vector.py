import py
from rpython.jit.backend.x86.regloc import *
from rpython.jit.backend.llsupport.regalloc import Lifetime
from rpython.jit.backend.x86.regalloc import (RegAlloc,
        X86FrameManager, X86XMMRegisterManager, X86RegisterManager)
from rpython.jit.backend.x86.vector_ext import TempVector
from rpython.jit.backend.x86.test import test_basic
from rpython.jit.backend.x86.test.test_assembler import \
        (TestRegallocPushPop as BaseTestAssembler)
from rpython.jit.metainterp.test import test_zvector
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.backend.detect_cpu import getcpuclass

class TestBasic(test_basic.Jit386Mixin, test_zvector.VectorizeTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_basic.py
    def setup_method(self, method):
        clazz = self.CPUClass
        def init(*args, **kwargs):
            cpu = clazz(*args, **kwargs)
            # > 95% can be executed, thus let's cheat here a little
            cpu.supports_guard_gc_type = True
            return cpu
        self.CPUClass = init

    def supports_vector_ext(self):
        return self.CPUClass.vector_extension

    def test_list_vectorize(self):
        pass # needs support_guard_gc_type, disable for now

    enable_opts = 'intbounds:rewrite:virtualize:string:earlyforce:pure:heap:unroll'

@py.test.fixture
def regalloc(request):
    from rpython.jit.backend.x86.regalloc import X86FrameManager
    from rpython.jit.backend.x86.regalloc import X86XMMRegisterManager
    class FakeToken:
        class compiled_loop_token:
            asmmemmgr_blocks = None
    cpu = getcpuclass()(None, None)
    cpu.setup()
    if cpu.HAS_CODEMAP:
        cpu.codemap.setup()
    looptoken = FakeToken()
    asm = cpu.assembler
    asm.setup_once()
    asm.setup(looptoken)
    regalloc = RegAlloc(asm)
    regalloc.fm = fm = X86FrameManager(cpu.get_baseofs_of_frame_field())
    regalloc.rm = X86RegisterManager({}, frame_manager = fm, assembler = asm)
    regalloc.xrm = X86XMMRegisterManager({}, frame_manager = fm, assembler = asm)
    request.cls.asm = asm
    request.cls.regalloc = regalloc



class TestAssembler(BaseTestAssembler):

    def imm_4_int32(self, a, b, c, d):
        adr = self.xrm.assembler.datablockwrapper.malloc_aligned(16, 16)
        ptr = rffi.cast(rffi.CArrayPtr(rffi.INT), adr)
        ptr[0] = rffi.r_int(a)
        ptr[1] = rffi.r_int(b)
        ptr[2] = rffi.r_int(c)
        ptr[3] = rffi.r_int(d)
        return adr

    def test_simple_4_int_load_sum_x86_64(self):
        def callback(asm):
            if asm.mc.WORD != 8:
                py.test.skip()
            adr = self.imm_4_int32(123,543,0,0)
            asm.mc.MOV_ri(r8.value,adr)
            asm.mc.MOVDQU_xm(xmm7.value, (r8.value, 0))
            asm.mc.PADDD_xm(xmm7.value, (r8.value, 0))
            asm.mc.PADDD_xx(xmm7.value, xmm7.value)

            asm.mc.MOV_ri(edx.value, 0x00000000ffffffff)

            asm.mc.MOV_ri(eax.value, 0)
            asm.mc.MOVDQ_rx(ecx.value, xmm7.value)
            asm.mc.AND_rr(ecx.value, edx.value)
            asm.mc.ADD(eax, ecx)

            asm.mc.PSRLDQ_xi(xmm7.value, 4)
            asm.mc.MOVDQ_rx(ecx.value, xmm7.value)
            asm.mc.AND_rr(ecx.value, edx.value)
            asm.mc.ADD(eax, ecx)
        res = self.do_test(callback)
        assert res == 123*4 + 543*4

    def test_vector_store(self):
        def callback(asm):
            addr = self.imm_4_int32(11,12,13,14)
            asm.mov(ImmedLoc(addr), ecx)
            asm.mc.MOVDQU_xm(xmm6.value, (ecx.value,0))
            asm.mc.PADDD_xm(xmm6.value, (ecx.value,0))
            asm.mc.MOVDQU(AddressLoc(ecx,ImmedLoc(0)), xmm6)
            asm.mc.MOVDQU(xmm6, AddressLoc(ecx,ImmedLoc(0)))
            asm.mc.MOVDQ_rx(eax.value, xmm6.value)

        res = self.do_test(callback) & 0xffffffff
        assert res == 22


    def test_vector_store_aligned(self):
        def callback(asm):
            addr = self.imm_4_int32(11,12,13,14)
            asm.mov(ImmedLoc(addr), ecx)
            asm.mc.MOVDQA(xmm6, AddressLoc(ecx,ImmedLoc(0)))
            asm.mc.PADDD_xm(xmm6.value, (ecx.value,0))
            asm.mc.MOVDQA(AddressLoc(ecx,ImmedLoc(0)), xmm6)
            asm.mc.MOVDQA(xmm6, AddressLoc(ecx,ImmedLoc(0)))
            asm.mc.MOVDQ_rx(eax.value, xmm6.value)

        res = self.do_test(callback) & 0xffffffff
        assert res == 22

    def test_enforce_var(self, regalloc):
        arg = TempVector('f')
        args = []
        self.regalloc.fm.bindings[arg] = FrameLoc(0, 64, 'f')
        reg = self.regalloc.enforce_var_in_vector_reg(arg, args, xmm0)
        assert reg is xmm0

    def test_enforce_var_xmm0_forbidden(self, regalloc):
        arg = TempVector('f')
        arg1 = TempVector('f')
        args = [arg1]
        xrm = self.regalloc.xrm
        xrm.reg_bindings[arg1] = xmm0
        fr = xrm.free_regs
        xrm.free_regs = [r for r in fr if r is not xmm0]
        self.regalloc.fm.bindings[arg] = FrameLoc(0, 64, 'f')
        reg = self.regalloc.enforce_var_in_vector_reg(arg, args, xmm0)
        assert reg is xmm0
        assert len(xrm.reg_bindings) == 2
        assert xrm.reg_bindings[arg] == xmm0
        assert xrm.reg_bindings[arg1] != xmm0

    def test_enforce_var_spill(self, regalloc):
        arg = TempVector('f')
        arg1 = TempVector('f')
        arg2 = TempVector('f')
        args = []
        xrm = self.regalloc.xrm
        xrm.reg_bindings[arg1] = xmm0
        xrm.reg_bindings[arg2] = xmm1
        xrm.longevity[arg1] = Lifetime(0,1)
        xrm.longevity[arg2] = Lifetime(0,2)
        xrm.longevity[arg] = Lifetime(0,3)
        fr = xrm.free_regs
        xrm.free_regs = []
        self.regalloc.fm.bindings[arg] = FrameLoc(0, 64, 'f')
        self.regalloc.fm.bindings[arg2] = FrameLoc(0, 72, 'f')
        reg = self.regalloc.enforce_var_in_vector_reg(arg, args, xmm0)
        assert reg is xmm0
        assert len(xrm.reg_bindings) == 2
        assert xrm.reg_bindings[arg] == xmm0
        assert xrm.reg_bindings[arg1] == xmm1
        assert arg2 not in xrm.reg_bindings


