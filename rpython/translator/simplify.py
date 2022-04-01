"""Flow Graph Simplification

'Syntactic-ish' simplifications on a flow graph.

simplify_graph() applies all simplifications defined in this file.
"""
import py
from collections import defaultdict

from rpython.tool.algo.unionfind import UnionFind
from rpython.flowspace.model import (
        Variable, Constant, checkgraph, mkentrymap)
from rpython.flowspace.operation import OverflowingOperation, op
from rpython.rlib import rarithmetic
from rpython.translator import unsimplify
from rpython.rtyper.lltypesystem import lloperation, lltype
from rpython.translator.backendopt.ssa import (
        SSA_to_SSI, DataFlowFamilyBuilder)

def get_graph(arg, translator):
    if isinstance(arg, Variable):
        return None
    f = arg.value
    if not isinstance(f, lltype._ptr):
        return None
    try:
        funcobj = f._obj
    except lltype.DelayedPointer:
        return None
    try:
        return funcobj.graph
    except AttributeError:
        return None


def replace_exitswitch_by_constant(block, const):
    newexits = [link for link in block.exits
                     if link.exitcase == const.value]
    if len(newexits) == 0:
        newexits = [link for link in block.exits
                     if link.exitcase == 'default']
    assert len(newexits) == 1
    newexits[0].exitcase = None
    if hasattr(newexits[0], 'llexitcase'):
        newexits[0].llexitcase = None
    block.exitswitch = None
    block.recloseblock(*newexits)
    return newexits

# ____________________________________________________________

def eliminate_empty_blocks(graph):
    """Eliminate basic blocks that do not contain any operations.
    When this happens, we need to replace the preceeding link with the
    following link.  Arguments of the links should be updated."""
    for link in list(graph.iterlinks()):
        while not link.target.operations:
            block1 = link.target
            if block1.exitswitch is not None:
                break
            if not block1.exits:
                break
            exit = block1.exits[0]
            assert block1 is not exit.target, (
                "the graph contains an empty infinite loop")
            subst = dict(zip(block1.inputargs, link.args))
            link.args = [v.replace(subst) for v in exit.args]
            link.target = exit.target
            # the while loop above will simplify recursively the new link

def transform_ovfcheck(graph):
    """The special function calls ovfcheck needs to
    be translated into primitive operations. ovfcheck is called directly
    after an operation that should be turned into an overflow-checked
    version. It is considered a syntax error if the resulting <op>_ovf
    is not defined in objspace/flow/objspace.py.
    """
    covf = Constant(rarithmetic.ovfcheck)

    for block in graph.iterblocks():
        for i in range(len(block.operations)-1, -1, -1):
            op = block.operations[i]
            if op.opname != 'simple_call':
                continue
            if op.args[0] == covf:
                if i == 0:
                    # hard case: ovfcheck() on an operation that occurs
                    # in the previous block, like 'floordiv'.  The generic
                    # exception handling around the ovfcheck() is enough
                    # to cover all cases; kill the one around the previous op.
                    entrymap = mkentrymap(graph)
                    links = entrymap[block]
                    assert len(links) == 1
                    prevblock = links[0].prevblock
                    assert prevblock.exits[0].target is block
                    prevblock.exitswitch = None
                    prevblock.exits = (links[0],)
                    join_blocks(graph)         # merge the two blocks together
                    transform_ovfcheck(graph)  # ...and try again
                    return
                op1 = block.operations[i - 1]
                if not isinstance(op1, OverflowingOperation):
                    raise Exception("ovfcheck in %s: Operation %s has no "
                                    "overflow variant" % (graph.name, op1.opname))
                op1_ovf = op1.ovfchecked()
                block.operations[i - 1] = op1_ovf
                del block.operations[i]
                block.renamevariables({op.result: op1_ovf.result})

