from rpython.jit.metainterp import jitprof, resume, compile
from rpython.jit.metainterp.executor import execute_nonspec_const
from rpython.jit.metainterp.history import (
    Const, ConstInt, CONST_NULL, new_ref_dict)
from rpython.jit.metainterp.optimizeopt.intutils import (
    IntBound, ConstIntBound, MININT, MAXINT, IntUnbounded)
from rpython.jit.metainterp.optimizeopt.util import (
    make_dispatcher_method, get_box_replacement)
from rpython.jit.metainterp.optimizeopt.bridgeopt import (
    deserialize_optimizer_knowledge)
from rpython.jit.metainterp.resoperation import (
    rop, AbstractResOp, GuardResOp, OpHelpers)
from .info import getrawptrinfo, getptrinfo
from rpython.jit.metainterp.optimizeopt import info
from rpython.jit.metainterp.optimize import InvalidLoop
from rpython.rlib.objectmodel import specialize, we_are_translated
from rpython.rtyper import rclass
from rpython.rtyper.lltypesystem import llmemory
from rpython.jit.metainterp.optimize import SpeculativeError




CONST_0      = ConstInt(0)
CONST_1      = ConstInt(1)
CONST_ZERO_FLOAT = Const._new(0.0)
REMOVED = AbstractResOp()

class LoopInfo(object):
    label_op = None

class BasicLoopInfo(LoopInfo):
    def __init__(self, inputargs, quasi_immutable_deps, jump_op):
        self.inputargs = inputargs
        self.jump_op = jump_op
        self.quasi_immutable_deps = quasi_immutable_deps
        self.extra_same_as = []
        self.extra_before_label = []

    def final(self):
        return True

    def post_loop_compilation(self, loop, jitdriver_sd, metainterp, jitcell_token):
        pass


class OptimizationResult(object):
    def __init__(self, opt, op):
        self.opt = opt
        self.op = op

    def callback(self):
        self.opt.propagate_postprocess(self.op)


