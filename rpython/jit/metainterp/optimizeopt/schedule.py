from rpython.jit.backend.llsupport.rewrite import cpu_simplify_scale
from rpython.jit.metainterp.history import (VECTOR, FLOAT, INT,
        ConstInt, ConstFloat, TargetToken)
from rpython.jit.metainterp.resoperation import (rop, ResOperation,
        GuardResOp, VecOperation, OpHelpers, VecOperationNew,
        VectorizationInfo)
from rpython.jit.metainterp.optimizeopt.dependency import (DependencyGraph,
        MemoryRef, Node, IndexVar)
from rpython.jit.metainterp.optimizeopt.renamer import Renamer
from rpython.jit.metainterp.resume import AccumInfo
from rpython.rlib.objectmodel import we_are_translated
from rpython.jit.metainterp.jitexc import NotAProfitableLoop
from rpython.rlib.objectmodel import specialize, always_inline
from rpython.jit.metainterp.jitexc import NotAVectorizeableLoop, NotAProfitableLoop
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem import lltype
from rpython.rlib.debug import debug_print


def forwarded_vecinfo(op):
    fwd = op.get_forwarded()
    if fwd is None or not isinstance(fwd, VectorizationInfo):
        # the optimizer clears getforwarded AFTER
        # vectorization, it happens that this is not clean
        fwd = VectorizationInfo(op)
        if not op.is_constant():
            op.set_forwarded(fwd)
    return fwd