def simplify_exceptions(graph):
    """The exception handling caused by non-implicit exceptions
    starts with an exitswitch on Exception, followed by a lengthy
    chain of is_/issubtype tests. We collapse them all into
    the block's single list of exits.
    """
    renaming = {}
    for block in graph.iterblocks():
        if not (block.canraise
                and block.exits[-1].exitcase is Exception):
            continue
        covered = [link.exitcase for link in block.exits[1:-1]]
        seen = []
        preserve = list(block.exits[:-1])
        exc = block.exits[-1]
        last_exception = exc.last_exception
        last_exc_value = exc.last_exc_value
        query = exc.target
        switches = []
        # collect the targets
        while len(query.exits) == 2:
            newrenaming = {}
            for lprev, ltarg in zip(exc.args, query.inputargs):
                newrenaming[ltarg] = lprev.replace(renaming)
            op = query.operations[0]
            if not (op.opname in ("is_", "issubtype") and
                    op.args[0].replace(newrenaming) == last_exception):
                break
            renaming.update(newrenaming)
            case = query.operations[0].args[-1].value
            assert issubclass(case, py.builtin.BaseException)
            lno, lyes = query.exits
            assert lno.exitcase == False and lyes.exitcase == True
            if case not in seen:
                is_covered = False
                for cov in covered:
                    if issubclass(case, cov):
                        is_covered = True
                        break
                if not is_covered:
                    switches.append( (case, lyes) )
                seen.append(case)
            exc = lno
            query = exc.target
        if Exception not in seen:
            switches.append( (Exception, exc) )
        # construct the block's new exits
        exits = []
        for case, oldlink in switches:
            link = oldlink.replace(renaming)
            assert case is not None
            link.last_exception = last_exception
            link.last_exc_value = last_exc_value
            # make the above two variables unique
            renaming2 = {}
            for v in link.getextravars():
                renaming2[v] = Variable(v)
            link = link.replace(renaming2)
            link.exitcase = case
            exits.append(link)
        block.recloseblock(*(preserve + exits))

def transform_xxxitem(graph):
    # xxx setitem too
    for block in graph.iterblocks():
        if block.canraise:
            last_op = block.raising_op
            if last_op.opname == 'getitem':
                postfx = []
                for exit in block.exits:
                    if exit.exitcase is IndexError:
                        postfx.append('idx')
                if postfx:
                    Op = getattr(op, '_'.join(['getitem'] + postfx))
                    newop = Op(*last_op.args)
                    newop.result = last_op.result
                    block.operations[-1] = newop


def remove_dead_exceptions(graph):
    """Exceptions can be removed if they are unreachable"""
    def issubclassofmember(cls, seq):
        for member in seq:
            if member and issubclass(cls, member):
                return True
        return False

    for block in list(graph.iterblocks()):
        if not block.canraise:
            continue
        exits = []
        seen = []
        for link in block.exits:
            case = link.exitcase
            # check whether exceptions are shadowed
            if issubclassofmember(case, seen):
                continue
            # see if the previous case can be merged
            while len(exits) > 1:
                prev = exits[-1]
                if not (issubclass(prev.exitcase, link.exitcase) and
                    prev.target is link.target and prev.args == link.args):
                    break
                exits.pop()
            exits.append(link)
            seen.append(case)
        block.recloseblock(*exits)

def constfold_exitswitch(graph):
    """Remove trivial links by merging their source and target blocks

    A link is trivial if it has no arguments, is the single exit of its
    source and the single parent of its target.
    """
    block = graph.startblock
    seen = set([block])
    stack = list(block.exits)
    while stack:
        link = stack.pop()
        target = link.target
        if target in seen:
            continue
        source = link.prevblock
        switch = source.exitswitch
        if (isinstance(switch, Constant) and not source.canraise):
            exits = replace_exitswitch_by_constant(source, switch)
            stack.extend(exits)
        else:
            seen.add(target)
            stack.extend(target.exits)


def remove_trivial_links(graph):
    """Remove trivial links by merging their source and target blocks

    A link is trivial if it has no arguments, is the single exit of its
    source and the single parent of its target.
    """
    entrymap = mkentrymap(graph)
    block = graph.startblock
    seen = set([block])
    stack = list(block.exits)
    while stack:
        link = stack.pop()
        if link.target in seen:
            continue
        source = link.prevblock
        target = link.target
        if (not link.args and source.exitswitch is None and
                len(entrymap[target]) == 1 and
                target.exits):  # stop at the returnblock
            assert len(source.exits) == 1
            source.operations.extend(target.operations)
            source.exitswitch = newexitswitch = target.exitswitch
            source.recloseblock(*target.exits)
            stack.extend(source.exits)
        else:
            seen.add(target)
            stack.extend(target.exits)


