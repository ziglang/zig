from rpython.translator.interactive import Translation
from rpython.translator.translator import graphof
from rpython.translator.backendopt.escape import AbstractDataFlowInterpreter
from rpython.translator.backendopt.escape import malloc_like_graphs
from rpython.rlib.objectmodel import instantiate
from rpython.conftest import option

def build_adi(function, types):
    t = Translation(function, types)
    t.rtype()
    if option.view:
        t.view()
    adi = AbstractDataFlowInterpreter(t.context)
    graph = graphof(t.context, function)
    adi.schedule_function(graph)
    adi.complete()
    return t.context, adi, graph

def test_simple():
    class A(object):
        pass
    def f():
        a = A()
        a.x = 1
        return a.x
    t, adi, graph = build_adi(f, [])
    avar = graph.startblock.operations[0].result
    state = adi.getstate(avar)
    crep, = state.creation_points
    assert not crep.escapes

def test_branch():
    class T:
        pass
    def fn2(x, y):
        t = T()
        t.x = x
        t.y = y
        if x > 0:
            return t.x + t.y
        else:
            return t.x - t.y
    t, adi, graph = build_adi(fn2, [int, int])
    tvar = graph.startblock.operations[0].result
    state = adi.getstate(tvar)
    crep, = state.creation_points
    assert not crep.escapes

def test_loop():
    class A(object):
        pass
    def f():
        a = A()
        i = 0
        while i < 3:
            a.x = i
            a = A()
            i += 1
        return a.x
    t, adi, graph = build_adi(f, [])
    avar = graph.startblock.operations[0].result
    state = adi.getstate(avar)
    crep, = state.creation_points
    assert not crep.escapes
    avarinloop = graph.startblock.exits[0].target.inputargs[1]
    state1 = adi.getstate(avarinloop)
    assert crep in state1.creation_points
    assert len(state1.creation_points) == 2

def test_global():
    class A(object):
        pass
    globala = A()
    def f():
        a = A()
        a.next = None
        globala.next = a
    t, adi, graph = build_adi(f, [])
    avar = graph.startblock.operations[0].result
    state = adi.getstate(avar)
    assert len(state.creation_points) == 1
    crep, = state.creation_points
    assert crep.escapes

def test_classattrs():
    class A:
        attr = 666
    class B(A):
        attr = 42
    def fn5():
        b = B()
        return b.attr
    t, adi, graph = build_adi(fn5, [])
    bvar = graph.startblock.operations[0].result
    state = adi.getstate(bvar)
    crep, = state.creation_points
    assert not crep.escapes

def test_aliasing():
    class A:
        pass
    def fn6(n):
        a1 = A()
        a1.x = 5
        a2 = A()
        a2.x = 6
        if n > 0:
            a = a1
        else:
            a = a2
        a.x = 12
        return a1.x
    t, adi, graph = build_adi(fn6, [int])
    op = graph.startblock.exits[0].target.operations[0]
    assert op.opname == 'setfield'
    avar = op.args[0]
    state = adi.getstate(avar)
    assert len(state.creation_points) == 2
    for crep in state.creation_points:
        assert not crep.escapes

def test_call():
    class A(object):
        pass
    def g(b):
        return b.i + 2
    def f():
        a = A()
        a.i = 2
        return g(a)
    t, adi, graph = build_adi(f, [])
    g_graph = graphof(t, g)
    bvar = g_graph.startblock.inputargs[0]
    bstate = adi.getstate(bvar)
    bcrep, = bstate.creation_points
    assert not bcrep.escapes
    avar = graph.startblock.operations[0].result
    astate = adi.getstate(avar)
    acrep, = astate.creation_points
    assert not acrep.escapes

def test_dependencies():
    class A(object):
        pass
    globala = A()
    globala.l = [1]
    def g(a):
        a.append(1)
        globala.l = a
    def f():
        a = [0]
        a.append(1)
        # g(a)
        return globala.l[0]
    t, adi, graph = build_adi(f, [])
    avar = graph.startblock.operations[0].result
    astate = adi.getstate(avar)
    appendgraph = graph.startblock.operations[3].args[0].value._obj.graph
    appendarg0 = appendgraph.startblock.inputargs[0]
    appendstate = adi.getstate(appendarg0)
    resizegraph = [op for op in appendgraph.startblock.operations if op.opname != "same_as"][2].args[0].value._obj.graph
    resizearg0 = resizegraph.startblock.inputargs[0]
    resizestate = adi.getstate(resizearg0)
    reallygraph = resizegraph.startblock.exits[0].target.operations[0].args[0].value._obj.graph
    reallyarg0 = reallygraph.startblock.inputargs[0]
    reallystate = adi.getstate(reallyarg0)

