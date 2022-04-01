import py
from rpython.jit.backend.zarch.pool import LiteralPool, PoolOverflow
from rpython.jit.metainterp.history import (AbstractFailDescr,
         AbstractDescr, BasicFailDescr, BasicFinalDescr, JitCellToken,
         TargetToken, ConstInt, ConstPtr, Const, ConstFloat)
from rpython.jit.metainterp.resoperation import (ResOperation, rop,
         InputArgInt)
from rpython.jit.backend.zarch.codebuilder import InstrBuilder
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.jit.backend.zarch.helper.regalloc import check_imm32
from rpython.jit.backend.zarch.assembler import AssemblerZARCH
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.tool.oparser import parse

class FakeAsm(object):
    def write_i64(self, val):
        pass

class TestPoolZARCH(object):
    def setup_class(self):
        self.calldescr = None

    def setup_method(self, name):
        self.pool = LiteralPool()
        self.asm = FakeAsm()
        self.asm.mc = FakeAsm()
        self.cpu = getcpuclass()(None, None)
        self.cpu.setup_once()

    def ensure_can_hold(self, opnum, args, descr=None):
        op = ResOperation(opnum, args, descr=descr)
        self.pool.ensure_can_hold_constants(self.asm, op)

    def const_in_pool(self, c):
        try:
            self.pool.get_offset(c)
            return True
        except KeyError:
            return False

    def test_constant_in_call_malloc(self):
        c = ConstPtr(rffi.cast(llmemory.GCREF, 0xdeadbeef1234))
        self.ensure_can_hold(rop.COND_CALL, [c], descr=self.calldescr)
        assert self.const_in_pool(c)
        assert self.const_in_pool(ConstPtr(rffi.cast(llmemory.GCREF, 0xdeadbeef1234)))

    @py.test.mark.parametrize('opnum',
            [rop.INT_ADD, rop.INT_SUB, rop.INT_MUL])
    def test_constants_arith(self, opnum):
        for c1 in [ConstInt(1), ConstInt(2**44), InputArgInt(1)]:
            for c2 in [InputArgInt(1), ConstInt(-2**33), ConstInt(2**55)]:
                self.ensure_can_hold(opnum, [c1,c2])
                if c1.is_constant() and not -2**31 <= c1.getint() <= 2**31-1:
                    assert self.const_in_pool(c1)
                if c2.is_constant() and not -2**31 <= c1.getint() <= 2**31-1:
                    assert self.const_in_pool(c2)

    def test_pool_overflow(self):
        self.pool.size = (2**19-1) - 8
        self.pool.allocate_slot(8)
        assert self.pool.size == 2**19-1
        with py.test.raises(PoolOverflow) as of:
            self.pool.allocate_slot(8)
