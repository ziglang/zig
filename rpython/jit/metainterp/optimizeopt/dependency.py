import py

from rpython.jit.metainterp import compile
from rpython.jit.metainterp.optimizeopt.util import make_dispatcher_method
from rpython.jit.metainterp.resoperation import (rop, GuardResOp, ResOperation)
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp.history import (ConstPtr, ConstInt,Const,
        AbstractValue, AbstractFailDescr)
from rpython.rtyper.lltypesystem import llmemory
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.objectmodel import we_are_translated

MODIFY_COMPLEX_OBJ = [ (rop.SETARRAYITEM_GC, 0, 1)
                     , (rop.SETARRAYITEM_RAW, 0, 1)
                     , (rop.RAW_STORE, 0, 1)
                     , (rop.VEC_STORE, 0, 1)
                     , (rop.SETINTERIORFIELD_GC, 0, -1)
                     , (rop.SETINTERIORFIELD_RAW, 0, -1)
                     , (rop.SETFIELD_GC, 0, -1)
                     , (rop.SETFIELD_RAW, 0, -1)
                     , (rop.ZERO_ARRAY, 0, -1)
                     , (rop.STRSETITEM, 0, -1)
                     , (rop.UNICODESETITEM, 0, -1)
                     ]

UNROLLED_MODIFY_COMPLEX_OBJ = unrolling_iterable(MODIFY_COMPLEX_OBJ)

LOAD_COMPLEX_OBJ = [ (rop.GETARRAYITEM_GC_I, 0, 1)
                   , (rop.GETARRAYITEM_GC_F, 0, 1)
                   , (rop.GETARRAYITEM_GC_R, 0, 1)
                   , (rop.GETARRAYITEM_RAW_I, 0, 1)
                   , (rop.GETARRAYITEM_RAW_F, 0, 1)
                   , (rop.RAW_LOAD_I, 0, 1)
                   , (rop.RAW_LOAD_F, 0, 1)
                   , (rop.VEC_LOAD_I, 0, 1)
                   , (rop.VEC_LOAD_F, 0, 1)
                   , (rop.GETINTERIORFIELD_GC_I, 0, 1)
                   , (rop.GETINTERIORFIELD_GC_F, 0, 1)
                   , (rop.GETINTERIORFIELD_GC_R, 0, 1)
                   , (rop.GETFIELD_GC_I, 0, -1)
                   , (rop.GETFIELD_GC_F, 0, -1)
                   , (rop.GETFIELD_GC_R, 0, -1)
                   , (rop.GETFIELD_RAW_I, 0, -1)
                   , (rop.GETFIELD_RAW_F, 0, -1)
                   , (rop.GETFIELD_RAW_R, 0, -1)
                   ]

UNROLLED_LOAD_COMPLEX_OBJ = unrolling_iterable(LOAD_COMPLEX_OBJ)

class Path(object):
    def __init__(self,path):
        self.path = path

    def second(self):
        if len(self.path) <= 1:
            return None
        return self.path[1]

    def last_but_one(self):
        if len(self.path) < 2:
            return None
        return self.path[-2]

    def last(self):
        if len(self.path) < 1:
            return None
        return self.path[-1]

    def first(self):
        return self.path[0]

    def is_always_pure(self, exclude_first=False, exclude_last=False):
        last = len(self.path)-1
        count = len(self.path)
        i = 0
        if exclude_first:
            i += 1
        if exclude_last:
            count -= 1
        while i < count: 
            node = self.path[i]
            if node.is_imaginary():
                i += 1
                continue
            op = node.getoperation()
            if rop.is_guard(op.opnum):
                descr = op.getdescr()
                if not descr:
                    return False
                assert isinstance(descr, AbstractFailDescr)
                if not descr.exits_early():
                    return False
            elif not rop.is_always_pure(op.opnum):
                return False
            i += 1
        return True

    def set_schedule_priority(self, p):
        for node in self.path:
            node.setpriority(p)

    def walk(self, node):
        self.path.append(node)

    def cut_off_at(self, index):
        self.path = self.path[:index]

    def check_acyclic(self):
        """NOT_RPYTHON"""
        seen = set()
        for segment in self.path:
            if segment in seen:
                print "path:"
                for segment in self.path:
                    print " ->", segment
                print ""
                assert 0, "segment %s was already seen. this makes the path cyclic!" % segment
            else:
                seen.add(segment)
        return True

    def clone(self):
        return Path(self.path[:])

    def as_str(self):
        """ NOT_RPYTHON """
        return ' -> '.join([str(p) for p in self.path])

