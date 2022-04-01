import py
from rpython.flowspace.model import checkgraph, Constant, summary
from rpython.translator.translator import TranslationContext, graphof
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper import rclass
from rpython.rlib import objectmodel
from rpython.translator.backendopt.constfold import constant_fold_graph
from rpython.translator.backendopt.constfold import replace_we_are_jitted
from rpython.conftest import option

def get_graph(fn, signature):
    t = TranslationContext()
    t.buildannotator().build_types(fn, signature)
    t.buildrtyper().specialize()
    graph = graphof(t, fn)
    if option.view:
        t.view()
    return graph, t

def check_graph(graph, args, expected_result, t):
    if option.view:
        t.view()
    checkgraph(graph)
    interp = LLInterpreter(t.rtyper)
    res = interp.eval_graph(graph, args)
    assert res == expected_result


def test_simple(S1=None):
    if S1 is None:
        S1 = lltype.GcStruct('S1', ('x', lltype.Signed),
                             hints={'immutable': True})
    s1 = lltype.malloc(S1)
    s1.x = 123
    def g(y):
        return y + 1
    def fn():
        return g(s1.x)

    graph, t = get_graph(fn, [])
    assert summary(graph) == {'getfield': 1, 'direct_call': 1}
    constant_fold_graph(graph)
    assert summary(graph) == {'direct_call': 1}
    check_graph(graph, [], 124, t)


def test_immutable_fields():
    accessor = rclass.FieldListAccessor()
    S2 = lltype.GcStruct('S2', ('x', lltype.Signed),
                         hints={'immutable_fields': accessor})
    accessor.initialize(S2, {'x': rclass.IR_IMMUTABLE})
    test_simple(S2)


def test_along_link():
    S1 = lltype.GcStruct('S1', ('x', lltype.Signed), hints={'immutable': True})
    s1 = lltype.malloc(S1)
    s1.x = 123
    s2 = lltype.malloc(S1)
    s2.x = 60
    def fn(x):
        if x:
            x = s1.x
        else:
            x = s2.x
        return x+1

    graph, t = get_graph(fn, [int])
    assert summary(graph) == {'int_is_true': 1,
                              'getfield': 2,
                              'int_add': 1}
    constant_fold_graph(graph)
    assert summary(graph) == {'int_is_true': 1}
    check_graph(graph, [-1], 124, t)
    check_graph(graph, [0], 61, t)


def test_multiple_incoming_links():
    S1 = lltype.GcStruct('S1', ('x', lltype.Signed), hints={'immutable': True})
    s1 = lltype.malloc(S1)
    s1.x = 123
    s2 = lltype.malloc(S1)
    s2.x = 60
    s3 = lltype.malloc(S1)
    s3.x = 15
    def fn(x):
        y = x * 10
        if x == 1:
            x = s1.x
        elif x == 2:
            x = s2.x
        elif x == 3:
            x = s3.x
            y = s1.x
        return (x+1) + y

    graph, t = get_graph(fn, [int])
    constant_fold_graph(graph)
    assert summary(graph) == {'int_mul': 1, 'int_eq': 3, 'int_add': 2}
    for link in graph.iterlinks():
        if Constant(139) in link.args:
            break
    else:
        raise AssertionError("139 not found in the graph as a constant")
    for i in range(4):
        check_graph(graph, [i], fn(i), t)


def test_fold_exitswitch():
    S1 = lltype.GcStruct('S1', ('x', lltype.Signed), hints={'immutable': True})
    s1 = lltype.malloc(S1)
    s1.x = 123
    s2 = lltype.malloc(S1)
    s2.x = 60
    def fn(n):
        if s1.x:
            return n * 5
        else:
            return n - 7

    graph, t = get_graph(fn, [int])
    assert summary(graph) == {'getfield': 1,
                              'int_is_true': 1,
                              'int_mul': 1,
                              'int_sub': 1}
    constant_fold_graph(graph)
    assert summary(graph) == {'int_mul': 1}
    check_graph(graph, [12], 60, t)


def test_exception():
    def g():
        return 15
    def fn(n):
        try:
            g()
        except ValueError:
            pass
        return n

    graph, t = get_graph(fn, [int])
    constant_fold_graph(graph)
    check_graph(graph, [12], 12, t)


def test_malloc():
    S1 = lltype.GcStruct('S1', ('x', lltype.Signed), hints={'immutable': True})
    def fn():
        s = lltype.malloc(S1)
        s.x = 12
        objectmodel.keepalive_until_here(s)
        return s.x

    graph, t = get_graph(fn, [])
    constant_fold_graph(graph)
    check_graph(graph, [], 12, t)


def xxx_test_later_along_link():
    S1 = lltype.GcStruct('S1', ('x', lltype.Signed), hints={'immutable': True})
    s1 = lltype.malloc(S1)
    s1.x = 123
    s2 = lltype.malloc(S1)
    s2.x = 60
    def fn(x, y):
        if x:
            x = s1.x
        else:
            x = s2.x
        y *= 2
        return (x+1) - y

    graph, t = get_graph(fn, [int, int])
    assert summary(graph) == {'int_is_true': 1,
                              'getfield': 2,
                              'int_mul': 1,
                              'int_add': 1,
                              'int_sub': 1}
    constant_fold_graph(graph)
    assert summary(graph) == {'int_is_true': 1,
                              'int_mul': 1,
                              'int_sub': 1}
    check_graph(graph, [-1], 124, t)
    check_graph(graph, [0], 61, t)


