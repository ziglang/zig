from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.codewriter import longlong
from rpython.jit.metainterp import compile
from rpython.jit.metainterp.history import (
    Const, ConstInt, make_hashable_int, ConstFloat, CONST_NULL)
from rpython.jit.metainterp.optimize import InvalidLoop
from rpython.jit.metainterp.optimizeopt.optimizer import (
    Optimization, OptimizationResult, REMOVED, CONST_0, CONST_1)
from rpython.jit.metainterp.optimizeopt.info import (
    INFO_NONNULL, INFO_NULL, getptrinfo)
from rpython.jit.metainterp.optimizeopt.util import (
    _findall, make_dispatcher_method, get_box_replacement)
from rpython.jit.metainterp.resoperation import (
    rop, ResOperation, opclasses, OpHelpers)
from rpython.rlib.rarithmetic import highest_bit
import math


class CallLoopinvariantOptimizationResult(OptimizationResult):
    def __init__(self, opt, op, old_op):
        OptimizationResult.__init__(self, opt, op)
        self.old_op = old_op

    def callback(self):
        self._callback(self.op, self.old_op)

    def _callback(self, op, old_op):
        key = make_hashable_int(op.getarg(0).getint())
        self.opt.loop_invariant_producer[key] = self.opt.optimizer.getlastop()
        self.opt.loop_invariant_results[key] = old_op


