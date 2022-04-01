
import sys
from rpython.jit.metainterp.history import Const, TargetToken, JitCellToken
from rpython.jit.metainterp.optimizeopt.shortpreamble import ShortBoxes,\
     ShortPreambleBuilder, ExtendedShortPreambleBuilder, PreambleOp
from rpython.jit.metainterp.optimizeopt import info, intutils
from rpython.jit.metainterp.optimize import InvalidLoop, SpeculativeError
from rpython.jit.metainterp.optimizeopt.optimizer import Optimizer,\
     Optimization, LoopInfo, MININT, MAXINT, BasicLoopInfo
from rpython.jit.metainterp.optimizeopt.vstring import StrPtrInfo
from rpython.jit.metainterp.optimizeopt.virtualstate import (
    VirtualStateConstructor, VirtualStatesCantMatch)
from .util import get_box_replacement
from rpython.jit.metainterp.resoperation import rop, ResOperation, GuardResOp
from rpython.jit.metainterp import compile
from rpython.rlib.debug import debug_print, debug_start, debug_stop,\
     have_debug_prints

class UnrollOptimizer(Optimizer):
    def __init__(self, metainterp_sd, jitdriver_sd, optimizations):
        Optimizer.__init__(self, metainterp_sd, jitdriver_sd, optimizations)
        self.optunroll = OptUnroll()
        self.optunroll.optimizer = self

    def force_op_from_preamble(self, preamble_op):
        if isinstance(preamble_op, PreambleOp):
            if self.optunroll.short_preamble_producer is None:
                assert False # unreachable code
            op = preamble_op.op
            # special hack for int_add(x, accumulator-const) optimization
            self.optunroll.short_preamble_producer.use_box(op,
                                                preamble_op.preamble_op, self)
            if not preamble_op.op.is_constant():
                if preamble_op.invented_name:
                    op = get_box_replacement(op)
                self.optunroll.potential_extra_ops[op] = preamble_op
            return preamble_op.op
        return preamble_op

    def setinfo_from_preamble_list(self, lst, infos):
        for item in lst:
            if item is None:
                continue
            i = infos.get(item, None)
            if i is not None:
                self.setinfo_from_preamble(item, i, infos)
            else:
                item.set_forwarded(None)
                # let's not inherit stuff we don't
                # know anything about

    def setinfo_from_preamble(self, op, preamble_info, exported_infos):
        op = get_box_replacement(op)
        if op.get_forwarded() is not None:
            return
        if op.is_constant():
            return # nothing we can learn
        if isinstance(preamble_info, info.PtrInfo):
            if preamble_info.is_virtual():
                op.set_forwarded(preamble_info)
                self.setinfo_from_preamble_list(preamble_info.all_items(),
                                          exported_infos)
                return
            if preamble_info.is_constant():
                # but op is not
                op.set_forwarded(preamble_info.getconst())
                return
            if preamble_info.get_descr() is not None:
                if isinstance(preamble_info, info.StructPtrInfo):
                    op.set_forwarded(info.StructPtrInfo(
                        preamble_info.get_descr()))
                if isinstance(preamble_info, info.InstancePtrInfo):
                    op.set_forwarded(info.InstancePtrInfo(
                        preamble_info.get_descr()))
            known_class = preamble_info.get_known_class(self.cpu)
            if known_class:
                self.make_constant_class(op, known_class, False)
            if isinstance(preamble_info, info.ArrayPtrInfo):
                arr_info = info.ArrayPtrInfo(preamble_info.descr)
                bound = preamble_info.getlenbound(None).clone()
                assert isinstance(bound, intutils.IntBound)
                arr_info.lenbound = bound
                op.set_forwarded(arr_info)
            if isinstance(preamble_info, StrPtrInfo):
                str_info = StrPtrInfo(preamble_info.mode)
                bound = preamble_info.getlenbound(None).clone()
                assert isinstance(bound, intutils.IntBound)
                str_info.lenbound = bound
                op.set_forwarded(str_info)
            if preamble_info.is_nonnull():
                self.make_nonnull(op)
        elif isinstance(preamble_info, intutils.IntBound):
            fix_lo = preamble_info.has_lower and preamble_info.lower >= MININT/2
            fix_up = preamble_info.has_upper and preamble_info.upper <= MAXINT/2
            if fix_lo or fix_up:
                intbound = self.getintbound(op)
                if fix_lo:
                    intbound.has_lower = True
                    intbound.lower = preamble_info.lower
                if fix_up:
                    intbound.has_upper = True
                    intbound.upper = preamble_info.upper
        elif isinstance(preamble_info, info.FloatConstInfo):
            op.set_forwarded(preamble_info._const)

    def optimize_preamble(self, trace, runtime_boxes, call_pure_results, memo):
        info, newops = self.propagate_all_forward(
            trace.get_iter(), call_pure_results, flush=False)
        exported_state = self.optunroll.export_state(info.jump_op.getarglist(),
                                           info.inputargs,
                                           runtime_boxes, memo)
        exported_state.quasi_immutable_deps = info.quasi_immutable_deps
        # we need to absolutely make sure that we've cleaned up all
        # the optimization info
        self._clean_optimization_info(self._newoperations)
        return exported_state, self._newoperations

    def optimize_peeled_loop(self, trace, celltoken, state, call_pure_results):
        trace = trace.get_iter()
        try:
            label_args = self.optunroll.import_state(trace.inputargs, state)
        except VirtualStatesCantMatch:
            raise InvalidLoop("Cannot import state, virtual states don't match")
        self.optunroll.potential_extra_ops = {}
        try:
            info, _ = self.propagate_all_forward(
                trace, call_pure_results, flush=False)
        except SpeculativeError:
            raise InvalidLoop("Speculative heap access would be ill-typed")
        end_jump = info.jump_op
        label_op = ResOperation(rop.LABEL, label_args, descr=celltoken)
        for a in end_jump.getarglist():
            self.force_box_for_end_of_preamble(get_box_replacement(a))
        current_vs = self.optunroll.get_virtual_state(end_jump.getarglist())
        # pick the vs we want to jump to
        assert isinstance(celltoken, JitCellToken)

        target_virtual_state = self.optunroll.pick_virtual_state(
            current_vs, state.virtual_state, celltoken.target_tokens)
        # force the boxes for virtual state to match
        try:
            args = target_virtual_state.make_inputargs(
               [get_box_replacement(x) for x in end_jump.getarglist()],
               self, force_boxes=True)
            for arg in args:
                if arg is not None:
                    self.force_box(arg)
        except VirtualStatesCantMatch:
            raise InvalidLoop("Virtual states did not match "
                              "after picking the virtual state, when forcing"
                              " boxes")
        extra_same_as = self.optunroll.short_preamble_producer.extra_same_as[:]
        target_token = self.optunroll.finalize_short_preamble(label_op,
                                                    state.virtual_state)
        label_op.setdescr(target_token)

        try:
            new_virtual_state = self.optunroll.jump_to_existing_trace(
                end_jump, label_op, state.runtime_boxes, force_boxes=False)
        except InvalidLoop:
            # inlining short preamble failed, jump to preamble
            self.jump_to_preamble(celltoken, end_jump)
            return (UnrollInfo(target_token, label_op, extra_same_as,
                               self.quasi_immutable_deps),
                    self._newoperations)

        if new_virtual_state is not None:
            # Attempt to force virtual boxes in order to avoid jumping
            # to the preamble.
            try:
                new_virtual_state = self.optunroll.jump_to_existing_trace(
                    end_jump, label_op, state.runtime_boxes, force_boxes=True)
            except InvalidLoop:
                pass

        if new_virtual_state is not None:
            self.jump_to_preamble(celltoken, end_jump)
            return (UnrollInfo(target_token, label_op, extra_same_as,
                               self.quasi_immutable_deps),
                    self._newoperations)

        self.optunroll.disable_retracing_if_max_retrace_guards(
            self._newoperations, target_token)

        return (UnrollInfo(target_token, label_op, extra_same_as,
                           self.quasi_immutable_deps),
                self._newoperations)

    def optimize_bridge(self, trace, runtime_boxes, call_pure_results,
                        inline_short_preamble, box_names_memo, resumestorage):
        from rpython.jit.metainterp.optimizeopt.bridgeopt import deserialize_optimizer_knowledge
        frontend_inputargs = trace.inputargs
        trace = trace.get_iter()
        self.optunroll._check_no_forwarding([trace.inputargs])
        if resumestorage:
            deserialize_optimizer_knowledge(self,
                                            resumestorage, frontend_inputargs,
                                            trace.inputargs)
        info, ops = self.propagate_all_forward(trace,
            call_pure_results, False)
        jump_op = info.jump_op
        cell_token = jump_op.getdescr()
        assert isinstance(cell_token, JitCellToken)
        if not inline_short_preamble or len(cell_token.target_tokens) == 1:
            self.jump_to_preamble(cell_token, jump_op)
            return info, self._newoperations[:]
        # force all the information that does not go to the short
        # preamble at all
        self.flush()
        for a in jump_op.getarglist():
            self.force_box_for_end_of_preamble(a)
        try:
            vs = self.optunroll.jump_to_existing_trace(jump_op, None, runtime_boxes,
                                             force_boxes=False)
        except InvalidLoop:
            self.jump_to_preamble(cell_token, jump_op)
            return info, self._newoperations[:]
        if vs is None:
            return info, self._newoperations[:]
        warmrunnerdescr = self.metainterp_sd.warmrunnerdesc
        limit = warmrunnerdescr.memory_manager.retrace_limit
        if cell_token.retraced_count < limit:
            cell_token.retraced_count += 1
            debug_print('Retracing (%d/%d)' % (cell_token.retraced_count, limit))
        else:
            # Try forcing boxes to avoid jumping to the preamble
            try:
                vs = self.optunroll.jump_to_existing_trace(jump_op, None, runtime_boxes,
                                                 force_boxes=True)
            except InvalidLoop:
                pass
            if vs is None:
                return info, self._newoperations[:]
            debug_print("Retrace count reached, jumping to preamble")
            self.jump_to_preamble(cell_token, jump_op)
            return info, self._newoperations[:]
        exported_state = self.optunroll.export_state(info.jump_op.getarglist(),
                                           info.inputargs, runtime_boxes,
                                           box_names_memo)
        exported_state.quasi_immutable_deps = self.quasi_immutable_deps
        self._clean_optimization_info(self._newoperations)
        return exported_state, self._newoperations

    def jump_to_preamble(self, cell_token, jump_op):
        assert cell_token.target_tokens[0].virtual_state is None
        jump_op = jump_op.copy_and_change(
            rop.JUMP, descr=cell_token.target_tokens[0])
        self.send_extra_operation(jump_op)


