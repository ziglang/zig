"""
This is the core of the vec. optimization. It combines dependency.py and schedule.py
to rewrite a loop in vectorized form.

See the rpython doc for more high level details.
"""

import py
import time

from rpython.jit.metainterp.jitexc import NotAVectorizeableLoop, NotAProfitableLoop
from rpython.jit.metainterp.compile import (CompileLoopVersionDescr, ResumeDescr)
from rpython.jit.metainterp.history import (INT, FLOAT, VECTOR, ConstInt, ConstFloat,
        TargetToken, JitCellToken, AbstractFailDescr)
from rpython.jit.metainterp.optimizeopt.optimizer import Optimizer, Optimization
from rpython.jit.metainterp.optimizeopt.renamer import Renamer
from rpython.jit.metainterp.optimizeopt.dependency import (DependencyGraph,
        MemoryRef, Node, IndexVar)
from rpython.jit.metainterp.optimizeopt.version import LoopVersionInfo
from rpython.jit.metainterp.optimizeopt.schedule import (VecScheduleState,
        SchedulerState, Scheduler, Pack, Pair, AccumPack, forwarded_vecinfo)
from rpython.jit.metainterp.optimizeopt.guard import GuardStrengthenOpt
from rpython.jit.metainterp.resoperation import (rop, ResOperation, GuardResOp,
        OpHelpers, VecOperation, VectorizationInfo)
from rpython.rlib import listsort
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rlib.jit import Counters
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.jit.backend.llsupport.symbolic import (WORD as INT_WORD,
        SIZEOF_FLOAT as FLOAT_WORD)

def copy_resop(op):
    newop = op.copy()
    fwd = op.get_forwarded()
    if fwd is not None and isinstance(fwd, VectorizationInfo):
        newop.set_forwarded(fwd)
    return newop

class VectorLoop(object):
    def __init__(self, label, oplist, jump):
        self.label = label
        self.inputargs = label.getarglist_copy()
        self.prefix = []
        self.prefix_label = None
        assert self.label.getopnum() == rop.LABEL
        self.operations = oplist
        self.jump = jump
        assert self.jump.getopnum() == rop.JUMP
        self.align_operations = []

    def setup_vectorization(self):
        for op in self.operations:
            op.set_forwarded(VectorizationInfo(op))

    def teardown_vectorization(self):
        for op in self.operations:
            op.set_forwarded(None)

    def finaloplist(self, jitcell_token=None, reset_label_token=True, label=False):
        if jitcell_token:
            if reset_label_token:
                token = TargetToken(jitcell_token)
                token.original_jitcell_token = jitcell_token
                jitcell_token.target_tokens.append(token)
                self.label.setdescr(token)
            else:
                token = self.jump.getdescr()
                assert isinstance(token, TargetToken)
            if self.prefix_label:
                token = TargetToken(jitcell_token)
                token.original_jitcell_token = jitcell_token
                jitcell_token.target_tokens.append(token)
                self.prefix_label.setdescr(token)
                self.jump.setdescr(token)
            if reset_label_token:
                self.jump.setdescr(token)
        oplist = []
        if self.prefix_label:
            oplist = self.prefix + [self.prefix_label]
        elif self.prefix:
            oplist = self.prefix
        if label:
            oplist = [self.label] + oplist
        if not label:
            for op in oplist:
                op.set_forwarded(None)
            self.jump.set_forwarded(None)
        ops = oplist + self.operations + [self.jump]
        return ops

    def clone(self):
        renamer = Renamer()
        label = copy_resop(self.label)
        prefix = []
        for op in self.prefix:
            newop = copy_resop(op)
            renamer.rename(newop)
            if not newop.returns_void():
                renamer.start_renaming(op, newop)
            prefix.append(newop)
        prefix_label = None
        if self.prefix_label:
            prefix_label = copy_resop(self.prefix_label)
            renamer.rename(prefix_label)
        oplist = []
        for op in self.operations:
            newop = copy_resop(op)
            renamer.rename(newop)
            if not newop.returns_void():
                renamer.start_renaming(op, newop)
            oplist.append(newop)
        jump = copy_resop(self.jump)
        renamer.rename(jump)
        loop = VectorLoop(copy_resop(self.label), oplist, jump)
        loop.prefix = prefix
        loop.prefix_label = prefix_label
        return loop

