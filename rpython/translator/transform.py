"""Flow Graph Transformation

The difference between simplification and transformation is that
transformation is based on annotations; it runs after the annotator
completed.
"""

from rpython.flowspace.model import (
    SpaceOperation, Variable, Constant, Link, checkgraph)
from rpython.annotator import model as annmodel
from rpython.rtyper.lltypesystem import lltype

def checkgraphs(self, blocks):
    seen = set()
    for block in blocks:
        graph = self.annotated[block]
        if graph not in seen:
            checkgraph(graph)
            seen.add(graph)

def fully_annotated_blocks(self):
    """Ignore blocked blocks."""
    for block, is_annotated in self.annotated.iteritems():
        if is_annotated:
            yield block

# XXX: Lots of duplicated codes. Fix this!

# [a] * b
# -->
# c = newlist(a)
# d = mul(c, b)
# -->
# d = alloc_and_set(b, a)

def transform_allocate(self, block_subset):
    """Transforms [a] * b to alloc_and_set(b, a) where b is int."""
    for block in block_subset:
        length1_lists = {}   # maps 'c' to 'a', in the above notation
        for i in range(len(block.operations)):
            op = block.operations[i]
            if (op.opname == 'newlist' and
                len(op.args) == 1):
                length1_lists[op.result] = op.args[0]
            elif (op.opname == 'mul' and
                  op.args[0] in length1_lists):
                new_op = SpaceOperation('alloc_and_set',
                                        (op.args[1], length1_lists[op.args[0]]),
                                        op.result)
                block.operations[i] = new_op

# lst += string[x:y]
# -->
# b = getslice(string, x, y)
# c = inplace_add(lst, b)
# -->
# c = extend_with_str_slice(lst, x, y, string)

def transform_extend_with_str_slice(self, block_subset):
    """Transforms lst += string[x:y] to extend_with_str_slice"""
    for block in block_subset:
        slice_sources = {}    # maps b to [string, slice] in the above notation
        for i in range(len(block.operations)):
            op = block.operations[i]
            if (op.opname == 'getslice' and
                self.gettype(op.args[0]) is str):
                slice_sources[op.result] = op.args
            elif (op.opname == 'inplace_add' and
                  op.args[1] in slice_sources and
                  self.gettype(op.args[0]) is list):
                v_string, v_x, v_y = slice_sources[op.args[1]]
                new_op = SpaceOperation('extend_with_str_slice',
                                        [op.args[0], v_x, v_y, v_string],
                                        op.result)
                block.operations[i] = new_op

# lst += char*count        [or count*char]
# -->
# b = mul(char, count)     [or count, char]
# c = inplace_add(lst, b)
# -->
# c = extend_with_char_count(lst, char, count)

def transform_extend_with_char_count(self, block_subset):
    """Transforms lst += char*count to extend_with_char_count"""
    for block in block_subset:
        mul_sources = {}    # maps b to (char, count) in the above notation
        for i in range(len(block.operations)):
            op = block.operations[i]
            if op.opname == 'mul':
                s0 = self.annotation(op.args[0])
                s1 = self.annotation(op.args[1])
                if (isinstance(s0, annmodel.SomeChar) and
                    isinstance(s1, annmodel.SomeInteger)):
                    mul_sources[op.result] = op.args[0], op.args[1]
                elif (isinstance(s1, annmodel.SomeChar) and
                      isinstance(s0, annmodel.SomeInteger)):
                    mul_sources[op.result] = op.args[1], op.args[0]
            elif (op.opname == 'inplace_add' and
                  op.args[1] in mul_sources and
                  self.gettype(op.args[0]) is list):
                v_char, v_count = mul_sources[op.args[1]]
                new_op = SpaceOperation('extend_with_char_count',
                                        [op.args[0], v_char, v_count],
                                        op.result)
                block.operations[i] = new_op

# x in [2, 3]
# -->
# b = newlist(2, 3)
# c = contains(b, x)
# -->
# c = contains(Constant((2, 3)), x)

def transform_list_contains(self, block_subset):
    """Transforms x in [2, 3]"""
    for block in block_subset:
        newlist_sources = {}    # maps b to [2, 3] in the above notation
        for i in range(len(block.operations)):
            op = block.operations[i]
            if op.opname == 'newlist':
                newlist_sources[op.result] = op.args
            elif op.opname == 'contains' and op.args[0] in newlist_sources:
                items = {}
                for v in newlist_sources[op.args[0]]:
                    s = self.annotation(v)
                    if not s.is_immutable_constant():
                        break
                    items[s.const] = None
                else:
                    # all arguments of the newlist are annotation constants
                    op.args[0] = Constant(items)
                    s_dict = self.annotation(op.args[0])
                    s_dict.dictdef.generalize_key(self.binding(op.args[1]))


def transform_dead_op_vars(ann, block_subset):
    # we redo the same simplification from simplify.py,
    # to kill dead (never-followed) links,
    # which can possibly remove more variables.
    from rpython.translator.simplify import transform_dead_op_vars_in_blocks
    transform_dead_op_vars_in_blocks(block_subset, ann.translator.graphs,
            ann.translator)

