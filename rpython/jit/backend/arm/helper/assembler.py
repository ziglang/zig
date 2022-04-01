from __future__ import with_statement
from rpython.jit.backend.arm import conditions as c
from rpython.jit.backend.arm import registers as r
from rpython.jit.backend.arm.codebuilder import InstrBuilder
from rpython.jit.metainterp.history import FLOAT
from rpython.rlib.rarithmetic import r_uint, r_longlong, intmask
from rpython.jit.metainterp.resoperation import rop


def flush_cc(asm, condition, result_loc):
    # After emitting an instruction that leaves a boolean result in
    # a condition code (cc), call this.  In the common case, result_loc
    # will be set to 'fp' by the regalloc, which in this case means
    # "propagate it between this operation and the next guard by keeping
    # it in the cc".  In the uncommon case, result_loc is another
    # register, and we emit a load from the cc into this register.
    assert asm.guard_success_cc == c.cond_none
    if result_loc is r.fp:
        asm.guard_success_cc = condition
    else:
        asm.mc.MOV_ri(result_loc.value, 1, condition)
        asm.mc.MOV_ri(result_loc.value, 0, c.get_opposite_of(condition))


def gen_emit_op_unary_cmp(name, true_cond):
    def f(self, op, arglocs, regalloc, fcond):
        assert fcond is not None
        reg, res = arglocs
        self.mc.CMP_ri(reg.value, 0)
        flush_cc(self, true_cond, res)
        return fcond
    f.__name__ = 'emit_op_%s' % name
    return f

def gen_emit_op_ri(name, opname):
    ri_op = getattr(InstrBuilder, '%s_ri' % opname)
    rr_op = getattr(InstrBuilder, '%s_rr' % opname)
    def f(self, op, arglocs, regalloc, fcond):
        assert fcond is not None
        l0, l1, res = arglocs
        if l1.is_imm():
            ri_op(self.mc, res.value, l0.value, imm=l1.value, cond=fcond)
        else:
            rr_op(self.mc, res.value, l0.value, l1.value)
        return fcond
    f.__name__ = 'emit_op_%s' % name
    return f

def gen_emit_cmp_op(name, true_cond):
    def f(self, op, arglocs, regalloc, fcond):
        l0, l1, res = arglocs

        if l1.is_imm():
            self.mc.CMP_ri(l0.value, imm=l1.getint(), cond=fcond)
        else:
            self.mc.CMP_rr(l0.value, l1.value, cond=fcond)
        flush_cc(self, true_cond, res)
        return fcond
    f.__name__ = 'emit_op_%s' % name
    return f

def gen_emit_float_op(name, opname):
    op_rr = getattr(InstrBuilder, opname)
    def f(self, op, arglocs, regalloc, fcond):
        arg1, arg2, result = arglocs
        op_rr(self.mc, result.value, arg1.value, arg2.value)
        return fcond
    f.__name__ = 'emit_op_%s' % name
    return f

def gen_emit_unary_float_op(name, opname):
    op_rr = getattr(InstrBuilder, opname)
    def f(self, op, arglocs, regalloc, fcond):
        arg1, result = arglocs
        op_rr(self.mc, result.value, arg1.value)
        return fcond
    f.__name__ = 'emit_op_%s' % name
    return f

def gen_emit_float_cmp_op(name, true_cond):
    def f(self, op, arglocs, regalloc, fcond):
        arg1, arg2, res = arglocs
        self.mc.VCMP(arg1.value, arg2.value)
        self.mc.VMRS(cond=fcond)
        flush_cc(self, true_cond, res)
        return fcond
    f.__name__ = 'emit_op_%s' % name
    return f


class saved_registers(object):
    def __init__(self, cb, regs_to_save, vfp_regs_to_save=None):
        self.cb = cb
        if vfp_regs_to_save is None:
            vfp_regs_to_save = []
        self.regs = regs_to_save
        self.vfp_regs = vfp_regs_to_save

    def __enter__(self):
        if len(self.regs) > 0:
            self.cb.PUSH([r.value for r in self.regs])
        if len(self.vfp_regs) > 0:
            self.cb.VPUSH([r.value for r in self.vfp_regs])

    def __exit__(self, *args):
        if len(self.vfp_regs) > 0:
            self.cb.VPOP([r.value for r in self.vfp_regs])
        if len(self.regs) > 0:
            self.cb.POP([r.value for r in self.regs])

def count_reg_args(args):
    reg_args = 0
    words = 0
    count = 0
    for x in range(min(len(args), 4)):
        if args[x].type == FLOAT:
            words += 2
            if count % 2 != 0:
                words += 1
                count = 0
        else:
            count += 1
            words += 1
        reg_args += 1
        if words > 4:
            reg_args = x
            break
    return reg_args