class OptUnroll(Optimization):
    """Unroll the loop into two iterations. The first one will
    become the preamble or entry bridge (don't think there is a
    distinction anymore)"""

    short_preamble_producer = None

    def get_virtual_state(self, args):
        modifier = VirtualStateConstructor(self.optimizer)
        return modifier.get_virtual_state(args)

    def _check_no_forwarding(self, lsts, check_newops=True):
        for lst in lsts:
            for op in lst:
                assert op.get_forwarded() is None
        if check_newops:
            assert not self.optimizer._newoperations


    def disable_retracing_if_max_retrace_guards(self, ops, target_token):
        maxguards = self.optimizer.metainterp_sd.warmrunnerdesc.memory_manager.max_retrace_guards
        count = 0
        for op in ops:
            if op.is_guard():
                count += 1
        if count > maxguards:
            assert isinstance(target_token, TargetToken)
            target_token.targeting_jitcell_token.retraced_count = sys.maxint

    def pick_virtual_state(self, my_vs, label_vs, target_tokens):
        if target_tokens is None:
            return label_vs # for tests
        for token in target_tokens:
            if token.virtual_state is None:
                continue
            if token.virtual_state.generalization_of(my_vs, self.optimizer):
                return token.virtual_state
        return label_vs

    def finalize_short_preamble(self, label_op, virtual_state):
        sb = self.short_preamble_producer
        self.optimizer._clean_optimization_info(sb.short_inputargs)
        short_preamble = sb.build_short_preamble()
        jitcelltoken = label_op.getdescr()
        assert isinstance(jitcelltoken, JitCellToken)
        if jitcelltoken.target_tokens is None:
            jitcelltoken.target_tokens = []
        target_token = TargetToken(jitcelltoken,
                                   original_jitcell_token=jitcelltoken)
        target_token.original_jitcell_token = jitcelltoken
        target_token.virtual_state = virtual_state
        target_token.short_preamble = short_preamble
        jitcelltoken.target_tokens.append(target_token)
        self.short_preamble_producer = ExtendedShortPreambleBuilder(
            target_token, sb)
        label_op.initarglist(label_op.getarglist() + sb.used_boxes)
        return target_token


    def jump_to_existing_trace(self, jump_op, label_op, runtime_boxes, force_boxes=False):
        # there is a big conceptual problem here: it's not safe at all to catch
        # InvalidLoop in the callers of _jump_to_existing_trace and then
        # continue trying to jump to some other label, because inlining the
        # short preamble could have worked partly, leaving some unwanted new
        # ops at the end of the trace. Here's at least a stopgap to stop
        # terrible things from happening: we *must not* move any of those bogus
        # guards earlier into the trace. see
        # test_unroll_shortpreamble_mutates_bug in test_loop, and issue #3598

        # leaving the bogus operations at the end of the trace is not great,
        # but should be safe: at worst, they just always do a bit of stuff and
        # then fail
        with self.optimizer.cant_replace_guards():
            return self._jump_to_existing_trace(jump_op, label_op, runtime_boxes, force_boxes)

    def _jump_to_existing_trace(self, jump_op, label_op, runtime_boxes, force_boxes=False):
        jitcelltoken = jump_op.getdescr()
        assert isinstance(jitcelltoken, JitCellToken)
        virtual_state = self.get_virtual_state(jump_op.getarglist())
        args = [get_box_replacement(op) for op in jump_op.getarglist()]
        for target_token in jitcelltoken.target_tokens:
            target_virtual_state = target_token.virtual_state
            if target_virtual_state is None:
                continue
            try:
                extra_guards = target_virtual_state.generate_guards(
                    virtual_state, args, runtime_boxes, self.optimizer,
                    force_boxes=force_boxes)
                patchguardop = self.optimizer.patchguardop
                for guard in extra_guards.extra_guards:
                    if isinstance(guard, GuardResOp):
                        guard.rd_resume_position = patchguardop.rd_resume_position
                        guard.setdescr(compile.ResumeAtPositionDescr())
                    self.optimizer.send_extra_operation(guard)
            except VirtualStatesCantMatch:
                continue

            # When force_boxes == True, creating the virtual args can fail when
            # components of the virtual state alias. If this occurs, we must
            # recompute the virtual state as boxes will have been forced.
            try:
                args, virtuals = target_virtual_state.make_inputargs_and_virtuals(
                    args, self.optimizer, force_boxes=force_boxes)
            except VirtualStatesCantMatch:
                assert force_boxes
                virtual_state = self.get_virtual_state(args)
                continue

            short_preamble = target_token.short_preamble
            extra = self.inline_short_preamble(args + virtuals, args,
                                short_preamble, self.optimizer.patchguardop,
                                target_token, label_op)
            self.optimizer.send_extra_operation(jump_op.copy_and_change(rop.JUMP,
                                      args=args + extra,
                                      descr=target_token))
            return None # explicit because the return can be non-None

        return virtual_state

    def _map_args(self, mapping, arglist):
        result = []
        for box in arglist:
            if not isinstance(box, Const):
                box = mapping[box]
            result.append(box)
        return result

    def inline_short_preamble(self, jump_args, args_no_virtuals, short,
                              patchguardop, target_token, label_op):
        short_inputargs = short[0].getarglist()
        short_jump_args = short[-1].getarglist()
        sb = self.short_preamble_producer
        if sb is not None:
            assert isinstance(sb, ExtendedShortPreambleBuilder)
            if sb.target_token is target_token:
                # this means we're inlining the short preamble that's being
                # built. Make sure we modify the correct things in-place
                self.short_preamble_producer.setup(short_jump_args,
                                                   short, label_op.getarglist())
                # after this call, THE REST OF THIS FUNCTION WILL MODIFY ALL
                # THE LISTS PROVIDED, POTENTIALLY

        # We need to make a list of fresh new operations corresponding
        # to the short preamble operations.  We could temporarily forward
        # the short operations to the fresh ones, but there are obscure
        # issues: send_extra_operation() below might occasionally invoke
        # use_box(), which assumes the short operations are not forwarded.
        # So we avoid such temporary forwarding and just use a dict here.
        assert len(short_inputargs) == len(jump_args)
        mapping = {}
        for i in range(len(jump_args)):
            mapping[short_inputargs[i]] = jump_args[i]

        # a fix-point loop, runs only once in almost all cases
        i = 1
        while 1:
            self._check_no_forwarding([short_inputargs, short], False)
            while i < len(short) - 1:
                sop = short[i]
                arglist = self._map_args(mapping, sop.getarglist())
                if sop.is_guard():
                    op = sop.copy_and_change(sop.getopnum(), arglist,
                                    descr=compile.ResumeAtPositionDescr())
                    assert isinstance(op, GuardResOp)
                    op.rd_resume_position = patchguardop.rd_resume_position
                else:
                    op = sop.copy_and_change(sop.getopnum(), arglist)
                mapping[sop] = op
                i += 1
                self.optimizer.send_extra_operation(op)
            # force all of them except the virtuals
            for arg in (args_no_virtuals +
                        self._map_args(mapping, short_jump_args)):
                self.optimizer.force_box(get_box_replacement(arg))
            self.optimizer.flush()
            # done unless "short" has grown again
            if i == len(short) - 1:
                break

        return [get_box_replacement(box)
                for box in self._map_args(mapping, short_jump_args)]

    def _expand_info(self, arg, infos):
        arg1 = self.optimizer.as_operation(arg)
        if arg1 is not None and rop.is_same_as(arg1.opnum):
            info = self.optimizer.getinfo(arg1.getarg(0))
        else:
            info = self.optimizer.getinfo(arg)
        if arg in infos:
            return
        if info:
            infos[arg] = info
            if info.is_virtual():
                self._expand_infos_from_virtual(info, infos)

    def _expand_infos_from_virtual(self, info, infos):
        items = info.all_items()
        for item in items:
            if item is None:
                continue
            self._expand_info(item, infos)

    def export_state(self, original_label_args, renamed_inputargs,
                     runtime_boxes, memo):
        end_args = [self.optimizer.force_box_for_end_of_preamble(a)
                    for a in original_label_args]
        self.optimizer.flush()
        virtual_state = self.get_virtual_state(end_args)
        end_args = [get_box_replacement(arg) for arg in end_args]
        infos = {}
        for arg in end_args:
            self._expand_info(arg, infos)
        label_args, virtuals = virtual_state.make_inputargs_and_virtuals(
            end_args, self.optimizer)
        for arg in label_args:
            self._expand_info(arg, infos)
        sb = ShortBoxes()
        short_boxes = sb.create_short_boxes(self.optimizer, renamed_inputargs,
                                            label_args + virtuals)
        short_inputargs = sb.create_short_inputargs(label_args + virtuals)
        for produced_op in short_boxes:
            op = produced_op.short_op.res
            if not isinstance(op, Const):
                self._expand_info(op, infos)
        self.optimizer._clean_optimization_info(end_args)
        return ExportedState(label_args, end_args, virtual_state, infos,
                             short_boxes, renamed_inputargs,
                             short_inputargs, runtime_boxes, memo)

    def import_state(self, targetargs, exported_state):
        # the mapping between input args (from old label) and what we need
        # to actually emit. Update the info
        assert len(exported_state.next_iteration_args) == len(targetargs)
        for i, target in enumerate(exported_state.next_iteration_args):
            source = targetargs[i]
            assert source is not target
            source.set_forwarded(target)
            info = exported_state.exported_infos.get(target, None)
            if info is not None:
                self.optimizer.setinfo_from_preamble(source, info,
                                            exported_state.exported_infos)
        # import the optimizer state, starting from boxes that can be produced
        # by short preamble
        label_args = exported_state.virtual_state.make_inputargs(
            targetargs, self.optimizer)

        self.short_preamble_producer = ShortPreambleBuilder(
            label_args, exported_state.short_boxes,
            exported_state.short_inputargs, exported_state.exported_infos,
            self.optimizer)

        for produced_op in exported_state.short_boxes:
            produced_op.produce_op(self, exported_state.exported_infos)

        return label_args


