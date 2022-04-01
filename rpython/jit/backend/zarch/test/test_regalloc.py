import py
from rpython.jit.metainterp.history import JitCellToken
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.backend.zarch.arch import WORD
from rpython.jit.backend.zarch.regalloc import (ZARCHRegisterManager,
        ZARCHFrameManager)
import rpython.jit.backend.zarch.registers as r
from rpython.jit.backend.llsupport.regalloc import TempVar, NoVariableToSpill
from rpython.jit.tool.oparser import parse

CPU = getcpuclass()

class FakeAssembler(object):
    def __init__(self):
        self.move_count = 0
        self.num_spills = 0
        self.num_spills_to_existing = 0

    def regalloc_mov(self, f, t):
        self.move_count += 1

class FakeRegalloc(ZARCHRegisterManager):
    def __init__(self):
        ZARCHRegisterManager.__init__(self, {}, ZARCHFrameManager(0), FakeAssembler())

    def allocate(self, *regs):
        for reg,var in regs:
            register = r.registers[reg]
            self.reg_bindings[var] = register
            self.free_regs = [fr for fr in self.free_regs if fr is not register]

class TempInt(TempVar):
    type = 'i' 
    def __repr__(self):
        return "<TempInt at %s>" % (id(self),)

def temp_vars(count):
    return [TempInt() for _ in range(count)]

class TestRegalloc(object):
    def setup_method(self, name):
        self.rm = FakeRegalloc()

    def test_all_free(self):
        a,b = temp_vars(2)
        self.rm.force_allocate_reg_pair(a, b, [])
        assert self.rm.reg_bindings[a] == r.r2
        assert self.rm.reg_bindings[b] == r.r3

    def test_cannot_spill_too_many_forbidden_vars(self):
        v = temp_vars(12)
        a, b = v[10], v[11]
        self.rm.frame_manager.bindings[a] = self.rm.frame_manager.loc(a)
        self.rm.frame_manager.bindings[b] = self.rm.frame_manager.loc(b)
        # all registers are allocated
        self.rm.allocate((2,v[0]),(3,v[1]),(4,v[2]),(5,v[3]),
                         (6,v[4]),(7,v[5]),(8,v[6]),(9,v[7]),
                         (10,v[8]),(11,v[9]))
        self.rm.temp_boxes = v[:-2]
        with py.test.raises(AssertionError):
            # assert len(forbidden_vars) <= 8
            self.rm.ensure_even_odd_pair(a, b, bind_first=False)

    def test_all_but_one_forbidden(self):
        a,b,f1,f2,f3,f4,o = temp_vars(7)
        self.rm.allocate((2,f1),(4,f2),(6,f3),(8,f4),(10,o))
        self.rm.force_allocate_reg_pair(a, b, [f1,f2,f3,f4])
        assert self.rm.reg_bindings[a] == r.r10
        assert self.rm.reg_bindings[b] == r.r11

    def test_all_but_one_forbidden_odd(self):
        a,b,f1,f2,f3,f4,f5 = temp_vars(7)
        self.rm.allocate((3,f1),(5,f2),(7,f3),(9,f4),(11,f5))
        self.rm.force_allocate_reg_pair(a, b, [f1,f3,f4,f5])
        assert self.rm.reg_bindings[a] == r.r4
        assert self.rm.reg_bindings[b] == r.r5

    def test_ensure_reg_pair(self):
        a,b,f1 = temp_vars(3)
        self.rm.allocate((4,f1),(2,a))
        self.rm.temp_boxes = [f1]
        re, ro = self.rm.ensure_even_odd_pair(a, b)
        assert re == r.r6
        assert ro == r.r7
        assert re != self.rm.reg_bindings[a]
        assert ro != self.rm.reg_bindings[a]
        assert self.rm.assembler.move_count == 1

    def test_ensure_reg_pair_bind_second(self):
        a,b,f1,f2,f3,f4 = temp_vars(6)
        self.rm.allocate((4,f1),(2,a),(6,f2),(8,f3),(10,f4))
        self.rm.temp_boxes = [f1,f2,f3,f4]
        re, ro = self.rm.ensure_even_odd_pair(a, b, bind_first=False)
        assert re == r.r2
        assert ro == r.r3
        assert ro == self.rm.reg_bindings[b]
        assert a not in self.rm.reg_bindings
        assert self.rm.assembler.move_count == 2

    def test_ensure_pair_fully_allocated_first_forbidden(self):
        v = temp_vars(12)
        a, b = v[10], v[11]
        self.rm.frame_manager.bindings[a] = self.rm.frame_manager.loc(a)
        self.rm.frame_manager.bindings[b] = self.rm.frame_manager.loc(b)
        # all registers are allocated
        self.rm.allocate((2,v[0]),(3,v[1]),(4,v[2]),(5,v[3]),
                         (6,v[4]),(7,v[5]),(8,v[6]),(9,v[7]),
                         (10,v[8]),(11,v[9]))
        self.rm.temp_boxes = [v[0],v[2],v[4],v[6],v[8]]
        e, o = self.rm.ensure_even_odd_pair(a, b, bind_first=False)
        assert e == r.r2
        assert o == r.r3

        self.rm.temp_boxes = [v[0],v[1],v[2],v[4],v[6],v[8]]
        e, o = self.rm.ensure_even_odd_pair(a, b, bind_first=False)
        assert e == r.r2
        assert o == r.r3

def run(inputargs, ops):
    cpu = CPU(None, None)
    cpu.setup_once()
    loop = parse(ops, cpu, namespace=locals())
    looptoken = JitCellToken()
    cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
    deadframe = cpu.execute_token(looptoken, *inputargs)
    return cpu, deadframe

def test_bug_rshift():
    cpu, deadframe = run([9], '''
    [i1]
    i2 = int_add(i1, i1)
    i3 = int_invert(i2)
    i4 = uint_rshift(i1, 3)
    i5 = int_add(i4, i3)
    finish(i5)
    ''')
    assert cpu.get_int_value(deadframe, 0) == (9 >> 3) + (~18)

def test_bug_int_is_true_1():
    cpu, deadframe = run([-10], '''
    [i1]
    i2 = int_mul(i1, i1)
    i3 = int_mul(i2, i1)
    i5 = int_is_true(i2)
    i4 = int_is_zero(i5)
    guard_false(i5) [i4, i3]
    finish(42)
    ''')
    assert cpu.get_int_value(deadframe, 0) == 0
    assert cpu.get_int_value(deadframe, 1) == -1000