class Node(object):
    def __init__(self, op, opidx):
        self.op = op
        self.opidx = opidx
        self.adjacent_list = []
        self.adjacent_list_back = []
        self.memory_ref = None
        self.pack = None
        self.pack_position = -1
        self.emitted = False
        self.schedule_position = -1
        self.priority = 0
        self._stack = False
        self.delayed = None

    def is_imaginary(self):
        return False

    def getoperation(self):
        return self.op

    def getindex(self):
        return self.opidx

    def getopnum(self):
        return self.op.getopnum()

    def getopname(self):
        return self.op.getopname()

    def setpriority(self, value):
        self.priority = value

    def can_be_relaxed(self):
        return self.op.getopnum() in (rop.GUARD_TRUE, rop.GUARD_FALSE)

    def is_pure(self):
        return rop.is_always_pure(self.op.getopnum())

    def edge_to(self, to, arg=None, failarg=False, label=None):
        if self is to:
            return
        dep = self.depends_on(to)
        if not dep:
            #if force or self.independent(idx_from, idx_to):
            dep = Dependency(self, to, arg, failarg)
            self.adjacent_list.append(dep)
            dep_back = Dependency(to, self, arg, failarg)
            dep.backward = dep_back
            to.adjacent_list_back.append(dep_back)
            if not we_are_translated():
                if label is None:
                    label = ''
                dep.label = label
        else:
            if not dep.because_of(arg):
                dep.add_dependency(self,to,arg)
            # if a fail argument is overwritten by another normal
            # dependency it will remove the failarg flag
            if not (dep.is_failarg() and failarg):
                dep.set_failarg(False)
            if not we_are_translated() and label is not None:
                _label = getattr(dep, 'label', '')
                dep.label = _label + ", " + label
        return dep

    def clear_dependencies(self):
        self.adjacent_list = []
        self.adjacent_list_back = []

    def exits_early(self):
        if self.op.is_guard():
            descr = self.op.getdescr()
            return descr.exits_early()
        return False

    def loads_from_complex_object(self):
        return rop._ALWAYS_PURE_LAST <= self.op.getopnum() < rop._MALLOC_FIRST

    def modifies_complex_object(self):
        return rop.SETARRAYITEM_GC <= self.op.getopnum() <= rop.UNICODESETITEM

    def side_effect_arguments(self):
        # if an item in array p0 is modified or a call contains an argument
        # it can modify it is returned in the destroyed list.
        args = []
        op = self.op
        if self.modifies_complex_object():
            for opnum, i, j in UNROLLED_MODIFY_COMPLEX_OBJ: #unrolling_iterable(MODIFY_COMPLEX_OBJ):
                if op.getopnum() == opnum:
                    op_args = op.getarglist()
                    if j == -1:
                        args.append((op.getarg(i), None, True))
                        for j in range(i+1,len(op_args)):
                            args.append((op.getarg(j), None, False))
                    else:
                        args.append((op.getarg(i), op.getarg(j), True))
                        for x in range(j+1,len(op_args)):
                            args.append((op.getarg(x), None, False))
                    return args
        # assume this destroys every argument... can be enhanced by looking
        # at the effect info of a call for instance
        for arg in op.getarglist():
            # if it is a constant argument it cannot be destroyed.
            # neither can a box float be destroyed. BoxInt can
            # contain a reference thus it is assumed to be destroyed
            if arg.is_constant() or arg.type == 'f':
                args.append((arg, None, False))
            else:
                args.append((arg, None, True))
        return args

    def provides_count(self):
        return len(self.adjacent_list)

    def provides(self):
        return self.adjacent_list

    def depends_count(self):
        return len(self.adjacent_list_back)

    def depends(self):
        return self.adjacent_list_back

    def depends_on(self, to):
        """ Does there exist a dependency from the instruction to another?
            Returns None if there is no dependency or the Dependency object in
            any other case.
        """
        for edge in self.adjacent_list:
            if edge.to is to:
                return edge
        return None 

    def dependencies(self):
        return self.adjacent_list[:] + self.adjacent_list_back[:] # COPY

    def is_after(self, other):
        return self.opidx > other.opidx

    def is_before(self, other):
        return self.opidx < other.opidx

    def independent(self, other):
        """ An instruction depends on another if there is a path from
        self to other. """
        if self == other:
            return True
        # forward
        worklist = [self]
        while len(worklist) > 0:
            node = worklist.pop()
            for dep in node.provides():
                if dep.to.is_after(other):
                    continue
                if dep.points_to(other):
                    # dependent. There is a path from self to other
                    return False
                worklist.append(dep.to)
        # backward
        worklist = [self]
        while len(worklist) > 0:
            node = worklist.pop()
            for dep in node.depends():
                if dep.to.is_before(other):
                    continue
                if dep.points_to(other):
                    # dependent. There is a path from self to other
                    return False
                worklist.append(dep.to)
        return True

    def iterate_paths(self, to, backwards=False, path_max_len=-1, blacklist=False):
        """ Yield all nodes from self leading to 'to'.
            
            backwards: Determines the iteration direction.
            blacklist: Marks nodes that have already been visited.
                       It comes in handy if a property must hold for every path.
                       Not *every* possible instance must be iterated, but trees
                       that have already been visited can be ignored after the
                       first visit.
        """
        if self is to:
            return
        blacklist_visit = {}
        path = Path([self])
        worklist = [(0, self, 1)]
        while len(worklist) > 0:
            index,node,pathlen = worklist.pop()
            if backwards:
                iterdir = node.depends()
            else:
                iterdir = node.provides()
            if index >= len(iterdir):
                if to is None and index == 0:
                    yield Path(path.path[:])
                if blacklist:
                    blacklist_visit[node] = None
                continue
            else:
                next_dep = iterdir[index]
                next_node = next_dep.to
                index += 1
                if index < len(iterdir):
                    worklist.append((index, node, pathlen))
                else:
                    blacklist_visit[node] = None
                path.cut_off_at(pathlen)
                path.walk(next_node)
                if blacklist and next_node in blacklist_visit:
                    yield Path(path.path[:])
                    continue
                pathlen += 1

                if next_node is to or \
                   (path_max_len > 0 and pathlen >= path_max_len):
                    yield Path(path.path[:])
                    # note that the destiantion node ``to'' is never blacklisted
                    #if blacklist:
                    #    blacklist_visit[next_node] = None
                else:
                    worklist.append((0, next_node, pathlen))

    def remove_edge_to(self, node):
        i = 0
        while i < len(self.adjacent_list):
            dep = self.adjacent_list[i]
            if dep.to is node:
                del self.adjacent_list[i]
                break
            i += 1
        i = 0
        while i < len(node.adjacent_list_back):
            dep = node.adjacent_list_back[i]
            if dep.to is self:
                del node.adjacent_list_back[i]
                break
            i += 1

    def getedge_to(self, other):
        for dep in self.adjacent_list:
            if dep.to == other:
                return dep
        return None

    def __repr__(self):
        pack = ''
        if self.pack:
            pack = "p: %d" % self.pack.numops()
        return "Node(%s,%s i: %d)" % (self.op, pack, self.opidx)

    def getdotlabel(self):
        """ NOT_RPTYHON """
        op_str = str(self.op)
        if self.op.is_guard():
            args_str = []
            for arg in self.op.getfailargs():
                name = 'None'
                if arg:
                    name = arg.repr_short(arg._repr_memo)
                args_str.append(name)
            op_str += " " + ','.join(args_str)
        return "[%d] %s" % (self.opidx, op_str)