class UnrollInfo(BasicLoopInfo):
    """ A state after optimizing the peeled loop, contains the following:

    * target_token - generated target token
    * label_args - label operations at the beginning
    * extra_same_as - list of extra same as to add at the end of the preamble
    """
    def __init__(self, target_token, label_op, extra_same_as,
                 quasi_immutable_deps):
        self.target_token = target_token
        self.label_op = label_op
        self.extra_same_as = extra_same_as
        self.quasi_immutable_deps = quasi_immutable_deps
        self.extra_before_label = []

    def final(self):
        return True

class ExportedState(LoopInfo):
    """ Exported state consists of a few pieces of information:

    * next_iteration_args - starting arguments for next iteration
    * exported_infos - a mapping from ops to infos, including inputargs
    * end_args - arguments that end up in the label leading to the next
                 iteration
    * virtual_state - instance of VirtualState representing current state
                      of virtuals at this label
    * short boxes - a mapping op -> preamble_op
    * renamed_inputargs - the start label arguments in optimized version
    * short_inputargs - the renamed inputargs for short preamble
    * quasi_immutable_deps - for tracking quasi immutables
    * runtime_boxes - runtime values for boxes, necessary when generating
                      guards to jump to
    """

    def __init__(self, end_args, next_iteration_args, virtual_state,
                 exported_infos, short_boxes, renamed_inputargs,
                 short_inputargs, runtime_boxes, memo):
        self.end_args = end_args
        self.next_iteration_args = next_iteration_args
        self.virtual_state = virtual_state
        self.exported_infos = exported_infos
        self.short_boxes = short_boxes
        self.renamed_inputargs = renamed_inputargs
        self.short_inputargs = short_inputargs
        self.runtime_boxes = runtime_boxes
        self.dump(memo)

    def dump(self, memo):
        if have_debug_prints():
            debug_start("jit-log-exported-state")
            debug_print("[" + ", ".join([x.repr_short(memo) for x in self.next_iteration_args]) + "]")
            for box in self.short_boxes:
                debug_print("  " + box.repr(memo))
            debug_stop("jit-log-exported-state")

    def final(self):
        return False
