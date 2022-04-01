from rpython.rlib.objectmodel import instantiate
from rpython.jit.backend.arm.assembler import AssemblerARM
from rpython.jit.backend.arm.locations import imm, ConstFloatLoc
from rpython.jit.backend.arm.locations import RegisterLocation, StackLocation
from rpython.jit.backend.arm.locations import VFPRegisterLocation, get_fp_offset
from rpython.jit.backend.arm.locations import RawSPStackLocation
from rpython.jit.backend.arm.registers import lr, ip, fp, vfp_ip, sp
from rpython.jit.backend.arm.conditions import AL
from rpython.jit.backend.arm.arch import WORD
from rpython.jit.metainterp.history import FLOAT
import py


class MockInstr(object):
    def __init__(self, name, *args, **kwargs):
        self.name = name
        self.args = args
        self.kwargs = kwargs

    def __call__(self, *args, **kwargs):
        self.args = args
        self.kwargs = kwargs

    def __repr__(self):
        return "%s %r %r" % (self.name, self.args, self.kwargs)

    __str__ = __repr__

    def __eq__(self, other):
        return (self.__class__ == other.__class__
                and self.name == other.name
                and self.args == other.args
                and self.kwargs == other.kwargs)
mi = MockInstr


# helper method for tests
def r(i):
    return RegisterLocation(i)


def vfp(i):
    return VFPRegisterLocation(i)


def stack(i, **kwargs):
    return StackLocation(i, get_fp_offset(0, i), **kwargs)


def stack_float(i, **kwargs):
    return StackLocation(i, get_fp_offset(0, i + 1), type=FLOAT)


def imm_float(value):
    addr = int(value)  # whatever
    return ConstFloatLoc(addr)

def raw_stack(i):
    return RawSPStackLocation(i)

def raw_stack_float(i):
    return RawSPStackLocation(i, type=FLOAT)


class MockBuilder(object):
    def __init__(self):
        self.instrs = []

    def __getattr__(self, name):
        i = MockInstr(name)
        self.instrs.append(i)
        return i

class MockRegalloc(object):
    def get_free_reg(self):
        return r('helper')

class BaseMovTest(object):
    def setup_method(self, method):
        self.builder = MockBuilder()
        self.asm = instantiate(AssemblerARM)
        self.asm._regalloc = MockRegalloc()
        self.asm.mc = self.builder

    def validate(self, expected):
        result = self.builder.instrs
        assert result == expected

    def mov(self, a, b, expected=None):
        self.asm.regalloc_mov(a, b)
        self.validate(expected)