def join_blocks(graph):
    """Links can be deleted if they are the single exit of a block and
    the single entry point of the next block.  When this happens, we can
    append all the operations of the following block to the preceeding
    block (but renaming variables with the appropriate arguments.)
    """
    entrymap = mkentrymap(graph)
    block = graph.startblock
    seen = {block: True}
    stack = list(block.exits)
    while stack:
        link = stack.pop()
        if (link.prevblock.exitswitch is None and
            len(entrymap[link.target]) == 1 and
            link.target.exits):  # stop at the returnblock
            assert len(link.prevblock.exits) == 1
            renaming = {}
            for vprev, vtarg in zip(link.args, link.target.inputargs):
                renaming[vtarg] = vprev
            def rename_op(op):
                op = op.replace(renaming)
                # special case...
                if op.opname == 'indirect_call':
                    if isinstance(op.args[0], Constant):
                        assert isinstance(op.args[-1], Constant)
                        del op.args[-1]
                        op.opname = 'direct_call'
                return op
            for op in link.target.operations:
                link.prevblock.operations.append(rename_op(op))
            exits = []
            for exit in link.target.exits:
                newexit = exit.replace(renaming)
                exits.append(newexit)
            if link.target.exitswitch:
                newexitswitch = link.target.exitswitch.replace(renaming)
            else:
                newexitswitch = None
            link.prevblock.exitswitch = newexitswitch
            link.prevblock.recloseblock(*exits)
            if (isinstance(newexitswitch, Constant) and
                    not link.prevblock.canraise):
                exits = replace_exitswitch_by_constant(link.prevblock,
                                                       newexitswitch)
            stack.extend(exits)
        else:
            if link.target not in seen:
                stack.extend(link.target.exits)
                seen[link.target] = True

def remove_assertion_errors(graph):
    """Remove branches that go directly to raising an AssertionError,
    assuming that AssertionError shouldn't occur at run-time.  Note that
    this is how implicit exceptions are removed (see _implicit_ in
    flowcontext.py).
    """
    for block in list(graph.iterblocks()):
        for i in range(len(block.exits)-1, -1, -1):
            exit = block.exits[i]
            if not (exit.target is graph.exceptblock and
                    exit.args[0] == Constant(AssertionError)):
                continue
            # can we remove this exit without breaking the graph?
            if len(block.exits) < 2:
                break
            if block.canraise:
                if exit.exitcase is None:
                    break
                if len(block.exits) == 2:
                    # removing the last non-exceptional exit
                    block.exitswitch = None
                    exit.exitcase = None
            # remove this exit
            lst = list(block.exits)
            del lst[i]
            block.recloseblock(*lst)


# _____________________________________________________________________
# decide whether a function has side effects

def op_has_side_effects(op):
    return lloperation.LL_OPERATIONS[op.opname].sideeffects

def has_no_side_effects(translator, graph, seen=None):
    #is the graph specialized? if no we can't say anything
    #don't cache the result though
    if translator.rtyper is None:
        return False
    else:
        if graph.startblock not in translator.rtyper.already_seen:
            return False
    if seen is None:
        seen = {}
    elif graph in seen:
        return True
    newseen = seen.copy()
    newseen[graph] = True
    for block in graph.iterblocks():
        if block is graph.exceptblock:
            return False     # graphs explicitly raising have side-effects
        for op in block.operations:
            if rec_op_has_side_effects(translator, op, newseen):
                return False
    return True

def rec_op_has_side_effects(translator, op, seen=None):
    if op.opname == "direct_call":
        g = get_graph(op.args[0], translator)
        if g is None:
            return True
        if not has_no_side_effects(translator, g, seen):
            return True
    elif op.opname == "indirect_call":
        graphs = op.args[-1].value
        if graphs is None:
            return True
        for g in graphs:
            if not has_no_side_effects(translator, g, seen):
                return True
    else:
        return op_has_side_effects(op)

# ___________________________________________________________________________
# remove operations if their result is not used and they have no side effects

def transform_dead_op_vars(graph, translator=None):
    """Remove dead operations and variables that are passed over a link
    but not used in the target block. Input is a graph."""
    return transform_dead_op_vars_in_blocks(list(graph.iterblocks()),
                                            [graph], translator)

# the set of operations that can safely be removed
# (they have no side effects, at least in R-Python)
CanRemove = {}
for _op in '''
        newtuple newlist newdict bool
        is_ id type issubtype isinstance repr str len hash getattr getitem
        pos neg abs hex oct ord invert add sub mul
        truediv floordiv div mod divmod pow lshift rshift and_ or_
        xor int float long lt le eq ne gt ge cmp coerce contains
        iter get'''.split():
    CanRemove[_op] = True
from rpython.rtyper.lltypesystem.lloperation import enum_ops_without_sideeffects
for _op in enum_ops_without_sideeffects():
    CanRemove[_op] = True
del _op
CanRemoveBuiltins = {
    hasattr: True,
    }