def optimize_vector(trace, metainterp_sd, jitdriver_sd, warmstate,
                    loop_info, loop_ops, jitcell_token=None):
    """ Enter the world of SIMD. Bails if it cannot transform the trace. """
    user_code = not jitdriver_sd.vec and warmstate.vec_all
    e = len(loop_ops)-1
    assert e > 0
    assert rop.is_final(loop_ops[e].getopnum())
    loop = VectorLoop(loop_info.label_op, loop_ops[:e], loop_ops[-1])
    if user_code and user_loop_bail_fast_path(loop, warmstate):
        return loop_info, loop_ops
    # the original loop (output of optimize_unroll)
    info = LoopVersionInfo(loop_info)
    version = info.snapshot(loop)
    loop.setup_vectorization()
    try:
        debug_start("vec-opt-loop")
        metainterp_sd.logger_noopt.log_loop([], loop.finaloplist(label=True), -2, None, None, "pre vectorize")
        metainterp_sd.profiler.count(Counters.OPT_VECTORIZE_TRY)
        #
        start = time.clock()
        opt = VectorizingOptimizer(metainterp_sd, jitdriver_sd, warmstate.vec_cost)
        oplist = opt.run_optimization(metainterp_sd, info, loop, jitcell_token, user_code)
        end = time.clock()
        #
        metainterp_sd.profiler.count(Counters.OPT_VECTORIZED)
        metainterp_sd.logger_noopt.log_loop([], loop.finaloplist(label=True), -2, None, None, "post vectorize")
        nano = int((end-start)*10.0**9)
        debug_print("# vecopt factor: %d opcount: (%d -> %d) took %dns" % \
                      (opt.unroll_count+1, len(version.loop.operations), len(loop.operations), nano))
        debug_stop("vec-opt-loop")
        #
        info.label_op = loop.label
        return info, oplist
    except NotAVectorizeableLoop:
        debug_stop("vec-opt-loop")
        # vectorization is not possible
        return loop_info, version.loop.finaloplist()
    except NotAProfitableLoop:
        debug_stop("vec-opt-loop")
        debug_print("failed to vectorize loop, cost model indicated it is not profitable")
        # cost model says to skip this loop
        return loop_info, version.loop.finaloplist()
    except Exception as e:
        debug_stop("vec-opt-loop")
        debug_print("failed to vectorize loop. THIS IS A FATAL ERROR!")
        if we_are_translated():
            llop.debug_print_traceback(lltype.Void)
        else:
            raise
    finally:
        loop.teardown_vectorization()
    return loop_info, loop_ops

def user_loop_bail_fast_path(loop, warmstate):
    """ In a fast path over the trace loop: try to prevent vecopt
        of spending time on a loop that will most probably fail.
    """

    resop_count = 0 # the count of operations minus debug_merge_points
    vector_instr = 0
    guard_count = 0
    at_least_one_array_access = True
    for i,op in enumerate(loop.operations):
        if rop.is_jit_debug(op.opnum):
            continue

        if op.vector >= 0 and not rop.is_guard(op.opnum):
            vector_instr += 1

        resop_count += 1

        if op.is_primitive_array_access():
            at_least_one_array_access = True

        if rop.is_call(op.opnum) or rop.is_call_assembler(op.opnum):
            return True

        if rop.is_guard(op.opnum):
            guard_count += 1

    if not at_least_one_array_access:
        return True

    return False