class TestRegallocMov(BaseMovTest):

    def test_mov_imm_to_reg(self):
        val = imm(123)
        reg = r(7)
        expected = [mi('gen_load_int', 7, 123, cond=AL)]
        self.mov(val, reg, expected)

    def test_mov_large_imm_to_reg(self):
        val = imm(65536)
        reg = r(7)
        expected = [mi('gen_load_int', 7, 65536, cond=AL)]
        self.mov(val, reg, expected)

    def test_mov_imm_to_stacklock(self):
        val = imm(100)
        s = stack(7)
        expected = [
                mi('gen_load_int', lr.value, 100, cond=AL),
                mi('STR_ri', lr.value, fp.value, imm=s.value, cond=AL),
        ]
        self.mov(val, s, expected)

    def test_mov_big_imm_to_stacklock(self):
        val = imm(65536)
        s = stack(7)
        expected = [
                mi('gen_load_int', lr.value, 65536, cond=AL),
                mi('STR_ri', lr.value, fp.value, imm=s.value, cond=AL),
                ]
        self.mov(val, s, expected)

    def test_mov_imm_to_big_stacklock(self):
        val = imm(100)
        s = stack(8191)
        expected = [ mi('gen_load_int', lr.value, 100, cond=AL),
                    mi('gen_load_int', ip.value, s.value, cond=AL),
                    mi('STR_rr', lr.value, fp.value, ip.value, cond=AL),
                    ]
        self.mov(val, s, expected)

    def test_mov_big_imm_to_big_stacklock(self):
        val = imm(65536)
        s = stack(8191)
        expected = [
                    mi('gen_load_int', lr.value, 65536, cond=AL),
                    mi('gen_load_int', ip.value, s.value, cond=AL),
                    mi('STR_rr', lr.value, fp.value, ip.value, cond=AL),
                    ]
        self.mov(val, s, expected)

    def test_mov_reg_to_reg(self):
        r1 = r(1)
        r9 = r(9)
        expected = [mi('MOV_rr', r9.value, r1.value, cond=AL)]
        self.mov(r1, r9, expected)

    def test_mov_reg_to_stack(self):
        s = stack(10)
        r6 = r(6)
        expected = [mi('STR_ri', r6.value, fp.value, imm=s.value, cond=AL)]
        self.mov(r6, s, expected)

    def test_mov_reg_to_big_stackloc(self):
        s = stack(8191)
        r6 = r(6)
        expected = [
                    mi('gen_load_int', ip.value, s.value, cond=AL),
                    mi('STR_rr', r6.value, fp.value, ip.value, cond=AL),
                   ]
        self.mov(r6, s, expected)

    def test_mov_stack_to_reg(self):
        s = stack(10)
        r6 = r(6)
        expected = [mi('LDR_ri', r6.value, fp.value, imm=s.value, cond=AL)]
        self.mov(s, r6, expected)

    def test_mov_big_stackloc_to_reg(self):
        s = stack(8191)
        r6 = r(6)
        expected = [
                   mi('gen_load_int', ip.value, 32940, cond=AL),
                   mi('LDR_rr', r6.value, fp.value, ip.value, cond=AL),
        ]
        self.mov(s, r6, expected)

    def test_mov_float_imm_to_vfp_reg(self):
        f = imm_float(3.5)
        reg = vfp(5)
        expected = [
                    mi('gen_load_int', ip.value, f.value, cond=AL),
                    mi('VLDR', 5, ip.value, imm=0, cond=AL),
                    ]
        self.mov(f, reg, expected)

    def test_mov_vfp_reg_to_vfp_reg(self):
        reg1 = vfp(5)
        reg2 = vfp(14)
        expected = [mi('VMOV_cc', reg2.value, reg1.value, cond=AL)]
        self.mov(reg1, reg2, expected)

    def test_mov_vfp_reg_to_stack(self):
        reg = vfp(7)
        s = stack_float(3)
        expected = [mi('VSTR', reg.value, fp.value, imm=192, cond=AL)]
        self.mov(reg, s, expected)

    def test_mov_vfp_reg_to_large_stackloc(self):
        reg = vfp(7)
        s = stack_float(800)
        expected = [
                    mi('gen_load_int', ip.value, s.value, cond=AL),
                    mi('ADD_rr', ip.value, fp.value, ip.value, cond=AL),
                    mi('VSTR', reg.value, ip.value, cond=AL),
                   ]
        self.mov(reg, s, expected)

    def test_mov_stack_to_vfp_reg(self):
        reg = vfp(7)
        s = stack_float(3)
        expected = [mi('VLDR', reg.value, fp.value, imm=192, cond=AL)]
        self.mov(s, reg, expected)

    def test_mov_big_stackloc_to_vfp_reg(self):
        reg = vfp(7)
        s = stack_float(800)
        expected = [
                    mi('gen_load_int', ip.value, s.value, cond=AL),
                    mi('ADD_rr', ip.value, fp.value, ip.value, cond=AL),
                    mi('VSTR', reg.value, ip.value, cond=AL),
                   ]
        self.mov(reg, s, expected)

    def test_unsopported_cases(self):
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(imm(1), imm(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(imm(1), imm_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(imm(1), vfp(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(imm(1), stack_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(imm_float(1), imm(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(imm_float(1), imm_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(imm_float(1), r(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(imm_float(1), stack(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(r(1), imm(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(r(1), imm_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(r(1), stack_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(r(1), vfp(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack(1), imm(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack(1), imm_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack(1), stack(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack(1), stack_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack(1), vfp(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack_float(1), imm(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack_float(1), imm_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack_float(1), r(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack_float(1), stack(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(stack_float(1), stack_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(vfp(1), imm(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(vfp(1), imm_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(vfp(1), r(2))')
        py.test.raises(AssertionError,
                    'self.asm.regalloc_mov(vfp(1), stack(2))')


class TestMovFromVFPLoc(BaseMovTest):
    def mov(self, a, b, c, expected=None):
        self.asm.mov_from_vfp_loc(a, b, c)
        self.validate(expected)

    def test_from_vfp(self):
        vr = vfp(10)
        r1 = r(1)
        r2 = r(2)
        e = [mi('VMOV_rc', r1.value, r2.value, vr.value, cond=AL)]
        self.mov(vr, r1, r2, e)

    def test_from_vfp_stack(self):
        s = stack_float(4)
        r1 = r(1)
        r2 = r(2)
        e = [
            mi('LDR_ri', r1.value, fp.value, imm=s.value, cond=AL),
            mi('LDR_ri', r2.value, fp.value, imm=s.value + WORD, cond=AL)]
        self.mov(s, r1, r2, e)

    def test_from_big_vfp_stack(self):
        s = stack_float(2049)
        r1 = r(1)
        r2 = r(2)
        e = [
            mi('gen_load_int', ip.value, s.value, cond=AL),
            mi('LDR_rr', r1.value, fp.value, ip.value, cond=AL),
            mi('ADD_ri', ip.value, ip.value, imm=WORD, cond=AL),
            mi('LDR_rr', r2.value, fp.value, ip.value, cond=AL),
            ]
        self.mov(s, r1, r2, e)

    def test_from_imm_float(self):
        i = imm_float(4)
        r1 = r(1)
        r2 = r(2)
        e = [
            mi('gen_load_int', ip.value, i.value, cond=AL),
            mi('LDR_ri', r1.value, ip.value, cond=AL),
            mi('LDR_ri', r2.value, ip.value, imm=4, cond=AL),
            ]
        self.mov(i, r1, r2, e)

    def test_unsupported(self):
        py.test.raises(AssertionError,
                        'self.asm.mov_from_vfp_loc(vfp(1), r(5), r(2))')
        py.test.raises(AssertionError,
                        'self.asm.mov_from_vfp_loc(stack(1), r(1), r(2))')
        py.test.raises(AssertionError,
                        'self.asm.mov_from_vfp_loc(imm(1), r(1), r(2))')
        py.test.raises(AssertionError,
                        'self.asm.mov_from_vfp_loc(r(1), r(1), r(2))')


class TestMoveToVFPLoc(BaseMovTest):
    def mov(self, r1, r2, vfp, expected):
        self.asm.mov_to_vfp_loc(r1, r2, vfp)
        self.validate(expected)

    def mov_to_vfp_reg(self):
        vr = vfp(10)
        r1 = r(1)
        r2 = r(2)
        e = [mi('VMOV_cr', vr.value, r1.value, r2.value, cond=AL)]
        self.mov(vr, r1, r2, e)

    def test_to_vfp_stack(self):
        s = stack_float(4)
        r1 = r(1)
        r2 = r(2)
        e = [
            mi('STR_ri', r1.value, fp.value, imm=s.value, cond=AL),
            mi('STR_ri', r2.value, fp.value, imm=s.value + WORD, cond=AL)]
        self.mov(r1, r2, s, e)

    def test_from_big_vfp_stack(self):
        s = stack_float(2049)
        r1 = r(1)
        r2 = r(2)
        e = [
            mi('gen_load_int', ip.value, s.value, cond=AL),
            mi('STR_rr', r1.value, fp.value, ip.value, cond=AL),
            mi('ADD_ri', ip.value, ip.value, imm=4, cond=AL),
            mi('STR_rr', r2.value, fp.value, ip.value, cond=AL),
            ]
        self.mov(r1, r2, s, e)

    def unsupported(self):
        py.test.raises(AssertionError,
                    'self.asm.mov_from_vfp_loc(r(5), r(2), vfp(4))')
        py.test.raises(AssertionError,
                    'self.asm.mov_from_vfp_loc(r(1), r(2), stack(2))')
        py.test.raises(AssertionError,
                    'self.asm.mov_from_vfp_loc(r(1), r(2), imm(2))')
        py.test.raises(AssertionError,
                    'self.asm.mov_from_vfp_loc(r(1), r(2), imm_float(2))')
        py.test.raises(AssertionError,
                    'self.asm.mov_from_vfp_loc(r(1), r(1), r(2))')


class TestRegallocPush(BaseMovTest):
    def push(self, v, e):
        self.asm.regalloc_push(v)
        self.validate(e)

    def test_push_imm(self):
        i = imm(12)
        e = [mi('gen_load_int', ip.value, 12, cond=AL),
             mi('PUSH', [ip.value], cond=AL)]
        self.push(i, e)

    def test_push_reg(self):
        r7 = r(7)
        e = [mi('PUSH', [r7.value], cond=AL)]
        self.push(r7, e)

    def test_push_imm_float(self):
        f = imm_float(7)
        e = [
            mi('gen_load_int', ip.value, 7, cond=AL),
            mi('VLDR', vfp_ip.value, ip.value, imm=0, cond=AL),
            mi('VPUSH', [vfp_ip.value], cond=AL)
            ]
        self.push(f, e)

    def test_push_stack(self):
        s = stack(7)
        e = [mi('LDR_ri', ip.value, fp.value, imm=s.value, cond=AL),
            mi('PUSH', [ip.value], cond=AL)
            ]
        self.push(s, e)

    def test_push_big_stack(self):
        s = stack(1025)
        e = [
            mi('gen_load_int', lr.value, s.value, cond=AL),
            mi('LDR_rr', ip.value, fp.value, lr.value, cond=AL),
            mi('PUSH', [ip.value], cond=AL)
            ]
        self.push(s, e)

    def test_push_vfp_reg(self):
        v1 = vfp(1)
        e = [mi('VPUSH', [v1.value], cond=AL)]
        self.push(v1, e)

    def test_push_stack_float(self):
        sf = stack_float(4)
        e = [
            mi('VLDR', vfp_ip.value, fp.value, imm=196, cond=AL),
            mi('VPUSH', [vfp_ip.value], cond=AL),
        ]
        self.push(sf, e)

    def test_push_large_stackfloat(self):
        sf = stack_float(1000)
        e = [
            mi('gen_load_int', ip.value, sf.value, cond=AL),
            mi('ADD_rr', ip.value, fp.value, ip.value, cond=AL),
            mi('VLDR', vfp_ip.value, ip.value, cond=AL),
            mi('VPUSH', [vfp_ip.value], cond=AL),
        ]
        self.push(sf, e)


class TestRegallocPop(BaseMovTest):
    def pop(self, loc, e):
        self.asm.regalloc_pop(loc)
        self.validate(e)

    def test_pop_reg(self):
        r1 = r(1)
        e = [mi('POP', [r1.value], cond=AL)]
        self.pop(r1, e)

    def test_pop_vfp_reg(self):
        vr1 = vfp(1)
        e = [mi('VPOP', [vr1.value], cond=AL)]
        self.pop(vr1, e)

    def test_pop_stackloc(self):
        s = stack(12)
        e = [
            mi('POP', [ip.value], cond=AL),
            mi('STR_ri', ip.value, fp.value, imm=s.value, cond=AL)]
        self.pop(s, e)

    def test_pop_big_stackloc(self):
        s = stack(1200)
        e = [
            mi('POP', [ip.value], cond=AL),
            mi('gen_load_int', lr.value, s.value, cond=AL),
            mi('STR_rr', ip.value, fp.value, lr.value, cond=AL),
            ]
        self.pop(s, e)

    def test_pop_float_stackloc(self):
        s = stack_float(12)
        e = [
            mi('VPOP', [vfp_ip.value], cond=AL),
            mi('VSTR', vfp_ip.value, fp.value, imm=s.value, cond=AL),
            ]
        self.pop(s, e)

    def test_pop_big_float_stackloc(self):
        s = stack_float(1200)
        e = [
            mi('VPOP', [vfp_ip.value], cond=AL),
            mi('gen_load_int', ip.value, s.value, cond=AL),
            mi('ADD_rr', ip.value, fp.value, ip.value, cond=AL),
            mi('VSTR', vfp_ip.value, ip.value, cond=AL),
        ]
        self.pop(s, e)

    def test_unsupported(self):
        py.test.raises(AssertionError, 'self.asm.regalloc_pop(imm(1))')
        py.test.raises(AssertionError, 'self.asm.regalloc_pop(imm_float(1))')

class TestRawStackLocs(BaseMovTest):
    def test_unsupported(self):
        py.test.raises(AssertionError, 'self.asm.regalloc_mov(raw_stack(0), imm(1))')
        py.test.raises(AssertionError, 'self.asm.regalloc_mov(raw_stack(0), imm_float(1))')
        py.test.raises(AssertionError, 'self.asm.regalloc_mov(raw_stack(0), vfp(1))')
        py.test.raises(AssertionError, 'self.asm.regalloc_mov(raw_stack(0), stack(1))')
        py.test.raises(AssertionError, 'self.asm.regalloc_mov(raw_stack(0), stack_float(1))')

        py.test.raises(AssertionError, 'self.asm.regalloc_mov(imm_float(1), raw_stack(1))')
        py.test.raises(AssertionError, 'self.asm.regalloc_mov(imm(1), raw_stack_float(1))')

        py.test.raises(AssertionError, 'self.asm.regalloc_mov(vfp(1), raw_stack(1))')
        py.test.raises(AssertionError, 'self.asm.regalloc_mov(r(1), raw_stack_float(1))')

        py.test.raises(AssertionError, 'self.asm.regalloc_mov(stack_float(1), raw_stack(1))')
        py.test.raises(AssertionError, 'self.asm.regalloc_mov(stack(1), raw_stack_float(1))')

    def test_from_imm(self):
        s = raw_stack(1024)
        i = imm(999)
        e = [
            mi('gen_load_int', lr.value, i.value, cond=AL),
            mi('gen_load_int', ip.value, s.value, cond=AL),
            mi('STR_rr', lr.value, sp.value, ip.value, cond=AL),
            ]
        self.mov(i, s, e)

    def test_from_vfp_imm(self):
        s = raw_stack_float(1024)
        i = imm_float(999)
        e = [
            mi('gen_load_int', ip.value, i.value, cond=AL),
            mi('VLDR', vfp_ip.value, ip.value, cond=AL, imm=0),
            mi('gen_load_int', ip.value, s.value, cond=AL),
            mi('ADD_rr', ip.value, sp.value, ip.value, cond=AL),
            mi('VSTR', vfp_ip.value, ip.value, cond=AL),
            ]
        self.mov(i, s, e)

    def test_from_reg(self):
        s = raw_stack(1024)
        reg = r(10)
        e = [mi('gen_load_int', ip.value, s.value, cond=AL),
             mi('STR_rr', reg.value, sp.value, ip.value, cond=AL),
            ]
        self.mov(reg, s, e)

    def test_from_vfp_reg(self):
        s = raw_stack_float(1024)
        reg = vfp(10)
        e = [mi('gen_load_int', ip.value, s.value, cond=AL),
             mi('ADD_rr', ip.value, sp.value, ip.value, cond=AL),
             mi('VSTR', reg.value, ip.value, cond=AL),
            ]
        self.mov(reg, s, e)

    def test_from_stack(self):
        s = raw_stack(1024)
        reg = stack(10)
        e = [mi('LDR_ri', ip.value, fp.value, imm=216, cond=AL),
             mi('gen_load_int', lr.value, s.value, cond=AL),
             mi('STR_rr', ip.value, sp.value, lr.value, cond=AL),
            ]
        self.mov(reg, s, e)

    def test_from_vfp_stack(self):
        s = raw_stack_float(1024)
        reg = stack_float(10)
        e = [mi('VLDR', vfp_ip.value, fp.value, imm=220, cond=AL),
             mi('gen_load_int', ip.value, s.value, cond=AL),
             mi('ADD_rr', ip.value, sp.value, ip.value, cond=AL),
             mi('VSTR', vfp_ip.value, ip.value, cond=AL),
            ]
        self.mov(reg, s, e)