def transform_dead_op_vars_in_blocks(blocks, graphs, translator=None):
    """Remove dead operations and variables that are passed over a link
    but not used in the target block. Input is a set of blocks"""
    read_vars = set()  # set of variables really used
    dependencies = defaultdict(set) # map {Var: list-of-Vars-it-depends-on}
    set_of_blocks = set(blocks)
    if len(graphs) == 1:
        start_blocks = {graphs[0].startblock}
    else:
        assert translator
        start_blocks = {translator.annotator.annotated[block].startblock
                for block in blocks}

    def canremove(op, block):
        return op.opname in CanRemove and op is not block.raising_op

    # compute dependencies and an initial read_vars
    for block in blocks:
        # figure out which variables are ever read
        for op in block.operations:
            if not canremove(op, block):   # the inputs are always needed
                read_vars.update(op.args)
            else:
                dependencies[op.result].update(op.args)

        if isinstance(block.exitswitch, Variable):
            read_vars.add(block.exitswitch)

        if block.exits:
            for link in block.exits:
                if link.target not in set_of_blocks:
                    for arg, targetarg in zip(link.args, link.target.inputargs):
                        read_vars.add(arg)
                        read_vars.add(targetarg)
                else:
                    for arg, targetarg in zip(link.args, link.target.inputargs):
                        dependencies[targetarg].add(arg)
        else:
            # return and except blocks implicitely use their input variable(s)
            for arg in block.inputargs:
                read_vars.add(arg)
        # a start block's inputargs should not be modified, even if some
        # of the function's input arguments are not actually used
        if block in start_blocks:
            for arg in block.inputargs:
                read_vars.add(arg)

    # flow read_vars backwards so that any variable on which a read_vars
    # depends is also included in read_vars
    def flow_read_var_backward(pending):
        while pending:
            var = pending.pop()
            for prevvar in dependencies[var]:
                if prevvar not in read_vars:
                    read_vars.add(prevvar)
                    pending.add(prevvar)

    flow_read_var_backward(set(read_vars))

    for block in blocks:

        # look for removable operations whose result is never used
        for i in range(len(block.operations)-1, -1, -1):
            op = block.operations[i]
            if op.result not in read_vars:
                if canremove(op, block):
                    del block.operations[i]
                elif op.opname == 'simple_call':
                    # XXX we want to have a more effective and safe
                    # way to check if this operation has side effects
                    # ...
                    if op.args and isinstance(op.args[0], Constant):
                        func = op.args[0].value
                        try:
                            if func in CanRemoveBuiltins:
                                del block.operations[i]
                        except TypeError:   # func is not hashable
                            pass
                elif op.opname == 'direct_call':
                    if translator is not None:
                        graph = get_graph(op.args[0], translator)
                        if (graph is not None and
                                has_no_side_effects(translator, graph) and
                                op is not block.raising_op):
                            del block.operations[i]
        # look for output variables never used
        # warning: this must be completely done *before* we attempt to
        # remove the corresponding variables from block.inputargs!
        # Otherwise the link.args get out of sync with the
        # link.target.inputargs.
        for link in block.exits:
            assert len(link.args) == len(link.target.inputargs)
            for i in range(len(link.args)-1, -1, -1):
                if link.target.inputargs[i] not in read_vars:
                    del link.args[i]
            # the above assert would fail here

    for block in blocks:
        # look for input variables never used
        # The corresponding link.args have already been all removed above
        for i in range(len(block.inputargs)-1, -1, -1):
            if block.inputargs[i] not in read_vars:
                del block.inputargs[i]

class Representative(object):
    def __init__(self, var):
        self.rep = var

    def absorb(self, other):
        pass

def all_equal(lst):
    first = lst[0]
    return all(first == x for x in lst[1:])

def isspecialvar(v):
    return isinstance(v, Variable) and v._name in ('last_exception_', 'last_exc_value_')