class ImaginaryNode(Node):
    _index = 987654321 # big enough? :)
    def __init__(self, label):
        index = -1
        if not we_are_translated():
            self.dotlabel = label
            index = ImaginaryNode._index
            ImaginaryNode._index += 1
        Node.__init__(self, None, index)

    def is_imaginary(self):
        return True

    def getdotlabel(self):
        """ NOT_RPTYHON """
        return self.dotlabel

class Dependency(object):
    def __init__(self, at, to, arg, failarg=False):
        assert at != to
        self.args = [] 
        if arg is not None:
            self.add_dependency(at, to, arg)
        self.at = at
        self.to = to
        self.failarg = failarg
        self.backward = None

    def because_of(self, var):
        for arg in self.args:
            if arg[1] == var:
                return True
        return False

    def target_node(self):
        return self.to

    def origin_node(self):
        return self.at

    def to_index(self):
        return self.to.getindex()
    def at_index(self):
        return self.at.getindex()

    def points_after_to(self, to):
        return self.to.opidx < to.opidx
    def points_above_at(self, at):
        return self.at.opidx < at.opidx
    def i_points_above_at(self, idx):
        return self.at.opidx < idx

    def points_to(self, to):
        return self.to == to
    def points_at(self, at):
        return self.at == at

    def add_dependency(self, at, to, arg):
        self.args.append((at,arg))

    def set_failarg(self, value):
        self.failarg = value
        if self.backward:
            self.backward.failarg = value

    def is_failarg(self):
        return self.failarg

    def reverse_direction(self, ref):
        """ if the parameter index is the same as idx_to then
        this edge is in reverse direction.
        """
        return self.to == ref

    def __repr__(self):
        return 'Dep(T[%d] -> T[%d], arg: %s)' \
                % (self.at.opidx, self.to.opidx, self.args)

class DefTracker(object):
    def __init__(self, graph):
        self.graph = graph
        self.defs = {}
        self.non_pure = []

    def add_non_pure(self, node):
        self.non_pure.append(node)

    def define(self, arg, node, argcell=None):
        if isinstance(arg, Const):
            return
        if arg in self.defs:
            self.defs[arg].append((node,argcell))
        else:
            self.defs[arg] = [(node,argcell)]

    def redefinitions(self, arg):
        for _def in self.defs[arg]:
            yield _def[0]

    def is_defined(self, arg):
        return arg in self.defs

    def definition(self, arg, node=None, argcell=None):
        if arg.is_constant():
            return None
        def_chain = self.defs.get(arg,None)
        if not def_chain:
            return None
        if not argcell:
            return def_chain[-1][0]
        else:
            assert node is not None
            i = len(def_chain)-1
            try:
                mref = node.memory_ref
                while i >= 0:
                    def_node = def_chain[i][0]
                    oref = def_node.memory_ref
                    if oref is not None and mref.alias(oref):
                        return def_node
                    elif oref is None:
                        return def_node
                    i -= 1
                return None
            except KeyError:
                # when a key error is raised, this means
                # no information is available, safe default
                pass
            return def_chain[-1][0]

    def depends_on_arg(self, arg, to, argcell=None):
        try:
            at = self.definition(arg, to, argcell)
            if at is None:
                return
            at.edge_to(to, arg)
        except KeyError:
            if not we_are_translated():
                if not isinstance(arg, Const):
                    assert False, "arg %s must be defined" % arg