class VectorizingOptimizer(Optimizer):
    """ Try to unroll the loop and find instructions to group """

    def __init__(self, metainterp_sd, jitdriver_sd, cost_threshold):
        Optimizer.__init__(self, metainterp_sd, jitdriver_sd)
        self.cpu = metainterp_sd.cpu
        self.vector_ext = self.cpu.vector_ext
        self.cost_threshold = cost_threshold
        self.packset = None
        self.unroll_count = 0
        self.smallest_type_bytes = 0
        self.orig_label_args = None

    def run_optimization(self, metainterp_sd, info, loop, jitcell_token, user_code):
        self.orig_label_args = loop.label.getarglist_copy()
        self.linear_find_smallest_type(loop)
        byte_count = self.smallest_type_bytes
        vsize = self.vector_ext.vec_size()
        # stop, there is no chance to vectorize this trace
            # we cannot optimize normal traces (if there is no label)
        if vsize == 0:
            debug_print("vector size is zero")
            raise NotAVectorizeableLoop
        if byte_count == 0:
            debug_print("could not find smallest type")
            raise NotAVectorizeableLoop
        if loop.label.getopnum() != rop.LABEL:
            debug_print("not a loop, can only vectorize loops")
            raise NotAVectorizeableLoop
        # find index guards and move to the earliest position
        graph = self.analyse_index_calculations(loop)
        if graph is not None:
            state = SchedulerState(metainterp_sd.cpu, graph)
            self.schedule(state) # reorder the trace

        # unroll
        self.unroll_count = self.get_unroll_count(vsize)
        align_unroll = self.unroll_count==1 and \
                       self.vector_ext.should_align_unroll
        self.unroll_loop_iterations(loop, self.unroll_count,
                                    align_unroll_once=align_unroll)

        # vectorize
        graph = DependencyGraph(loop)
        self.find_adjacent_memory_refs(graph)
        self.extend_packset()
        self.combine_packset()
        costmodel = GenericCostModel(self.cpu, self.cost_threshold)
        state = VecScheduleState(graph, self.packset, self.cpu, costmodel)
        self.schedule(state)
        if not state.profitable():
            raise NotAProfitableLoop
        gso = GuardStrengthenOpt(graph.index_vars)
        gso.propagate_all_forward(info, loop, user_code)

        # re-schedule the trace -> removes many pure operations
        graph = DependencyGraph(loop)
        state = SchedulerState(self.cpu, graph)
        state.schedule()

        info.extra_before_label = loop.align_operations
        for op in loop.align_operations:
            op.set_forwarded(None)

        return loop.finaloplist(jitcell_token=jitcell_token, reset_label_token=False)

    def unroll_loop_iterations(self, loop, unroll_count, align_unroll_once=False):
        """ Unroll the loop `unroll_count` times. There can be an additional unroll step
            if alignment might benefit """
        numops = len(loop.operations)

        renamer = Renamer()
        operations = loop.operations
        orig_jump_args = loop.jump.getarglist()[:]
        prohibit_opnums = (rop.GUARD_FUTURE_CONDITION,
                           rop.GUARD_NOT_INVALIDATED,
                           rop.DEBUG_MERGE_POINT)
        unrolled = []

        if align_unroll_once:
            unroll_count += 1

        # it is assumed that #label_args == #jump_args
        label_arg_count = len(orig_jump_args)
        label = loop.label
        jump = loop.jump
        new_label = loop.label
        for u in range(unroll_count):
            # fill the map with the renaming boxes. keys are boxes from the label
            for i in range(label_arg_count):
                la = label.getarg(i)
                ja = jump.getarg(i)
                ja = renamer.rename_box(ja)
                if la != ja:
                    renamer.start_renaming(la, ja)
            #
            for i, op in enumerate(operations):
                if op.getopnum() in prohibit_opnums:
                    continue # do not unroll this operation twice
                copied_op = copy_resop(op)
                if not copied_op.returns_void():
                    # every result assigns a new box, thus creates an entry
                    # to the rename map.
                    renamer.start_renaming(op, copied_op)
                #
                args = copied_op.getarglist()
                for a, arg in enumerate(args):
                    value = renamer.rename_box(arg)
                    copied_op.setarg(a, value)
                # not only the arguments, but also the fail args need
                # to be adjusted. rd_snapshot stores the live variables
                # that are needed to resume.
                if copied_op.is_guard():
                    self.copy_guard_descr(renamer, copied_op)
                #
                unrolled.append(copied_op)
            #
            if align_unroll_once and u == 0:
                descr = label.getdescr()
                args = label.getarglist()[:]
                new_label = ResOperation(rop.LABEL, args, descr)
                renamer.rename(new_label)
            #

        # the jump arguments have been changed
        # if label(iX) ... jump(i(X+1)) is called, at the next unrolled loop
        # must look like this: label(i(X+1)) ... jump(i(X+2))
        args = loop.jump.getarglist()
        for i, arg in enumerate(args):
            value = renamer.rename_box(arg)
            loop.jump.setarg(i, value)
        #
        loop.label = new_label
        if align_unroll_once:
            loop.align_operations = operations
            loop.operations = unrolled
        else:
            loop.operations = operations + unrolled

    def copy_guard_descr(self, renamer, copied_op):
        descr = copied_op.getdescr()
        if descr:
            assert isinstance(descr, ResumeDescr)
            copied_op.setdescr(descr.clone())
            failargs = renamer.rename_failargs(copied_op, clone=True)
            if not we_are_translated():
                for arg in failargs:
                    if arg is None:
                        continue
                    assert not arg.is_constant()
            copied_op.setfailargs(failargs)

    def linear_find_smallest_type(self, loop):
        # O(#operations)
        for i,op in enumerate(loop.operations):
            if op.is_primitive_array_access():
                descr = op.getdescr()
                byte_count = descr.get_item_size_in_bytes()
                if self.smallest_type_bytes == 0 \
                   or byte_count < self.smallest_type_bytes:
                    self.smallest_type_bytes = byte_count

    def get_unroll_count(self, simd_vec_reg_bytes):
        """ This is an estimated number of further unrolls """
        # this optimization is not opaque, and needs info about the CPU
        byte_count = self.smallest_type_bytes
        if byte_count == 0:
            return 0
        unroll_count = simd_vec_reg_bytes // byte_count
        return unroll_count-1 # it is already unrolled once

    def find_adjacent_memory_refs(self, graph):
        """ The pre pass already builds a hash of memory references and the
            operations. Since it is in SSA form there are no array indices.
            If there are two array accesses in the unrolled loop
            i0,i1 and i1 = int_add(i0,c), then i0 = i0 + 0, i1 = i0 + 1.
            They are represented as a linear combination: i*c/d + e, i is a variable,
            all others are integers that are calculated in reverse direction
        """
        loop = graph.loop
        operations = loop.operations

        self.packset = PackSet(self.vector_ext.vec_size())
        memory_refs = graph.memory_refs.items()
        # initialize the pack set
        for node_a,memref_a in memory_refs:
            for node_b,memref_b in memory_refs:
                if memref_a is memref_b:
                    continue
                # instead of compare every possible combination and
                # exclue a_opidx == b_opidx only consider the ones
                # that point forward:
                if memref_a.is_adjacent_after(memref_b):
                    pair = self.packset.can_be_packed(node_a, node_b, None, False)
                    if pair:
                        self.packset.add_pack(pair)

    def extend_packset(self):
        """ Follow dependency chains to find more candidates to put into
            pairs.
        """
        pack_count = self.packset.pack_count()
        while True:
            i = 0
            packs = self.packset.packs
            while i < len(packs):
                pack = packs[i]
                self.follow_def_uses(pack)
                i += 1
            if pack_count == self.packset.pack_count():
                pack_count = self.packset.pack_count()
                i = 0
                while i < len(packs):
                    pack = packs[i]
                    self.follow_use_defs(pack)
                    i += 1
                if pack_count == self.packset.pack_count():
                    break
            pack_count = self.packset.pack_count()

    def follow_use_defs(self, pack):
        assert pack.numops() == 2
        for ldep in pack.leftmost(True).depends():
            for rdep in pack.rightmost(True).depends():
                lnode = ldep.to
                rnode = rdep.to
                # only valid if left is in args of pack left
                left = lnode.getoperation()
                args = pack.leftmost().getarglist()
                if left is None or left not in args:
                    continue
                isomorph = isomorphic(lnode.getoperation(), rnode.getoperation())
                if isomorph and lnode.is_before(rnode):
                    pair = self.packset.can_be_packed(lnode, rnode, pack, False)
                    if pair:
                        self.packset.add_pack(pair)

    def follow_def_uses(self, pack):
        assert pack.numops() == 2
        for ldep in pack.leftmost(node=True).provides():
            for rdep in pack.rightmost(node=True).provides():
                lnode = ldep.to
                rnode = rdep.to
                left = pack.leftmost()
                args = lnode.getoperation().getarglist()
                if left is None or left not in args:
                    continue
                isomorph = isomorphic(lnode.getoperation(), rnode.getoperation())
                if isomorph and lnode.is_before(rnode):
                    pair = self.packset.can_be_packed(lnode, rnode, pack, True)
                    if pair:
                        self.packset.add_pack(pair)

    def combine_packset(self):
        """ Combination is done iterating the packs that have
            a sorted op index of the first operation (= left).
            If a pack is marked as 'full', the next pack that is
            encountered having the full_pack.right == pack.left,
            the pack is removed. This is because the packs have
            intersecting edges.
        """
        if len(self.packset.packs) == 0:
            debug_print("packset is empty")
            raise NotAVectorizeableLoop
        i = 0
        j = 0
        end_ij = len(self.packset.packs)
        while True:
            len_before = len(self.packset.packs)
            i = 0
            while i < end_ij:
                while j < end_ij and i < end_ij:
                    if i == j:
                        # do not pack with itself! won't work...
                        j += 1
                        continue
                    pack1 = self.packset.packs[i]
                    pack2 = self.packset.packs[j]
                    if pack1.rightmost_match_leftmost(pack2):
                        end_ij = self.packset.combine(i,j)
                    else:
                        # do not inc in rightmost_match_leftmost
                        # this could miss some pack
                        j += 1
                i += 1
                j = 0
            if len_before == len(self.packset.packs):
                break

        self.packset.split_overloaded_packs(self.cpu.vector_ext)

        if not we_are_translated():
            # some test cases check the accumulation variables
            self.packset.accum_vars = {}
            print "packs:"
            check = {}
            fail = False
            for pack in self.packset.packs:
                left = pack.operations[0]
                right = pack.operations[-1]
                if left in check or right in check:
                    fail = True
                check[left] = None
                check[right] = None
                print " ", pack
            if fail:
                assert False

    def schedule(self, state):
        state.prepare()
        scheduler = Scheduler()
        scheduler.walk_and_emit(state)
        if not state.profitable():
            return
        state.post_schedule()

    def analyse_index_calculations(self, loop):
        """ Tries to move guarding instructions an all the instructions that
            need to be computed for the guard to the loop header. This ensures
            that guards fail 'early' and relax dependencies. Without this
            step vectorization would not be possible!
        """
        graph = DependencyGraph(loop)
        zero_deps = {}
        for node in graph.nodes:
            if node.depends_count() == 0:
                zero_deps[node] = 0
        earlyexit = graph.imaginary_node("early exit")
        guards = graph.guards
        one_valid = False
        valid_guards = []
        for guard_node in guards:
            modify_later = []
            last_prev_node = None
            valid = True
            if guard_node in zero_deps:
                del zero_deps[guard_node]
            for prev_dep in guard_node.depends():
                prev_node = prev_dep.to
                if prev_dep.is_failarg():
                    # remove this edge later.
                    # 1) only because of failing, this dependency exists
                    # 2) non pure operation points to this guard.
                    #    but if this guard only depends on pure operations, it can be checked
                    #    at an earlier position, the non pure op can execute later!
                    modify_later.append(prev_node)
                else:
                    for path in prev_node.iterate_paths(None, backwards=True, blacklist=True):
                        if not path.is_always_pure():
                            valid = False
                        else:
                            if path.last() in zero_deps:
                                del zero_deps[path.last()]
                    if not valid:
                        break
            if valid:
                # transformation is valid, modify the graph and execute
                # this guard earlier
                one_valid = True
                for node in modify_later:
                    node.remove_edge_to(guard_node)
                # every edge that starts in the guard, the early exit
                # inherts the edge and guard then provides to early exit
                for dep in guard_node.provides()[:]:
                    assert not dep.target_node().is_imaginary()
                    earlyexit.edge_to(dep.target_node(), failarg=True)
                    guard_node.remove_edge_to(dep.target_node())
                valid_guards.append(guard_node)

                guard_node.edge_to(earlyexit)
                self.mark_guard(guard_node, loop)
        for node in zero_deps.keys():
            assert not node.is_imaginary()
            earlyexit.edge_to(node)
        if one_valid:
            return graph
        return None

    def mark_guard(self, node, loop):
        """ Marks this guard as an early exit! """
        op = node.getoperation()
        assert isinstance(op, GuardResOp)
        if op.getopnum() in (rop.GUARD_TRUE, rop.GUARD_FALSE):
            descr = CompileLoopVersionDescr()
            olddescr = op.getdescr()
            if olddescr:
                descr.copy_all_attributes_from(olddescr)
            op.setdescr(descr)
        arglistcopy = loop.label.getarglist_copy()
        if not we_are_translated():
            for arg in arglistcopy:
                assert not arg.is_constant()
        op.setfailargs(arglistcopy)

