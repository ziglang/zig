from rpython.flowspace.model import Variable
from rpython.rtyper.lltypesystem import lltype
from rpython.translator.simplify import get_graph
from rpython.tool.uid import uid


class CreationPoint(object):
    def __init__(self, creation_method, TYPE, op=None):
        self.escapes = False
        self.returns = False
        self.creation_method = creation_method
        if creation_method == "constant":
            self.escapes = True
        self.TYPE = TYPE
        self.op = op

    def __repr__(self):
        return ("CreationPoint(<0x%x>, %r, %s, esc=%s)" %
                (uid(self), self.TYPE, self.creation_method, self.escapes))

class VarState(object):
    def __init__(self, *creps):
        self.creation_points = set()
        for crep in creps:
            self.creation_points.add(crep)

    def contains(self, other):
        return other.creation_points.issubset(self.creation_points)

    def merge(self, other):
        creation_points = self.creation_points.union(other.creation_points)
        return VarState(*creation_points)

    def setescapes(self):
        changed = []
        for crep in self.creation_points:
            if not crep.escapes:
                changed.append(crep)
                crep.escapes = True
        return changed

    def setreturns(self):
        changed = []
        for crep in self.creation_points:
            if not crep.returns:
                changed.append(crep)
                crep.returns = True
        return changed

    def does_escape(self):
        for crep in self.creation_points:
            if crep.escapes:
                return True
        return False

    def does_return(self):
        for crep in self.creation_points:
            if crep.returns:
                return True
        return False

    def __repr__(self):
        return "<VarState %s>" % (self.creation_points, )