class OptRewrite(Optimization):
    """Rewrite operations into equivalent, cheaper operations.
       This includes already executed operations and constants.
    """
    def __init__(self):
        self.loop_invariant_results = {}
        self.loop_invariant_producer = {}

    def setup(self):
        self.optimizer.optrewrite = self

    def produce_potential_short_preamble_ops(self, sb):
        for op in self.loop_invariant_producer.values():
            sb.add_loopinvariant_op(op)

    def propagate_forward(self, op):
        if opclasses[op.opnum].boolinverse != -1 or opclasses[op.opnum].boolreflex != -1:
            if self.find_rewritable_bool(op):
                return

        return dispatch_opt(self, op)

    def propagate_postprocess(self, op):
        return dispatch_postprocess(self, op)

    def try_boolinvers(self, op, targs):
        oldop = self.get_pure_result(targs)
        if oldop is not None:
            b = self.getintbound(oldop)
            if b.equal(1):
                self.make_constant(op, CONST_0)
                return True
            elif b.equal(0):
                self.make_constant(op, CONST_1)
                return True
        return False

    def find_rewritable_bool(self, op):
        oldopnum = op.boolinverse
        arg0 = op.getarg(0)
        arg1 = op.getarg(1)
        if oldopnum != -1:
            top = ResOperation(oldopnum, [arg0, arg1])
            if self.try_boolinvers(op, top):
                return True

        oldopnum = op.boolreflex  # FIXME: add INT_ADD, INT_MUL
        if oldopnum != -1:
            top = ResOperation(oldopnum, [arg1, arg0])
            oldop = self.get_pure_result(top)
            if oldop is not None:
                self.optimizer.make_equal_to(op, oldop)
                return True

        if op.boolreflex == -1:
            return False
        oldopnum = opclasses[op.boolreflex].boolinverse
        if oldopnum != -1:
            top = ResOperation(oldopnum, [arg1, arg0])
            if self.try_boolinvers(op, top):
                return True

        return False

    def optimize_INT_AND(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        if b1.equal(0) or b2.equal(0):
            self.make_constant_int(op, 0)
            return
        elif b2.is_constant():
            val = b2.lower
            if val == -1 or (b1.bounded() and b1.lower >= 0
                                          and b1.upper <= val & ~(val + 1)):
                self.make_equal_to(op, op.getarg(0))
                return
        elif b1.is_constant():
            val = b1.lower
            if val == -1 or (b2.bounded() and b2.lower >= 0
                                          and b2.upper <= val & ~(val + 1)):
                self.make_equal_to(op, op.getarg(1))
                return

        return self.emit(op)

    def optimize_INT_OR(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))
        if b1.equal(0):
            self.make_equal_to(op, op.getarg(1))
        elif b2.equal(0):
            self.make_equal_to(op, op.getarg(0))
        else:
            return self.emit(op)

    def optimize_INT_SUB(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        arg2 = get_box_replacement(op.getarg(1))
        b1 = self.getintbound(arg1)
        b2 = self.getintbound(arg2)
        if b2.equal(0):
            self.make_equal_to(op, arg1)
        elif b1.equal(0):
            op = self.replace_op_with(op, rop.INT_NEG, args=[arg2])
            return self.emit(op)
        elif arg1 == arg2:
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def postprocess_INT_SUB(self, op):
        import sys
        arg0 = op.getarg(0)
        arg1 = op.getarg(1)
        self.optimizer.pure_from_args(rop.INT_ADD, [op, arg1], arg0)
        self.optimizer.pure_from_args(rop.INT_SUB, [arg0, op], arg1)
        if isinstance(arg1, ConstInt):
            # invert the constant
            i1 = arg1.getint()
            if i1 == -sys.maxint - 1:
                return
            inv_arg1 = ConstInt(-i1)
            self.optimizer.pure_from_args(rop.INT_ADD, [arg0, inv_arg1], op)
            self.optimizer.pure_from_args(rop.INT_ADD, [inv_arg1, arg0], op)
            self.optimizer.pure_from_args(rop.INT_SUB, [op, inv_arg1], arg0)
            self.optimizer.pure_from_args(rop.INT_SUB, [op, arg0], inv_arg1)

    def optimize_INT_ADD(self, op):
        if self.is_raw_ptr(op.getarg(0)) or self.is_raw_ptr(op.getarg(1)):
            return self.emit(op)
        arg1 = get_box_replacement(op.getarg(0))
        b1 = self.getintbound(arg1)
        arg2 = get_box_replacement(op.getarg(1))
        b2 = self.getintbound(arg2)

        # If one side of the op is 0 the result is the other side.
        if b1.equal(0):
            self.make_equal_to(op, arg2)
        elif b2.equal(0):
            self.make_equal_to(op, arg1)
        else:
            return self.emit(op)

    def postprocess_INT_ADD(self, op):
        import sys
        arg0 = op.getarg(0)
        arg1 = op.getarg(1)
        self.optimizer.pure_from_args(rop.INT_ADD, [arg1, arg0], op)
        # Synthesize the reverse op for optimize_default to reuse
        self.optimizer.pure_from_args(rop.INT_SUB, [op, arg1], arg0)
        self.optimizer.pure_from_args(rop.INT_SUB, [op, arg0], arg1)
        if isinstance(arg0, ConstInt):
            # invert the constant
            i0 = arg0.getint()
            if i0 == -sys.maxint - 1:
                return
            inv_arg0 = ConstInt(-i0)
        elif isinstance(arg1, ConstInt):
            # commutative
            i0 = arg1.getint()
            if i0 == -sys.maxint - 1:
                return
            inv_arg0 = ConstInt(-i0)
            arg1 = arg0
        else:
            return
        self.optimizer.pure_from_args(rop.INT_SUB, [arg1, inv_arg0], op)
        self.optimizer.pure_from_args(rop.INT_SUB, [arg1, op], inv_arg0)
        self.optimizer.pure_from_args(rop.INT_ADD, [op, inv_arg0], arg1)
        self.optimizer.pure_from_args(rop.INT_ADD, [inv_arg0, op], arg1)

    def optimize_INT_MUL(self, op):
        arg1 = get_box_replacement(op.getarg(0))
        b1 = self.getintbound(arg1)
        arg2 = get_box_replacement(op.getarg(1))
        b2 = self.getintbound(arg2)

        # If one side of the op is 1 the result is the other side.
        if b1.equal(1):
            self.make_equal_to(op, arg2)
        elif b2.equal(1):
            self.make_equal_to(op, arg1)
        elif b1.equal(0) or b2.equal(0):
            self.make_constant_int(op, 0)
        else:
            for lhs, rhs in [(arg1, arg2), (arg2, arg1)]:
                lh_info = self.getintbound(lhs)
                if lh_info.is_constant():
                    x = lh_info.getint()
                    # x & (x - 1) == 0 is a quick test for power of 2
                    if x & (x - 1) == 0:
                        new_rhs = ConstInt(highest_bit(lh_info.getint()))
                        op = self.replace_op_with(op, rop.INT_LSHIFT, args=[rhs, new_rhs])
                        break
            return self.emit(op)

    def _optimize_CALL_INT_UDIV(self, op):
        b2 = self.getintbound(op.getarg(2))
        if b2.is_constant() and b2.getint() == 1:
            self.make_equal_to(op, op.getarg(1))
            self.last_emitted_operation = REMOVED
            return True
        return False

    def optimize_INT_LSHIFT(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))

        if b2.equal(0):
            self.make_equal_to(op, op.getarg(0))
        elif b1.equal(0):
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def optimize_INT_RSHIFT(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))

        if b2.equal(0):
            self.make_equal_to(op, op.getarg(0))
        elif b1.equal(0):
            self.make_constant_int(op, 0)
        else:
            return self.emit(op)

    def optimize_INT_XOR(self, op):
        b1 = self.getintbound(op.getarg(0))
        b2 = self.getintbound(op.getarg(1))

        if b1.equal(0):
            self.make_equal_to(op, op.getarg(1))
        elif b2.equal(0):
            self.make_equal_to(op, op.getarg(0))
        else:
            return self.emit(op)

    def postprocess_INT_INVERT(self, op):
        self.optimizer.pure_from_args(rop.INT_INVERT, [op], op.getarg(0))

    def optimize_FLOAT_MUL(self, op):
        arg1 = op.getarg(0)
        arg2 = op.getarg(1)

        # Constant fold f0 * 1.0 and turn f0 * -1.0 into a FLOAT_NEG, these
        # work in all cases, including NaN and inf
        for lhs, rhs in [(arg1, arg2), (arg2, arg1)]:
            v1 = get_box_replacement(lhs)
            v2 = get_box_replacement(rhs)

            if v1.is_constant():
                if v1.getfloat() == 1.0:
                    self.make_equal_to(op, v2)
                    return
                elif v1.getfloat() == -1.0:
                    newop = self.replace_op_with(op, rop.FLOAT_NEG, args=[rhs])
                    return self.emit(newop)
        return self.emit(op)

    def postprocess_FLOAT_MUL(self, op):
        self.optimizer.pure_from_args(rop.FLOAT_MUL,
                                      [op.getarg(1), op.getarg(0)], op)

    def optimize_FLOAT_TRUEDIV(self, op):
        arg1 = op.getarg(0)
        arg2 = op.getarg(1)
        v2 = get_box_replacement(arg2)

        # replace "x / const" by "x * (1/const)" if possible
        newop = op
        if v2.is_constant():
            divisor = v2.getfloat()
            fraction = math.frexp(divisor)[0]
            # This optimization is valid for powers of two
            # but not for zeroes, some denormals and NaN:
            if fraction == 0.5 or fraction == -0.5:
                reciprocal = 1.0 / divisor
                rfraction = math.frexp(reciprocal)[0]
                if rfraction == 0.5 or rfraction == -0.5:
                    c = ConstFloat(longlong.getfloatstorage(reciprocal))
                    newop = self.replace_op_with(op, rop.FLOAT_MUL,
                                                 args=[arg1, c])
        return self.emit(newop)

    def optimize_FLOAT_NEG(self, op):
        return self.emit(op)

    def postprocess_FLOAT_NEG(self, op):
        self.optimizer.pure_from_args(rop.FLOAT_NEG, [op], op.getarg(0))

    def optimize_guard(self, op, constbox):
        box = op.getarg(0)
        if box.type == 'i':
            intbound = self.getintbound(box)
            if intbound.is_constant():
                if not intbound.getint() == constbox.getint():
                    r = self.optimizer.metainterp_sd.logger_ops.repr_of_resop(
                        op)
                    raise InvalidLoop('A GUARD_{VALUE,TRUE,FALSE} (%s) '
                                      'was proven to always fail' % r)
                return
        elif box.type == 'r':
            box = get_box_replacement(box)
            if box.is_constant():
                if not box.same_constant(constbox):
                    r = self.optimizer.metainterp_sd.logger_ops.repr_of_resop(
                        op)
                    raise InvalidLoop('A GUARD_VALUE (%s) '
                                      'was proven to always fail' % r)
                return

        return self.emit(op)

    def optimize_GUARD_ISNULL(self, op):
        info = getptrinfo(op.getarg(0))
        if info is not None:
            if info.is_null():
                return
            elif info.is_nonnull():
                r = self.optimizer.metainterp_sd.logger_ops.repr_of_resop(op)
                raise InvalidLoop('A GUARD_ISNULL (%s) was proven to always '
                                  'fail' % r)
        return self.emit(op)

    def postprocess_GUARD_ISNULL(self, op):
        self.make_constant(op.getarg(0), CONST_NULL)

    def optimize_GUARD_IS_OBJECT(self, op):
        info = getptrinfo(op.getarg(0))
        if info and info.is_constant():
            if info.is_null():
                raise InvalidLoop("A GUARD_IS_OBJECT(NULL) found")
            c = get_box_replacement(op.getarg(0))
            if self.optimizer.cpu.check_is_object(c.getref_base()):
                return
            raise InvalidLoop("A GUARD_IS_OBJECT(not-an-object) found")
        if info is not None:
            if info.is_about_object():
                return
            if info.is_precise():
                raise InvalidLoop()
        return self.emit(op)

    def optimize_GUARD_GC_TYPE(self, op):
        info = getptrinfo(op.getarg(0))
        if info and info.is_constant():
            c = get_box_replacement(op.getarg(0))
            tid = self.optimizer.cpu.get_actual_typeid(c.getref_base())
            if tid != op.getarg(1).getint():
                raise InvalidLoop("wrong GC type ID found on a constant")
            return
        if info is not None and info.get_descr() is not None:
            if info.get_descr().get_type_id() != op.getarg(1).getint():
                raise InvalidLoop("wrong GC types passed around!")
            return
        return self.emit(op)

    def optimize_GUARD_SUBCLASS(self, op):
        info = getptrinfo(op.getarg(0))
        optimizer = self.optimizer
        # must raise 'InvalidLoop' in all cases where 'info' shows the
        # class cannot possibly match (see test_issue2926)
        if info and info.is_constant():
            c = get_box_replacement(op.getarg(0))
            vtable = optimizer.cpu.cls_of_box(c).getint()
            if optimizer._check_subclass(vtable, op.getarg(1).getint()):
                return
            raise InvalidLoop("GUARD_SUBCLASS(const) proven to always fail")
        if info is not None and info.is_about_object():
            known_class = info.get_known_class(optimizer.cpu)
            if known_class:
                # Class of 'info' is exactly 'known_class'.
                # We know statically if the 'guard_subclass' will pass or fail.
                if optimizer._check_subclass(known_class.getint(),
                                             op.getarg(1).getint()):
                    return
                else:
                    raise InvalidLoop(
                        "GUARD_SUBCLASS(known_class) proven to always fail")
            elif info.get_descr() is not None:
                # Class of 'info' is either get_descr() or a subclass of it.
                # We're keeping the 'guard_subclass' at runtime only in the
                # case where get_descr() is some strict parent class of
                # the argument to 'guard_subclass'.
                info_base_descr = info.get_descr().get_vtable()
                if optimizer._check_subclass(info_base_descr,
                                             op.getarg(1).getint()):
                    return    # guard_subclass always passing
                elif optimizer._check_subclass(op.getarg(1).getint(),
                                               info_base_descr):
                    pass      # don't know, must keep the 'guard_subclass'
                else:
                    raise InvalidLoop(
                        "GUARD_SUBCLASS(base_class) proven to always fail")
        return self.emit(op)

    def optimize_GUARD_NONNULL(self, op):
        opinfo = getptrinfo(op.getarg(0))
        if opinfo is not None:
            if opinfo.is_nonnull():
                return
            elif opinfo.is_null():
                r = self.optimizer.metainterp_sd.logger_ops.repr_of_resop(op)
                raise InvalidLoop('A GUARD_NONNULL (%s) was proven to always '
                                  'fail' % r)
        return self.emit(op)

    def postprocess_GUARD_NONNULL(self, op):
        self.make_nonnull(op.getarg(0))
        getptrinfo(op.getarg(0)).mark_last_guard(self.optimizer)

    def optimize_GUARD_VALUE(self, op):
        arg0 = op.getarg(0)
        if arg0.type == 'r':
            info = getptrinfo(arg0)
            if info:
                if info.is_virtual():
                    raise InvalidLoop("promote of a virtual")
                old_guard_op = info.get_last_guard(self.optimizer)
                if old_guard_op is not None:
                    op = self.replace_old_guard_with_guard_value(op, info,
                                                              old_guard_op)
        elif arg0.type == 'f':
            arg0 = get_box_replacement(arg0)
            if arg0.is_constant():
                return
        constbox = op.getarg(1)
        assert isinstance(constbox, Const)
        return self.optimize_guard(op, constbox)

    def postprocess_GUARD_VALUE(self, op):
        box = get_box_replacement(op.getarg(0))
        self.make_constant(box, op.getarg(1))

    def replace_old_guard_with_guard_value(self, op, info, old_guard_op):
        # there already has been a guard_nonnull or guard_class or
        # guard_nonnull_class on this value, which is rather silly.
        # This function replaces the original guard with a
        # guard_value.  Must be careful: doing so is unsafe if the
        # original guard checks for something inconsistent,
        # i.e. different than what it would give if the guard_value
        # passed (this is a rare case, but possible).  If we get
        # inconsistent results in this way, then we must not do the
        # replacement, otherwise we'd put guard_value up there but all
        # intermediate ops might be executed by assuming something
        # different, from the old guard that is now removed...

        c_value = op.getarg(1)
        if not c_value.nonnull():
            raise InvalidLoop('A GUARD_VALUE(..., NULL) follows some other '
                              'guard that it is not NULL')
        previous_classbox = info.get_known_class(self.optimizer.cpu)
        if previous_classbox is not None:
            expected_classbox = self.optimizer.cpu.cls_of_box(c_value)
            assert expected_classbox is not None
            if not previous_classbox.same_constant(
                    expected_classbox):
                r = self.optimizer.metainterp_sd.logger_ops.repr_of_resop(op)
                raise InvalidLoop('A GUARD_VALUE (%s) was proven to '
                                  'always fail' % r)
        if not self.optimizer.can_replace_guards:
            return op
        descr = compile.ResumeGuardDescr()
        op = old_guard_op.copy_and_change(rop.GUARD_VALUE,
                         args=[old_guard_op.getarg(0), op.getarg(1)],
                         descr=descr)
        # Note: we give explicitly a new descr for 'op'; this is why the
        # old descr must not be ResumeAtPositionDescr (checked above).
        # Better-safe-than-sorry but it should never occur: we should
        # not put in short preambles guard_xxx and guard_value
        # on the same box.
        self.optimizer.replace_guard(op, info)
        # to be safe
        info.reset_last_guard_pos()
        return op

    def optimize_GUARD_TRUE(self, op):
        return self.optimize_guard(op, CONST_1)

    def postprocess_GUARD_TRUE(self, op):
        box = get_box_replacement(op.getarg(0))
        box1 = self.optimizer.as_operation(box)
        if box1 is not None and box1.getopnum() == rop.INT_IS_TRUE:
            # we can't use the (current) range analysis for this because
            # "anything but 0" is not a valid range
            self.pure_from_args(rop.INT_IS_ZERO, [box1.getarg(0)], CONST_0)
        self.make_constant(box, CONST_1)

    def optimize_GUARD_FALSE(self, op):
        return self.optimize_guard(op, CONST_0)

    def postprocess_GUARD_FALSE(self, op):
        box = get_box_replacement(op.getarg(0))
        box1 = self.optimizer.as_operation(box)
        if box1 is not None and box1.getopnum() == rop.INT_IS_ZERO:
            # we can't use the (current) range analysis for this because
            # "anything but 0" is not a valid range
            self.pure_from_args(rop.INT_IS_TRUE, [box1.getarg(0)], CONST_1)
        self.make_constant(box, CONST_0)

    def optimize_ASSERT_NOT_NONE(self, op):
        self.make_nonnull(op.getarg(0))

    def optimize_RECORD_EXACT_CLASS(self, op):
        opinfo = getptrinfo(op.getarg(0))
        expectedclassbox = op.getarg(1)
        assert isinstance(expectedclassbox, Const)
        if opinfo is not None:
            realclassbox = opinfo.get_known_class(self.optimizer.cpu)
            if realclassbox is not None:
                assert realclassbox.same_constant(expectedclassbox)
                return
        self.make_constant_class(op.getarg(0), expectedclassbox,
                                 update_last_guard=False)

    def optimize_GUARD_CLASS(self, op):
        expectedclassbox = op.getarg(1)
        info = self.ensure_ptr_info_arg0(op)
        assert isinstance(expectedclassbox, Const)
        realclassbox = info.get_known_class(self.optimizer.cpu)
        if realclassbox is not None:
            if realclassbox.same_constant(expectedclassbox):
                return
            r = self.optimizer.metainterp_sd.logger_ops.repr_of_resop(op)
            raise InvalidLoop('A GUARD_CLASS (%s) was proven to always fail'
                              % r)
        old_guard_op = info.get_last_guard(self.optimizer)
        if old_guard_op and not isinstance(old_guard_op.getdescr(),
                                           compile.ResumeAtPositionDescr):
            # there already has been a guard_nonnull or guard_class or
            # guard_nonnull_class on this value.
            if (self.optimizer.can_replace_guards and
                    old_guard_op.getopnum() == rop.GUARD_NONNULL):
                # it was a guard_nonnull, which we replace with a
                # guard_nonnull_class.
                descr = compile.ResumeGuardDescr()
                op = old_guard_op.copy_and_change(rop.GUARD_NONNULL_CLASS,
                            args=[old_guard_op.getarg(0), op.getarg(1)],
                            descr=descr)
                # Note: we give explicitly a new descr for 'op'; this is why the
                # old descr must not be ResumeAtPositionDescr (checked above).
                # Better-safe-than-sorry but it should never occur: we should
                # not put in short preambles guard_nonnull and guard_class
                # on the same box.
                self.optimizer.replace_guard(op, info)
                return self.emit(op)
        return self.emit(op)

    def postprocess_GUARD_CLASS(self, op):
        expectedclassbox = op.getarg(1)
        info = getptrinfo(op.getarg(0))
        old_guard_op = info.get_last_guard(self.optimizer)
        update_last_guard = not old_guard_op or isinstance(
            old_guard_op.getdescr(), compile.ResumeAtPositionDescr)
        self.make_constant_class(op.getarg(0), expectedclassbox, update_last_guard)

    def optimize_GUARD_NONNULL_CLASS(self, op):
        info = getptrinfo(op.getarg(0))
        if info and info.is_null():
            r = self.optimizer.metainterp_sd.logger_ops.repr_of_resop(op)
            raise InvalidLoop('A GUARD_NONNULL_CLASS (%s) was proven to '
                              'always fail' % r)
        return self.optimize_GUARD_CLASS(op)

    postprocess_GUARD_NONNULL_CLASS = postprocess_GUARD_CLASS

    def optimize_CALL_LOOPINVARIANT_I(self, op):
        arg = op.getarg(0)
        # 'arg' must be a Const, because residual_call in codewriter
        # expects a compile-time constant
        assert isinstance(arg, Const)
        key = make_hashable_int(arg.getint())

        resvalue = self.loop_invariant_results.get(key, None)
        if resvalue is not None:
            resvalue = self.optimizer.force_op_from_preamble(resvalue)
            self.loop_invariant_results[key] = resvalue
            self.make_equal_to(op, resvalue)
            self.last_emitted_operation = REMOVED
            return
        # change the op to be a normal call, from the backend's point of view
        # there is no reason to have a separate operation for this
        newop = self.replace_op_with(op,
                                     OpHelpers.call_for_descr(op.getdescr()))
        return self.emit_result(CallLoopinvariantOptimizationResult(self, newop, op))

    optimize_CALL_LOOPINVARIANT_R = optimize_CALL_LOOPINVARIANT_I
    optimize_CALL_LOOPINVARIANT_F = optimize_CALL_LOOPINVARIANT_I
    optimize_CALL_LOOPINVARIANT_N = optimize_CALL_LOOPINVARIANT_I

    def optimize_COND_CALL(self, op):
        arg = op.getarg(0)
        b = self.getintbound(arg)
        if b.is_constant():
            if b.getint() == 0:
                self.last_emitted_operation = REMOVED
                return
            opnum = OpHelpers.call_for_type(op.type)
            op = op.copy_and_change(opnum, args=op.getarglist()[1:])
        return self.emit(op)

    def optimize_COND_CALL_VALUE_I(self, op):
        # look if we know the nullness of the first argument
        info = self.getnullness(op.getarg(0))
        if info == INFO_NONNULL:
            self.make_equal_to(op, op.getarg(0))
            self.last_emitted_operation = REMOVED
            return
        if info == INFO_NULL:
            opnum = OpHelpers.call_pure_for_type(op.type)
            op = self.replace_op_with(op, opnum, args=op.getarglist()[1:])
        return self.emit(op)
    optimize_COND_CALL_VALUE_R = optimize_COND_CALL_VALUE_I

    def _optimize_nullness(self, op, box, expect_nonnull):
        info = self.getnullness(box)
        if info == INFO_NONNULL:
            self.make_constant_int(op, expect_nonnull)
        elif info == INFO_NULL:
            self.make_constant_int(op, not expect_nonnull)
        else:
            return self.emit(op)

    def optimize_INT_IS_TRUE(self, op):
        if (not self.is_raw_ptr(op.getarg(0)) and
            self.getintbound(op.getarg(0)).is_bool()):
            self.make_equal_to(op, op.getarg(0))
            return
        return self._optimize_nullness(op, op.getarg(0), True)

    def optimize_INT_IS_ZERO(self, op):
        return self._optimize_nullness(op, op.getarg(0), False)

    def _optimize_oois_ooisnot(self, op, expect_isnot, instance):
        arg0 = get_box_replacement(op.getarg(0))
        arg1 = get_box_replacement(op.getarg(1))
        info0 = getptrinfo(arg0)
        info1 = getptrinfo(arg1)
        if info0 and info0.is_virtual():
            if info1 and info1.is_virtual():
                intres = (info0 is info1) ^ expect_isnot
                self.make_constant_int(op, intres)
            else:
                self.make_constant_int(op, expect_isnot)
        elif info1 and info1.is_virtual():
            self.make_constant_int(op, expect_isnot)
        elif info1 and info1.is_null():
            return self._optimize_nullness(op, op.getarg(0), expect_isnot)
        elif info0 and info0.is_null():
            return self._optimize_nullness(op, op.getarg(1), expect_isnot)
        elif arg0 is arg1:
            self.make_constant_int(op, not expect_isnot)
        else:
            if instance:
                if info0 is None:
                    cls0 = None
                else:
                    cls0 = info0.get_known_class(self.optimizer.cpu)
                if cls0 is not None:
                    if info1 is None:
                        cls1 = None
                    else:
                        cls1 = info1.get_known_class(self.optimizer.cpu)
                    if cls1 is not None and not cls0.same_constant(cls1):
                        # cannot be the same object, as we know that their
                        # class is different
                        self.make_constant_int(op, expect_isnot)
                        return
            return self.emit(op)

    def optimize_PTR_EQ(self, op):
        return self._optimize_oois_ooisnot(op, False, False)

    def optimize_PTR_NE(self, op):
        return self._optimize_oois_ooisnot(op, True, False)

    def optimize_INSTANCE_PTR_EQ(self, op):
        arg0 = get_box_replacement(op.getarg(0))
        arg1 = get_box_replacement(op.getarg(1))
        self.pure_from_args(rop.INSTANCE_PTR_EQ, [arg1, arg0], op)
        return self._optimize_oois_ooisnot(op, False, True)

    def optimize_INSTANCE_PTR_NE(self, op):
        arg0 = get_box_replacement(op.getarg(0))
        arg1 = get_box_replacement(op.getarg(1))
        self.pure_from_args(rop.INSTANCE_PTR_NE, [arg1, arg0], op)
        return self._optimize_oois_ooisnot(op, True, True)

    def optimize_CALL_N(self, op):
        # dispatch based on 'oopspecindex' to a method that handles
        # specifically the given oopspec call.  For non-oopspec calls,
        # oopspecindex is just zero.
        effectinfo = op.getdescr().get_extra_info()
        oopspecindex = effectinfo.oopspecindex
        if oopspecindex == EffectInfo.OS_ARRAYCOPY:
            return self._optimize_CALL_ARRAYCOPY(op)
        if oopspecindex == EffectInfo.OS_ARRAYMOVE:
            return self._optimize_CALL_ARRAYMOVE(op)
        return self.emit(op)

    def _optimize_CALL_ARRAYCOPY(self, op):
        if self._optimize_call_arrayop(op, op.getarg(1), op.getarg(2),
                             op.getarg(3), op.getarg(4), op.getarg(5)):
            return None
        return self.emit(op)

    def _optimize_CALL_ARRAYMOVE(self, op):
        array_box = op.getarg(1)
        if self._optimize_call_arrayop(op, array_box, array_box,
                             op.getarg(2), op.getarg(3), op.getarg(4)):
            return None
        return self.emit(op)

    def _optimize_call_arrayop(self, op, source_box, dest_box,
                               source_start_box, dest_start_box, length_box):
        length = self.get_constant_box(length_box)
        if length and length.getint() == 0:
            return True  # 0-length arraycopy or arraymove

        source_info = getptrinfo(source_box)
        dest_info = getptrinfo(dest_box)
        source_start_box = self.get_constant_box(source_start_box)
        dest_start_box = self.get_constant_box(dest_start_box)
        extrainfo = op.getdescr().get_extra_info()
        if (source_start_box and dest_start_box
            and length and ((dest_info and dest_info.is_virtual()) or
                            length.getint() <= 8) and
            ((source_info and source_info.is_virtual()) or length.getint() <= 8)
            and extrainfo.single_write_descr_array is not None): #<-sanity check
            source_start = source_start_box.getint()
            dest_start = dest_start_box.getint()
            arraydescr = extrainfo.single_write_descr_array
            if arraydescr.is_array_of_structs():
                return False        # not supported right now

            index_current = 0
            index_delta = +1
            index_stop = length.getint()
            if (source_box is dest_box and        # ARRAYMOVE only
                    source_start < dest_start):   # iterate in reverse order
                index_current = index_stop - 1
                index_delta = -1
                index_stop = -1

            # XXX fish fish fish
            while index_current != index_stop:
                index = index_current
                index_current += index_delta
                assert index >= 0
                if source_info and source_info.is_virtual():
                    val = source_info.getitem(arraydescr, index + source_start)
                else:
                    opnum = OpHelpers.getarrayitem_for_descr(arraydescr)
                    newop = ResOperation(opnum,
                                      [source_box,
                                       ConstInt(index + source_start)],
                                       descr=arraydescr)
                    self.optimizer.send_extra_operation(newop)
                    val = newop
                if val is None:
                    continue
                if dest_info and dest_info.is_virtual():
                    dest_info.setitem(arraydescr, index + dest_start,
                                      get_box_replacement(dest_box),
                                      val)
                else:
                    newop = ResOperation(rop.SETARRAYITEM_GC,
                                         [dest_box,
                                          ConstInt(index + dest_start),
                                          val],
                                         descr=arraydescr)
                    self.optimizer.send_extra_operation(newop)
            return True
        return False

    def optimize_CALL_PURE_I(self, op):
        # this removes a CALL_PURE with all constant arguments.
        # Note that it's also done in pure.py.  For now we need both...
        result = self._can_optimize_call_pure(op)
        if result is not None:
            self.make_constant(op, result)
            self.last_emitted_operation = REMOVED
            return

        # dispatch based on 'oopspecindex' to a method that handles
        # specifically the given oopspec call.
        effectinfo = op.getdescr().get_extra_info()
        oopspecindex = effectinfo.oopspecindex
        if oopspecindex == EffectInfo.OS_INT_UDIV:
            if self._optimize_CALL_INT_UDIV(op):
                return
        elif oopspecindex == EffectInfo.OS_INT_PY_DIV:
            if self._optimize_CALL_INT_PY_DIV(op):
                return
        elif oopspecindex == EffectInfo.OS_INT_PY_MOD:
            if self._optimize_CALL_INT_PY_MOD(op):
                return
        return self.emit(op)
    optimize_CALL_PURE_R = optimize_CALL_PURE_I
    optimize_CALL_PURE_F = optimize_CALL_PURE_I
    optimize_CALL_PURE_N = optimize_CALL_PURE_I

    def optimize_GUARD_NO_EXCEPTION(self, op):
        if self.last_emitted_operation is REMOVED:
            # it was a CALL_PURE or a CALL_LOOPINVARIANT that was killed;
            # so we also kill the following GUARD_NO_EXCEPTION
            return
        return self.emit(op)

    def optimize_GUARD_FUTURE_CONDITION(self, op):
        self.optimizer.notice_guard_future_condition(op)

    def _optimize_CALL_INT_PY_DIV(self, op):
        arg1 = op.getarg(1)
        b1 = self.getintbound(arg1)
        arg2 = op.getarg(2)
        b2 = self.getintbound(arg2)

        if b1.equal(0):
            self.make_constant_int(op, 0)
            self.last_emitted_operation = REMOVED
            return True
        if not b2.is_constant():
            return False
        val = b2.getint()
        if val <= 0:
            return False
        if val == 1:
            self.make_equal_to(op, arg1)
            self.last_emitted_operation = REMOVED
            return True
        elif val & (val - 1) == 0:   # val == 2**shift
            from rpython.jit.metainterp.history import DONT_CHANGE
            op = self.replace_op_with(op, rop.INT_RSHIFT,
                        args=[arg1, ConstInt(highest_bit(val))],
                        descr=DONT_CHANGE)  # <- xxx rename? means "kill"
            self.optimizer.send_extra_operation(op)
            return True
        else:
            from rpython.jit.metainterp.optimizeopt import intdiv
            known_nonneg = b1.known_nonnegative()
            operations = intdiv.division_operations(arg1, val, known_nonneg)
            newop = None
            for newop in operations:
                self.optimizer.send_extra_operation(newop)
            self.make_equal_to(op, newop)
            return True

    def _optimize_CALL_INT_PY_MOD(self, op):
        arg1 = op.getarg(1)
        b1 = self.getintbound(arg1)
        arg2 = op.getarg(2)
        b2 = self.getintbound(arg2)

        if b1.equal(0):
            self.make_constant_int(op, 0)
            self.last_emitted_operation = REMOVED
            return True
        # This is Python's integer division: 'x // (2**shift)' can always
        # be replaced with 'x >> shift', even for negative values of x
        if not b2.is_constant():
            return False
        val = b2.getint()
        if val <= 0:
            return False
        if val == 1:
            self.make_constant_int(op, 0)
            self.last_emitted_operation = REMOVED
            return True
        elif val & (val - 1) == 0:   # val == 2**shift
            from rpython.jit.metainterp.history import DONT_CHANGE
            # x % power-of-two ==> x & (power-of-two - 1)
            # with Python's modulo, this is valid even if 'x' is negative.
            op = self.replace_op_with(op, rop.INT_AND,
                        args=[arg1, ConstInt(val - 1)],
                        descr=DONT_CHANGE)  # <- xxx rename? means "kill"
            self.optimizer.send_extra_operation(op)
            return True
        else:
            from rpython.jit.metainterp.optimizeopt import intdiv
            known_nonneg = b1.known_nonnegative()
            operations = intdiv.modulo_operations(arg1, val, known_nonneg)
            newop = None
            for newop in operations:
                self.optimizer.send_extra_operation(newop)
            self.make_equal_to(op, newop)
            return True

    def optimize_CAST_PTR_TO_INT(self, op):
        self.optimizer.pure_from_args(rop.CAST_INT_TO_PTR, [op], op.getarg(0))
        return self.emit(op)

    def optimize_CAST_INT_TO_PTR(self, op):
        self.optimizer.pure_from_args(rop.CAST_PTR_TO_INT, [op], op.getarg(0))
        return self.emit(op)

    def optimize_CONVERT_FLOAT_BYTES_TO_LONGLONG(self, op):
        self.optimizer.pure_from_args(rop.CONVERT_LONGLONG_BYTES_TO_FLOAT, [op], op.getarg(0))
        return self.emit(op)

    def optimize_CONVERT_LONGLONG_BYTES_TO_FLOAT(self, op):
        self.optimizer.pure_from_args(rop.CONVERT_FLOAT_BYTES_TO_LONGLONG, [op], op.getarg(0))
        return self.emit(op)

    def optimize_SAME_AS_I(self, op):
        self.make_equal_to(op, op.getarg(0))
    optimize_SAME_AS_R = optimize_SAME_AS_I
    optimize_SAME_AS_F = optimize_SAME_AS_I

    def serialize_optrewrite(self, available_boxes):
        res = []
        for i, box in self.loop_invariant_results.iteritems():
            box = get_box_replacement(box)
            if box in available_boxes:
                res.append((i, box))
        return res

    def deserialize_optrewrite(self, tups):
        for i, box in tups:
            self.loop_invariant_results[i] = box

dispatch_opt = make_dispatcher_method(OptRewrite, 'optimize_',
                                      default=OptRewrite.emit)
optimize_guards = _findall(OptRewrite, 'optimize_', 'GUARD')
dispatch_postprocess = make_dispatcher_method(OptRewrite, 'postprocess_')