class CostModel(object):
    """ Utility to estimate the savings for the new trace loop.
        The main reaons to have this is of frequent unpack instructions,
        and the missing ability (by design) to detect not vectorizable loops.
    """
    def __init__(self, cpu, threshold):
        self.threshold = threshold
        self.vec_reg_size = cpu.vector_ext.vec_size()
        self.savings = 0

    def reset_savings(self):
        self.savings = 0

    def record_cast_int(self, op):
        raise NotImplementedError

    def record_pack_savings(self, pack, times):
        raise NotImplementedError

    def record_vector_pack(self, box, index, count):
        raise NotImplementedError

    def record_vector_unpack(self, box, index, count):
        raise NotImplementedError

    def unpack_cost(self, op, index, count):
        raise NotImplementedError

    def savings_for_pack(self, pack, times):
        raise NotImplementedError

    def profitable(self):
        return self.savings >= 0

class GenericCostModel(CostModel):
    def record_pack_savings(self, pack, times):
        cost, benefit_factor = (1,1)
        node = pack.operations[0]
        op = node.getoperation()
        if op.getopnum() == rop.INT_SIGNEXT:
            cost, benefit_factor = self.cb_signext(pack)
        #
        self.savings += benefit_factor * times - cost

    def cb_signext(self, pack):
        left = pack.leftmost()
        if left.cast_to_bytesize() == left.cast_from_bytesize():
            return 0, 0
        # no benefit for this operation! needs many x86 instrs
        return 1,0

    def record_cast_int(self, fromsize, tosize, count):
        # for each move there is 1 instruction
        if fromsize == 8 and tosize == 4 and count == 2:
            self.savings -= 1
        else:
            self.savings += -count

    def record_vector_pack(self, src, index, count):
        vecinfo = forwarded_vecinfo(src)
        if vecinfo.datatype == FLOAT:
            if index == 1 and count == 1:
                self.savings -= 2
                return
        self.savings -= count

    def record_vector_unpack(self, src, index, count):
        self.record_vector_pack(src, index, count)

