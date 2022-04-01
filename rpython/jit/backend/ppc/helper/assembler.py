import rpython.jit.backend.ppc.condition as c
from rpython.rlib.rarithmetic import intmask
from rpython.jit.backend.ppc.arch import MAX_REG_PARAMS, IS_PPC_32, WORD
from rpython.jit.metainterp.history import FLOAT
from rpython.jit.metainterp.resoperation import rop
import rpython.jit.backend.ppc.register as r
from rpython.rtyper.lltypesystem import rffi, lltype


def flush_cc(asm, condition, result_loc):
    # After emitting an instruction that leaves a boolean result in
    # a condition code (cc), call this.  In the common case, result_loc
    # will be set to SPP by the regalloc, which in this case means
    # "propagate it between this operation and the next guard by keeping
    # it in the cc".  In the uncommon case, result_loc is another
    # register, and we emit a load from the cc into this register.
    assert asm.guard_success_cc == c.cond_none
    if result_loc is r.SPP:
        asm.guard_success_cc = condition
    else:
        # Possibly invert the bit in the CR
        bit, invert = c.encoding[condition]
        assert 0 <= bit <= 3
        if invert == 12:
            pass
        elif invert == 4:
            asm.mc.crnor(bit, bit, bit)
        else:
            assert 0

        resval = result_loc.value
        # move the content of the CR to resval
        asm.mc.mfcr(resval)
        # zero out everything except of the result
        asm.mc.rlwinm(resval, resval, 1 + bit, 31, 31)


def do_emit_cmp_op(self, arglocs, condition, signed, fp):
    l0 = arglocs[0]
    l1 = arglocs[1]
    assert not l0.is_imm()
    # do the comparison
    self.mc.cmp_op(0, l0.value, l1.value,
                   imm=l1.is_imm(), signed=signed, fp=fp)

    # CR bits:
    #     0: LT
    #     1: GT
    #     2: EQ
    #     3: UNordered

    if fp:
        # Support for NaNs: with LE or GE, if one of the operands is a
        # NaN, we get CR=1,0,0,0 (unordered bit only).  We're about to
        # check "not GT" or "not LT", but in case of NaN we want to
        # get the answer False.
        if condition == c.LE:
            self.mc.crnor(1, 1, 3)
            condition = c.GT
        elif condition == c.GE:
            self.mc.crnor(0, 0, 3)
            condition = c.LT

    flush_cc(self, condition, arglocs[2])


def gen_emit_cmp_op(condition, signed=True, fp=False):
    def f(self, op, arglocs, regalloc):
        do_emit_cmp_op(self, arglocs, condition, signed, fp)
    return f

def count_reg_args(args):
    reg_args = 0
    words = 0
    count = 0
    for x in range(min(len(args), MAX_REG_PARAMS)):
        if args[x].type == FLOAT:
            count += 1
            words += 1
        else:
            count += 1
            words += 1
        reg_args += 1
        if words > MAX_REG_PARAMS:
            reg_args = x
            break
    return reg_args

class Saved_Volatiles(object):
    """ used in _gen_leave_jitted_hook_code to save volatile registers
        in ENCODING AREA around calls
    """

    def __init__(self, codebuilder, save_RES=True, save_FLOAT=True):
        self.mc = codebuilder
        self.save_RES = save_RES
        self.save_FLOAT = save_FLOAT
        self.FLOAT_OFFSET = len(r.VOLATILES)

    def __enter__(self):
        """ before a call, volatile registers are saved in ENCODING AREA
        """
        for i, reg in enumerate(r.VOLATILES):
            if not self.save_RES and reg is r.RES:
                continue
            self.mc.store(reg.value, r.SPP.value, i * WORD)
        if self.save_FLOAT:
            for i, reg in enumerate(r.VOLATILES_FLOAT):
                if not self.save_RES and reg is r.f1:
                    continue
                self.mc.stfd(reg.value, r.SPP.value,
                             (i + self.FLOAT_OFFSET) * WORD)

    def __exit__(self, *args):
        """ after call, volatile registers have to be restored
        """
        for i, reg in enumerate(r.VOLATILES):
            if not self.save_RES and reg is r.RES:
                continue
            self.mc.load(reg.value, r.SPP.value, i * WORD)
        if self.save_FLOAT:
            for i, reg in enumerate(r.VOLATILES_FLOAT):
                if not self.save_RES and reg is r.f1:
                    continue
                self.mc.lfd(reg.value, r.SPP.value,
                             (i + self.FLOAT_OFFSET) * WORD)