def test_substruct():
    class A(object):
        pass
    class B(object):
        pass
    def g(a, b):
        a.b = b
        a.b.x = 1
        return a.b
    def f():
        a0 = A()
        b0 = B()
        return g(a0, b0).x
    t, adi, graph = build_adi(f, [])
    g_graph = graphof(t, g)
    a0var = graph.startblock.operations[0].result
    b0var = graph.startblock.operations[3].result
    a0state = adi.getstate(a0var)
    b0state = adi.getstate(b0var)
    a0crep, = a0state.creation_points
    assert not a0crep.escapes
    b0crep, = b0state.creation_points
    assert b0crep.escapes

def test_multiple_calls():
    class A(object):
        pass
    def h(a, b):
        a.x = 1
        return b
    def g(a, b):
        return h(b, a)
    def f():
        a1 = A()
        a2 = A()
        a3 = A()
        a4 = h(a1, a2)
        a5 = g(a3, a4)
    t, adi, graph = build_adi(f, [])
    a1var = graph.startblock.operations[0].result
    a2var = graph.startblock.operations[3].result
    a3var = graph.startblock.operations[6].result
    a1state = adi.getstate(a1var)
    a2state = adi.getstate(a2var)
    a3state = adi.getstate(a3var)
    a1crep, = a1state.creation_points
    a2crep, = a2state.creation_points
    a3crep, = a3state.creation_points
    assert not a1crep.escapes and not a2crep.escapes and not a3crep.escapes
    assert not a1crep.returns and a2crep.returns and a3crep.returns

def test_indirect_call():
    class A(object):
        pass
    def f1(a):
        return a.x
    def f2(a):
        return a.x + 1
    def g1(a):
        return a
    def g2(a):
        return None
    def f(i):
        a1 = A()
        a2 = A()
        a1.x = 1
        a2.x = 2
        if i:
            f = f1
            g = g1
        else:
            f = f2
            g = g2
        x = f(a1)
        a0 = g(a2)
        if a0 is not None:
            return x
        else:
            return 42
    t, adi, graph = build_adi(f, [int])
    a1var = graph.startblock.operations[0].result
    a2var = graph.startblock.operations[3].result
    a1state = adi.getstate(a1var)
    a2state = adi.getstate(a2var)
    a1crep, = a1state.creation_points
    a2crep, = a2state.creation_points
    assert not a1crep.escapes and a2crep.returns

def test_indirect_call_unknown_graphs():
    class A:
        pass
    class B:
        pass
    def f(i):
        if i:
            klass = A
        else:
            klass = B
        a = instantiate(klass)
    # does not crash
    t, adi, graph = build_adi(f, [int])

def test_getarray():
    class A(object):
        pass
    def f():
        a = A()
        l = [None]
        l[0] = a
    t, adi, graph = build_adi(f, [])
    avar = graph.startblock.operations[0].result
    state = adi.getstate(avar)
    crep, = state.creation_points
    assert crep.escapes

def test_flow_blocksonce():
    class A(object):
        pass
    def f():
        a = 0
        for i in range(10):
            a += i
        b = A()
        b.x = 1
        return b.x + 2
    t, adi, graph = build_adi(f, [])
    avar = graph.startblock.exits[0].target.exits[1].target.operations[0].result
    state = adi.getstate(avar)
    assert not state.does_escape()

def test_call_external():
    import time
    def f():
        return time.time()
    #does not crash
    t, adi, graph = build_adi(f, [])

def test_getsubstruct():
    def f(i):
        s = "hello"
        return s[i]
    # does not crash
    t, adi, graph = build_adi(f, [int])

def test_getarraysubstruct():
    def createdict(i, j):
        d = {2 : 23,
             3 : 21}
        return d[i] + d[j]
    # does not crash, for now
    t, adi, graph = build_adi(createdict, [int, int])
    dvar = graph.startblock.operations[0].result
    dstate = adi.getstate(dvar)
    assert not dstate.does_escape()

def test_raise_escapes():
    def f():
        a = ValueError()
        raise a
    t, adi, graph = build_adi(f, [])
    avar = graph.startblock.operations[0].result
    state = adi.getstate(avar)
    assert state.does_escape()

def test_return():
    class A(object):
        pass
    def f():
        a = A()
        return a
    t, adi, graph = build_adi(f, [])
    avar = graph.startblock.operations[0].result
    state = adi.getstate(avar)
    assert not state.does_escape()
    assert state.does_return()


def test_big():
    from rpython.translator.goal.targetrpystonex import make_target_definition
    entrypoint, _, _ = make_target_definition(10)
    # does not crash
    t, adi, graph = build_adi(entrypoint, [int])

def test_find_malloc_like_graphs():
    class A(object):
        pass
    def f(x):
        a = A()
        a.x = x
        return a

    def g(a):
        return a

    def h(x):
        return f(x + 1)
    def main(x):
        return f(x).x + g(h(x)).x

    t, adi, graph = build_adi(main, [int])
    graphs = malloc_like_graphs(adi)
    assert set([g.name for g in graphs]) == set(["f", "h"])

