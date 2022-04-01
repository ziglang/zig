from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.test.test_llinterp import gengraph
from rpython.conftest import option
from rpython.memory.gctransform.shadowcolor import *
from rpython.flowspace import model as graphmodel
from rpython.translator.simplify import join_blocks, cleanup_graph
from hypothesis import given, strategies


def make_graph(f, argtypes):
    t, rtyper, graph = gengraph(f, argtypes, viewbefore=False)
    if getattr(option, 'view', False):
        graph.show()
    return graph

def nameof(v):
    return v._name.rstrip('_')

def summary(interesting_vars):
    result = {}
    for v in interesting_vars:
        name = nameof(v)
        result[name] = result.get(name, 0) + 1
    return result

def summary_regalloc(regalloc):
    result = []
    for block in regalloc.graph.iterblocks():
        print block.inputargs
        for op in block.operations:
            print '\t', op
        blockvars = block.inputargs + [op.result for op in block.operations]
        for v in blockvars:
            if regalloc.consider_var(v):
                result.append((nameof(v), regalloc.getcolor(v)))
                print '\t\t%s: %s' % (v, regalloc.getcolor(v))
    result.sort()
    return result


def test_find_predecessors_1():
    def f(a, b):
        c = a + b
        return c
    graph = make_graph(f, [int, int])
    pred = find_predecessors(graph, [(graph.returnblock, graph.getreturnvar())])
    assert summary(pred) == {'c': 1, 'v': 1}

def test_find_predecessors_2():
    def f(a, b):
        c = a + b
        while a > 0:
            a -= 2
        return c
    graph = make_graph(f, [int, int])
    pred = find_predecessors(graph, [(graph.returnblock, graph.getreturnvar())])
    assert summary(pred) == {'c': 3, 'v': 1}

def test_find_predecessors_3():
    def f(a, b):
        while b > 100:
            b -= 2
        if b > 10:
            c = a + b      # 'c' created in this block
        else:
            c = a - b      # 'c' created in this block
        return c           # 'v' is the return var
    graph = make_graph(f, [int, int])
    pred = find_predecessors(graph, [(graph.returnblock, graph.getreturnvar())])
    assert summary(pred) == {'c': 2, 'v': 1}

def test_find_predecessors_4():
    def f(a, b):           # 'a' in the input block
        while b > 100:     # 'a' in the loop header block
            b -= 2         # 'a' in the loop body block
        if b > 10:         # 'a' in the condition block
            while b > 5:   # nothing
                b -= 2     # nothing
            c = a + b      # 'c' created in this block
        else:
            c = a
        return c           # 'v' is the return var
    graph = make_graph(f, [int, int])
    pred = find_predecessors(graph, [(graph.returnblock, graph.getreturnvar())])
    assert summary(pred) == {'a': 4, 'c': 1, 'v': 1}

def test_find_predecessors_trivial_rewrite():
    def f(a, b):                              # 'b' in empty startblock
        while a > 100:                        # 'b'
            a -= 2                            # 'b'
        c = llop.same_as(lltype.Signed, b)    # 'c', 'b'
        while b > 10:                         # 'c'
            b -= 2                            # 'c'
        d = llop.same_as(lltype.Signed, c)    # 'd', 'c'
        return d           # 'v' is the return var
    graph = make_graph(f, [int, int])
    pred = find_predecessors(graph, [(graph.returnblock, graph.getreturnvar())])
    assert summary(pred) == {'b': 4, 'c': 4, 'd': 1, 'v': 1}

def test_find_successors_1():
    def f(a, b):
        return a + b
    graph = make_graph(f, [int, int])
    succ = find_successors(graph, [(graph.startblock, graph.getargs()[0])])
    assert summary(succ) == {'a': 1}

def test_find_successors_2():
    def f(a, b):
        if b > 10:
            return a + b
        else:
            return a - b
    graph = make_graph(f, [int, int])
    succ = find_successors(graph, [(graph.startblock, graph.getargs()[0])])
    assert summary(succ) == {'a': 3}

def test_find_successors_3():
    def f(a, b):
        if b > 10:      # 'a' condition block
            a = a + b   # 'a' input
            while b > 100:
                b -= 2
        while b > 5:    # 'a' in loop header
            b -= 2      # 'a' in loop body
        return a * b    # 'a' in product
    graph = make_graph(f, [int, int])
    succ = find_successors(graph, [(graph.startblock, graph.getargs()[0])])
    assert summary(succ) == {'a': 5}