def test_keepalive_const_fieldptr():
    S1 = lltype.GcStruct('S1', ('x', lltype.Signed))
    s1 = lltype.malloc(S1)
    s1.x = 1234
    def fn():
        p1 = lltype.direct_fieldptr(s1, 'x')
        return p1[0]
    graph, t = get_graph(fn, [])
    assert summary(graph) == {'direct_fieldptr': 1, 'getarrayitem': 1}
    constant_fold_graph(graph)

    # kill all references to 's1'
    s1 = fn = None
    del graph.func
    import gc; gc.collect()

    assert summary(graph) == {'getarrayitem': 1}
    check_graph(graph, [], 1234, t)


def test_keepalive_const_arrayitems():
    A1 = lltype.GcArray(lltype.Signed)
    a1 = lltype.malloc(A1, 10)
    a1[6] = 1234
    def fn():
        p1 = lltype.direct_arrayitems(a1)
        p2 = lltype.direct_ptradd(p1, 6)
        return p2[0]
    graph, t = get_graph(fn, [])
    assert summary(graph) == {'direct_arrayitems': 1, 'direct_ptradd': 1,
                              'getarrayitem': 1}
    constant_fold_graph(graph)

    # kill all references to 'a1'
    a1 = fn = None
    del graph.func
    import gc; gc.collect()

    assert summary(graph) == {'getarrayitem': 1}
    check_graph(graph, [], 1234, t)


def test_dont_constfold_debug_print():
    def fn():
        llop.debug_print(lltype.Void, "hello world")

    graph, t = get_graph(fn, [])
    assert summary(graph) == {'debug_print': 1}
    constant_fold_graph(graph)
    assert summary(graph) == {'debug_print': 1}


def test_fold_exitswitch_along_one_path():
    def g(n):
        if n == 42:
            return 5
        else:
            return n+1
    def fn(n):
        if g(n) == 5:
            return 100
        else:
            return 0

    graph, t = get_graph(fn, [int])
    from rpython.translator.backendopt import removenoops, inline
    inline.auto_inline_graphs(t, t.graphs, threshold=999)
    constant_fold_graph(graph)
    removenoops.remove_same_as(graph)
    if option.view:
        t.view()
    # check that the graph starts with a condition (which should be 'n==42')
    # and that if this condition is true, it goes directly to 'return 100'.
    assert len(graph.startblock.exits) == 2
    assert graph.startblock.exits[1].exitcase == True
    assert graph.startblock.exits[1].target is graph.returnblock
    check_graph(graph, [10], 0, t)
    check_graph(graph, [42], 100, t)

def test_knownswitch_after_exitswitch():
    def fn(n):
        cond = n > 10
        if cond:
            return cond + 5
        else:
            return cond + 17

    graph, t = get_graph(fn, [int])
    from rpython.translator.backendopt import removenoops
    removenoops.remove_same_as(graph)
    constant_fold_graph(graph)
    if option.view:
        t.view()
    assert summary(graph) == {'int_gt': 1}
    check_graph(graph, [2], 17, t)
    check_graph(graph, [42], 6, t)

def test_coalesce_exitswitchs():
    def g(n):
        return n > 5 and n < 20
    def fn(n):
        if g(n):
            return 100
        else:
            return 0

    graph, t = get_graph(fn, [int])
    from rpython.translator.backendopt import removenoops, inline
    inline.auto_inline_graphs(t, t.graphs, threshold=999)
    removenoops.remove_same_as(graph)
    constant_fold_graph(graph)
    if option.view:
        t.view()
    # check that the graph starts with a condition (which should be 'n > 5')
    # and that if this condition is false, it goes directly to 'return 0'.
    assert summary(graph) == {'int_gt': 1, 'int_lt': 1}
    assert len(graph.startblock.exits) == 2
    assert graph.startblock.exits[0].exitcase == False
    assert graph.startblock.exits[0].target is graph.returnblock
    check_graph(graph, [2], 0, t)
    check_graph(graph, [10], 100, t)
    check_graph(graph, [42], 0, t)

def test_merge_if_blocks_bug():
    def fn(n):
        if n == 1: return 5
        elif n == 2: return 6
        elif n == 3: return 8
        elif n == 4: return -123
        elif n == 5: return 12973
        else: return n
    
    graph, t = get_graph(fn, [int])
    from rpython.translator.backendopt.removenoops import remove_same_as
    from rpython.translator.backendopt import merge_if_blocks
    remove_same_as(graph)
    merge_if_blocks.merge_if_blocks_once(graph)
    constant_fold_graph(graph)
    check_graph(graph, [4], -123, t)
    check_graph(graph, [9], 9, t)

def test_merge_if_blocks_bug_2():
    def fn():
        n = llop.same_as(lltype.Signed, 66)
        if n == 1: return 5
        elif n == 2: return 6
        elif n == 3: return 8
        elif n == 4: return -123
        elif n == 5: return 12973
        else: return n
    
    graph, t = get_graph(fn, [])
    from rpython.translator.backendopt.removenoops import remove_same_as
    from rpython.translator.backendopt import merge_if_blocks
    remove_same_as(graph)
    merge_if_blocks.merge_if_blocks_once(graph)
    constant_fold_graph(graph)
    check_graph(graph, [], 66, t)

def test_replace_we_are_jitted():
    from rpython.rlib import jit
    def fn():
        if jit.we_are_jitted():
            return 1
        return 2 + jit.we_are_jitted()
    graph, t = get_graph(fn, [])
    result = replace_we_are_jitted(graph)
    assert result
    checkgraph(graph)
    # check shape of graph
    assert len(graph.startblock.operations) == 0
    assert graph.startblock.exitswitch is None
    assert graph.startblock.exits[0].target.exits[0].args[0].value == 2