class SchedulerState(object):
    def __init__(self, cpu, graph):
        self.cpu = cpu
        self.renamer = Renamer()
        self.graph = graph
        self.oplist = []
        self.worklist = []
        self.invariant_oplist = []
        self.invariant_vector_vars = []
        self.seen = {}
        self.delayed = []

    def resolve_delayed(self, needs_resolving, delayed, op):
        # recursive solving of all delayed objects
        if not delayed:
            return
        args = op.getarglist()
        if op.is_guard():
            args = args[:] + op.getfailargs()
        for arg in args:
            if arg is None or arg.is_constant() or arg.is_inputarg():
                continue
            if arg not in self.seen:
                box = self.renamer.rename_box(arg)
                needs_resolving[box] = None

        indexvars = self.graph.index_vars
        i = len(delayed)-1
        while i >= 0:
            node = delayed[i]
            op = node.getoperation()
            if op in needs_resolving:
                # either it is a normal operation, or we know that there is a linear combination
                del needs_resolving[op]
                if op in indexvars:
                    opindexvar = indexvars[op]
                    # there might be a variable already, that
                    # calculated the index variable, thus just reuse it
                    for var, indexvar in indexvars.items(): 
                        if indexvar == opindexvar and var in self.seen:
                            self.renamer.start_renaming(op, var)
                            break
                    else:
                        if opindexvar.calculated_by(op):
                            # just append this operation
                            self.seen[op] = None
                            self.append_to_oplist(op)
                        else:
                            # here is an easier way to calculate just this operation
                            last = op
                            for operation in opindexvar.get_operations():
                                self.append_to_oplist(operation)
                                last = operation
                            indexvars[last] = opindexvar
                            self.renamer.start_renaming(op, last)
                            self.seen[op] = None
                            self.seen[last] = None
                else: 
                    self.resolve_delayed(needs_resolving, delayed, op)
                    self.append_to_oplist(op)
                    self.seen[op] = None
                if len(delayed) > i:
                    del delayed[i]
            i -= 1
            # some times the recursive call can remove several items from delayed,
            # thus we correct the index here
            if len(delayed) <= i:
                i = len(delayed)-1

    def append_to_oplist(self, op):
        self.renamer.rename(op)
        self.oplist.append(op)

    def schedule(self):
        self.prepare()
        Scheduler().walk_and_emit(self)
        self.post_schedule()

    def post_schedule(self):
        loop = self.graph.loop
        jump = loop.jump
        if self.delayed:
            # some operations can be delayed until the jump instruction,
            # handle them here
            self.resolve_delayed({}, self.delayed, jump)
        self.renamer.rename(jump)
        loop.operations = self.oplist

    def profitable(self):
        return True

    def prepare(self):
        for node in self.graph.nodes:
            if node.depends_count() == 0:
                self.worklist.insert(0, node)

    def try_emit_or_delay(self, node):
        if not node.is_imaginary() and node.is_pure():
            # this operation might never be emitted. only if it is really needed
            self.delay_emit(node)
            return
        # emit a now!
        self.pre_emit(node, True)
        self.mark_emitted(node)
        if not node.is_imaginary():
            op = node.getoperation()
            self.seen[op] = None
            self.append_to_oplist(op)

    def delay_emit(self, node):
        """ it has been decided that the operation might be scheduled later """
        delayed = node.delayed or []
        if node not in delayed:
            delayed.append(node)
        node.delayed = None
        provides = node.provides()
        if len(provides) == 0:
            for n in delayed:
                self.delayed.append(n)
        else:
            for to in node.provides():
                tnode = to.target_node()
                self.delegate_delay(tnode, delayed[:])
        self.mark_emitted(node)

    def delegate_delay(self, node, delayed):
        """ Chain up delays, this can reduce many more of the operations """
        if node.delayed is None:
            node.delayed = delayed
        else:
            delayedlist = node.delayed
            for d in delayed:
                if d not in delayedlist:
                    delayedlist.append(d)


    def mark_emitted(state, node, unpack=True):
        """ An operation has been emitted, adds new operations to the worklist
            whenever their dependency count drops to zero.
            Keeps worklist sorted (see priority) """
        worklist = state.worklist
        provides = node.provides()[:]
        for dep in provides: # COPY
            target = dep.to
            node.remove_edge_to(target)
            if not target.emitted and target.depends_count() == 0:
                # sorts them by priority
                i = len(worklist)-1
                while i >= 0:
                    cur = worklist[i]
                    c = (cur.priority - target.priority)
                    if c < 0: # meaning itnode.priority < target.priority:
                        worklist.insert(i+1, target)
                        break
                    elif c == 0:
                        # if they have the same priority, sort them
                        # using the original position in the trace
                        if target.getindex() < cur.getindex():
                            worklist.insert(i+1, target)
                            break
                    i -= 1
                else:
                    worklist.insert(0, target)
        node.clear_dependencies()
        node.emitted = True
        if not node.is_imaginary():
            op = node.getoperation()
            state.renamer.rename(op)
            if unpack:
                state.ensure_args_unpacked(op)
            state.post_emit(node)


    def delay(self, node):
        return False

    def has_more(self):
        return len(self.worklist) > 0

    def ensure_args_unpacked(self, op):
        pass

    def post_emit(self, node):
        pass

    def pre_emit(self, orignode, pack_first=True):
        delayed = orignode.delayed
        if delayed:
            # there are some nodes that have been delayed just for this operation
            if pack_first:
                op = orignode.getoperation()
                self.resolve_delayed({}, delayed, op)

            for node in delayed:
                op = node.getoperation()
                if op in self.seen:
                    continue
                if node is not None:
                    provides = node.provides()
                    if len(provides) == 0:
                        # add this node to the final delay list
                        # might be emitted before jump!
                        self.delayed.append(node)
                    else:
                        for to in node.provides():
                            tnode = to.target_node()
                            self.delegate_delay(tnode, [node])
            orignode.delayed = None

class Scheduler(object):
    """ Create an instance of this class to (re)schedule a vector trace. """
    def __init__(self):
        pass

    def next(self, state):
        """ select the next candidate node to be emitted, or None """
        worklist = state.worklist
        visited = 0
        while len(worklist) > 0:
            if visited == len(worklist):
                return None
            node = worklist.pop()
            if node.emitted:
                continue
            if not self.delay(node, state):
                return node
            worklist.insert(0, node)
            visited += 1
        return None

    def try_to_trash_pack(self, state):
        # one element a pack has several dependencies pointing to
        # it thus we MUST skip this pack!
        if len(state.worklist) > 0:
            # break the first!
            i = 0
            node = state.worklist[i]
            i += 1
            while i < len(state.worklist) and not node.pack:
                node = state.worklist[i]
                i += 1

            if not node.pack:
                return False

            pack = node.pack
            for n in node.pack.operations:
                if n.depends_count() > 0:
                    pack.clear()
                    return True
            else:
                return False

        return False

    def delay(self, node, state):
        """ Delay this operation?
            Only if any dependency has not been resolved """
        if state.delay(node):
            return True
        return node.depends_count() != 0

    def walk_and_emit(self, state):
        """ Emit all the operations into the oplist parameter.
            Initiates the scheduling. """
        assert isinstance(state, SchedulerState)
        while state.has_more():
            node = self.next(state)
            if node:
                state.try_emit_or_delay(node)
                continue

            # it happens that packs can emit many nodes that have been
            # added to the scheuldable_nodes list, in this case it could
            # be that no next exists even though the list contains elements
            if not state.has_more():
                break

            if self.try_to_trash_pack(state):
                continue

            raise AssertionError("schedule failed cannot continue. possible reason: cycle")

        if not we_are_translated():
            for node in state.graph.nodes:
                assert node.emitted

