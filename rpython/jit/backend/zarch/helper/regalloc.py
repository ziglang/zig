from rpython.jit.metainterp.history import AbstractValue, ConstInt, FLOAT, Const
from rpython.jit.backend.zarch.locations import imm, addr
from rpython.jit.backend.llsupport.regalloc import TempVar
import rpython.jit.backend.zarch.registers as r

def check_imm_value(value, lower_bound=-2**15, upper_bound=2**15-1):
    return lower_bound <= value <= upper_bound

def check_imm(arg, lower_bound=-2**15, upper_bound=2**15-1):
    if isinstance(arg, ConstInt):
        i = arg.getint()
        return lower_bound <= i <= upper_bound
    return False

def check_imm32(arg):
    return check_imm(arg, -2**31, 2**31-1)

def check_imm20(arg):
    return check_imm(arg, -2**19, 2**19-1)

def prepare_int_add(self, op):
    a0 = op.getarg(0)
    a1 = op.getarg(1)
    if a0.is_constant():
        a0, a1 = a1, a0
    if check_imm32(a1):
        l1 = imm(a1.getint())
    else:
        l1 = self.ensure_reg_or_pool(a1)
    l0 = self.force_result_in_reg(op, a0)
    return [l0, l1]

def prepare_int_mul(self, op):
    a0 = op.getarg(0)
    a1 = op.getarg(1)
    if a0.is_constant():
        a0, a1 = a1, a0
    if check_imm32(a1):
        l1 = imm(a1.getint())
    else:
        l1 = self.ensure_reg_or_pool(a1)
    l0 = self.force_result_in_reg(op, a0)
    return [l0, l1]

def prepare_int_mul_ovf(self, op):
    a0 = op.getarg(0)
    a1 = op.getarg(1)
    if a0.is_constant():
        a0, a1 = a1, a0
    if check_imm32(a1):
        l1 = imm(a1.getint())
    else:
        l1 = self.ensure_reg_or_pool(a1)
    lr,lq = self.rm.ensure_even_odd_pair(a0, op, bind_first=False)
    return [lr, lq, l1]

def generate_div_mod(modulus):
    def f(self, op):
        a0 = op.getarg(0)
        a1 = op.getarg(1)
        l1 = self.ensure_reg(a1)
        if isinstance(a0, Const):
            loc = self.ensure_reg_or_pool(a0)
            lr,lq = self.rm.ensure_even_odd_pair(a0, op,
                                bind_first=modulus, must_exist=False,
                                move_regs=False)
            self.assembler.regalloc_mov(loc, lq)
        else:
            lr,lq = self.rm.ensure_even_odd_pair(a0, op, bind_first=modulus)
        return [lr, lq, l1]
    return f

prepare_int_div = generate_div_mod(False)
prepare_int_mod = generate_div_mod(True)

def prepare_int_sub(self, op):
    a0 = op.getarg(0)
    a1 = op.getarg(1)
    # sub is not commotative, thus cannot swap operands
    l0 = self.ensure_reg(a0)
    l1 = self.ensure_reg(a1)
    res = self.force_allocate_reg(op)
    return [res, l0, l1]

def prepare_int_logic(self, op):
    a0 = op.getarg(0)
    a1 = op.getarg(1)
    if a0.is_constant():
        a0, a1 = a1, a0
    l1 = self.ensure_reg(a1)
    l0 = self.force_result_in_reg(op, a0)
    return [l0, l1]

def prepare_int_shift(self, op):
    a0 = op.getarg(0)
    a1 = op.getarg(1)
    if isinstance(a1, ConstInt):
        # note that the shift value is stored
        # in the addr part of the instruction
        l1 = addr(a1.getint())
    else:
        tmp = self.rm.ensure_reg(a1)
        l1 = addr(0, tmp)
    l0 = self.ensure_reg(a0)
    lr = self.force_allocate_reg(op)
    return [lr, l0, l1]

def generate_cmp_op(signed=True):
    def prepare_cmp_op(self, op):
        a0 = op.getarg(0)
        a1 = op.getarg(1)
        invert = imm(0)
        l0 = self.ensure_reg(a0)
        if signed and check_imm32(a1):
            l1 = imm(a1.getint())
        else:
            l1 = self.ensure_reg(a1)
        res = self.force_allocate_reg_or_cc(op)
        return [l0, l1, res, invert]
    return prepare_cmp_op

def prepare_float_cmp_op(self, op):
    l0 = self.ensure_reg(op.getarg(0))
    l1 = self.ensure_reg(op.getarg(1))
    res = self.force_allocate_reg_or_cc(op)
    return [l0, l1, res]

def prepare_binary_op(self, op):
    a0 = op.getarg(0)
    a1 = op.getarg(1)
    l0 = self.ensure_reg(a0)
    l1 = self.ensure_reg(a1)
    self.force_result_in_reg(op, a0)
    return [l0, l1]

def generate_prepare_float_binary_op(allow_swap=False):
    def prepare_float_binary_op(self, op):
        a0 = op.getarg(0)
        a1 = op.getarg(1)
        if allow_swap:
            if isinstance(a0, Const):
                a0,a1 = a1,a0
        l1 = self.ensure_reg(a1)
        l0 = self.force_result_in_reg(op, a0)
        return [l0, l1]
    return prepare_float_binary_op

def prepare_unary_cmp(self, op):
    l0 = self.ensure_reg(op.getarg(0))
    res = self.force_allocate_reg_or_cc(op)
    return [l0, res]

def prepare_unary_op(self, op):
    res = self.force_result_in_reg(op, op.getarg(0))
    return [res,]

def prepare_same_as(self, op):
    a0 = op.getarg(0)
    l0 = self.ensure_reg(a0)
    res = self.force_allocate_reg(op)
    return [l0, res]