class DependencyGraph(object):
    """ A graph that represents one of the following dependencies:
          * True dependency
          * Anti dependency (not present in SSA traces)
          * Ouput dependency (not present in SSA traces)
        Traces in RPython are not in SSA form when it comes to complex
        object modification such as array or object side effects.
        Representation is an adjacent list. The number of edges between the
        vertices is expected to be small.
        Note that adjacent lists order their dependencies. They are ordered
        by the target instruction they point to if the instruction is
        a dependency.

        memory_refs: a dict that contains indices of memory references
        (load,store,getarrayitem,...). If none provided, the construction
        is conservative. It will never dismiss dependencies of two
        modifications of one array even if the indices can never point to
        the same element.
    """
    def __init__(self, loop):
        self.loop = loop
        label = loop.prefix_label or loop.label
        self.label = Node(label, 0)
        self.nodes = [ Node(op,0) for op in loop.operations if not rop.is_jit_debug(op.opnum) ]
        for i,node in enumerate(self.nodes):
            node.opidx = i+1
        self.inodes = [] # imaginary nodes
        self.jump = Node(loop.jump, len(self.nodes)+1)
        self.invariant_vars = {}
        self.update_invariant_vars(label)
        self.memory_refs = {}
        self.schedulable_nodes = []
        self.index_vars = {}
        self.comparison_vars = {}
        self.guards = []
        self.build_dependencies()

    def getnode(self, i):
        return self.nodes[i]

    def imaginary_node(self, label):
        node = ImaginaryNode(label)
        self.inodes.append(node)
        return node

    def update_invariant_vars(self, label_op=None):
        if not label_op:
            label_op = self.label.getoperation()
        jump_op = self.jump.getoperation()
        assert label_op.numargs() == jump_op.numargs()
        for i in range(label_op.numargs()):
            label_box = label_op.getarg(i)
            jump_box = jump_op.getarg(i)
            if label_box == jump_box:
                self.invariant_vars[label_box] = None

    def box_is_invariant(self, box):
        return box in self.invariant_vars

    def build_dependencies(self):
        """ This is basically building the definition-use chain and saving this
            information in a graph structure. This is the same as calculating
            the reaching definitions and the 'looking back' whenever it is used.

            Write After Read, Write After Write dependencies are not possible,
            the operations are in SSA form
        """
        tracker = DefTracker(self)
        #
        label_pos = 0
        jump_pos = len(self.nodes)-1
        intformod = IntegralForwardModification(self.memory_refs, self.index_vars,
                                                self.comparison_vars, self.invariant_vars)
        # pass 1
        for i,node in enumerate(self.nodes):
            op = node.op
            if rop.is_always_pure(op.opnum):
                node.setpriority(1)
            if rop.is_guard(op.opnum):
                node.setpriority(2)
            # the label operation defines all operations at the
            # beginning of the loop

            intformod.inspect_operation(op,node)
            # definition of a new variable
            if op.type != 'v':
                # In SSA form. Modifications get a new variable
                tracker.define(op, node)
            # usage of defined variables
            if rop.is_always_pure(op.opnum) or rop.is_final(op.opnum):
                # normal case every arguments definition is set
                for arg in op.getarglist():
                    tracker.depends_on_arg(arg, node)
            elif rop.is_guard(op.opnum):
                if node.exits_early():
                    pass
                else:
                    # consider cross iterations?
                    if len(self.guards) > 0:
                        last_guard = self.guards[-1]
                        last_guard.edge_to(node, failarg=True, label="guardorder")
                    for nonpure in tracker.non_pure:
                        nonpure.edge_to(node, failarg=True, label="nonpure")
                    tracker.non_pure = []
                self.guards.append(node)
                self.build_guard_dependencies(node, tracker)
            else:
                self.build_non_pure_dependencies(node, tracker)

    def guard_argument_protection(self, guard_node, tracker):
        """ the parameters the guard protects are an indicator for
            dependencies. Consider the example:
            i3 = ptr_eq(p1,p2)
            guard_true(i3) [...]

            guard_true|false are exceptions because they do not directly
            protect the arguments, but a comparison function does.
        """
        guard_op = guard_node.getoperation()
        guard_opnum = guard_op.getopnum()
        for arg in guard_op.getarglist():
            if not arg.is_constant() and arg.type not in ('i','f'):
                # redefine pointers, consider the following example
                # guard_nonnull(r1)
                # i1 = getfield(r1, ...)
                # guard must be emitted before the getfield, thus
                # redefine r1 at guard_nonnull
                tracker.define(arg, guard_node)
        if guard_opnum == rop.GUARD_NOT_FORCED_2:
            # must be emitted before finish, thus delayed the longest
            guard_node.setpriority(-10)
        elif guard_opnum in (rop.GUARD_OVERFLOW, rop.GUARD_NO_OVERFLOW):
            # previous operation must be an ovf_operation
            guard_node.setpriority(100)
            i = guard_node.getindex()-1
            while i >= 0:
                node = self.nodes[i]
                op = node.getoperation()
                if op.is_ovf():
                    break
                i -= 1
            else:
                raise AssertionError("(no)overflow: no overflowing op present")
            node.edge_to(guard_node, None, label='overflow')
        elif guard_opnum in (rop.GUARD_NO_EXCEPTION, rop.GUARD_EXCEPTION, rop.GUARD_NOT_FORCED):
            # previous op must be one that can raise or a not forced guard
            guard_node.setpriority(100)
            i = guard_node.getindex() - 1
            while i >= 0:
                node = self.nodes[i]
                op = node.getoperation()
                if op.can_raise():
                    node.edge_to(guard_node, None, label='exception/notforced')
                    break
                if op.is_guard():
                    node.edge_to(guard_node, None, label='exception/notforced')
                    break
                i -= 1
            else:
                raise AssertionError("(no)exception/not_forced: not op raises for them")
        else:
            pass # not invalidated, future condition!

    def guard_exit_dependence(self, guard_node, var, tracker):
        def_node = tracker.definition(var)
        if def_node is None:
            return
        for dep in def_node.provides():
            if guard_node.is_before(dep.to) and dep.because_of(var):
                guard_node.edge_to(dep.to, var, label='guard_exit('+str(var)+')')

    def build_guard_dependencies(self, guard_node, tracker):
        guard_op = guard_node.op
        if guard_op.getopnum() >= rop.GUARD_FUTURE_CONDITION:
            # ignore invalidated & future condition guard & early exit
            return
        # true dependencies
        for arg in guard_op.getarglist():
            tracker.depends_on_arg(arg, guard_node)
        # dependencies to uses of arguments it protects
        self.guard_argument_protection(guard_node, tracker)
        #
        descr = guard_op.getdescr()
        if descr.exits_early():
            return
        # handle fail args
        if guard_op.getfailargs():
            for i,arg in enumerate(guard_op.getfailargs()):
                if arg is None:
                    continue
                if not tracker.is_defined(arg):
                    continue
                try:
                    for at in tracker.redefinitions(arg):
                        # later redefinitions are prohibited
                        if at.is_before(guard_node):
                            at.edge_to(guard_node, arg, failarg=True, label="fail")
                except KeyError:
                    assert False

    def build_non_pure_dependencies(self, node, tracker):
        op = node.op
        if node.loads_from_complex_object():
            # If this complex object load operation loads an index that has been
            # modified, the last modification should be used to put a def-use edge.
            for opnum, i, j in UNROLLED_LOAD_COMPLEX_OBJ:
                if opnum == op.getopnum():
                    cobj = op.getarg(i)
                    if j != -1:
                        index_var = op.getarg(j)
                        tracker.depends_on_arg(cobj, node, index_var)
                        tracker.depends_on_arg(index_var, node)
                    else:
                        tracker.depends_on_arg(cobj, node)
                    break
        else:
            for arg, argcell, destroyed in node.side_effect_arguments():
                if argcell is not None:
                    # tracks the exact cell that is modified
                    tracker.depends_on_arg(arg, node, argcell)
                    tracker.depends_on_arg(argcell, node)
                else:
                    if destroyed:
                        # cannot be sure that only a one cell is modified
                        # assume all cells are (equivalent to a redefinition)
                        try:
                            # A trace is not entirely in SSA form. complex object
                            # modification introduces WAR/WAW dependencies
                            def_node = tracker.definition(arg)
                            if def_node:
                                for dep in def_node.provides():
                                    if dep.to != node:
                                        dep.to.edge_to(node, argcell, label='war')
                                def_node.edge_to(node, argcell)
                        except KeyError:
                            pass
                    else:
                        # not destroyed, just a normal use of arg
                        tracker.depends_on_arg(arg, node)
                if destroyed:
                    tracker.define(arg, node, argcell=argcell)
            # it must be assumed that a side effect operation must not be executed
            # before the last guard operation
            if len(self.guards) > 0:
                last_guard = self.guards[-1]
                last_guard.edge_to(node, label="sideeffect")
            # and the next guard instruction
            tracker.add_non_pure(node)

    def cycles(self):
        """ NOT_RPYTHON """
        stack = []
        for node in self.nodes:
            node._stack = False
        #
        label = self.nodes[0]
        if _first_cycle(stack, label):
            return stack
        return None

    def __repr__(self):
        graph = "graph([\n"
        for node in self.nodes:
            graph += "       " + str(node.opidx) + ": "
            for dep in node.provides():
                graph += "=>" + str(dep.to.opidx) + ","
            graph += " | "
            for dep in node.depends():
                graph += "<=" + str(dep.to.opidx) + ","
            graph += "\n"
        return graph + "      ])"

    def view(self):
        """ NOT_RPYTHON """
        from rpython.translator.tool.graphpage import GraphPage
        page = GraphPage()
        page.source = self.as_dot()
        page.links = []
        page.display()

    def as_dot(self):
        """ NOT_RPTYHON """
        if not we_are_translated():
            dot = "digraph dep_graph {\n"
            for node in self.nodes + self.inodes:
                dot += " n%d [label=\"%s\"];\n" % (node.getindex(),node.getdotlabel())
            dot += "\n"
            for node in self.nodes + self.inodes:
                for dep in node.provides():
                    label = ''
                    if getattr(dep, 'label', None):
                        label = '[label="%s"]' % dep.label
                    dot += " n%d -> n%d %s;\n" % (node.getindex(),dep.to_index(),label)
            dot += "\n}\n"
            return dot
        raise NotImplementedError("dot only for debug purpose")