def failnbail_transformation(msg):
    msg = '%s\n' % msg
    debug_print(msg)
    raise NotAVectorizeableLoop

def turn_into_vector(state, pack):
    """ Turn a pack into a vector instruction """
    check_if_pack_supported(state, pack)
    state.costmodel.record_pack_savings(pack, pack.numops())
    left = pack.leftmost()
    oprestrict = state.cpu.vector_ext.get_operation_restriction(left)
    if oprestrict is not None:
        newargs = oprestrict.check_operation(state, pack, left)
        if newargs:
            args = newargs
        else:
            args = left.getarglist_copy()
    else:
        args = left.getarglist_copy()
    prepare_arguments(state, oprestrict, pack, args)
    vecop = VecOperation(left.vector, args, left,
                         pack.numops(), left.getdescr())

    for i,node in enumerate(pack.operations):
        op = node.getoperation()
        if op.returns_void():
            continue
        state.setvector_of_box(op,i,vecop)
        if pack.is_accumulating() and not op.is_guard():
            state.renamer.start_renaming(op, vecop)
    if left.is_guard():
        prepare_fail_arguments(state, pack, left, vecop)
    state.append_to_oplist(vecop)
    assert vecop.count >= 1

def prepare_arguments(state, oprestrict, pack, args):
    # Transforming one argument to a vector box argument
    # The following cases can occur:
    # 1) argument is present in the box_to_vbox map.
    #    a) vector can be reused immediatly (simple case)
    #    b) the size of the input is mismatching (crop the vector)
    #    c) values are scattered in differnt registers
    #    d) the operand is not at the right position in the vector
    # 2) argument is not known to reside in a vector
    #    a) expand vars/consts before the label and add as argument
    #    b) expand vars created in the loop body
    #
    if not oprestrict:
        return
    restrictions = oprestrict.argument_restrictions
    for i,arg in enumerate(args):
        if i >= len(restrictions) or restrictions[i] is None:
            # ignore this argument
            continue
        restrict = restrictions[i]
        if arg.returns_vector():
            restrict.check(arg)
            continue
        pos, vecop = state.getvector_of_box(arg)
        if not vecop:
            # 2) constant/variable expand this box
            expand(state, pack, args, arg, i)
            restrict.check(args[i])
            continue
        # 1)
        args[i] = vecop # a)
        assemble_scattered_values(state, pack, args, i) # c)
        position_values(state, restrict, pack, args, i, pos) # d)
        crop_vector(state, oprestrict, restrict, pack, args, i) # b)
        restrict.check(args[i])

def prepare_fail_arguments(state, pack, left, vecop):
    assert isinstance(left, GuardResOp)
    assert isinstance(vecop, GuardResOp)
    args = left.getfailargs()[:]
    for i, arg in enumerate(args):
        pos, newarg = state.getvector_of_box(arg)
        if newarg is None:
            newarg = arg
        if newarg.is_vector(): # can be moved to guard exit!
            newarg = unpack_from_vector(state, newarg, 0, 1)
        args[i] = newarg
    vecop.setfailargs(args)
    # TODO vecop.rd_snapshot = left.rd_snapshot