def test_find_successors_trivial_rewrite():
    def f(a, b):                              # 'b' in empty startblock
        while a > 100:                        # 'b'
            a -= 2                            # 'b'
        c = llop.same_as(lltype.Signed, b)    # 'c', 'b'
        while b > 10:                         # 'c', 'b'
            b -= 2                            # 'c', 'b'
        d = llop.same_as(lltype.Signed, c)    # 'd', 'c'
        return d           # 'v' is the return var
    graph = make_graph(f, [int, int])
    pred = find_successors(graph, [(graph.startblock, graph.getargs()[1])])
    assert summary(pred) == {'b': 6, 'c': 4, 'd': 1, 'v': 1}


def test_interesting_vars_0():
    def f(a, b):
        pass
    graph = make_graph(f, [llmemory.GCREF, int])
    assert not find_interesting_variables(graph)

def test_interesting_vars_1():
    def f(a, b):
        llop.gc_push_roots(lltype.Void, a)
        llop.gc_pop_roots(lltype.Void, a)
    graph = make_graph(f, [llmemory.GCREF, int])
    assert summary(find_interesting_variables(graph)) == {'a': 1}

def test_interesting_vars_2():
    def f(a, b, c):
        llop.gc_push_roots(lltype.Void, a)
        llop.gc_pop_roots(lltype.Void, a)
        while b > 0:
            b -= 5
        llop.gc_push_roots(lltype.Void, c)
        llop.gc_pop_roots(lltype.Void, c)
    graph = make_graph(f, [llmemory.GCREF, int, llmemory.GCREF])
    assert summary(find_interesting_variables(graph)) == {'a': 1, 'c': 1}

def test_interesting_vars_3():
    def f(a, b):
        llop.gc_push_roots(lltype.Void, a)
        llop.gc_pop_roots(lltype.Void, a)
        while b > 0:   # 'a' remains interesting across the blocks of this loop
            b -= 5
        llop.gc_push_roots(lltype.Void, a)
        llop.gc_pop_roots(lltype.Void, a)
    graph = make_graph(f, [llmemory.GCREF, int])
    assert summary(find_interesting_variables(graph)) == {'a': 4}

def test_allocate_registers_1():
    def f(a, b):
        llop.gc_push_roots(lltype.Void, a)
        llop.gc_pop_roots(lltype.Void, a)
        while b > 0:   # 'a' remains interesting across the blocks of this loop
            b -= 5
        llop.gc_push_roots(lltype.Void, a)
        llop.gc_pop_roots(lltype.Void, a)
    graph = make_graph(f, [llmemory.GCREF, int])
    regalloc = allocate_registers(graph)
    assert summary_regalloc(regalloc) == [('a', 0)] * 4

