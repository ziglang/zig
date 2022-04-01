from rpython.translator.translator import TranslationContext, graphof
from rpython.translator.backendopt.support import \
     find_loop_blocks, find_backedges, compute_reachability

#__________________________________________________________
# test compute_reachability

def test_simple_compute_reachability():
    def f(x):
        if x < 0:
            if x == -1:
                return x+1
            else:
                return x+2
        else:
            if x == 1:
                return x-1
            else:
                return x-2
    t = TranslationContext()
    g = t.buildflowgraph(f)
    reach = compute_reachability(g)
    assert len(reach[g.startblock]) == 7
    assert len(reach[g.startblock.exits[0].target]) == 3
    assert len(reach[g.startblock.exits[1].target]) == 3
#__________________________________________________________
# test loop detection

def test_find_backedges():
    def f(k):
        result = 0
        for i in range(k):
            result += 1
        for j in range(k):
            result += 1
        return result
    t = TranslationContext()
    t.buildannotator().build_types(f, [int])
    t.buildrtyper().specialize()
    graph = graphof(t, f)
    backedges = find_backedges(graph)
    assert len(backedges) == 2

def test_find_loop_blocks():
    def f(k):
        result = 0
        for i in range(k):
            result += 1
        for j in range(k):
            result += 1
        return result
    t = TranslationContext()
    t.buildannotator().build_types(f, [int])
    t.buildrtyper().specialize()
    graph = graphof(t, f)
    loop_blocks = find_loop_blocks(graph)
    assert len(loop_blocks) == 4

def test_find_loop_blocks_simple():
    def f(a):
        if a <= 0:
            return 1
        return f(a - 1)
    t = TranslationContext()
    t.buildannotator().build_types(f, [int])
    t.buildrtyper().specialize()
    graph = graphof(t, f)
    backedges = find_backedges(graph)
    assert backedges == []
    loop_blocks = find_loop_blocks(graph)
    assert len(loop_blocks) == 0

def test_find_loop_blocks2():
    class A:
        pass
    def f(n):
        a1 = A()
        a1.x = 1
        a2 = A()
        a2.x = 2
        if n > 0:
            a = a1
        else:
            a = a2
        return a.x
    t = TranslationContext()
    t.buildannotator().build_types(f, [int])
    t.buildrtyper().specialize()
    graph = graphof(t, f)
    backedges = find_backedges(graph)
    assert backedges == []
    loop_blocks = find_loop_blocks(graph)
    assert len(loop_blocks) == 0

def test_find_loop_blocks3():
    import os
    def ps(loops):
        return 42.0, 42.1
    def f(loops):
        benchtime, stones = ps(abs(loops))
        s = '' # annotator happiness
        if loops >= 0:
            s = ("RPystone(%s) time for %d passes = %f" %
                 (23, loops, benchtime) + '\n' + (
                 "This machine benchmarks at %f pystones/second" % stones))
        os.write(1, s)
        if loops == 12345:
            f(loops-1)
    t = TranslationContext()
    t.buildannotator().build_types(f, [int])
    t.buildrtyper().specialize()
    graph = graphof(t, f)
    backedges = find_backedges(graph)
    assert backedges == []
    loop_blocks = find_loop_blocks(graph)
    assert len(loop_blocks) == 0