@always_inline
def crop_vector(state, oprestrict, restrict, pack, args, i):
    # convert size i64 -> i32, i32 -> i64, ...
    arg = args[i]
    vecinfo = forwarded_vecinfo(arg)
    size = vecinfo.bytesize
    left = pack.leftmost()
    if oprestrict.must_crop_vector(left, i):
        newsize = oprestrict.crop_to_size(left, i)
        assert arg.type == 'i'
        state._prevent_signext(newsize, size)
        count = vecinfo.count
        vecop = VecOperationNew(rop.VEC_INT_SIGNEXT, [arg, ConstInt(newsize)],
                                'i', newsize, vecinfo.signed, count)
        state.append_to_oplist(vecop)
        state.costmodel.record_cast_int(size, newsize, count)
        args[i] = vecop

@always_inline
def assemble_scattered_values(state, pack, args, index):
    args_at_index = [node.getoperation().getarg(index) for node in pack.operations]
    args_at_index[0] = args[index]
    vectors = pack.argument_vectors(state, pack, index, args_at_index)
    if len(vectors) > 1:
        # the argument is scattered along different vector boxes
        args[index] = gather(state, vectors, pack.numops())
        state.remember_args_in_vector(pack, index, args[index])

@always_inline
def gather(state, vectors, count): # packed < packable and packed < stride:
    (_, arg) = vectors[0]
    i = 1
    while i < len(vectors):
        (newarg_pos, newarg) = vectors[i]
        vecinfo = forwarded_vecinfo(arg)
        newvecinfo = forwarded_vecinfo(newarg)
        if vecinfo.count + newvecinfo.count <= count:
            arg = pack_into_vector(state, arg, vecinfo.count, newarg, newarg_pos, newvecinfo.count)
        i += 1
    return arg

@always_inline
def position_values(state, restrict, pack, args, index, position):
    arg = args[index]
    vecinfo = forwarded_vecinfo(arg)
    count = vecinfo.count
    newcount = restrict.count
    if not restrict.any_count() and newcount != count:
        if position == 0:
            pass
        pass
    if position != 0:
        # The vector box is at a position != 0 but it
        # is required to be at position 0. Unpack it!
        arg = args[index]
        vecinfo = forwarded_vecinfo(arg)
        count = restrict.max_input_count(vecinfo.count)
        args[index] = unpack_from_vector(state, arg, position, count)
        state.remember_args_in_vector(pack, index, args[index])

def check_if_pack_supported(state, pack):
    left = pack.leftmost()
    vecinfo = forwarded_vecinfo(left)
    insize = vecinfo.bytesize
    if left.is_typecast():
        # prohibit the packing of signext calls that
        # cast to int16/int8.
        state._prevent_signext(left.cast_to_bytesize(),
                               left.cast_from_bytesize())
    if left.getopnum() == rop.INT_MUL:
        if insize == 8 or insize == 1:
            # see assembler for comment why
            raise NotAProfitableLoop

def unpack_from_vector(state, arg, index, count):
    """ Extract parts of the vector box into another vector box """
    assert count > 0
    vecinfo = forwarded_vecinfo(arg)
    assert index + count <= vecinfo.count
    args = [arg, ConstInt(index), ConstInt(count)]
    vecop = OpHelpers.create_vec_unpack(arg.type, args, vecinfo.bytesize,
                                        vecinfo.signed, count)
    state.costmodel.record_vector_unpack(arg, index, count)
    state.append_to_oplist(vecop)
    return vecop

def pack_into_vector(state, tgt, tidx, src, sidx, scount):
    """ tgt = [1,2,3,4,_,_,_,_]
        src = [5,6,_,_]
        new_box = [1,2,3,4,5,6,_,_] after the operation, tidx=4, scount=2
    """
    assert sidx == 0 # restriction
    vecinfo = forwarded_vecinfo(tgt)
    newcount = vecinfo.count + scount
    args = [tgt, src, ConstInt(tidx), ConstInt(scount)]
    vecop = OpHelpers.create_vec_pack(tgt.type, args, vecinfo.bytesize, vecinfo.signed, newcount)
    state.append_to_oplist(vecop)
    state.costmodel.record_vector_pack(src, sidx, scount)
    if not we_are_translated():
        _check_vec_pack(vecop)
    return vecop