def test_allocate_registers_2():
    def f(a, b, c):
        llop.gc_push_roots(lltype.Void, a)
        llop.gc_pop_roots(lltype.Void, a)
        while b > 0:
            b -= 5
        llop.gc_push_roots(lltype.Void, c)
        llop.gc_pop_roots(lltype.Void, c)
    graph = make_graph(f, [llmemory.GCREF, int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    assert summary_regalloc(regalloc) == [('a', 0), ('c', 0)]

def test_allocate_registers_3():
    def f(a, b, c):
        llop.gc_push_roots(lltype.Void, c, a)
        llop.gc_pop_roots(lltype.Void, c, a)
        while b > 0:
            b -= 5
        llop.gc_push_roots(lltype.Void, a)
        llop.gc_pop_roots(lltype.Void, a)
    graph = make_graph(f, [llmemory.GCREF, int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    assert summary_regalloc(regalloc) == [('a', 1)] * 4 + [('c', 0)]

def test_allocate_registers_4():
    def g(a, x):
        return x   # (or something different)
    def f(a, b, c):
        llop.gc_push_roots(lltype.Void, a, c) # 'a', 'c'
        llop.gc_pop_roots(lltype.Void, a, c)
        while b > 0:                          # 'a' only; 'c' not in push_roots
            b -= 5
            llop.gc_push_roots(lltype.Void, a)# 'a'
            d = g(a, c)
            llop.gc_pop_roots(lltype.Void, a)
            c = d
        return c
    graph = make_graph(f, [llmemory.GCREF, int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    assert summary_regalloc(regalloc) == [('a', 1)] * 3 + [('c', 0)]

def test_allocate_registers_5():
    def g(a, x):
        return x   # (or something different)
    def f(a, b, c):
        while b > 0:                          # 'a', 'c'
            b -= 5
            llop.gc_push_roots(lltype.Void, a, c)  # 'a', 'c'
            g(a, c)
            llop.gc_pop_roots(lltype.Void, a, c)
        while b < 10:
            b += 2
        return c
    graph = make_graph(f, [llmemory.GCREF, int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    assert summary_regalloc(regalloc) == [('a', 1)] * 2 + [('c', 0)] * 2

@given(strategies.lists(strategies.booleans(), max_size=31))
def test_make_bitmask(boollist):
    index, bitmask = make_bitmask(boollist)
    if index is None:
        assert bitmask is None
    else:
        assert 0 <= index < len(boollist)
        assert boollist[index] == False
        assert bitmask >= 1
        while bitmask:
            if bitmask & 1:
                assert index >= 0
                assert boollist[index] == False
                boollist[index] = True
            bitmask >>= 1
            index -= 1
    assert boollist == [True] * len(boollist)


class FakeRegAlloc:
    graph = '?'

    def __init__(self, expected_op, **colors):
        self.expected_op = expected_op
        self.numcolors = len(colors)
        self.getcolor = colors.__getitem__

    def check(self, got):
        got = list(got)
        result = []
        for spaceop in got:
            assert spaceop.opname == self.expected_op
            result.append((spaceop.args[0].value, spaceop.args[1]))
        return result

def test_expand_one_push_roots():
    regalloc = FakeRegAlloc('gc_save_root', a=0, b=1, c=2)
    assert regalloc.check(expand_one_push_roots(regalloc, ['a', 'b', 'c'])) == [
        (0, 'a'), (1, 'b'), (2, 'c')]
    assert regalloc.check(expand_one_push_roots(regalloc, ['a', 'c'])) == [
        (0, 'a'), (2, 'c'), (1, Constant(0x1, lltype.Signed))]
    assert regalloc.check(expand_one_push_roots(regalloc, ['b'])) == [
        (1, 'b'), (2, Constant(0x5, lltype.Signed))]
    assert regalloc.check(expand_one_push_roots(regalloc, ['a'])) == [
        (0, 'a'), (2, Constant(0x3, lltype.Signed))]
    assert regalloc.check(expand_one_push_roots(regalloc, [])) == [
        (2, Constant(0x7, lltype.Signed))]

    assert list(expand_one_push_roots(None, [])) == []

def test_expand_one_pop_roots():
    regalloc = FakeRegAlloc('gc_restore_root', a=0, b=1, c=2)
    assert regalloc.check(expand_one_pop_roots(regalloc, ['a', 'b', 'c'])) == [
        (0, 'a'), (1, 'b'), (2, 'c')]
    assert regalloc.check(expand_one_pop_roots(regalloc, ['a', 'c'])) == [
        (0, 'a'), (2, 'c')]
    assert regalloc.check(expand_one_pop_roots(regalloc, ['b'])) == [
        (1, 'b')]
    assert regalloc.check(expand_one_pop_roots(regalloc, ['a'])) == [
        (0, 'a')]
    assert regalloc.check(expand_one_pop_roots(regalloc, [])) == []

    assert list(expand_one_pop_roots(None, [])) == []

def test_move_pushes_earlier_1():
    def g(a):
        return a - 1
    def f(a, b):
        a *= 2
        while a > 10:
            llop.gc_push_roots(lltype.Void, b)
            a = g(a)
            llop.gc_pop_roots(lltype.Void, b)
        return b

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    assert graphmodel.summary(graph) == {
        'int_mul': 1,
        'gc_enter_roots_frame': 1,
        'gc_save_root': 1,
        'gc_restore_root': 1,
        'int_gt': 1,
        'direct_call': 1,
        'gc_leave_roots_frame': 1,
        }
    assert len(graph.startblock.operations) == 3
    assert graph.startblock.operations[0].opname == 'int_mul'
    assert graph.startblock.operations[1].opname == 'gc_enter_roots_frame'
    assert graph.startblock.operations[2].opname == 'gc_save_root'
    assert graph.startblock.operations[2].args[0].value == 0
    postprocess_double_check(graph)

def test_move_pushes_earlier_2():
    def g(a):
        pass
    def f(a, b):
        llop.gc_push_roots(lltype.Void, b)
        g(a)
        llop.gc_pop_roots(lltype.Void, b)
        while a > 10:
            a -= 2
        llop.gc_push_roots(lltype.Void, b)
        g(a)
        llop.gc_pop_roots(lltype.Void, b)
        return b

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    assert graphmodel.summary(graph) == {
        'gc_save_root': 1,
        'gc_restore_root': 2,
        'int_gt': 1,
        'int_sub': 1,
        'direct_call': 2,
        }
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    postprocess_double_check(graph)

def test_remove_intrablock_push_roots():
    def g(a):
        pass
    def f(a, b):
        llop.gc_push_roots(lltype.Void, b)
        g(a)
        llop.gc_pop_roots(lltype.Void, b)
        llop.gc_push_roots(lltype.Void, b)
        g(a)
        llop.gc_pop_roots(lltype.Void, b)
        return b

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    assert graphmodel.summary(graph) == {
        'gc_save_root': 1,
        'gc_restore_root': 2,
        'direct_call': 2,
        }

PSTRUCT = lltype.Ptr(lltype.GcStruct('S'))

def test_move_pushes_earlier_rename_1():
    def g(a):
        pass
    def f(a, b):
        llop.gc_push_roots(lltype.Void, b)
        g(a)
        llop.gc_pop_roots(lltype.Void, b)
        c = lltype.cast_opaque_ptr(PSTRUCT, b)
        while a > 10:
            a -= 2
        llop.gc_push_roots(lltype.Void, c)
        g(a)
        llop.gc_pop_roots(lltype.Void, c)
        return c

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    assert graphmodel.summary(graph) == {
        'gc_save_root': 1,
        'gc_restore_root': 2,
        'cast_opaque_ptr': 1,
        'int_gt': 1,
        'int_sub': 1,
        'direct_call': 2,
        }
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    postprocess_double_check(graph)

def test_move_pushes_earlier_rename_2():
    def g(a):
        pass
    def f(a, b):
        llop.gc_push_roots(lltype.Void, b)
        g(a)
        llop.gc_pop_roots(lltype.Void, b)
        while a > 10:
            a -= 2
        c = lltype.cast_opaque_ptr(PSTRUCT, b)
        llop.gc_push_roots(lltype.Void, c)
        g(a)
        llop.gc_pop_roots(lltype.Void, c)
        return c

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    assert graphmodel.summary(graph) == {
        'gc_save_root': 1,
        'gc_restore_root': 2,
        'cast_opaque_ptr': 1,
        'int_gt': 1,
        'int_sub': 1,
        'direct_call': 2,
        }
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    postprocess_double_check(graph)

def test_move_pushes_earlier_rename_3():
    def g(a):
        pass
    def f(a, b):
        llop.gc_push_roots(lltype.Void, b)
        g(a)
        llop.gc_pop_roots(lltype.Void, b)
        while a > 10:
            a -= 2
        c = lltype.cast_opaque_ptr(PSTRUCT, b)
        while a > 10:
            a -= 2
        llop.gc_push_roots(lltype.Void, c)
        g(a)
        llop.gc_pop_roots(lltype.Void, c)
        return c

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    assert graphmodel.summary(graph) == {
        'gc_save_root': 1,
        'gc_restore_root': 2,
        'cast_opaque_ptr': 1,
        'int_gt': 2,
        'int_sub': 2,
        'direct_call': 2,
        }
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    postprocess_double_check(graph)

def test_move_pushes_earlier_rename_4():
    def g(a):
        return a - 2
    def f(a, b):
        while a > 10:
            b1 = lltype.cast_opaque_ptr(PSTRUCT, b)
            while a > 100:
                a -= 3
            b2 = lltype.cast_opaque_ptr(llmemory.GCREF, b1)
            llop.gc_push_roots(lltype.Void, b2)
            a = g(a)
            llop.gc_pop_roots(lltype.Void, b2)
            b3 = lltype.cast_opaque_ptr(PSTRUCT, b2)
            while a > 100:
                a -= 4
            b4 = lltype.cast_opaque_ptr(llmemory.GCREF, b3)
            llop.gc_push_roots(lltype.Void, b4)
            a = g(a)
            llop.gc_pop_roots(lltype.Void, b4)
            b5 = lltype.cast_opaque_ptr(PSTRUCT, b4)
            while a > 100:
                a -= 5
            b = lltype.cast_opaque_ptr(llmemory.GCREF, b5)
        return b

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    assert graphmodel.summary(graph) == {
        'gc_save_root': 1,
        'gc_restore_root': 2,
        'cast_opaque_ptr': 6,
        'int_gt': 4,
        'int_sub': 3,
        'direct_call': 2,
        }
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    postprocess_double_check(graph)

def test_add_leave_roots_frame_1():
    def g(b):
        pass
    def f(a, b):
        if a & 1:
            llop.gc_push_roots(lltype.Void, b)
            g(b)
            llop.gc_pop_roots(lltype.Void, b)
            a += 5
        else:
            llop.gc_push_roots(lltype.Void, b)
            g(b)
            llop.gc_pop_roots(lltype.Void, b)
            a += 6
        #...b forgotten here, even though it is pushed/popped above
        while a > 100:
            a -= 3
        return a

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    assert len(graph.startblock.exits) == 2
    for link in graph.startblock.exits:
        assert [op.opname for op in link.target.operations] == [
            'gc_enter_roots_frame',
            'gc_save_root',
            'direct_call',
            'gc_restore_root',
            'gc_leave_roots_frame',
            'int_add']
    postprocess_double_check(graph)

def test_add_leave_roots_frame_2():
    def g(b):
        pass
    def f(a, b):
        llop.gc_push_roots(lltype.Void, b)
        g(b)
        llop.gc_pop_roots(lltype.Void, b)
        #...b forgotten here; the next push/pop is empty
        llop.gc_push_roots(lltype.Void)
        g(b)
        llop.gc_pop_roots(lltype.Void)
        while a > 100:
            a -= 3
        return a

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    assert [op.opname for op in graph.startblock.operations] == [
        'gc_enter_roots_frame',
        'gc_save_root',
        'direct_call',
        'gc_restore_root',
        'gc_leave_roots_frame',
        'direct_call']
    postprocess_double_check(graph)

def test_bug_1():
    class W:
        pass
    def foo(a):
        if a < 10:
            return W()
        else:
            return None
    def compare(w_a, w_b):
        return W()
    def fetch_compare(w_a, w_b):
        return W()
    def is_true(a, w_b):
        return not a
    def call_next(w_a):
        return W()

    def f(a, w_tup):
        llop.gc_push_roots(lltype.Void, w_tup)
        w_key = foo(a)
        llop.gc_pop_roots(lltype.Void, w_tup)

        llop.gc_push_roots(lltype.Void, w_key)
        w_iter = foo(a)
        llop.gc_pop_roots(lltype.Void, w_key)

        has_key = w_key is not None
        hasit = False
        w_maxit = None
        w_max_val = None

        while True:
            llop.gc_push_roots(lltype.Void, w_iter, w_key, w_maxit, w_max_val)
            w_item = call_next(w_iter)
            llop.gc_pop_roots(lltype.Void, w_iter, w_key, w_maxit, w_max_val)

            if has_key:
                llop.gc_push_roots(lltype.Void, w_iter, w_key,
                                       w_maxit, w_max_val, w_item)
                w_compare_with = fetch_compare(w_key, w_item)
                llop.gc_pop_roots(lltype.Void, w_iter, w_key,
                                       w_maxit, w_max_val, w_item)
            else:
                w_compare_with = w_item

            if hasit:
                llop.gc_push_roots(lltype.Void, w_iter, w_key,
                                w_maxit, w_max_val, w_item, w_compare_with)
                w_bool = compare(w_compare_with, w_max_val)
                llop.gc_pop_roots(lltype.Void, w_iter, w_key,
                                w_maxit, w_max_val, w_item, w_compare_with)

                llop.gc_push_roots(lltype.Void, w_iter, w_key,
                                w_maxit, w_max_val, w_item, w_compare_with)
                condition = is_true(a, w_bool)
                llop.gc_pop_roots(lltype.Void, w_iter, w_key,
                                w_maxit, w_max_val, w_item, w_compare_with)
            else:
                condition = True

            if condition:
                hasit = True
                w_maxit = w_item
                w_max_val = w_compare_with

    graph = make_graph(f, [int, llmemory.GCREF])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    postprocess_double_check(graph)

def test_bug_2():
    def f(w_tup):
        while True:
            llop.gc_push_roots(lltype.Void, w_tup)
            llop.gc_pop_roots(lltype.Void, w_tup)

    graph = make_graph(f, [llmemory.GCREF])
    assert not graph.startblock.operations
    # this test is about what occurs if the startblock of the graph
    # is also reached from another block.  None of the 'simplify'
    # functions actually remove that, but the JIT transformation can...
    graph.startblock = graph.startblock.exits[0].target

    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    postprocess_double_check(graph)

def test_add_enter_roots_frame_remove_empty():
    class W:
        pass
    def g():
        return W()
    def h(x):
        pass
    def k():
        pass
    def f():
        llop.gc_push_roots(lltype.Void)
        x = g()
        llop.gc_pop_roots(lltype.Void)
        llop.gc_push_roots(lltype.Void, x)
        h(x)
        llop.gc_pop_roots(lltype.Void, x)
        llop.gc_push_roots(lltype.Void)
        h(x)
        llop.gc_pop_roots(lltype.Void)
        llop.gc_push_roots(lltype.Void)
        k()
        llop.gc_pop_roots(lltype.Void)

    graph = make_graph(f, [])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    assert [op.opname for op in graph.startblock.operations] == [
        "direct_call",
        "gc_enter_roots_frame",
        "gc_save_root",
        "direct_call",
        "gc_restore_root",
        "gc_leave_roots_frame",
        "direct_call",
        "direct_call",
        ]
    postprocess_double_check(graph)

def test_add_enter_roots_frame_avoided():
    def g(x):
        return x
    def f(x, n):
        if n > 100:
            llop.gc_push_roots(lltype.Void, x)
            g(x)
            llop.gc_pop_roots(lltype.Void, x)
        return x

    graph = make_graph(f, [llmemory.GCREF, int])
    regalloc = allocate_registers(graph)
    expand_push_roots(graph, regalloc)
    move_pushes_earlier(graph, regalloc)
    expand_pop_roots(graph, regalloc)
    add_enter_leave_roots_frame(graph, regalloc, Constant('fake gcdata'))
    assert [op.opname for op in graph.startblock.operations] == [
        'int_gt', 'same_as']
    [fastpath, slowpath] = graph.startblock.exits
    assert fastpath.target is graph.returnblock
    block2 = slowpath.target
    assert [op.opname for op in block2.operations] == [
        'gc_enter_roots_frame',
        'gc_save_root',
        'direct_call',
        'gc_restore_root',
        'gc_leave_roots_frame']
    postprocess_double_check(graph)

def test_fix_graph_after_inlining():
    # the graph of f looks like it inlined another graph, which itself
    # would be "if x > 100: foobar()".  The foobar() function is supposed
    # to be the big slow-path.
    def foobar():
        print 42
    def f(x):
        llop.gc_push_roots(lltype.Void, x)
        if x > 100:  # slow-path
            foobar()
        llop.gc_pop_roots(lltype.Void, x)
        return x
    graph = make_graph(f, [int])
    postprocess_inlining(graph)
    cleanup_graph(graph)
    assert [op.opname for op in graph.startblock.operations] == [
        'int_gt', 'same_as']
    [fastpath, slowpath] = graph.startblock.exits
    assert fastpath.target is graph.returnblock
    block2 = slowpath.target
    [v] = block2.inputargs
    assert block2.operations[0].opname == 'gc_push_roots'
    assert block2.operations[0].args == [v]
    assert block2.operations[1].opname == 'direct_call'   # -> foobar
    assert block2.operations[2].opname == 'gc_pop_roots'
    assert block2.operations[2].args == [v]
    assert len(block2.exits) == 1
    assert block2.exits[0].target is graph.returnblock