class Optimization(object):
    next_optimization = None
    potential_extra_ops = None

    def __init__(self):
        pass # make rpython happy

    def propagate_forward(self, op):
        raise NotImplementedError

    def propagate_postprocess(self, op):
        pass

    def emit_operation(self, op):
        assert False, "This should never be called."

    def emit(self, op):
        return self.emit_result(OptimizationResult(self, op))

    def emit_result(self, opt_result):
        self.last_emitted_operation = opt_result.op
        return opt_result

    def emit_extra(self, op, emit=True):
        if emit:
            self.emit(op)
        self.optimizer.send_extra_operation(op, self.next_optimization)

    def getintbound(self, op):
        assert op.type == 'i'
        op = get_box_replacement(op)
        if isinstance(op, ConstInt):
            return ConstIntBound(op.getint())
        fw = op.get_forwarded()
        if fw is not None:
            if isinstance(fw, IntBound):
                return fw
            # rare case: fw might be a RawBufferPtrInfo
            return IntUnbounded()
        assert op.type == 'i'
        intbound = IntBound(MININT, MAXINT)
        op.set_forwarded(intbound)
        return intbound

    def setintbound(self, op, bound):
        assert op.type == 'i'
        op = get_box_replacement(op)
        if op.is_constant():
            return
        cur = op.get_forwarded()
        if cur is not None:
            if isinstance(cur, IntBound):
                cur.intersect(bound)
        else:
            op.set_forwarded(bound)

    def getnullness(self, op):
        if op.type == 'r' or self.is_raw_ptr(op):
            ptrinfo = getptrinfo(op)
            if ptrinfo is None:
                return info.INFO_UNKNOWN
            return ptrinfo.getnullness()
        elif op.type == 'i':
            return self.getintbound(op).getnullness()
        assert False

    def make_constant_class(self, op, class_const, update_last_guard=True):
        op = op.get_box_replacement()
        opinfo = op.get_forwarded()
        if isinstance(opinfo, info.InstancePtrInfo):
            opinfo._known_class = class_const
        else:
            if opinfo is not None:
                last_guard_pos = opinfo.get_last_guard_pos()
            else:
                last_guard_pos = -1
            opinfo = info.InstancePtrInfo(None, class_const)
            opinfo.last_guard_pos = last_guard_pos
            op.set_forwarded(opinfo)
        if update_last_guard:
            opinfo.mark_last_guard(self.optimizer)
        return opinfo

    def is_raw_ptr(self, op):
        fw = get_box_replacement(op).get_forwarded()
        if isinstance(fw, info.AbstractRawPtrInfo):
            return True
        return False

    def replace_op_with(self, op, newopnum, args=None, descr=None):
        return self.optimizer.replace_op_with(op, newopnum, args, descr)

    def ensure_ptr_info_arg0(self, op):
        return self.optimizer.ensure_ptr_info_arg0(op)

    def make_constant(self, box, constbox):
        return self.optimizer.make_constant(box, constbox)

    def make_constant_int(self, box, intconst):
        return self.optimizer.make_constant_int(box, intconst)

    def make_equal_to(self, box, value):
        return self.optimizer.make_equal_to(box, value)

    def make_nonnull(self, op):
        return self.optimizer.make_nonnull(op)

    def make_nonnull_str(self, op, mode):
        return self.optimizer.make_nonnull_str(op, mode)

    def get_constant_box(self, box):
        return self.optimizer.get_constant_box(box)

    def pure(self, opnum, result):
        if self.optimizer.optpure:
            self.optimizer.optpure.pure(opnum, result)

    def pure_from_args(self, opnum, args, op, descr=None):
        if self.optimizer.optpure:
            self.optimizer.optpure.pure_from_args(opnum, args, op, descr)

    def get_pure_result(self, key):
        if self.optimizer.optpure:
            return self.optimizer.optpure.get_pure_result(key)
        return None

    def setup(self):
        pass

    # Called after last operation has been propagated to flush out any posponed ops
    def flush(self):
        pass

    def produce_potential_short_preamble_ops(self, potential_ops):
        pass

    def _can_optimize_call_pure(self, op, start_index=0):
        arg_consts = []
        for i in range(start_index, op.numargs()):
            arg = op.getarg(i)
            const = self.optimizer.get_constant_box(arg)
            if const is None:
                return None
            arg_consts.append(const)
        else:
            # all constant arguments: check if we already know the result
            try:
                return self.optimizer.call_pure_results[arg_consts]
            except KeyError:
                return None