def _check_vec_pack(op):
    arg0 = op.getarg(0)
    arg1 = op.getarg(1)
    index = op.getarg(2)
    count = op.getarg(3)
    assert op.is_vector()
    assert arg0.is_vector()
    assert index.is_constant()
    assert isinstance(count, ConstInt)
    vecinfo = forwarded_vecinfo(op)
    argvecinfo = forwarded_vecinfo(arg0)
    assert argvecinfo.bytesize == vecinfo.bytesize
    if arg1.is_vector():
        assert argvecinfo.bytesize == vecinfo.bytesize
    else:
        assert count.value == 1
    assert index.value < vecinfo.count
    assert index.value + count.value <= vecinfo.count
    assert vecinfo.count > argvecinfo.count

def expand(state, pack, args, arg, index):
    """ Expand a value into a vector box. useful for arithmetic
        of one vector with a scalar (either constant/varialbe)
    """
    left = pack.leftmost()
    box_type = arg.type
    expanded_map = state.expanded_map

    ops = state.invariant_oplist
    variables = state.invariant_vector_vars
    if not arg.is_constant() and arg not in state.inputargs:
        # cannot be created before the loop, expand inline
        ops = state.oplist
        variables = None

    for i, node in enumerate(pack.operations):
        op = node.getoperation()
        if not arg.same_box(op.getarg(index)):
            break
        i += 1
    else:
        # note that heterogenous nodes are not yet tracked
        vecop = state.find_expanded([arg])
        if vecop:
            args[index] = vecop
            return vecop
        left = pack.leftmost()
        vecinfo = forwarded_vecinfo(left)
        vecop = OpHelpers.create_vec_expand(arg, vecinfo.bytesize, vecinfo.signed, pack.numops())
        ops.append(vecop)
        if variables is not None:
            variables.append(vecop)
        state.expand([arg], vecop)
        args[index] = vecop
        return vecop

    # quick search if it has already been expanded
    expandargs = [op.getoperation().getarg(index) for op in pack.operations]
    vecop = state.find_expanded(expandargs)
    if vecop:
        args[index] = vecop
        return vecop

    arg_vecinfo = forwarded_vecinfo(arg)
    vecop = OpHelpers.create_vec(arg.type, arg_vecinfo.bytesize, arg_vecinfo.signed, pack.opnum())
    ops.append(vecop)
    for i,node in enumerate(pack.operations):
        op = node.getoperation()
        arg = op.getarg(index)
        arguments = [vecop, arg, ConstInt(i), ConstInt(1)]
        vecinfo = forwarded_vecinfo(vecop)
        vecop = OpHelpers.create_vec_pack(arg.type, arguments, vecinfo.bytesize,
                                          vecinfo.signed, vecinfo.count+1)
        ops.append(vecop)
    state.expand(expandargs, vecop)

    if variables is not None:
        variables.append(vecop)
    args[index] = vecop