def remove_identical_vars_SSA(graph):
    """When the same variable is passed multiple times into the next block,
    pass it only once.  This enables further optimizations by the annotator,
    which otherwise doesn't realize that tests performed on one of the copies
    of the variable also affect the other."""
    uf = UnionFind(Representative)
    entrymap = mkentrymap(graph)
    del entrymap[graph.startblock]
    entrymap.pop(graph.returnblock, None)
    entrymap.pop(graph.exceptblock, None)
    inputs = {}
    for block, links in entrymap.items():
        phis = zip(block.inputargs, zip(*[link.args for link in links]))
        inputs[block] = phis

    def simplify_phis(block):
        phis = inputs[block]
        to_remove = []
        unique_phis = {}
        for i, (input, phi_args) in enumerate(phis):
            new_args = [uf.find_rep(arg) for arg in phi_args]
            if all_equal(new_args) and not isspecialvar(new_args[0]):
                uf.union(new_args[0], input)
                to_remove.append(i)
            else:
                t = tuple(new_args)
                if t in unique_phis:
                    uf.union(unique_phis[t], input)
                    to_remove.append(i)
                else:
                    unique_phis[t] = input
        for i in reversed(to_remove):
            del phis[i]
        return bool(to_remove)

    progress = True
    while progress:
        progress = False
        for block in inputs:
            if simplify_phis(block):
                progress = True

    renaming = dict((key, uf[key].rep) for key in uf)
    for block, links in entrymap.items():
        if inputs[block]:
            new_inputs, new_args = zip(*inputs[block])
            new_args = map(list, zip(*new_args))
        else:
            new_inputs = []
            new_args = [[] for _ in links]
        block.inputargs = new_inputs
        assert len(links) == len(new_args)
        for link, args in zip(links, new_args):
            link.args = args
    for block in entrymap:
        block.renamevariables(renaming)

def remove_identical_vars(graph):
    """When the same variable is passed multiple times into the next block,
    pass it only once.  This enables further optimizations by the annotator,
    which otherwise doesn't realize that tests performed on one of the copies
    of the variable also affect the other."""

    # This algorithm is based on DataFlowFamilyBuilder, used as a
    # "phi node remover" (in the SSA sense).  'variable_families' is a
    # UnionFind object that groups variables by families; variables from the
    # same family can be identified, and if two input arguments of a block
    # end up in the same family, then we really remove one of them in favor
    # of the other.
    #
    # The idea is to identify as much variables as possible by trying
    # iteratively two kinds of phi node removal:
    #
    #  * "vertical", by identifying variables from different blocks, when
    #    we see that a value just flows unmodified into the next block without
    #    needing any merge (this is what backendopt.ssa.SSI_to_SSA() would do
    #    as well);
    #
    #  * "horizontal", by identifying two input variables of the same block,
    #    when these two variables' phi nodes have the same argument -- i.e.
    #    when for all possible incoming paths they would get twice the same
    #    value (this is really the purpose of remove_identical_vars()).
    #
    builder = DataFlowFamilyBuilder(graph)
    variable_families = builder.get_variable_families()  # vertical removal
    while True:
        if not builder.merge_identical_phi_nodes():    # horizontal removal
            break
        if not builder.complete():                     # vertical removal
            break

    for block, links in mkentrymap(graph).items():
        if block is graph.startblock:
            continue
        renaming = {}
        family2blockvar = {}
        kills = []
        for i, v in enumerate(block.inputargs):
            v1 = variable_families.find_rep(v)
            if v1 in family2blockvar:
                # already seen -- this variable can be shared with the
                # previous one
                renaming[v] = family2blockvar[v1]
                kills.append(i)
            else:
                family2blockvar[v1] = v
        if renaming:
            block.renamevariables(renaming)
            # remove the now-duplicate input variables
            kills.reverse()   # starting from the end
            for i in kills:
                del block.inputargs[i]
                for link in links:
                    del link.args[i]


def coalesce_bool(graph):
    """coalesce paths that go through an bool and a directly successive
       bool both on the same value, transforming the link into the
       second bool from the first to directly jump to the correct
       target out of the second."""
    candidates = []

    def has_bool_exitpath(block):
        tgts = []
        start_op = block.operations[-1]
        cond_v = start_op.args[0]
        if block.exitswitch == start_op.result:
            for exit in block.exits:
                tgt = exit.target
                if tgt == block:
                    continue
                rrenaming = dict(zip(tgt.inputargs,exit.args))
                if len(tgt.operations) == 1 and tgt.operations[0].opname == 'bool':
                    tgt_op = tgt.operations[0]
                    if tgt.exitswitch == tgt_op.result and rrenaming.get(tgt_op.args[0]) == cond_v:
                        tgts.append((exit.exitcase, tgt))
        return tgts

    for block in graph.iterblocks():
        if block.operations and block.operations[-1].opname == 'bool':
            tgts = has_bool_exitpath(block)
            if tgts:
                candidates.append((block, tgts))

    while candidates:
        cand, tgts = candidates.pop()
        newexits = list(cand.exits)
        for case, tgt in tgts:
            exit = cand.exits[case]
            rrenaming = dict(zip(tgt.inputargs,exit.args))
            rrenaming[tgt.operations[0].result] = cand.operations[-1].result
            def rename(v):
                return rrenaming.get(v,v)
            newlink = tgt.exits[case].copy(rename)
            newexits[case] = newlink
        cand.recloseblock(*newexits)
        newtgts = has_bool_exitpath(cand)
        if newtgts:
            candidates.append((cand, newtgts))