def _first_cycle(stack, node):
    node._stack = True
    stack.append(node)

    for dep in node.provides():
        succ = dep.to
        if succ._stack:
            # found cycle!
            while stack[0] is not succ:
                del stack[0]
            return True
        else:
            return _first_cycle(stack, succ)

    return False

def _strongly_connect(index, stack, cycles, node):
    """ currently unused """
    node._scc_index = index
    node._scc_lowlink = index
    index += 1
    stack.append(node)
    node._scc_stack = True

    for dep in node.provides():
        succ = dep.to
        if succ._scc_index == -1:
            index = _strongly_connect(index, stack, cycles, succ)
            node._scc_lowlink = min(node._scc_lowlink, succ._scc_lowlink)
        elif succ._scc_stack:
            node._scc_lowlink = min(node._scc_lowlink, succ._scc_index)

    if node._scc_lowlink == node._scc_index:
        cycle = []
        while True:
            w = stack.pop()
            w._scc_stack = False
            cycle.append(w)
            if w is node:
                break
        cycles.append(cycle)
    return index

class IntegralForwardModification(object):
    """ Calculates integral modifications on integer boxes. """
    def __init__(self, memory_refs, index_vars, comparison_vars, invariant_vars):
        self.index_vars = index_vars
        self.comparison_vars = comparison_vars
        self.memory_refs = memory_refs
        self.invariant_vars = invariant_vars

    def is_const_integral(self, box):
        if isinstance(box, ConstInt):
            return True
        return False

    def get_or_create(self, arg):
        var = self.index_vars.get(arg, None)
        if not var:
            var = self.index_vars[arg] = IndexVar(arg)
        return var

    additive_func_source = """
    def operation_{name}(self, op, node):
        box_r = op
        box_a0 = op.getarg(0)
        box_a1 = op.getarg(1)
        if self.is_const_integral(box_a0) and self.is_const_integral(box_a1):
            idx_ref = IndexVar(box_r)
            idx_ref.constant = box_a0.getint() {op} box_a1.getint()
            self.index_vars[box_r] = idx_ref 
        elif self.is_const_integral(box_a0):
            idx_ref = self.get_or_create(box_a1)
            idx_ref = idx_ref.clone()
            idx_ref.constant {op}= box_a0.getint()
            self.index_vars[box_r] = idx_ref
        elif self.is_const_integral(box_a1):
            idx_ref = self.get_or_create(box_a0)
            idx_ref = idx_ref.clone()
            idx_ref.constant {op}= box_a1.getint()
            self.index_vars[box_r] = idx_ref
    """
    exec(py.code.Source(additive_func_source
            .format(name='INT_ADD', op='+')).compile())
    exec(py.code.Source(additive_func_source
            .format(name='INT_SUB', op='-')).compile())
    del additive_func_source

    multiplicative_func_source = """
    def operation_{name}(self, op, node):
        box_r = op
        if not box_r:
            return
        box_a0 = op.getarg(0)
        box_a1 = op.getarg(1)
        if self.is_const_integral(box_a0) and self.is_const_integral(box_a1):
            idx_ref = IndexVar(box_r)
            idx_ref.constant = box_a0.getint() {cop} box_a1.getint()
            self.index_vars[box_r] = idx_ref 
        elif self.is_const_integral(box_a0):
            idx_ref = self.get_or_create(box_a1)
            idx_ref = idx_ref.clone()
            idx_ref.coefficient_{tgt} *= box_a0.getint()
            idx_ref.constant {cop}= box_a0.getint()
            self.index_vars[box_r] = idx_ref
        elif self.is_const_integral(box_a1):
            idx_ref = self.get_or_create(box_a0)
            idx_ref = idx_ref.clone()
            idx_ref.coefficient_{tgt} {op}= box_a1.getint()
            idx_ref.constant {cop}= box_a1.getint()
            self.index_vars[box_r] = idx_ref
    """
    exec(py.code.Source(multiplicative_func_source
            .format(name='INT_MUL', op='*', tgt='mul', cop='*')).compile())
    del multiplicative_func_source

    array_access_source = """
    def operation_{name}(self, op, node):
        descr = op.getdescr()
        idx_ref = self.get_or_create(op.getarg(1))
        if descr and descr.is_array_of_primitives():
            node.memory_ref = MemoryRef(op, idx_ref, {raw_access})
            self.memory_refs[node] = node.memory_ref
    """
    exec(py.code.Source(array_access_source
           .format(name='RAW_LOAD_I',raw_access=True)).compile())
    exec(py.code.Source(array_access_source
           .format(name='RAW_LOAD_F',raw_access=True)).compile())
    exec(py.code.Source(array_access_source
           .format(name='RAW_STORE',raw_access=True)).compile())
    exec(py.code.Source(array_access_source
           .format(name='GETARRAYITEM_RAW_I',raw_access=False)).compile())
    exec(py.code.Source(array_access_source
           .format(name='GETARRAYITEM_RAW_F',raw_access=False)).compile())
    exec(py.code.Source(array_access_source
           .format(name='SETARRAYITEM_RAW',raw_access=False)).compile())
    exec(py.code.Source(array_access_source
           .format(name='GETARRAYITEM_GC_I',raw_access=False)).compile())
    exec(py.code.Source(array_access_source
           .format(name='GETARRAYITEM_GC_F',raw_access=False)).compile())
    exec(py.code.Source(array_access_source
           .format(name='SETARRAYITEM_GC',raw_access=False)).compile())
    del array_access_source