class VecScheduleState(SchedulerState):
    def __init__(self, graph, packset, cpu, costmodel):
        SchedulerState.__init__(self, cpu, graph)
        self.box_to_vbox = {}
        self.vec_reg_size = cpu.vector_ext.vec_size()
        self.expanded_map = {}
        self.costmodel = costmodel
        self.inputargs = {}
        self.packset = packset
        for arg in graph.loop.inputargs:
            self.inputargs[arg] = None
        self.accumulation = {}

    def expand(self, args, vecop):
        index = 0
        if len(args) == 1:
            # loop is executed once, thus sets -1 as index
            index = -1
        for arg in args:
            self.expanded_map.setdefault(arg, []).append((vecop, index))
            index += 1

    def find_expanded(self, args):
        if len(args) == 1:
            candidates = self.expanded_map.get(args[0], [])
            for (vecop, index) in candidates:
                if index == -1:
                    # found an expanded variable/constant
                    return vecop
            return None
        possible = {}
        for i, arg in enumerate(args):
            expansions = self.expanded_map.get(arg, [])
            candidates = [vecop for (vecop, index) in expansions \
                          if i == index and possible.get(vecop,True)]
            for vecop in candidates:
                for key in possible.keys():
                    if key not in candidates:
                        # delete every not possible key,value
                        possible[key] = False
                # found a candidate, append it if not yet present
                possible[vecop] = True

            if not possible:
                # no possibility left, this combination is not expanded
                return None
        for vecop,valid in possible.items():
            if valid:
                return vecop
        return None

    def post_emit(self, node):
        pass

    def pre_emit(self, node, pack_first=True):
        op = node.getoperation()
        if op.is_guard():
            # add accumulation info to the descriptor
            failargs = op.getfailargs()[:]
            descr = op.getdescr()
            # note: stitching a guard must resemble the order of the label
            # otherwise a wrong mapping is handed to the register allocator
            for i,arg in enumerate(failargs):
                if arg is None:
                    continue
                accum = self.accumulation.get(arg, None)
                if accum:
                    from rpython.jit.metainterp.compile import AbstractResumeGuardDescr
                    assert isinstance(accum, AccumPack)
                    assert isinstance(descr, AbstractResumeGuardDescr)
                    info = AccumInfo(i, arg, accum.operator)
                    descr.attach_vector_info(info)
                    seed = accum.getleftmostseed()
                    failargs[i] = self.renamer.rename_map.get(seed, seed)
            op.setfailargs(failargs)

        SchedulerState.pre_emit(self, node, pack_first)


    def profitable(self):
        return self.costmodel.profitable()

    def prepare(self):
        SchedulerState.prepare(self)
        self.packset.accumulate_prepare(self)
        for arg in self.graph.loop.label.getarglist():
            self.seen[arg] = None

    def try_emit_or_delay(self, node):
        # emission might be blocked by other nodes if this node has a pack!
        if node.pack:
            assert node.pack.numops() > 1
            for i,node in enumerate(node.pack.operations):
                self.pre_emit(node, i==0)
                self.mark_emitted(node, unpack=False)
            turn_into_vector(self, node.pack)
        elif not node.emitted:
            SchedulerState.try_emit_or_delay(self, node)

    def delay(self, node):
        if node.pack:
            pack = node.pack
            if pack.is_accumulating():
                for node in pack.operations:
                    for dep in node.depends():
                        if dep.to.pack is not pack:
                            return True
            else:
                for node in pack.operations:
                    if node.depends_count() > 0:
                        return True
        return False

    def ensure_args_unpacked(self, op):
        """ If a box is needed that is currently stored within a vector
            box, this utility creates a unpacking instruction.
        """
        # unpack for an immediate use
        for i, argument in enumerate(op.getarglist()):
            if not argument.is_constant():
                arg = self.ensure_unpacked(i, argument)
                if argument is not arg:
                    op.setarg(i, arg)
        # unpack for a guard exit
        if op.is_guard():
            # could be moved to the guard exit
            fail_args = op.getfailargs()
            for i, argument in enumerate(fail_args):
                if argument and not argument.is_constant():
                    arg = self.ensure_unpacked(i, argument)
                    if argument is not arg:
                        fail_args[i] = arg
            op.setfailargs(fail_args)

    def ensure_unpacked(self, index, arg):
        if arg in self.seen or arg.is_vector():
            return arg
        (pos, var) = self.getvector_of_box(arg)
        if var:
            if var in self.invariant_vector_vars:
                return arg
            if arg in self.accumulation:
                return arg
            args = [var, ConstInt(pos), ConstInt(1)]
            vecinfo = forwarded_vecinfo(var)
            vecop = OpHelpers.create_vec_unpack(var.type, args, vecinfo.bytesize,
                                                vecinfo.signed, 1)
            self.renamer.start_renaming(arg, vecop)
            self.seen[vecop] = None
            self.costmodel.record_vector_unpack(var, pos, 1)
            self.append_to_oplist(vecop)
            return vecop
        return arg

    def _prevent_signext(self, outsize, insize):
        if insize != outsize:
            if outsize < 4 or insize < 4:
                raise NotAProfitableLoop

    def getvector_of_box(self, arg):
        return self.box_to_vbox.get(arg, (-1, None))

    def setvector_of_box(self, var, off, vector):
        if var.returns_void():
            assert 0, "not allowed to rename void resop"
        vecinfo = forwarded_vecinfo(vector)
        assert off < vecinfo.count
        assert not var.is_vector()
        self.box_to_vbox[var] = (off, vector)

    def remember_args_in_vector(self, pack, index, box):
        arguments = [op.getoperation().getarg(index) for op in pack.operations]
        for i,arg in enumerate(arguments):
            vecinfo = forwarded_vecinfo(arg)
            if i >= vecinfo.count:
                break
            self.setvector_of_box(arg, i, box)

    def post_schedule(self):
        SchedulerState.post_schedule(self)
        loop = self.graph.loop
        self.ensure_args_unpacked(loop.jump)
        loop.prefix = self.invariant_oplist
        if len(self.invariant_vector_vars) + len(self.invariant_oplist) > 0:
            # label
            args = loop.label.getarglist_copy() + self.invariant_vector_vars
            opnum = loop.label.getopnum()
            op = loop.label.copy_and_change(opnum, args)
            self.renamer.rename(op)
            loop.prefix_label = op
            # jump
            args = loop.jump.getarglist_copy() + self.invariant_vector_vars
            opnum = loop.jump.getopnum()
            op = loop.jump.copy_and_change(opnum, args)
            self.renamer.rename(op)
            loop.jump = op

