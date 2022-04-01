import sys
from rpython.jit.metainterp.history import ConstInt
from rpython.jit.metainterp.optimize import InvalidLoop
from rpython.jit.metainterp.optimizeopt.intutils import IntBound
from rpython.jit.metainterp.optimizeopt.optimizer import (Optimization, CONST_1,
    CONST_0)
from rpython.jit.metainterp.optimizeopt.util import (
    make_dispatcher_method, get_box_replacement)
from .info import getptrinfo
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.metainterp.optimizeopt import vstring
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.rlib.rarithmetic import intmask

def get_integer_min(is_unsigned, byte_size):
    if is_unsigned:
        return 0
    else:
        return -(1 << ((byte_size << 3) - 1))


def get_integer_max(is_unsigned, byte_size):
    if is_unsigned:
        return (1 << (byte_size << 3)) - 1
    else:
        return (1 << ((byte_size << 3) - 1)) - 1



class OptIntBounds(Optimization):
    """Keeps track of the bounds placed on integers by guards and remove
       redundant guards"""

    def propagate_forward(self, op):
        return dispatch_opt(self, op)

    def propagate_postprocess(self, op):
        return dispatch_postprocess(self, op)

    def propagate_bounds_backward(self, box):
        # FIXME: This takes care of the instruction where box is the result
        #        but the bounds produced by all instructions where box is
        #        an argument might also be tighten
        b = self.getintbound(box)
        if b.is_constant():
            self.make_constant_int(box, b.getint())

        box1 = self.optimizer.as_operation(box)
        if box1 is not None:
            dispatch_bounds_ops(self, box1)

    def _optimize_guard_true_false_value(self, op):
        return self.emit(op)

    def _postprocess_guard_true_false_value(self, op):
        if op.getarg(0).type == 'i':
            self.propagate_bounds_backward(op.getarg(0))

    optimize_GUARD_TRUE = _optimize_guard_true_false_value
    optimize_GUARD_FALSE = _optimize_guard_true_false_value
    optimize_GUARD_VALUE = _optimize_guard_true_false_value

    postprocess_GUARD_TRUE = _postprocess_guard_true_false_value
    postprocess_GUARD_FALSE = _postprocess_guard_true_false_value
    postprocess_GUARD_VALUE = _postprocess_guard_true_false_value

    def optimize_INT_OR_or_XOR(self, op):
        v1 = get_box_replacement(op.getarg(0))
        v2 = get_box_replacement(op.getarg(1))
        if v1 is v2:
            if op.getopnum() == rop.INT_OR:
                self.make_equal_to(op, v1)
            else:
                self.make_constant_int(op, 0)
            return None
        return self.emit(op)

    def postprocess_INT_OR_or_XOR(self, op):
        v1 = get_box_replacement(op.getarg(0))
        b1 = self.getintbound(v1)
        v2 = get_box_replacement(op.getarg(1))
        b2 = self.getintbound(v2)
        b = b1.or_bound(b2)
        self.getintbound(op).intersect(b)

    optimize_INT_OR = optimize_INT_OR_or_XOR
    optimize_INT_XOR = optimize_INT_OR_or_XOR

    postprocess_INT_OR = postprocess_INT_OR_or_XOR
    postprocess_INT_XOR = postprocess_INT_OR_or_XOR

    def optimize_INT_AND(self, op):
        return self.emit(op)

    def postprocess_INT_AND(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        b = b1.and_bound(b2)
        self.getintbound(op).intersect(b)

    def optimize_INT_SUB(self, op):
        return self.emit(op)

    def postprocess_INT_SUB(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        b = b1.sub_bound(b2)
        if b.bounded():
            self.getintbound(op).intersect(b)

    def optimize_INT_ADD(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        if self.is_raw_ptr(arg1) or self.is_raw_ptr(arg2):
            return self.emit(op)
        v1 = self.getintbound(arg1)
        v2 = self.getintbound(arg2)

        # Optimize for addition chains in code "b = a + 1; c = b + 1" by
        # detecting the int_add chain, and swapping with "b = a + 1;
        # c = a + 2". If b is not used elsewhere, the backend eliminates
        # it.

        # either v1 or v2 can be a constant, swap the arguments around if
        # v1 is the constant
        if v1.is_constant():
            arg1, arg2 = arg2, arg1
            v1, v2 = v2, v1
        # if both are constant, the pure optimization will deal with it
        if v2.is_constant() and not v1.is_constant():
            arg1 = self.optimizer.as_operation(arg1)
            if arg1 is not None:
                if arg1.getopnum() == rop.INT_ADD:
                    prod_arg1 = get_box_replacement(arg1.getarg(0))
                    prod_arg2 = get_box_replacement(arg1.getarg(1))
                    prod_v1 = self.getintbound(prod_arg1)
                    prod_v2 = self.getintbound(prod_arg2)

                    # same thing here: prod_v1 or prod_v2 can be a
                    # constant
                    if prod_v1.is_constant():
                        prod_arg1, prod_arg2 = prod_arg2, prod_arg1
                        prod_v1, prod_v2 = prod_v2, prod_v1
                    if prod_v2.is_constant():
                        sum = intmask(arg2.getint() + prod_arg2.getint())
                        arg1 = prod_arg1
                        arg2 = ConstInt(sum)
                        op = self.replace_op_with(op, rop.INT_ADD, args=[arg1, arg2])

        return self.emit(op)

    def postprocess_INT_ADD(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        r = self.getintbound(op)
        b = b1.add_bound(b2)
        # NB: the result only gets its bound updated if b has an upper and a
        # lower bound. This is important, to do the right thing in the presence
        # of overflow. Example:
        # y = x + 1 where x >= 0
        # here it's tempting to give a bound of y >= 1, but that would be
        # wrong, due to wraparound
        if b.bounded():
            r.intersect(b)

    def optimize_INT_MUL(self, op):
        return self.emit(op)

    def postprocess_INT_MUL(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        r = self.getintbound(op)
        b = b1.mul_bound(b2)
        if b.bounded():
            r.intersect(b)

    def optimize_CALL_PURE_I(self, op):
        return self.emit(op)

    def postprocess_CALL_PURE_I(self, op):
        # dispatch based on 'oopspecindex' to a method that handles
        # specifically the given oopspec call.
        effectinfo = op.getdescr().get_extra_info()
        oopspecindex = effectinfo.oopspecindex
        if oopspecindex == EffectInfo.OS_INT_PY_DIV:
            self.post_call_INT_PY_DIV(op)
        elif oopspecindex == EffectInfo.OS_INT_PY_MOD:
            self.post_call_INT_PY_MOD(op)

    def post_call_INT_PY_DIV(self, op):
        b1 = self.getintbound(op.getarg(1))
        b2 = self.getintbound(op.getarg(2))
        r = self.getintbound(op)
        r.intersect(b1.py_div_bound(b2))

    def post_call_INT_PY_MOD(self, op):
        b1 = self.getintbound(op.getarg(1))
        b2 = self.getintbound(op.getarg(2))
        r = self.getintbound(op)
        r.intersect(b1.mod_bound(b2))

    def optimize_INT_LSHIFT(self, op):
        return self.emit(op)

    def postprocess_INT_LSHIFT(self, op):
        arg0 = get_box_replacement(op.getarg(0))
        b1 = self.getintbound(arg0)
        arg1 = get_box_replacement(op.getarg(1))
        b2 = self.getintbound(arg1)
        r = self.getintbound(op)
        b = b1.lshift_bound(b2)
        r.intersect(b)
        # intbound.lshift_bound checks for an overflow and if the
        # lshift can be proven not to overflow sets b.has_upper and
        # b.has_lower
        if b.bounded():
            # Synthesize the reverse op for optimize_default to reuse
            self.pure_from_args(rop.INT_RSHIFT,
                                [op, arg1], arg0)

    def optimize_INT_RSHIFT(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        b = b1.rshift_bound(b2)
        if b.is_constant():
            # constant result (likely 0, for rshifts that kill all bits)
            self.make_constant_int(op, b.lower)
            return None
        return self.emit(op)

    def postprocess_INT_RSHIFT(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        b = b1.rshift_bound(b2)
        r = self.getintbound(op)
        r.intersect(b)

    def optimize_GUARD_NO_OVERFLOW(self, op):
        lastop = self.last_emitted_operation
        if lastop is not None:
            opnum = lastop.getopnum()
            args = lastop.getarglist()
            result = lastop
            # If the INT_xxx_OVF was replaced with INT_xxx or removed
            # completely, then we can kill the GUARD_NO_OVERFLOW.
            if (opnum != rop.INT_ADD_OVF and
                opnum != rop.INT_SUB_OVF and
                opnum != rop.INT_MUL_OVF):
                return
            # Else, synthesize the non overflowing op for optimize_default to
            # reuse, as well as the reverse op
            elif opnum == rop.INT_ADD_OVF:
                #self.pure(rop.INT_ADD, args[:], result)
                self.pure_from_args(rop.INT_SUB, [result, args[1]], args[0])
                self.pure_from_args(rop.INT_SUB, [result, args[0]], args[1])
            elif opnum == rop.INT_SUB_OVF:
                #self.pure(rop.INT_SUB, args[:], result)
                self.pure_from_args(rop.INT_ADD, [result, args[1]], args[0])
                self.pure_from_args(rop.INT_SUB, [args[0], result], args[1])
            #elif opnum == rop.INT_MUL_OVF:
            #    self.pure(rop.INT_MUL, args[:], result)
            return self.emit(op)

    def optimize_GUARD_OVERFLOW(self, op):
        # If INT_xxx_OVF was replaced by INT_xxx, *but* we still see
        # GUARD_OVERFLOW, then the loop is invalid.
        lastop = self.last_emitted_operation
        if lastop is None:
            return # e.g. beginning of the loop
        opnum = lastop.getopnum()
        if opnum not in (rop.INT_ADD_OVF, rop.INT_SUB_OVF, rop.INT_MUL_OVF):
            raise InvalidLoop('An INT_xxx_OVF was proven not to overflow but' +
                              'guarded with GUARD_OVERFLOW')

        return self.emit(op)

    def optimize_INT_ADD_OVF(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        resbound = b1.add_bound(b2)
        if resbound.bounded():
            # Transform into INT_ADD.  The following guard will be killed
            # by optimize_GUARD_NO_OVERFLOW; if we see instead an
            # optimize_GUARD_OVERFLOW, then InvalidLoop.

            # NB: this case also takes care of int_add_ovf with 0 as on of the
            # arguments: the result will be bounded, and then the optimization
            # for int_add with 0 as argument will remove the op.
            op = self.replace_op_with(op, rop.INT_ADD)
        return self.emit(op)

    def postprocess_INT_ADD_OVF(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        resbound = b1.add_bound(b2)
        r = self.getintbound(op)
        r.intersect(resbound)

    def optimize_INT_SUB_OVF(self, op):
        arg0 = get_box_replacement(op.getarg(0))
        arg1 = get_box_replacement(op.getarg(1))
        b0 = self.getintbound(arg0)
        b1 = self.getintbound(arg1)
        if arg0.same_box(arg1):
            self.make_constant_int(op, 0)
            return None
        resbound = b0.sub_bound(b1)
        if resbound.bounded():
            # this case takes care of int_sub_ovf(x, 0) as well
            op = self.replace_op_with(op, rop.INT_SUB)
        return self.emit(op)

    def postprocess_INT_SUB_OVF(self, op):
        arg0 = get_box_replacement(op.getarg(0))
        arg1 = get_box_replacement(op.getarg(1))
        b0 = self.getintbound(arg0)
        b1 = self.getintbound(arg1)
        resbound = b0.sub_bound(b1)
        r = self.getintbound(op)
        r.intersect(resbound)

    def optimize_INT_MUL_OVF(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        resbound = b1.mul_bound(b2)
        if resbound.bounded():
            # this case also takes care of multiplication with 0 and 1
            op = self.replace_op_with(op, rop.INT_MUL)
        return self.emit(op)

    def postprocess_INT_MUL_OVF(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        resbound = b1.mul_bound(b2)
        r = self.getintbound(op)
        r.intersect(resbound)

    def optimize_INT_LT(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b1.known_lt(b2):
            self.make_constant_int(op, 1)
        elif b1.known_ge(b2) or arg1 is arg2:
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def optimize_INT_GT(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b1.known_gt(b2):
            self.make_constant_int(op, 1)
        elif b1.known_le(b2) or arg1 is arg2:
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def optimize_INT_LE(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b1.known_le(b2) or arg1 is arg2:
            self.make_constant_int(op, 1)
        elif b1.known_gt(b2):
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def optimize_INT_GE(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b1.known_ge(b2) or arg1 is arg2:
            self.make_constant_int(op, 1)
        elif b1.known_lt(b2):
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    # The optimize_UINT_xx functions are disabled.  They work, but the
    # resulting PyPy is subtly broken.  This is probably because we only
    # have INT_ADD/INT_SUB, not the unsigned version, and the logic here
    # assumes that they are non-overflowing signed arithmetic.  That's
    # wrong, and they get too small intervals.  That's usually not a
    # problem, but it can definitely be a problem if it's followed by
    # one of the UINT_* comparisons.
    def DISABLED_optimize_UINT_LT(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b1.known_nonnegative() and b1.known_lt(b2):
            self.make_constant_int(op, 1)
        elif b2.known_nonnegative() and b1.known_ge(b2):
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def DISABLED_optimize_UINT_LE(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b1.known_nonnegative() and b1.known_le(b2):
            self.make_constant_int(op, 1)
        elif b2.known_nonnegative() and b1.known_gt(b2):
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def DISABLED_optimize_UINT_GT(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b2.known_nonnegative() and b1.known_gt(b2):
            self.make_constant_int(op, 1)
        elif b1.known_nonnegative() and b1.known_le(b2):
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def DISABLED_optimize_UINT_GE(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b2.known_nonnegative() and b1.known_ge(b2):
            self.make_constant_int(op, 1)
        elif b1.known_nonnegative() and b1.known_lt(b2):
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def optimize_INT_EQ(self, op):
        arg0 = get_box_replacement(op.getarg(0))
        b1 = self.getintbound(arg0)
        arg1 = get_box_replacement(op.getarg(1))
        b2 = self.getintbound(arg1)
        if b1.known_gt(b2):
            self.make_constant_int(op, 0)
        elif b1.known_lt(b2):
            self.make_constant_int(op, 0)
        elif arg0.same_box(arg1):
            self.make_constant_int(op, 1)
        else:
            return self.emit(op)

    def optimize_INT_NE(self, op):
        arg0 = get_box_replacement(op.getarg(0))
        b1 = self.getintbound(arg0)
        arg1 = get_box_replacement(op.getarg(1))
        b2 = self.getintbound(arg1)
        if b1.known_gt(b2):
            self.make_constant_int(op, 1)
        elif b1.known_lt(b2):
            self.make_constant_int(op, 1)
        elif arg0 is arg1:
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def optimize_INT_FORCE_GE_ZERO(self, op):
        b = self.getintbound(op.getarg(0))
        if b.known_nonnegative():
            self.make_equal_to(op, op.getarg(0))
        else:
            return self.emit(op)

    def optimize_INT_SIGNEXT(self, op):
        b = self.getintbound(op.getarg(0))
        numbits = op.getarg(1).getint() * 8
        start = -(1 << (numbits - 1))
        stop = 1 << (numbits - 1)
        bounds = IntBound(start, stop - 1)
        if bounds.contains_bound(b):
            self.make_equal_to(op, op.getarg(0))
        else:
            return self.emit(op)

    def postprocess_INT_SIGNEXT(self, op):
        numbits = op.getarg(1).getint() * 8
        start = -(1 << (numbits - 1))
        stop = 1 << (numbits - 1)
        bres = self.getintbound(op)
        bres.intersect_const(start, stop - 1)

    def postprocess_INT_INVERT(self, op):
        b = self.getintbound(op.getarg(0))
        bounds = b.invert_bound()
        bres = self.getintbound(op)
        bres.intersect(bounds)

    def propagate_bounds_INT_INVERT(self, op):
        b = self.getintbound(op.getarg(0))
        bres = self.getintbound(op)
        bounds = bres.invert_bound()
        b.intersect(bounds)

    def propagate_bounds_INT_NEG(self, op):
        b = self.getintbound(op.getarg(0))
        bres = self.getintbound(op)
        bounds = bres.neg_bound()
        b.intersect(bounds)

    def postprocess_INT_NEG(self, op):
        b = self.getintbound(op.getarg(0))
        bounds = b.neg_bound()
        bres = self.getintbound(op)
        bres.intersect(bounds)

    def optimize_ARRAYLEN_GC(self, op):
        return self.emit(op)

    def postprocess_ARRAYLEN_GC(self, op):
        array = self.ensure_ptr_info_arg0(op)
        self.optimizer.setintbound(op, array.getlenbound(None))

    def optimize_STRLEN(self, op):
        return self.emit(op)

    def postprocess_STRLEN(self, op):
        self.make_nonnull_str(op.getarg(0), vstring.mode_string)
        array = getptrinfo(op.getarg(0))
        self.optimizer.setintbound(op, array.getlenbound(vstring.mode_string))

    def optimize_UNICODELEN(self, op):
        return self.emit(op)

    def postprocess_UNICODELEN(self, op):
        self.make_nonnull_str(op.getarg(0), vstring.mode_unicode)
        array = getptrinfo(op.getarg(0))
        self.optimizer.setintbound(op, array.getlenbound(vstring.mode_unicode))

    def optimize_STRGETITEM(self, op):
        return self.emit(op)

    def postprocess_STRGETITEM(self, op):
        v1 = self.getintbound(op)
        v2 = getptrinfo(op.getarg(0))
        intbound = self.getintbound(op.getarg(1))
        if intbound.has_lower and v2 is not None:
            lenbound = v2.getlenbound(vstring.mode_string)
            if lenbound is not None:
                lenbound.make_gt_const(intbound.lower)
        v1.intersect_const(0, 255)

    def optimize_GETFIELD_RAW_I(self, op):
        return self.emit(op)

    def postprocess_GETFIELD_RAW_I(self, op):
        descr = op.getdescr()
        if descr.is_integer_bounded():
            b1 = self.getintbound(op)
            b1.intersect_const(descr.get_integer_min(), descr.get_integer_max())

    optimize_GETFIELD_RAW_F = optimize_GETFIELD_RAW_I
    optimize_GETFIELD_RAW_R = optimize_GETFIELD_RAW_I
    optimize_GETFIELD_GC_I = optimize_GETFIELD_RAW_I
    optimize_GETFIELD_GC_R = optimize_GETFIELD_RAW_I
    optimize_GETFIELD_GC_F = optimize_GETFIELD_RAW_I

    postprocess_GETFIELD_RAW_F = postprocess_GETFIELD_RAW_I
    postprocess_GETFIELD_RAW_R = postprocess_GETFIELD_RAW_I
    postprocess_GETFIELD_GC_I = postprocess_GETFIELD_RAW_I
    postprocess_GETFIELD_GC_R = postprocess_GETFIELD_RAW_I
    postprocess_GETFIELD_GC_F = postprocess_GETFIELD_RAW_I

    optimize_GETINTERIORFIELD_GC_I = optimize_GETFIELD_RAW_I
    optimize_GETINTERIORFIELD_GC_R = optimize_GETFIELD_RAW_I
    optimize_GETINTERIORFIELD_GC_F = optimize_GETFIELD_RAW_I

    postprocess_GETINTERIORFIELD_GC_I = postprocess_GETFIELD_RAW_I
    postprocess_GETINTERIORFIELD_GC_R = postprocess_GETFIELD_RAW_I
    postprocess_GETINTERIORFIELD_GC_F = postprocess_GETFIELD_RAW_I

    def optimize_GETARRAYITEM_RAW_I(self, op):
        return self.emit(op)

    def postprocess_GETARRAYITEM_RAW_I(self, op):
        descr = op.getdescr()
        if descr and descr.is_item_integer_bounded():
            intbound = self.getintbound(op)
            intbound.intersect_const(descr.get_item_integer_min(), descr.get_item_integer_max())

    optimize_GETARRAYITEM_RAW_F = optimize_GETARRAYITEM_RAW_I
    optimize_GETARRAYITEM_GC_I = optimize_GETARRAYITEM_RAW_I
    optimize_GETARRAYITEM_GC_F = optimize_GETARRAYITEM_RAW_I
    optimize_GETARRAYITEM_GC_R = optimize_GETARRAYITEM_RAW_I

    postprocess_GETARRAYITEM_RAW_F = postprocess_GETARRAYITEM_RAW_I
    postprocess_GETARRAYITEM_GC_I = postprocess_GETARRAYITEM_RAW_I
    postprocess_GETARRAYITEM_GC_F = postprocess_GETARRAYITEM_RAW_I
    postprocess_GETARRAYITEM_GC_R = postprocess_GETARRAYITEM_RAW_I

    def optimize_UNICODEGETITEM(self, op):
        return self.emit(op)

    def postprocess_UNICODEGETITEM(self, op):
        b1 = self.getintbound(op)
        b1.make_ge_const(0)
        v2 = getptrinfo(op.getarg(0))
        intbound = self.getintbound(op.getarg(1))
        if intbound.has_lower and v2 is not None:
            lenbound = v2.getlenbound(vstring.mode_unicode)
            if lenbound is not None:
                lenbound.make_gt_const(intbound.lower)

    def make_int_lt(self, box1, box2):
        b1 = self.getintbound(box1)
        b2 = self.getintbound(box2)
        if b1.make_lt(b2):
            self.propagate_bounds_backward(box1)
        if b2.make_gt(b1):
            self.propagate_bounds_backward(box2)

    def make_int_le(self, box1, box2):
        b1 = self.getintbound(box1)
        b2 = self.getintbound(box2)
        if b1.make_le(b2):
            self.propagate_bounds_backward(box1)
        if b2.make_ge(b1):
            self.propagate_bounds_backward(box2)

    def make_int_gt(self, box1, box2):
        self.make_int_lt(box2, box1)

    def make_int_ge(self, box1, box2):
        self.make_int_le(box2, box1)

    def propagate_bounds_INT_LT(self, op):
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == 1:
                self.make_int_lt(op.getarg(0), op.getarg(1))
            else:
                assert r.getint() == 0
                self.make_int_ge(op.getarg(0), op.getarg(1))

    def propagate_bounds_INT_GT(self, op):
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == 1:
                self.make_int_gt(op.getarg(0), op.getarg(1))
            else:
                assert r.getint() == 0
                self.make_int_le(op.getarg(0), op.getarg(1))

    def propagate_bounds_INT_LE(self, op):
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == 1:
                self.make_int_le(op.getarg(0), op.getarg(1))
            else:
                assert r.getint() == 0
                self.make_int_gt(op.getarg(0), op.getarg(1))

    def propagate_bounds_INT_GE(self, op):
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == 1:
                self.make_int_ge(op.getarg(0), op.getarg(1))
            else:
                assert r.getint() == 0
                self.make_int_lt(op.getarg(0), op.getarg(1))

    def make_uint_lt(self, box1, box2):
        b2 = self.getintbound(box2)
        if b2.known_nonnegative:
            b1 = self.getintbound(box1)
            if b1.make_lt(b2) | b1.make_ge_const(0):
                self.propagate_bounds_backward(box1)
            #if b2.make_gt(b1):
            # ^^ probably correct but I fail to see a case where it is helpful
            #    self.propagate_bounds_backward(box2)
        # elif box1 is known to be < 0... let's ignore that case

    def make_uint_le(self, box1, box2):
        b2 = self.getintbound(box2)
        if b2.known_nonnegative:
            b1 = self.getintbound(box1)
            if b1.make_le(b2) | b1.make_ge_const(0):
                self.propagate_bounds_backward(box1)
            #if b2.make_ge(b1):
            # ^^ probably correct but I fail to see a case where it is helpful
            #    self.propagate_bounds_backward(box2)
        # elif box1 is known to be < 0... let's ignore that case

    def make_uint_gt(self, box1, box2):
        self.make_uint_lt(box2, box1)

    def make_uint_ge(self, box1, box2):
        self.make_uint_le(box2, box1)

    # see DISABLED_optimize_UINT_xx above.
    def DISABLED_propagate_bounds_UINT_LT(self, op):
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == 1:
                self.make_uint_lt(op.getarg(0), op.getarg(1))
            else:
                assert r.getint() == 0
                self.make_uint_ge(op.getarg(0), op.getarg(1))

    def DISABLED_propagate_bounds_UINT_GT(self, op):
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == 1:
                self.make_uint_gt(op.getarg(0), op.getarg(1))
            else:
                assert r.getint() == 0
                self.make_uint_le(op.getarg(0), op.getarg(1))

    def DISABLED_propagate_bounds_UINT_LE(self, op):
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == 1:
                self.make_uint_le(op.getarg(0), op.getarg(1))
            else:
                assert r.getint() == 0
                self.make_uint_gt(op.getarg(0), op.getarg(1))

    def DISABLED_propagate_bounds_UINT_GE(self, op):
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == 1:
                self.make_uint_ge(op.getarg(0), op.getarg(1))
            else:
                assert r.getint() == 0
                self.make_uint_lt(op.getarg(0), op.getarg(1))

    def propagate_bounds_INT_EQ(self, op):
        r = self.getintbound(op)
        if r.equal(1):
            b1 = self.getintbound(op.getarg(0))
            b2 = self.getintbound(op.getarg(1))
            if b1.intersect(b2):
                self.propagate_bounds_backward(op.getarg(0))
            if b2.intersect(b1):
                self.propagate_bounds_backward(op.getarg(1))

    def propagate_bounds_INT_NE(self, op):
        r = self.getintbound(op)
        if r.equal(0):
            b1 = self.getintbound(op.getarg(0))
            b2 = self.getintbound(op.getarg(1))
            if b1.intersect(b2):
                self.propagate_bounds_backward(op.getarg(0))
            if b2.intersect(b1):
                self.propagate_bounds_backward(op.getarg(1))

    def _propagate_int_is_true_or_zero(self, op, valnonzero, valzero):
        if self.is_raw_ptr(op.getarg(0)):
            return
        r = self.getintbound(op)
        if r.is_constant():
            if r.getint() == valnonzero:
                b1 = self.getintbound(op.getarg(0))
                if b1.known_nonnegative():
                    b1.make_gt_const(0)
                    self.propagate_bounds_backward(op.getarg(0))
            elif r.getint() == valzero:
                self.make_constant_int(op.getarg(0), 0)
                self.propagate_bounds_backward(op.getarg(0))

    def propagate_bounds_INT_IS_TRUE(self, op):
        self._propagate_int_is_true_or_zero(op, 1, 0)

    def propagate_bounds_INT_IS_ZERO(self, op):
        self._propagate_int_is_true_or_zero(op, 0, 1)

    def propagate_bounds_INT_ADD(self, op):
        if self.is_raw_ptr(op.getarg(0)) or self.is_raw_ptr(op.getarg(1)):
            return
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        r = self.getintbound(op)
        b = r.sub_bound(b2)
        if b1.intersect(b):
            self.propagate_bounds_backward(op.getarg(0))
        b = r.sub_bound(b1)
        if b2.intersect(b):
            self.propagate_bounds_backward(op.getarg(1))

    def propagate_bounds_INT_SUB(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        r = self.getintbound(op)
        b = r.add_bound(b2)
        if b1.intersect(b):
            self.propagate_bounds_backward(op.getarg(0))
        b = r.sub_bound(b1).mul(-1)
        if b2.intersect(b):
            self.propagate_bounds_backward(op.getarg(1))

    def propagate_bounds_INT_MUL(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        r = self.getintbound(op)
        b = r.py_div_bound(b2)
        if b1.intersect(b):
            self.propagate_bounds_backward(op.getarg(0))
        b = r.py_div_bound(b1)
        if b2.intersect(b):
            self.propagate_bounds_backward(op.getarg(1))

    def propagate_bounds_INT_LSHIFT(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        r = self.getintbound(op)
        b = r.rshift_bound(b2)
        if b1.intersect(b):
            self.propagate_bounds_backward(op.getarg(0))

    propagate_bounds_INT_ADD_OVF = propagate_bounds_INT_ADD
    propagate_bounds_INT_SUB_OVF = propagate_bounds_INT_SUB
    propagate_bounds_INT_MUL_OVF = propagate_bounds_INT_MUL


dispatch_opt = make_dispatcher_method(OptIntBounds, 'optimize_',
                                      default=OptIntBounds.emit)
dispatch_bounds_ops = make_dispatcher_method(OptIntBounds, 'propagate_bounds_')
dispatch_postprocess = make_dispatcher_method(OptIntBounds, 'postprocess_')