integral_dispatch_opt = make_dispatcher_method(IntegralForwardModification, 'operation_')
IntegralForwardModification.inspect_operation = integral_dispatch_opt
del integral_dispatch_opt

class IndexVar(AbstractValue):
    """ IndexVar is an AbstractValue only to ensure that a box can be assigned
        to the same variable as an index var.
    """
    def __init__(self, var, coeff_mul=1, coeff_div=1, constant=0):
        self.var = var
        self.coefficient_mul = coeff_mul
        self.coefficient_div = coeff_div
        self.constant = constant
        # saves the next modification that uses a variable
        self.next_nonconst = None
        self.current_end = None

    def calculated_by(self, op):
        # quick check to indicate if this operation is not directly expressable using
        # the operation in the op parameter.
        if op.getopnum() == rop.INT_ADD:
            a0 = op.getarg(0)
            a1 = op.getarg(1)
            if a0 is self.var and a1.is_constant() and a1.getint() == self.constant:
                return True
            if a1 is self.var and a0.is_constant() and a0.getint() == self.constant:
                return True
        if op.getopnum() == rop.INT_SUB:
            a0 = op.getarg(0)
            a1 = op.getarg(1)
            if a0 is self.var and a1.is_constant() and a1.getint() == self.constant:
                return True
        return False

    def stride_const(self):
        return self.next_nonconst is None

    def add_const(self, number):
        if self.current_end is None:
            self.constant += number
        else:
            self.current_end.constant += number

    def set_next_nonconst_mod(self, idxvar):
        if self.current_end is None:
            self.next_nonconst = idxvar
        else:
            self.current_end.next_nonconst = idxvar
        self.current_end = idxvar

    def getvariable(self):
        return self.var

    def is_identity(self):
        return self.coefficient_mul == 1 and \
               self.coefficient_div == 1 and \
               self.constant == 0

    def clone(self):
        c = IndexVar(self.var)
        c.coefficient_mul = self.coefficient_mul
        c.coefficient_div = self.coefficient_div
        c.constant = self.constant
        return c

    def same_variable(self, other):
        assert isinstance(other, IndexVar)
        return other.var == self.var

    def same_mulfactor(self, other):
        coeff = self.coefficient_mul == other.coefficient_mul
        coeff = coeff and (self.coefficient_div == other.coefficient_div)
        if not coeff:
            # if not equal, try to check if they divide without rest
            selfmod = self.coefficient_mul % self.coefficient_div
            othermod = other.coefficient_mul % other.coefficient_div
            if selfmod == 0 and othermod == 0:
                # yet another chance for them to be equal
                selfdiv = self.coefficient_mul // self.coefficient_div
                otherdiv = other.coefficient_mul // other.coefficient_div
                coeff = selfdiv == otherdiv
        return coeff

    def constant_diff(self, other):
        """ calculates the difference as a second parameter """
        assert isinstance(other, IndexVar)
        return self.constant - other.constant

    def get_operations(self):
        var = self.var
        tolist = []
        if self.coefficient_mul != 1:
            args = [var, ConstInt(self.coefficient_mul)]
            var = ResOperation(rop.INT_MUL, args)
            tolist.append(var)
        if self.coefficient_div != 1:
            assert 0   # should never be the case with handling
                       # of INT_PY_DIV commented out in this file...
        if self.constant > 0:
            args = [var, ConstInt(self.constant)]
            var = ResOperation(rop.INT_ADD, args)
            tolist.append(var)
        if self.constant < 0:
            args = [var, ConstInt(-self.constant)]
            var = ResOperation(rop.INT_SUB, args)
            tolist.append(var)
        return tolist

    def emit_operations(self, opt, result_box=None):
        var = self.var
        if self.is_identity():
            return var
        last = None
        for op in self.get_operations():
            opt.emit_operation(op)
            last = op
        return last

    def compare(self, other):
        """ Returns if the two are compareable as a first result
            and a number (-1,0,1) of the ordering
        """
        coeff = self.coefficient_mul == other.coefficient_mul
        coeff = coeff and (self.coefficient_div == other.coefficient_div)
        if not coeff:
            # if not equal, try to check if they divide without rest
            selfmod = self.coefficient_mul % self.coefficient_div
            othermod = other.coefficient_mul % other.coefficient_div
            if selfmod == 0 and othermod == 0:
                # yet another chance for them to be equal
                selfdiv = self.coefficient_mul // self.coefficient_div
                otherdiv = other.coefficient_mul // other.coefficient_div
                coeff = selfdiv == otherdiv
        #
        if not coeff:
            return False, 0
        #
        c = (self.constant - other.constant)
        svar = self.var
        ovar = other.var
        if isinstance(svar, ConstInt) and isinstance(ovar, ConstInt):
            return True, (svar.getint() - ovar.getint())
        if svar.same_box(ovar):
            return True, c
        return False, 0

    def __eq__(self, other):
        if not self.same_variable(other):
            return False
        if not self.same_mulfactor(other):
            return False
        return self.constant_diff(other) == 0

    def __ne__(self, other):
        return not self.__eq__(other)

    def __repr__(self):
        if self.is_identity():
            return 'idx(%s)' % (self.var,)

        return 'idx(%s*(%s/%s)+%s)' % (self.var, self.coefficient_mul,
                                            self.coefficient_div, self.constant)

