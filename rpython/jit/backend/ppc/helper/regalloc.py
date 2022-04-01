from rpython.jit.metainterp.history import ConstInt, FLOAT
from rpython.jit.backend.ppc.locations import imm

def check_imm_box(arg, lower_bound=-2**15, upper_bound=2**15-1):
    if isinstance(arg, ConstInt):
        i = arg.getint()
        return lower_bound <= i <= upper_bound
    return False

def _check_imm_arg(i):
    return (-2**15) <= i <= (2**15-1)

def _prepare_cmp_op(signed):
    lower_bound = -2**15 if signed else 0
    upper_bound = 2**15-1 if signed else 2**16-1
    def f(self, op):
        l0 = self.ensure_reg(op.getarg(0))
        a1 = op.getarg(1)
        if check_imm_box(a1, lower_bound, upper_bound):
            l1 = imm(a1.getint())
        else:
            l1 = self.ensure_reg(a1)
        self.free_op_vars()
        res = self.force_allocate_reg_or_cc(op)
        return [l0, l1, res]
    return f
prepare_cmp_op          = _prepare_cmp_op(signed=True)
prepare_cmp_op_unsigned = _prepare_cmp_op(signed=False)

def prepare_unary_cmp(self, op):
    l0 = self.ensure_reg(op.getarg(0))
    l1 = imm(0)
    self.free_op_vars()
    res = self.force_allocate_reg_or_cc(op)
    return [l0, l1, res]

def prepare_float_cmp(self, op):
    l0 = self.ensure_reg(op.getarg(0))
    l1 = self.ensure_reg(op.getarg(1))
    self.free_op_vars()
    res = self.force_allocate_reg_or_cc(op)
    return [l0, l1, res]

def prepare_unary_op(self, op):
    l0 = self.ensure_reg(op.getarg(0))
    self.free_op_vars()
    res = self.force_allocate_reg(op)
    return [l0, res]

def prepare_binary_op(self, op):
    reg1 = self.ensure_reg(op.getarg(0))
    reg2 = self.ensure_reg(op.getarg(1))
    self.free_op_vars()
    res = self.force_allocate_reg(op)
    return [reg1, reg2, res]

def prepare_int_add_or_mul(self, op):
    a0 = op.getarg(0)
    a1 = op.getarg(1)
    if check_imm_box(a0):
        a0, a1 = a1, a0
    l0 = self.ensure_reg(a0)
    if check_imm_box(a1):
        l1 = imm(a1.getint())
    else:
        l1 = self.ensure_reg(a1)
    self.free_op_vars()
    res = self.force_allocate_reg(op)
    return [l0, l1, res]

def prepare_int_sub(self, op):
    l0 = self.ensure_reg(op.getarg(0))
    a1 = op.getarg(1)
    if check_imm_box(a1, -2**15+1, 2**15):
        l1 = imm(a1.getint())
    else:
        l1 = self.ensure_reg(a1)
    self.free_op_vars()
    res = self.force_allocate_reg(op)
    return [l0, l1, res]