class Pack(object):
    """ A pack is a set of n statements that are:
        * isomorphic
        * independent
    """
    FULL = 0
    _attrs_ = ('operations', 'accumulator', 'operator', 'position')

    operator = '\x00'
    position = -1
    accumulator = None

    def __init__(self, ops):
        self.operations = ops
        self.update_pack_of_nodes()

    def numops(self):
        return len(self.operations)

    @specialize.arg(1)
    def leftmost(self, node=False):
        if node:
            return self.operations[0]
        return self.operations[0].getoperation()

    @specialize.arg(1)
    def rightmost(self, node=False):
        if node:
            return self.operations[-1]
        return self.operations[-1].getoperation()

    def pack_type(self):
        ptype = self.input_type
        if self.input_type is None:
            # load does not have an input type, but only an output type
            ptype = self.output_type
        return ptype

    def input_byte_size(self):
        """ The amount of bytes the operations need with the current
            entries in self.operations. E.g. cast_singlefloat_to_float
            takes only #2 operations.
        """
        return self._byte_size(self.input_type)

    def output_byte_size(self):
        """ The amount of bytes the operations need with the current
            entries in self.operations. E.g. vec_load(..., descr=short) 
            with 10 operations returns 20
        """
        return self._byte_size(self.output_type)

    def pack_load(self, vec_reg_size):
        """ Returns the load of the pack a vector register would hold
            just after executing the operation.
            returns: < 0 - empty, nearly empty
                     = 0 - full
                     > 0 - overloaded
        """
        left = self.leftmost()
        if left.returns_void():
            if rop.is_primitive_store(left.opnum):
                # make this case more general if it turns out this is
                # not the only case where packs need to be trashed
                descr = left.getdescr()
                bytesize = descr.get_item_size_in_bytes()
                return bytesize * self.numops() - vec_reg_size
            else:
                assert left.is_guard() and left.getopnum() in \
                       (rop.GUARD_TRUE, rop.GUARD_FALSE)
                vecinfo = forwarded_vecinfo(left.getarg(0))
                bytesize = vecinfo.bytesize
                return bytesize * self.numops() - vec_reg_size
            return 0
        if self.numops() == 0:
            return -1
        if left.is_typecast():
            # casting is special, often only takes a half full vector
            if left.casts_down():
                # size is reduced
                size = left.cast_input_bytesize(vec_reg_size)
                return left.cast_from_bytesize() * self.numops() - size
            else:
                # size is increased
                #size = left.cast_input_bytesize(vec_reg_size)
                return left.cast_to_bytesize() * self.numops() - vec_reg_size
        vecinfo = forwarded_vecinfo(left)
        return vecinfo.bytesize * self.numops() - vec_reg_size

    def is_full(self, vec_reg_size):
        """ If one input element times the opcount is equal
            to the vector register size, we are full!
        """
        return self.pack_load(vec_reg_size) == Pack.FULL

    def opnum(self):
        assert len(self.operations) > 0
        return self.operations[0].getoperation().getopnum()

    def clear(self):
        for node in self.operations:
            node.pack = None
            node.pack_position = -1

    def update_pack_of_nodes(self):
        for i,node in enumerate(self.operations):
            node.pack = self
            node.pack_position = i

    def split(self, packlist, vec_reg_size, vector_ext):
        """ Combination phase creates the biggest packs that are possible.
            In this step the pack is reduced in size to fit into an
            vector register.
        """
        before_count = len(packlist)
        pack = self
        while pack.pack_load(vec_reg_size) > Pack.FULL:
            pack.clear()
            oplist, newoplist = pack.slice_operations(vec_reg_size, vector_ext)
            pack.operations = oplist
            pack.update_pack_of_nodes()
            if not pack.leftmost().is_typecast():
                assert pack.is_full(vec_reg_size)
            #
            newpack = pack.clone(newoplist)
            load = newpack.pack_load(vec_reg_size)
            if load >= Pack.FULL:
                pack.update_pack_of_nodes()
                pack = newpack
                packlist.append(newpack)
            else:
                newpack.clear()
                newpack.operations = []
                break
        pack.update_pack_of_nodes()

    def opcount_filling_vector_register(self, vec_reg_size, vector_ext):
        left = self.leftmost()
        oprestrict = vector_ext.get_operation_restriction(left)
        return oprestrict.opcount_filling_vector_register(left, vec_reg_size)

    def slice_operations(self, vec_reg_size, vector_ext):
        count = self.opcount_filling_vector_register(vec_reg_size, vector_ext)
        assert count > 0
        newoplist = self.operations[count:]
        oplist = self.operations[:count]
        assert len(newoplist) + len(oplist) == len(self.operations)
        assert len(newoplist) != 0
        return oplist, newoplist

    def rightmost_match_leftmost(self, other):
        """ Check if pack A can be combined with pack B """
        assert isinstance(other, Pack)
        rightmost = self.operations[-1]
        leftmost = other.operations[0]
        # if it is not accumulating it is valid
        if self.is_accumulating():
            if not other.is_accumulating():
                return False
            elif self.position != other.position:
                return False
        return rightmost is leftmost

    def argument_vectors(self, state, pack, index, pack_args_index):
        vectors = []
        last = None
        for arg in pack_args_index:
            pos, vecop = state.getvector_of_box(arg)
            if vecop is not last and vecop is not None:
                vectors.append((pos, vecop))
                last = vecop
        return vectors

    def __repr__(self):
        if len(self.operations) == 0:
            return "Pack(empty)"
        packs = self.operations[0].op.getopname() + '[' + ','.join(['%2d' % (o.opidx) for o in self.operations]) + ']'
        if self.operations[0].op.getdescr():
            packs += 'descr=' + str(self.operations[0].op.getdescr())
        return "Pack(%dx %s)" % (self.numops(), packs)

    def is_accumulating(self):
        return False

    def clone(self, oplist):
        return Pack(oplist)