class MemoryRef(object):
    """ a memory reference to an array object. IntegralForwardModification is able
    to propagate changes to this object if applied in backwards direction.
    Example:

    i1 = int_add(i0,1)
    i2 = int_mul(i1,2)
    setarrayitem_gc(p0, i2, 1, ...)

    will result in the linear combination i0 * (2/1) + 2
    """
    def __init__(self, op, index_var, raw_access=False):
        assert op.getdescr() is not None
        self.array = op.getarg(0)
        self.descr = op.getdescr()
        self.index_var = index_var
        self.raw_access = raw_access

    def is_adjacent_to(self, other):
        """ this is a symmetric relation """
        if not self.same_array(other):
            return False
        if not self.index_var.same_variable(other.index_var):
            return False
        if not self.index_var.same_mulfactor(other.index_var):
            return False
        stride = self.stride()
        return abs(self.index_var.constant_diff(other.index_var)) - stride == 0

    def is_adjacent_after(self, other):
        """ the asymetric relation to is_adjacent_to """
        if not self.same_array(other):
            return False
        if not self.index_var.same_variable(other.index_var):
            return False
        if not self.index_var.same_mulfactor(other.index_var):
            return False
        stride = self.stride()
        return other.index_var.constant_diff(self.index_var) == stride

    def alias(self, other):
        """ is this reference an alias to other?
            they can alias iff self.origin != other.origin, or their
            linear combination point to the same element.
        """
        assert other is not None
        if not self.same_array(other):
            return False
        svar = self.index_var
        ovar = other.index_var
        if not svar.same_variable(ovar):
            return True
        if not svar.same_mulfactor(ovar):
            return True
        return abs(svar.constant_diff(ovar)) < self.stride()

    def same_array(self, other):
        return self.array is other.array and self.descr == other.descr

    def __eq__(self, other):
        """ NOT_RPYTHON """
        if not self.same_array(other):
            return False
        if not self.index_var.same_variable(other.index_var):
            return False
        if not self.index_var.same_mulfactor(other.index_var):
            return False
        stride = self.stride()
        return other.index_var.constant_diff(self.index_var) == 0

    #def __ne__(self, other):
    #    return not self.__eq__(other)

    def stride(self):
        """ the stride in bytes """
        if not self.raw_access:
            return 1
        return self.descr.get_item_size_in_bytes()

    def __repr__(self):
        return 'MemRef(%s,%s)' % (self.array, self.index_var)