# ____________________________________________________________

def detect_list_comprehension(graph):
    """Look for the pattern:            Replace it with marker operations:

                                         v0 = newlist()
        v2 = newlist()                   v1 = hint(v0, iterable, {'maxlength'})
        loop start                       loop start
        ...                              ...
        exactly one append per loop      v1.append(..)
        and nothing else done with v2
        ...                              ...
        loop end                         v2 = hint(v1, {'fence'})
    """
    # NB. this assumes RPythonicity: we can only iterate over something
    # that has a len(), and this len() cannot change as long as we are
    # using the iterator.
    builder = DataFlowFamilyBuilder(graph)
    variable_families = builder.get_variable_families()
    c_append = Constant('append')
    newlist_v = {}
    iter_v = {}
    append_v = []
    loopnextblocks = []

    # collect relevant operations based on the family of their result
    for block in graph.iterblocks():
        if (len(block.operations) == 1 and
                block.operations[0].opname == 'next' and
                block.canraise and len(block.exits) >= 2):
            cases = [link.exitcase for link in block.exits]
            if None in cases and StopIteration in cases:
                # it's a straightforward loop start block
                loopnextblocks.append((block, block.operations[0].args[0]))
                continue
        for op in block.operations:
            if op.opname == 'newlist' and not op.args:
                vlist = variable_families.find_rep(op.result)
                newlist_v[vlist] = block
            if op.opname == 'iter':
                viter = variable_families.find_rep(op.result)
                iter_v[viter] = block
    loops = []
    for block, viter in loopnextblocks:
        viterfamily = variable_families.find_rep(viter)
        if viterfamily in iter_v:
            # we have a next(viter) operation where viter comes from a
            # single known iter() operation.  Check that the iter()
            # operation is in the block just before.
            iterblock = iter_v[viterfamily]
            if (len(iterblock.exits) == 1 and iterblock.exitswitch is None
                and iterblock.exits[0].target is block):
                # yes - simple case.
                loops.append((block, iterblock, viterfamily))
    if not newlist_v or not loops:
        return

    # XXX works with Python >= 2.4 only: find calls to append encoded as
    # getattr/simple_call pairs, as produced by the LIST_APPEND bytecode.
    for block in graph.iterblocks():
        for i in range(len(block.operations)-1):
            op = block.operations[i]
            if op.opname == 'getattr' and op.args[1] == c_append:
                vlist = variable_families.find_rep(op.args[0])
                if vlist in newlist_v:
                    for j in range(i + 1, len(block.operations)):
                        op2 = block.operations[j]
                        if (op2.opname == 'simple_call' and len(op2.args) == 2
                            and op2.args[0] is op.result):
                            append_v.append((op.args[0], op.result, block))
                            break
    if not append_v:
        return
    detector = ListComprehensionDetector(graph, loops, newlist_v,
                                         variable_families)
    graphmutated = False
    for location in append_v:
        if graphmutated:
            # new variables introduced, must restart the whole process
            return detect_list_comprehension(graph)
        try:
            detector.run(*location)
        except DetectorFailed:
            pass
        else:
            graphmutated = True

class DetectorFailed(Exception):
    pass