class Pair(Pack):
    """ A special Pack object with only two statements. """
    def __init__(self, left, right):
        assert isinstance(left, Node)
        assert isinstance(right, Node)
        Pack.__init__(self, [left, right])

    def __eq__(self, other):
        if isinstance(other, Pair):
            return self.left is other.left and \
                   self.right is other.right

class AccumPack(Pack):
    SUPPORTED = { rop.INT_ADD: '+', }

    def __init__(self, nodes, operator, position):
        Pack.__init__(self, nodes)
        self.operator = operator
        self.position = position

    def getdatatype(self):
        accum = self.leftmost().getarg(self.position)
        vecinfo = forwarded_vecinfo(accum)
        return vecinfo.datatype

    def getbytesize(self):
        accum = self.leftmost().getarg(self.position)
        vecinfo = forwarded_vecinfo(accum)
        return vecinfo.bytesize

    def getleftmostseed(self):
        return self.leftmost().getarg(self.position)

    def getseeds(self):
        """ The accumulatoriable holding the seed value """
        return [op.getoperation().getarg(self.position) for op in self.operations]

    def reduce_init(self):
        if self.operator == '*':
            return 1
        return 0

    def is_accumulating(self):
        return True

    def clone(self, oplist):
        return AccumPack(oplist, self.operator, self.position)