class AbstractDataFlowInterpreter(object):
    def __init__(self, translation_context):
        self.translation_context = translation_context
        self.scheduled = {} # block: graph containing it
        self.varstates = {} # var-or-const: state
        self.creationpoints = {} # var: creationpoint
        self.constant_cps = {} # const: creationpoint
        self.dependencies = {} # creationpoint: {block: graph containing it}
        self.functionargs = {} # graph: list of state of args
        self.flown_blocks = {} # block: True

    def seen_graphs(self):
        return self.functionargs.keys()

    def getstate(self, var_or_const):
        if not isonheap(var_or_const):
            return None
        if var_or_const in self.varstates:
            return self.varstates[var_or_const]
        if isinstance(var_or_const, Variable):
            varstate = VarState()
        else:
            if var_or_const not in self.constant_cps:
                crep = CreationPoint("constant", var_or_const.concretetype)
                self.constant_cps[var_or_const] = crep
            else:
                crep = self.constant_cps[var_or_const]
            varstate = VarState(crep)
        self.varstates[var_or_const] = varstate
        return varstate

    def getstates(self, varorconstlist):
        return [self.getstate(var) for var in varorconstlist]

    def setstate(self, var, state):
        self.varstates[var] = state

    def get_creationpoint(self, var, method="?", op=None):
        if var in self.creationpoints:
            return self.creationpoints[var]
        crep = CreationPoint(method, var.concretetype, op)
        self.creationpoints[var] = crep
        return crep

    def schedule_function(self, graph):
        startblock = graph.startblock
        if graph in self.functionargs:
            args = self.functionargs[graph]
        else:
            args = []
            for var in startblock.inputargs:
                if not isonheap(var):
                    varstate = None
                else:
                    crep = self.get_creationpoint(var, "arg")
                    varstate = VarState(crep)
                    self.setstate(var, varstate)
                args.append(varstate)
            self.scheduled[startblock] = graph
            self.functionargs[graph] = args
        resultstate = self.getstate(graph.returnblock.inputargs[0])
        return resultstate, args

    def flow_block(self, block, graph):
        self.flown_blocks[block] = True
        if block is graph.returnblock:
            if isonheap(block.inputargs[0]):
                self.returns(self.getstate(block.inputargs[0]))
            return
        if block is graph.exceptblock:
            if isonheap(block.inputargs[0]):
                self.escapes(self.getstate(block.inputargs[0]))
            if isonheap(block.inputargs[1]):
                self.escapes(self.getstate(block.inputargs[1]))
            return
        self.curr_block = block
        self.curr_graph = graph

        for op in block.operations:
            self.flow_operation(op)
        for exit in block.exits:
            args = self.getstates(exit.args)
            targetargs = self.getstates(exit.target.inputargs)
            # flow every block at least once
            if (multicontains(targetargs, args) and
                exit.target in self.flown_blocks):
                continue
            for prevstate, origstate, var in zip(args, targetargs,
                                                exit.target.inputargs):
                if not isonheap(var):
                    continue
                newstate = prevstate.merge(origstate)
                self.setstate(var, newstate)
            self.scheduled[exit.target] = graph

    def flow_operation(self, op):
        args = self.getstates(op.args)
        opimpl = getattr(self, 'op_' + op.opname, None)
        if opimpl is not None:
            res = opimpl(op, *args)
            if res is not NotImplemented:
                self.setstate(op.result, res)
                return

        if isonheap(op.result) or filter(None, args):
            for arg in args:
                if arg is not None:
                    self.escapes(arg)

    def complete(self):
        while self.scheduled:
            block, graph = self.scheduled.popitem()
            self.flow_block(block, graph)

    def escapes(self, arg):
        changed = arg.setescapes()
        self.handle_changed(changed)

    def returns(self, arg):
        changed = arg.setreturns()
        self.handle_changed(changed)

    def handle_changed(self, changed):
        for crep in changed:
            if crep not in self.dependencies:
                continue
            self.scheduled.update(self.dependencies[crep])

    def register_block_dependency(self, state, block=None, graph=None):
        if block is None:
            block = self.curr_block
            graph = self.curr_graph
        for crep in state.creation_points:
            self.dependencies.setdefault(crep, {})[block] = graph

    def register_state_dependency(self, state1, state2):
        "state1 depends on state2: if state2 does escape/change, so does state1"
        # change state1 according to how state2 is now
        if state2.does_escape():
            self.escapes(state1)
        if state2.does_return():
            self.returns(state1)
        # register a dependency of the current block on state2:
        # that means that if state2 changes the current block will be reflown
        # triggering this function again and thus updating state1
        self.register_block_dependency(state2)

    # _____________________________________________________________________
    # operation implementations

    def op_malloc(self, op, typestate, flagsstate):
        assert flagsstate is None
        flags = op.args[1].value
        if flags != {'flavor': 'gc'}:
            return NotImplemented
        return VarState(self.get_creationpoint(op.result, "malloc", op))

    def op_malloc_varsize(self, op, typestate, flagsstate, lengthstate):
        assert flagsstate is None
        flags = op.args[1].value
        if flags != {'flavor': 'gc'}:
            return NotImplemented
        return VarState(self.get_creationpoint(op.result, "malloc_varsize", op))

    def op_cast_pointer(self, op, state):
        return state

    def op_setfield(self, op, objstate, fieldname, valuestate):
        if valuestate is not None:
            # be pessimistic for now:
            # everything that gets stored into a structure escapes
            self.escapes(valuestate)
        return None

    def op_setarrayitem(self, op, objstate, indexstate, valuestate):
        if valuestate is not None:
            # everything that gets stored into a structure escapes
            self.escapes(valuestate)
        return None

    def op_getarrayitem(self, op, objstate, indexstate):
        if isonheap(op.result):
            return VarState(self.get_creationpoint(op.result, "getarrayitem", op))

    def op_getfield(self, op, objstate, fieldname):
        if isonheap(op.result):
            # assume that getfield creates a new value
            return VarState(self.get_creationpoint(op.result, "getfield", op))

    def op_getarraysize(self, op, arraystate):
        pass

    def op_direct_call(self, op, function, *args):
        graph = get_graph(op.args[0], self.translation_context)
        if graph is None:
            for arg in args:
                if arg is None:
                    continue
                # an external function can escape every parameter:
                self.escapes(arg)
            funcargs = [None] * len(args)
        else:
            result, funcargs = self.schedule_function(graph)
        assert len(args) == len(funcargs)
        for localarg, funcarg in zip(args, funcargs):
            if localarg is None:
                assert funcarg is None
                continue
            if funcarg is not None:
                self.register_state_dependency(localarg, funcarg)
        if isonheap(op.result):
            # assume that a call creates a new value
            return VarState(self.get_creationpoint(op.result, "direct_call", op))

    def op_indirect_call(self, op, function, *args):
        graphs = op.args[-1].value
        args = args[:-1]
        if graphs is None:
            for localarg in args:
                if localarg is None:
                    continue
                self.escapes(localarg)
        else:
            for graph in graphs:
                result, funcargs = self.schedule_function(graph)
                assert len(args) == len(funcargs)
                for localarg, funcarg in zip(args, funcargs):
                    if localarg is None:
                        assert funcarg is None
                        continue
                    self.register_state_dependency(localarg, funcarg)
        if isonheap(op.result):
            # assume that a call creates a new value
            return VarState(self.get_creationpoint(op.result, "indirect_call", op))

    def op_ptr_iszero(self, op, ptrstate):
        return None

    op_cast_ptr_to_int = op_keepalive = op_ptr_nonzero = op_ptr_iszero

    def op_ptr_eq(self, op, ptr1state, ptr2state):
        return None

    op_ptr_ne = op_ptr_eq

    def op_same_as(self, op, objstate):
        return objstate

def isonheap(var_or_const):
    return isinstance(var_or_const.concretetype, lltype.Ptr)

def multicontains(l1, l2):
    assert len(l1) == len(l2)
    for a, b in zip(l1, l2):
        if a is None:
            assert b is None
        elif not a.contains(b):
            return False
    return True


def is_malloc_like(adi, graph, seen):
    if graph in seen:
        return seen[graph]
    return_state = adi.getstate(graph.getreturnvar())
    if return_state is None or len(return_state.creation_points) != 1:
        seen[graph] = False
        return False
    crep, = return_state.creation_points
    if crep.escapes:
        seen[graph] = False
        return False
    if crep.creation_method in ["malloc", "malloc_varsize"]:
        assert crep.returns
        seen[graph] = True
        return True
    if crep.creation_method == "direct_call":
        subgraph = get_graph(crep.op.args[0], adi.translation_context)
        if subgraph is None:
            seen[graph] = False
            return False
        res = is_malloc_like(adi, subgraph, seen)
        seen[graph] = res
        return res
    seen[graph] = False
    return False


def malloc_like_graphs(adi):
    seen = {}
    return [graph for graph in adi.seen_graphs()
        if is_malloc_like(adi, graph, seen)]