class ListComprehensionDetector(object):

    def __init__(self, graph, loops, newlist_v, variable_families):
        self.graph = graph
        self.loops = loops
        self.newlist_v = newlist_v
        self.variable_families = variable_families
        self.reachable_cache = {}

    def enum_blocks_with_vlist_from(self, fromblock, avoid):
        found = {avoid: True}
        pending = [fromblock]
        while pending:
            block = pending.pop()
            if block in found:
                continue
            if not self.vlist_alive(block):
                continue
            yield block
            found[block] = True
            for exit in block.exits:
                pending.append(exit.target)

    def enum_reachable_blocks(self, fromblock, stop_at, stay_within=None):
        if fromblock is stop_at:
            return
        found = {stop_at: True}
        pending = [fromblock]
        while pending:
            block = pending.pop()
            if block in found:
                continue
            found[block] = True
            for exit in block.exits:
                if stay_within is None or exit.target in stay_within:
                    yield exit.target
                    pending.append(exit.target)

    def reachable_within(self, fromblock, toblock, avoid, stay_within):
        if toblock is avoid:
            return False
        for block in self.enum_reachable_blocks(fromblock, avoid, stay_within):
            if block is toblock:
                return True
        return False

    def reachable(self, fromblock, toblock, avoid):
        if toblock is avoid:
            return False
        try:
            return self.reachable_cache[fromblock, toblock, avoid]
        except KeyError:
            pass
        future = [fromblock]
        for block in self.enum_reachable_blocks(fromblock, avoid):
            self.reachable_cache[fromblock, block, avoid] = True
            if block is toblock:
                return True
            future.append(block)
        # 'toblock' is unreachable from 'fromblock', so it is also
        # unreachable from any of the 'future' blocks
        for block in future:
            self.reachable_cache[block, toblock, avoid] = False
        return False

    def vlist_alive(self, block):
        # check if 'block' is in the "cone" of blocks where
        # the vlistfamily lives
        try:
            return self.vlistcone[block]
        except KeyError:
            result = bool(self.contains_vlist(block.inputargs))
            self.vlistcone[block] = result
            return result

    def vlist_escapes(self, block):
        # check if the vlist "escapes" to uncontrolled places in that block
        try:
            return self.escapes[block]
        except KeyError:
            for op in block.operations:
                if op.result is self.vmeth:
                    continue       # the single getattr(vlist, 'append') is ok
                if op.opname == 'getitem':
                    continue       # why not allow getitem(vlist, index) too
                if self.contains_vlist(op.args):
                    result = True
                    break
            else:
                result = False
            self.escapes[block] = result
            return result

    def contains_vlist(self, args):
        for arg in args:
            if self.variable_families.find_rep(arg) is self.vlistfamily:
                return arg
        else:
            return None

    def remove_vlist(self, args):
        removed = 0
        for i in range(len(args)-1, -1, -1):
            arg = self.variable_families.find_rep(args[i])
            if arg is self.vlistfamily:
                del args[i]
                removed += 1
        assert removed == 1

    def run(self, vlist, vmeth, appendblock):
        # first check that the 'append' method object doesn't escape
        for hlop in appendblock.operations:
            if hlop.opname == 'simple_call' and hlop.args[0] is vmeth:
                pass
            elif vmeth in hlop.args:
                raise DetectorFailed      # used in another operation
        for link in appendblock.exits:
            if vmeth in link.args:
                raise DetectorFailed      # escapes to a next block

        self.vmeth = vmeth
        self.vlistfamily = self.variable_families.find_rep(vlist)
        newlistblock = self.newlist_v[self.vlistfamily]
        self.vlistcone = {newlistblock: True}
        self.escapes = {self.graph.returnblock: True,
                        self.graph.exceptblock: True}

        # in which loop are we?
        for loopnextblock, iterblock, viterfamily in self.loops:
            # check that the vlist is alive across the loop head block,
            # which ensures that we have a whole loop where the vlist
            # doesn't change
            if not self.vlist_alive(loopnextblock):
                continue      # no - unrelated loop

            # check that we cannot go from 'newlist' to 'append' without
            # going through the 'iter' of our loop (and the following 'next').
            # This ensures that the lifetime of vlist is cleanly divided in
            # "before" and "after" the loop...
            if self.reachable(newlistblock, appendblock, avoid=iterblock):
                continue

            # ... with the possible exception of links from the loop
            # body jumping back to the loop prologue, between 'newlist' and
            # 'iter', which we must forbid too:
            if self.reachable(loopnextblock, iterblock, avoid=newlistblock):
                continue

            # there must not be a larger number of calls to 'append' than
            # the number of elements that 'next' returns, so we must ensure
            # that we cannot go from 'append' to 'append' again without
            # passing 'next'...
            if self.reachable(appendblock, appendblock, avoid=loopnextblock):
                continue

            # ... and when the iterator is exhausted, we should no longer
            # reach 'append' at all.
            stopblocks = [link.target for link in loopnextblock.exits
                                      if link.exitcase is not None]
            accepted = True
            for stopblock1 in stopblocks:
                if self.reachable(stopblock1, appendblock, avoid=newlistblock):
                    accepted = False
            if not accepted:
                continue

            # now explicitly find the "loop body" blocks: they are the ones
            # from which we can reach 'append' without going through 'iter'.
            # (XXX inefficient)
            loopbody = {}
            for block in self.graph.iterblocks():
                if (self.vlist_alive(block) and
                    self.reachable(block, appendblock, iterblock)):
                    loopbody[block] = True

            # if the 'append' is actually after a 'break' or on a path that
            # can only end up in a 'break', then it won't be recorded as part
            # of the loop body at all.  This is a strange case where we have
            # basically proved that the list will be of length 1...  too
            # uncommon to worry about, I suspect
            if appendblock not in loopbody:
                continue

            # This candidate loop is acceptable if the list is not escaping
            # too early, i.e. in the loop header or in the loop body.
            loopheader = list(self.enum_blocks_with_vlist_from(newlistblock,
                                                    avoid=loopnextblock))
            assert loopheader[0] is newlistblock
            escapes = False
            for block in loopheader + loopbody.keys():
                assert self.vlist_alive(block)
                if self.vlist_escapes(block):
                    escapes = True
                    break

            if not escapes:
                break      # accept this loop!

        else:
            raise DetectorFailed      # no suitable loop

        # Found a suitable loop, let's patch the graph:
        assert iterblock not in loopbody
        assert loopnextblock in loopbody
        for stopblock1 in stopblocks:
            assert stopblock1 not in loopbody

        # at StopIteration, the new list is exactly of the same length as
        # the one we iterate over if it's not possible to skip the appendblock
        # in the body:
        exactlength = not self.reachable_within(loopnextblock, loopnextblock,
                                                avoid = appendblock,
                                                stay_within = loopbody)

        # - add a hint(vlist, iterable, {'maxlength'}) in the iterblock,
        #   where we can compute the known maximum length
        # - new in June 2017: we do that only if 'exactlength' is True.
        #   found some real use cases where the over-allocation scheme
        #   was over-allocating far too much: the loop would only append
        #   an item to the list after 'if some rare condition:'.  By
        #   dropping this hint, we disable preallocation and cause the
        #   append() to be done by checking the size, but still, after
        #   the loop, we will turn the list into a fixed-size one.
        #   ('maxlength_inexact' is never processed elsewhere; the hint
        #   is still needed to prevent this function from being entered
        #   in an infinite loop)
        link = iterblock.exits[0]
        vlist = self.contains_vlist(link.args)
        assert vlist
        for hlop in iterblock.operations:
            res = self.variable_families.find_rep(hlop.result)
            if res is viterfamily:
                break
        else:
            raise AssertionError("lost 'iter' operation")
        chint = Constant({'maxlength' if exactlength else 'maxlength_inexact':
                          True})
        hint = op.hint(vlist, hlop.args[0], chint)
        iterblock.operations.append(hint)
        link.args = list(link.args)
        for i in range(len(link.args)):
            if link.args[i] is vlist:
                link.args[i] = hint.result

        # - wherever the list exits the loop body, add a 'hint({fence})'
        for block in loopbody:
            for link in block.exits:
                if link.target not in loopbody:
                    vlist = self.contains_vlist(link.args)
                    if vlist is None:
                        continue  # list not passed along this link anyway
                    hints = {'fence': True}
                    if (exactlength and block is loopnextblock and
                        link.target in stopblocks):
                        hints['exactlength'] = True
                    chints = Constant(hints)
                    newblock = unsimplify.insert_empty_block(link)
                    index = link.args.index(vlist)
                    vlist2 = newblock.inputargs[index]
                    vlist3 = Variable(vlist2)
                    newblock.inputargs[index] = vlist3
                    hint = op.hint(vlist3, chints)
                    hint.result = vlist2
                    newblock.operations.append(hint)
        # done!


# ____ all passes & simplify_graph

all_passes = [
    transform_dead_op_vars,
    eliminate_empty_blocks,
    remove_assertion_errors,
    remove_identical_vars_SSA,
    constfold_exitswitch,
    remove_trivial_links,
    SSA_to_SSI,
    coalesce_bool,
    transform_ovfcheck,
    simplify_exceptions,
    transform_xxxitem,
    remove_dead_exceptions,
    ]

def simplify_graph(graph, passes=True): # can take a list of passes to apply, True meaning all
    """inplace-apply all the existing optimisations to the graph."""
    if passes is True:
        passes = all_passes
    for pass_ in passes:
        pass_(graph)
    checkgraph(graph)

def cleanup_graph(graph):
    checkgraph(graph)
    eliminate_empty_blocks(graph)
    join_blocks(graph)
    remove_identical_vars(graph)
    checkgraph(graph)