class Optimizer(Optimization):

    def __init__(self, metainterp_sd, jitdriver_sd, optimizations=None):
        self.metainterp_sd = metainterp_sd
        self.jitdriver_sd = jitdriver_sd
        self.cpu = metainterp_sd.cpu
        self.interned_refs = new_ref_dict()
        self.resumedata_memo = resume.ResumeDataLoopMemo(metainterp_sd)
        self.pendingfields = None # set temporarily to a list, normally by
                                  # heap.py, as we're about to generate a guard
        self.quasi_immutable_deps = None
        self.replaces_guard = {}
        self._newoperations = []
        self._emittedoperations = {}
        self.optimizer = self
        self.optpure = None
        self.optheap = None
        self.optrewrite = None
        self.optearlyforce = None
        self.optunroll = None
        self._really_emitted_operation = None

        self._last_guard_op = None

        self.can_replace_guards = True

        self.set_optimizations(optimizations)
        self.setup()

    def set_optimizations(self, optimizations):
        if optimizations:
            self.first_optimization = optimizations[0]
            for i in range(1, len(optimizations)):
                optimizations[i - 1].next_optimization = optimizations[i]
            optimizations[-1].next_optimization = self
            for o in optimizations:
                o.optimizer = self
                o.last_emitted_operation = None
                o.setup()
        else:
            optimizations = []
            self.first_optimization = self

        self.optimizations = optimizations

    def optimize_loop(self, trace, resumestorage, call_pure_results):
        traceiter = trace.get_iter()
        if resumestorage:
            frontend_inputargs = trace.inputargs
            deserialize_optimizer_knowledge(
                self, resumestorage, frontend_inputargs, traceiter.inputargs)
        return self.propagate_all_forward(traceiter, call_pure_results)

    def force_op_from_preamble(self, op):
        return op

    def notice_guard_future_condition(self, op):
        self.patchguardop = op

    def cant_replace_guards(self):
        return CantReplaceGuards(self)

    def replace_guard(self, op, value):
        assert self.can_replace_guards
        assert isinstance(value, info.NonNullPtrInfo)
        if value.last_guard_pos == -1:
            return
        self.replaces_guard[op] = value.last_guard_pos

    def force_box_for_end_of_preamble(self, box):
        if box.type == 'r':
            info = getptrinfo(box)
            if info is not None and info.is_virtual():
                rec = {}
                return info.force_at_the_end_of_preamble(box,
                                                self.optearlyforce, rec)
            return box
        if box.type == 'i':
            info = getrawptrinfo(box)
            if info is not None:
                return info.force_at_the_end_of_preamble(box,
                                            self.optearlyforce, None)
        return box

    def flush(self):
        for o in self.optimizations:
            o.flush()

    def produce_potential_short_preamble_ops(self, sb):
        for opt in self.optimizations:
            opt.produce_potential_short_preamble_ops(sb)

    def getinfo(self, op):
        if op.type == 'r':
            return getptrinfo(op)
        elif op.type == 'i':
            if self.is_raw_ptr(op):
                return getptrinfo(op)
            return self.getintbound(op)
        elif op.type == 'f':
            if get_box_replacement(op).is_constant():
                return info.FloatConstInfo(get_box_replacement(op))

    def get_box_replacement(self, op):
        if op is None:
            return op
        return op.get_box_replacement()

    def force_box(self, op, optforce=None):
        op = get_box_replacement(op)
        if optforce is None:
            #import pdb; pdb.set_trace()
            optforce = self
        info = op.get_forwarded()
        if self.optunroll and self.optunroll.potential_extra_ops:
            # XXX hack
            try:
                preamble_op = self.optunroll.potential_extra_ops.pop(op)
            except KeyError:
                pass
            else:
                sb = self.optunroll.short_preamble_producer
                sb.add_preamble_op(preamble_op)
        if info is not None:
            if op.type == 'i' and info.is_constant():
                return ConstInt(info.getint())
            return info.force_box(op, optforce)
        return op

    def as_operation(self, op):
        # You should never check "isinstance(op, AbstractResOp" directly.
        # Instead, use this helper.
        if isinstance(op, AbstractResOp) and op in self._emittedoperations:
            return op
        return None

    def get_constant_box(self, box):
        box = get_box_replacement(box)
        if isinstance(box, Const):
            return box
        if (box.type == 'i' and box.get_forwarded() and
            box.get_forwarded().is_constant()):
            return ConstInt(box.get_forwarded().getint())
        return None
        #self.ensure_imported(value)

    def make_equal_to(self, op, newop):
        op = get_box_replacement(op)
        if op is newop:
            return
        opinfo = op.get_forwarded()
        if opinfo is not None:
            assert isinstance(opinfo, info.AbstractInfo)
            op.set_forwarded(newop)
            if not isinstance(newop, Const):
                newop.set_forwarded(opinfo)
        else:
            op.set_forwarded(newop)

    def replace_op_with(self, op, newopnum, args=None, descr=None):
        newop = op.copy_and_change(newopnum, args, descr)
        if newop.type != 'v':
            op = get_box_replacement(op)
            opinfo = op.get_forwarded()
            if opinfo is not None:
                newop.set_forwarded(opinfo)
            op.set_forwarded(newop)
        return newop

    def make_constant(self, box, constbox):
        assert isinstance(constbox, Const)
        box = get_box_replacement(box)
        # safety-check: if the constant is outside the bounds for the
        # box, then it is an invalid loop
        if (box.get_forwarded() is not None and
            isinstance(constbox, ConstInt) and
            not isinstance(box.get_forwarded(), info.AbstractRawPtrInfo)):
            if not box.get_forwarded().contains(constbox.getint()):
                raise InvalidLoop("a box is turned into constant that is "
                                  "outside the range allowed for that box")
        if box.is_constant():
            return
        if box.type == 'r' and box.get_forwarded() is not None:
            opinfo = box.get_forwarded()
            opinfo.copy_fields_to_const(getptrinfo(constbox), self.optheap)
        box.set_forwarded(constbox)

    def make_constant_int(self, box, intvalue):
        self.make_constant(box, ConstInt(intvalue))

    def make_nonnull(self, op):
        op = self.get_box_replacement(op)
        if op.is_constant():
            return
        if op.type == 'i':
            # raw pointers
            return
        opinfo = op.get_forwarded()
        if opinfo is not None:
            assert opinfo.is_nonnull()
            return
        op.set_forwarded(info.NonNullPtrInfo())

    def make_nonnull_str(self, op, mode):
        from rpython.jit.metainterp.optimizeopt import vstring

        op = self.get_box_replacement(op)
        if op.is_constant():
            return
        opinfo = op.get_forwarded()
        if isinstance(opinfo, vstring.StrPtrInfo):
            return
        op.set_forwarded(vstring.StrPtrInfo(mode))

    def ensure_ptr_info_arg0(self, op):
        from rpython.jit.metainterp.optimizeopt import vstring

        arg0 = self.get_box_replacement(op.getarg(0))
        if arg0.is_constant():
            return info.ConstPtrInfo(arg0)
        opinfo = arg0.get_forwarded()
        if isinstance(opinfo, info.AbstractVirtualPtrInfo):
            return opinfo
        elif opinfo is not None:
            last_guard_pos = opinfo.get_last_guard_pos()
        else:
            last_guard_pos = -1
        assert opinfo is None or opinfo.__class__ is info.NonNullPtrInfo
        opnum = op.opnum
        if (rop.is_getfield(opnum) or opnum == rop.SETFIELD_GC or
            opnum == rop.QUASIIMMUT_FIELD):
            descr = op.getdescr()
            parent_descr = descr.get_parent_descr()
            if parent_descr.is_object():
                opinfo = info.InstancePtrInfo(parent_descr)
            else:
                opinfo = info.StructPtrInfo(parent_descr)
            opinfo.init_fields(parent_descr, descr.get_index())
        elif (rop.is_getarrayitem(opnum) or opnum == rop.SETARRAYITEM_GC or
              opnum == rop.ARRAYLEN_GC):
            opinfo = info.ArrayPtrInfo(op.getdescr())
        elif opnum in (rop.GUARD_CLASS, rop.GUARD_NONNULL_CLASS):
            opinfo = info.InstancePtrInfo()
        elif opnum in (rop.STRLEN,):
            opinfo = vstring.StrPtrInfo(vstring.mode_string)
        elif opnum in (rop.UNICODELEN,):
            opinfo = vstring.StrPtrInfo(vstring.mode_unicode)
        else:
            assert False, "operations %s unsupported" % op
        assert isinstance(opinfo, info.NonNullPtrInfo)
        opinfo.last_guard_pos = last_guard_pos
        arg0.set_forwarded(opinfo)
        return opinfo

    def new_const(self, fieldofs):
        if fieldofs.is_pointer_field():
            return CONST_NULL
        elif fieldofs.is_float_field():
            return CONST_ZERO_FLOAT
        else:
            return CONST_0

    def new_const_item(self, arraydescr):
        if arraydescr.is_array_of_pointers():
            return CONST_NULL
        elif arraydescr.is_array_of_floats():
            return CONST_ZERO_FLOAT
        else:
            return CONST_0

    def propagate_all_forward(self, trace, call_pure_results=None, flush=True):
        self.trace = trace
        deadranges = trace.get_dead_ranges()
        self.call_pure_results = call_pure_results
        last_op = None
        i = 0
        while not trace.done():
            self._really_emitted_operation = None
            op = trace.next()
            if op.getopnum() in (rop.FINISH, rop.JUMP):
                last_op = op
                break
            self.send_extra_operation(op)
            trace.kill_cache_at(deadranges[i + trace.start_index])
            if op.type != 'v':
                i += 1
        # accumulate counters
        if flush:
            self.flush()
            if last_op:
                self.send_extra_operation(last_op)
        self.resumedata_memo.update_counters(self.metainterp_sd.profiler)

        return (BasicLoopInfo(trace.inputargs, self.quasi_immutable_deps, last_op),
                self._newoperations)

    def _clean_optimization_info(self, lst):
        for op in lst:
            if op.get_forwarded() is not None:
                op.set_forwarded(None)

    def send_extra_operation(self, op, opt=None):
        if opt is None:
            opt = self.first_optimization
        opt_results = []
        while opt is not None:
            opt_result = opt.propagate_forward(op)
            if opt_result is None:
                op = None
                break
            opt_results.append(opt_result)
            op = opt_result.op
            opt = opt.next_optimization
        for opt_result in reversed(opt_results):
            opt_result.callback()

    def propagate_forward(self, op):
        dispatch_opt(self, op)

    def emit_extra(self, op, emit=True):
        # no forwarding, because we're at the end of the chain
        self.emit(op)

    def emit(self, op):
        # this actually emits the operation instead of forwarding it
        if rop.returns_bool_result(op.opnum):
            self.getintbound(op).make_bool()
        self._emit_operation(op)
        op = self.get_box_replacement(op)
        if op.type == 'i':
            opinfo = op.get_forwarded()
            if opinfo is not None:
                assert isinstance(opinfo, IntBound)
                if opinfo.is_constant():
                    op.set_forwarded(ConstInt(opinfo.getint()))

    @specialize.argtype(0)
    def _emit_operation(self, op):
        assert not rop.is_call_pure(op.getopnum())
        orig_op = op
        op = self.get_box_replacement(op)
        if op.is_constant():
            return # can happen e.g. if we postpone the operation that becomes
            # constant
        # XXX kill, requires thinking
        #op = self.replace_op_with(op, op.opnum)
        for i in range(op.numargs()):
            arg = self.force_box(op.getarg(i))
            op.setarg(i, arg)
        self.metainterp_sd.profiler.count(jitprof.Counters.OPT_OPS)
        if rop.is_guard(op.opnum):
            assert isinstance(op, GuardResOp)
            self.metainterp_sd.profiler.count(jitprof.Counters.OPT_GUARDS)
            pendingfields = self.pendingfields
            self.pendingfields = None
            if self.replaces_guard and orig_op in self.replaces_guard:
                self.replace_guard_op(self.replaces_guard[orig_op], op)
                del self.replaces_guard[orig_op]
                return
            else:
                op = self.emit_guard_operation(op, pendingfields)
        elif op.can_raise():
            self.exception_might_have_happened = True
        opnum = op.opnum
        if ((rop.has_no_side_effect(opnum) or rop.is_guard(opnum) or
             rop.is_jit_debug(opnum) or
             rop.is_ovf(opnum)) and not self.is_call_pure_pure_canraise(op)):
            pass
        else:
            self._last_guard_op = None
        self._really_emitted_operation = op
        self._newoperations.append(op)
        self._emittedoperations[op] = None

    def emit_guard_operation(self, op, pendingfields):
        guard_op = op # self.replace_op_with(op, op.getopnum())
        opnum = guard_op.getopnum()
        # If guard_(no)_exception is merged with another previous guard, then
        # it *should* be in "some_call;guard_not_forced;guard_(no)_exception".
        # The guard_(no)_exception can also occur at different places,
        # but these should not be preceeded immediately by another guard.
        # Sadly, asserting this seems to fail in rare cases.  So instead,
        # we simply give up sharing.
        if (opnum in (rop.GUARD_NO_EXCEPTION, rop.GUARD_EXCEPTION) and
                self._last_guard_op is not None and
                self._last_guard_op.getopnum() != rop.GUARD_NOT_FORCED):
            self._last_guard_op = None
        #
        if (self._last_guard_op and guard_op.getdescr() is None):
            self.metainterp_sd.profiler.count_ops(opnum,
                                            jitprof.Counters.OPT_GUARDS_SHARED)
            op = self._copy_resume_data_from(guard_op,
                                             self._last_guard_op)
        else:
            op = self.store_final_boxes_in_guard(guard_op, pendingfields)
            self._last_guard_op = op
            # for unrolling
            for farg in op.getfailargs():
                if farg:
                    self.force_box(farg)
        if op.getopnum() == rop.GUARD_EXCEPTION:
            self._last_guard_op = None
        return op

    def _copy_resume_data_from(self, guard_op, last_guard_op):
        last_descr = last_guard_op.getdescr()
        descr = compile.invent_fail_descr_for_op(guard_op.getopnum(), self, last_descr)
        assert isinstance(last_descr, compile.ResumeGuardDescr)
        if not isinstance(descr, compile.ResumeGuardCopiedDescr):
            descr.copy_all_attributes_from(last_descr)
        guard_op.setdescr(descr)
        guard_op.setfailargs(last_guard_op.getfailargs())
        descr.store_hash(self.metainterp_sd)
        assert isinstance(guard_op, GuardResOp)
        if guard_op.getopnum() == rop.GUARD_VALUE:
            guard_op = self._maybe_replace_guard_value(guard_op, descr)
        return guard_op

    def getlastop(self):
        return self._really_emitted_operation

    def is_call_pure_pure_canraise(self, op):
        if not rop.is_call_pure(op.getopnum()):
            return False
        effectinfo = op.getdescr().get_extra_info()
        if effectinfo.check_can_raise(ignore_memoryerror=True):
            return True
        return False

    def replace_guard_op(self, old_op_pos, new_op):
        old_op = self._newoperations[old_op_pos]
        assert old_op.is_guard()
        old_descr = old_op.getdescr()
        new_descr = new_op.getdescr()
        new_descr.copy_all_attributes_from(old_descr)
        self._newoperations[old_op_pos] = new_op
        self._emittedoperations[new_op] = None

    def store_final_boxes_in_guard(self, op, pendingfields):
        assert pendingfields is not None
        if op.getdescr() is not None:
            descr = op.getdescr()
            assert isinstance(descr, compile.ResumeGuardDescr)
        else:
            descr = compile.invent_fail_descr_for_op(op.getopnum(), self)
            op.setdescr(descr)
        assert isinstance(descr, compile.ResumeGuardDescr)
        assert isinstance(op, GuardResOp)
        modifier = resume.ResumeDataVirtualAdder(self, descr, op, self.trace,
                                                 self.resumedata_memo)
        try:
            newboxes = modifier.finish(pendingfields)
            if (newboxes is not None and
                len(newboxes) > self.metainterp_sd.options.failargs_limit):
                raise resume.TagOverflow
        except resume.TagOverflow:
            raise compile.giveup()
        # check no duplicates
        #if not we_are_translated():
        seen = {}
        for box in newboxes:
            if box is not None:
                assert box not in seen
                seen[box] = None
        descr.store_final_boxes(op, newboxes, self.metainterp_sd)
        #
        if op.getopnum() == rop.GUARD_VALUE:
            op = self._maybe_replace_guard_value(op, descr)
        return op

    def _maybe_replace_guard_value(self, op, descr):
        if op.getarg(0).type == 'i':
            b = self.getintbound(op.getarg(0))
            if b.is_bool():
                # Hack: turn guard_value(bool) into guard_true/guard_false.
                # This is done after the operation is emitted to let
                # store_final_boxes_in_guard set the guard_opnum field of
                # the descr to the original rop.GUARD_VALUE.
                constvalue = op.getarg(1).getint()
                if constvalue == 0:
                    opnum = rop.GUARD_FALSE
                elif constvalue == 1:
                    opnum = rop.GUARD_TRUE
                else:
                    # Issue #3128: there might be rare cases where strange
                    # code is produced.  That issue hits the assert from
                    # OptUnroll.inline_short_preamble's send_extra_operation().
                    # Better just disable this optimization than crash with
                    # an AssertionError here.  Note also that such code might
                    # trigger an InvalidLoop to be raised later---so we must
                    # not crash here.
                    return op
                newop = self.replace_op_with(op, opnum, [op.getarg(0)], descr)
                return newop
        return op

    def optimize_default(self, op):
        self.emit(op)

    def constant_fold(self, op):
        self.protect_speculative_operation(op)
        argboxes = [self.get_constant_box(op.getarg(i))
                    for i in range(op.numargs())]
        return execute_nonspec_const(self.cpu, None,
                                       op.getopnum(), argboxes,
                                       op.getdescr(), op.type)

    def protect_speculative_operation(self, op):
        """When constant-folding a pure operation that reads memory from
        a gcref, make sure that the gcref is non-null and of a valid type.
        Otherwise, raise SpeculativeError.  This should only occur when
        unrolling and optimizing the unrolled loop.  Note that if
        cpu.supports_guard_gc_type is false, we can't really do this
        check at all, but then we don't unroll in that case.
        """
        opnum = op.getopnum()
        cpu = self.cpu

        if OpHelpers.is_pure_getfield(opnum, op.getdescr()):
            fielddescr = op.getdescr()
            ref = self.get_constant_box(op.getarg(0)).getref_base()
            cpu.protect_speculative_field(ref, fielddescr)
            return

        elif (opnum == rop.GETARRAYITEM_GC_PURE_I or
              opnum == rop.GETARRAYITEM_GC_PURE_R or
              opnum == rop.GETARRAYITEM_GC_PURE_F or
              opnum == rop.ARRAYLEN_GC):
            arraydescr = op.getdescr()
            array = self.get_constant_box(op.getarg(0)).getref_base()
            cpu.protect_speculative_array(array, arraydescr)
            if opnum == rop.ARRAYLEN_GC:
                return
            arraylength = cpu.bh_arraylen_gc(array, arraydescr)

        elif (opnum == rop.STRGETITEM or
              opnum == rop.STRLEN):
            string = self.get_constant_box(op.getarg(0)).getref_base()
            cpu.protect_speculative_string(string)
            if opnum == rop.STRLEN:
                return
            arraylength = cpu.bh_strlen(string)

        elif (opnum == rop.UNICODEGETITEM or
              opnum == rop.UNICODELEN):
            unicode = self.get_constant_box(op.getarg(0)).getref_base()
            cpu.protect_speculative_unicode(unicode)
            if opnum == rop.UNICODELEN:
                return
            arraylength = cpu.bh_unicodelen(unicode)

        else:
            return

        index = self.get_constant_box(op.getarg(1)).getint()
        if not (0 <= index < arraylength):
            raise SpeculativeError

    @staticmethod
    def _check_subclass(vtable1, vtable2): # checks that vtable1 is a subclass of vtable2
        known_class = llmemory.cast_adr_to_ptr(
            llmemory.cast_int_to_adr(vtable1),
            rclass.CLASSTYPE)
        expected_class = llmemory.cast_adr_to_ptr(
            llmemory.cast_int_to_adr(vtable2),
            rclass.CLASSTYPE)
        # note: the test is for a range including 'max', but 'max'
        # should never be used for actual classes.  Including it makes
        # it easier to pass artificial tests.
        return (expected_class.subclassrange_min
                <= known_class.subclassrange_min
                <= expected_class.subclassrange_max)

    def is_virtual(self, op):
        opinfo = getptrinfo(op)
        return opinfo is not None and opinfo.is_virtual()

    # These are typically removed already by OptRewrite, but it can be
    # dissabled and unrolling emits some SAME_AS ops to setup the
    # optimizier state. These needs to always be optimized out.
    def optimize_SAME_AS_I(self, op):
        self.make_equal_to(op, op.getarg(0))
    optimize_SAME_AS_R = optimize_SAME_AS_I
    optimize_SAME_AS_F = optimize_SAME_AS_I

dispatch_opt = make_dispatcher_method(Optimizer, 'optimize_',
        default=Optimizer.optimize_default)


class CantReplaceGuards(object):
    def __init__(self, optimizer):
        self.optimizer = optimizer

    def __enter__(self, *args):
        self.oldval = self.optimizer.can_replace_guards
        self.optimizer.can_replace_guards = False

    def __exit__(self, *args):
        self.optimizer.can_replace_guards = self.oldval