def transform_dead_code(self, block_subset):
    """Remove dead code: these are the blocks that are not annotated at all
    because the annotation considered that no conditional jump could reach
    them."""
    for block in block_subset:
        for link in block.exits:
            if link not in self.links_followed:
                lst = list(block.exits)
                lst.remove(link)
                block.exits = tuple(lst)
                if not block.exits:
                    # oups! cannot reach the end of this block
                    cutoff_alwaysraising_block(self, block)
                elif block.canraise:
                    # exceptional exit
                    if block.exits[0].exitcase is not None:
                        # killed the non-exceptional path!
                        cutoff_alwaysraising_block(self, block)
                if len(block.exits) == 1:
                    block.exitswitch = None
                    block.exits[0].exitcase = None

def cutoff_alwaysraising_block(self, block):
    "Fix a block whose end can never be reached at run-time."
    # search the operation that cannot succeed
    can_succeed    = [op for op in block.operations
                         if op.result.annotation is not None]
    cannot_succeed = [op for op in block.operations
                         if op.result.annotation is None]
    n = len(can_succeed)
    # check consistency
    assert can_succeed == block.operations[:n]
    assert cannot_succeed == block.operations[n:]
    assert 0 <= n < len(block.operations)
    # chop off the unreachable end of the block
    del block.operations[n+1:]
    self.setbinding(block.operations[n].result, annmodel.s_ImpossibleValue)
    # insert the equivalent of 'raise AssertionError'
    graph = self.annotated[block]
    msg = "Call to %r should have raised an exception" % (getattr(graph, 'func', None),)
    c1 = Constant(AssertionError)
    c2 = Constant(AssertionError(msg))
    errlink = Link([c1, c2], graph.exceptblock)
    block.recloseblock(errlink, *block.exits)
    # record new link to make the transformation idempotent
    self.links_followed[errlink] = True
    # fix the annotation of the exceptblock.inputargs
    etype, evalue = graph.exceptblock.inputargs
    s_type = annmodel.SomeTypeOf([evalue])
    s_value = annmodel.SomeInstance(self.bookkeeper.getuniqueclassdef(Exception))
    self.setbinding(etype, s_type)
    self.setbinding(evalue, s_value)
    # make sure the bookkeeper knows about AssertionError
    self.bookkeeper.getuniqueclassdef(AssertionError)

def insert_ll_stackcheck(translator):
    from rpython.translator.backendopt.support import find_calls_from
    from rpython.rlib.rstack import stack_check
    from rpython.tool.algo.graphlib import Edge, make_edge_dict, break_cycles_v
    rtyper = translator.rtyper
    graph = rtyper.annotate_helper(stack_check, [])
    rtyper.specialize_more_blocks()
    stack_check_ptr = rtyper.getcallable(graph)
    stack_check_ptr_const = Constant(stack_check_ptr, lltype.typeOf(stack_check_ptr))
    edges = set()
    insert_in = set()
    block2graph = {}
    for caller in translator.graphs:
        pyobj = getattr(caller, 'func', None)
        if pyobj is not None:
            if getattr(pyobj, '_dont_insert_stackcheck_', False):
                continue
        for block, callee in find_calls_from(translator, caller):
            if getattr(getattr(callee, 'func', None),
                       'insert_stack_check_here', False):
                insert_in.add(callee.startblock)
                block2graph[callee.startblock] = callee
                continue
            if block is not caller.startblock:
                edges.add((caller.startblock, block))
                block2graph[caller.startblock] = caller
            edges.add((block, callee.startblock))
            block2graph[block] = caller

    edgelist = [Edge(block1, block2) for (block1, block2) in edges]
    edgedict = make_edge_dict(edgelist)
    for block in break_cycles_v(edgedict, edgedict):
        insert_in.add(block)

    for block in insert_in:
        v = Variable()
        v.concretetype = lltype.Void
        unwind_op = SpaceOperation('direct_call', [stack_check_ptr_const], v)
        block.operations.insert(0, unwind_op)
        # prevents cycles of tail calls from occurring -- such cycles would
        # not consume any stack, so would turn into potentially infinite loops
        graph = block2graph[block]
        graph.inhibit_tail_call = True
    return len(insert_in)


default_extra_passes = [
    transform_allocate,
    transform_extend_with_str_slice,
    transform_extend_with_char_count,
    transform_list_contains,
    ]

def transform_graph(ann, extra_passes=None, block_subset=None):
    """Apply set of transformations available."""
    # WARNING: this produces incorrect results if the graph has been
    #          modified by t.simplify() after it had been annotated.
    if extra_passes is None:
        extra_passes = default_extra_passes
    if block_subset is None:
        block_subset = fully_annotated_blocks(ann)
    if not isinstance(block_subset, dict):
        block_subset = dict.fromkeys(block_subset)
    if ann.translator:
        checkgraphs(ann, block_subset)
    transform_dead_code(ann, block_subset)
    for pass_ in extra_passes:
        pass_(ann, block_subset)
    # do this last, after the previous transformations had a
    # chance to remove dependency on certain variables
    transform_dead_op_vars(ann, block_subset)
    if ann.translator:
        checkgraphs(ann, block_subset)
