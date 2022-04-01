from rpython.jit.backend.arm import conditions as c
from rpython.jit.backend.arm import registers as r
from rpython.jit.metainterp.history import Const, ConstInt, FLOAT
from rpython.rlib.objectmodel import we_are_translated

VMEM_imm_size=0x3FC
default_imm_size=0xFF

def check_imm_arg(arg, size=default_imm_size, allow_zero=True):
    assert not isinstance(arg, Const)     # because it must be an int :-)
    if not we_are_translated():
        if not isinstance(arg, int):
            import pdb; pdb.set_trace()
    i = arg
    if allow_zero:
        lower_bound = i >= 0
    else:
        lower_bound = i > 0
    return i <= size and lower_bound

def check_imm_box(arg, size=0xFF, allow_zero=True):
    if isinstance(arg, ConstInt):
        return check_imm_arg(arg.getint(), size, allow_zero)
    return False


def prepare_op_ri(name=None, imm_size=0xFF, commutative=True, allow_zero=True):
    def f(self, op, fcond):
        assert fcond is not None
        a0 = op.getarg(0)
        a1 = op.getarg(1)
        boxes = list(op.getarglist())
        imm_a0 = check_imm_box(a0, imm_size, allow_zero=allow_zero)
        imm_a1 = check_imm_box(a1, imm_size, allow_zero=allow_zero)
        if not imm_a0 and imm_a1:
            l0 = self.make_sure_var_in_reg(a0)
            l1 = self.convert_to_imm(a1)
        elif commutative and imm_a0 and not imm_a1:
            l1 = self.convert_to_imm(a0)
            l0 = self.make_sure_var_in_reg(a1, boxes)
        else:
            l0 = self.make_sure_var_in_reg(a0, boxes)
            l1 = self.make_sure_var_in_reg(a1, boxes)
        self.possibly_free_vars_for_op(op)
        self.free_temp_vars()
        res = self.force_allocate_reg(op, boxes)
        return [l0, l1, res]
    if name:
        f.__name__ = name
    return f

def prepare_unary_op(self, op, fcond):
    loc1 = self.make_sure_var_in_reg(op.getarg(0))
    self.possibly_free_vars_for_op(op)
    self.free_temp_vars()
    res = self.force_allocate_reg(op)
    return [loc1, res]

def prepare_two_regs_op(self, op, fcond):
    loc1 = self.make_sure_var_in_reg(op.getarg(0))
    loc2 = self.make_sure_var_in_reg(op.getarg(1))
    self.possibly_free_vars_for_op(op)
    self.free_temp_vars()
    res = self.force_allocate_reg(op)
    return [loc1, loc2, res]

def prepare_float_cmp(self, op, fcond):
    loc1 = self.make_sure_var_in_reg(op.getarg(0))
    loc2 = self.make_sure_var_in_reg(op.getarg(1))
    self.possibly_free_vars_for_op(op)
    self.free_temp_vars()
    res = self.force_allocate_reg_or_cc(op)
    return [loc1, loc2, res]

def prepare_int_cmp(self, op, fcond):
    assert fcond is not None
    boxes = list(op.getarglist())
    arg0, arg1 = boxes
    imm_a1 = check_imm_box(arg1)

    l0 = self.make_sure_var_in_reg(arg0, forbidden_vars=boxes)
    if imm_a1:
        l1 = self.convert_to_imm(arg1)
    else:
        l1 = self.make_sure_var_in_reg(arg1, forbidden_vars=boxes)

    self.possibly_free_vars_for_op(op)
    self.free_temp_vars()
    res = self.force_allocate_reg_or_cc(op)
    return [l0, l1, res]

def prepare_unary_cmp(self, op, fcond):
    assert fcond is not None
    a0 = op.getarg(0)
    assert not isinstance(a0, Const)
    reg = self.make_sure_var_in_reg(a0)
    self.possibly_free_vars_for_op(op)
    res = self.force_allocate_reg_or_cc(op)
    return [reg, res]