def isomorphic(l_op, r_op):
    """ Subject of definition, here it is equal operation.
        See limintations (vectorization.rst).
    """
    if l_op.getopnum() == r_op.getopnum():
        l_vecinfo = forwarded_vecinfo(l_op)
        r_vecinfo = forwarded_vecinfo(r_op)
        return l_vecinfo.bytesize == r_vecinfo.bytesize
    return False

class PackSet(object):
    _attrs_ = ('packs', 'vec_reg_size')
    def __init__(self, vec_reg_size):
        self.packs = []
        self.vec_reg_size = vec_reg_size

    def pack_count(self):
        return len(self.packs)

    def add_pack(self, pack):
        self.packs.append(pack)

    def can_be_packed(self, lnode, rnode, origin_pack, forward):
        """ Check to ensure that two nodes might be packed into a Pair.
        """
        if isomorphic(lnode.getoperation(), rnode.getoperation()):
            # even if a guard depends on the previous it is able to
            lop = lnode.getoperation()
            independent = lnode.independent(rnode)
            if independent:
                if forward and origin_pack.is_accumulating():
                    # in this case the splitted accumulator must
                    # be combined. This case is not supported
                    debug_print("splitted accum must be flushed here (not supported)")
                    raise NotAVectorizeableLoop
                #
                if self.contains_pair(lnode, rnode):
                    return None
                #
                if origin_pack is None:
                    op = lnode.getoperation()
                    if rop.is_primitive_load(op.opnum):
                        return Pair(lnode, rnode)
                    else:
                        return Pair(lnode, rnode)
                if self.profitable_pack(lnode, rnode, origin_pack, forward):
                    return Pair(lnode, rnode)
            else:
                if self.contains_pair(lnode, rnode):
                    return None
                if origin_pack is not None:
                    return self.accumulates_pair(lnode, rnode, origin_pack)
        return None

    def contains_pair(self, lnode, rnode):
        for pack in self.packs:
            if pack.leftmost(node=True) is lnode or \
               pack.rightmost(node=True) is rnode:
                return True
        return False

    def profitable_pack(self, lnode, rnode, origin_pack, forward):
        if self.prohibit_packing(origin_pack, origin_pack.leftmost(),
                                 lnode.getoperation(), forward):
            return False
        if self.prohibit_packing(origin_pack, origin_pack.rightmost(),
                                 rnode.getoperation(), forward):
            return False
        return True

    def prohibit_packing(self, pack, packed, inquestion, forward):
        """ Blocks the packing of some operations """
        if inquestion.vector == -1:
            return True
        if packed.is_primitive_array_access():
            if packed.getarg(1) is inquestion:
                return True
        if not forward and inquestion.getopnum() == rop.INT_SIGNEXT:
            # prohibit the packing of signext in backwards direction
            # the type cannot be determined!
            return True
        return False

    def combine(self, i, j):
        """ Combine two packs. It is assumed that the attribute self.packs
            is not iterated when calling this method.
        """
        pkg_a = self.packs[i]
        pkg_b = self.packs[j]
        operations = pkg_a.operations
        for op in pkg_b.operations[1:]:
            operations.append(op)
        self.packs[i] = pkg_a.clone(operations)
        del self.packs[j]
        return len(self.packs)

    def accumulates_pair(self, lnode, rnode, origin_pack):
        # lnode and rnode are isomorphic and dependent
        assert isinstance(origin_pack, Pair)
        left = lnode.getoperation()
        opnum = left.getopnum()

        if opnum in AccumPack.SUPPORTED:
            right = rnode.getoperation()
            assert left.numargs() == 2 and not left.returns_void()
            scalar, index = self.getaccumulator_variable(left, right, origin_pack)
            if not scalar:
                return None
            # the dependency exists only because of the left?
            for dep in lnode.provides():
                if dep.to is rnode:
                    if not dep.because_of(scalar):
                        # not quite ... this is not handlable
                        return None
            # get the original variable
            scalar = left.getarg(index)

            # in either of the two cases the arguments are mixed,
            # which is not handled currently
            other_index = (index + 1) % 2
            if left.getarg(other_index) is not origin_pack.leftmost():
                return None
            if right.getarg(other_index) is not origin_pack.rightmost():
                return None

            # this can be handled by accumulation
            size = INT_WORD
            if left.type == 'f':
                size = FLOAT_WORD
            l_vecinfo = forwarded_vecinfo(left)
            r_vecinfo = forwarded_vecinfo(right)
            if not (l_vecinfo.bytesize == r_vecinfo.bytesize and l_vecinfo.bytesize == size):
                # do not support if if the type size is smaller
                # than the cpu word size.
                # WHY?
                # to ensure accum is done on the right size, the dependencies
                # of leading/preceding signext/floatcast instructions needs to be
                # considered. => tree pattern matching problem.
                return None
            operator = AccumPack.SUPPORTED[opnum]
            return AccumPack([lnode, rnode], operator, index)
        is_guard = left.is_guard() and left.getopnum() in (rop.GUARD_TRUE, rop.GUARD_FALSE)
        if is_guard:
            return AccumPack([lnode, rnode], 'g', 0)

        return None

    def getaccumulator_variable(self, left, right, origin_pack):
        for i, arg in enumerate(right.getarglist()):
            if arg is left:
                return arg, i
        return None, -1

    def accumulate_prepare(self, state):
        vec_reg_size = state.vec_reg_size
        for pack in self.packs:
            if not pack.is_accumulating():
                continue
            if pack.leftmost().is_guard():
                # guard breaks dependencies, thus it is an accumulation pack
                continue
            for i,node in enumerate(pack.operations):
                op = node.getoperation()
                state.accumulation[op] = pack
            assert isinstance(pack, AccumPack)
            datatype = pack.getdatatype()
            bytesize = pack.getbytesize()
            count = vec_reg_size // bytesize
            signed = datatype == 'i'
            oplist = state.invariant_oplist
            # reset the box to zeros or ones
            if pack.reduce_init() == 0:
                vecop = OpHelpers.create_vec(datatype, bytesize, signed, count)
                oplist.append(vecop)
                opnum = rop.VEC_INT_XOR
                if datatype == FLOAT:
                    # see PRECISION loss below
                    raise NotImplementedError
                vecop = VecOperation(opnum, [vecop, vecop],
                                     vecop, count)
                oplist.append(vecop)
            elif pack.reduce_init() == 1:
                # PRECISION loss, because the numbers are accumulated (associative, commutative properties must hold)
                # you can end up a small number and a huge number that is finally multiplied. giving an
                # inprecision result, thus this is disabled now
                raise NotImplementedError
                # multiply is only supported by floats
                vecop = OpHelpers.create_vec_expand(ConstFloat(1.0), bytesize,
                                                    signed, count)
                oplist.append(vecop)
            else:
                raise NotImplementedError("cannot handle %s" % pack.operator)
            # pack the scalar value
            args = [vecop, pack.getleftmostseed(), ConstInt(0), ConstInt(1)]
            vecop = OpHelpers.create_vec_pack(datatype, args, bytesize,
                                              signed, count)
            oplist.append(vecop)
            seed = pack.getleftmostseed()
            state.accumulation[seed] = pack
            # rename the variable with the box
            state.setvector_of_box(seed, 0, vecop) # prevent it from expansion
            state.renamer.start_renaming(seed, vecop)

    def split_overloaded_packs(self, vector_ext):
        newpacks = []
        for i,pack in enumerate(self.packs):
            load = pack.pack_load(self.vec_reg_size)
            if load > Pack.FULL:
                pack.split(newpacks, self.vec_reg_size, vector_ext)
                continue
            if load < Pack.FULL:
                for op in pack.operations:
                    op.priority = -100
                pack.clear()
                self.packs[i] = None
                continue
        self.packs = [pack for pack in self.packs + newpacks if pack]

