from rpython.translator.backendopt.merge_if_blocks import merge_if_blocks_once
from rpython.translator.backendopt.merge_if_blocks import merge_if_blocks
from rpython.translator.backendopt.all import backend_optimizations
from rpython.translator.translator import TranslationContext, graphof as tgraphof
from rpython.flowspace.model import Block, checkgraph
from rpython.translator.backendopt.removenoops import remove_same_as
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rlib.rarithmetic import r_uint, r_ulonglong, r_longlong, r_int
from rpython.annotator.model import SomeChar, SomeUnicodeCodePoint
from rpython.rlib.objectmodel import CDefinedIntSymbolic

def do_test_merge(fn, testvalues):
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(fn, [type(testvalues[0])])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    graph = tgraphof(t, fn)
    assert len(list(graph.iterblocks())) == 4 #startblock, blocks, returnblock
    remove_same_as(graph)
    merge_if_blocks_once(graph)
    assert len(graph.startblock.exits) == 4
    assert len(list(graph.iterblocks())) == 2 #startblock, returnblock
    interp = LLInterpreter(rtyper)
    for i in testvalues:
        expected = fn(i)
        actual = interp.eval_graph(graph, [i])
        assert actual == expected

def test_merge1():
    def merge_int(n):
        n += 1
        if n == 1:
            return 1
        elif n == 2:
            return 2
        elif n == 3:
            return 3
        return 4
    do_test_merge(merge_int, range(4))
    do_test_merge(merge_int, [r_uint(i) for i in range(4)])
    # this has been disabled:
    #if r_longlong is not r_int:
    #    do_test_merge(merge_int, [r_longlong(i) for i in range(4)])
    #do_test_merge(merge_int, [r_ulonglong(i) for i in range(4)])

    def merge_chr(n):
        c = chr(n + 1)
        if c == 'a':
            return 'a'
        elif c == 'b':
            return 'b'
        elif c == 'c':
            return 'c'
        return 'd'
    do_test_merge(merge_chr, range(96, 101))

    def merge_uchr(n):
        c = unichr(n + 1)
        if c == u'a':
            return u'a'
        elif c == u'b':
            return u'b'
        elif c == u'c':
            return u'c'
        return u'd'
    do_test_merge(merge_uchr, range(96, 101))
    
def test_merge_passonvars():
    def merge(n, m):
        if n == 1:
            return m + 1
        elif n == 2:
            return m + 2
        elif n == 3:
            return m + 3
        return m + 4
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(merge, [int, int])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    graph = tgraphof(t, merge)
    assert len(list(graph.iterblocks())) == 8
    remove_same_as(graph)
    merge_if_blocks_once(graph)
    assert len(graph.startblock.exits) == 4
    interp = LLInterpreter(rtyper)
    for i in range(1, 5):
        res = interp.eval_graph(graph, [i, 1])
        assert res == i + 1

def test_merge_several():
    def merge(n, m):
        r = -1
        if n == 0:
            if m == 0:
                r = 0
            elif m == 1:
                r = 1
            else:
                r = 2
        elif n == 1:
            r = 4
        else:
            r = 6
        return r
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(merge, [int, int])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    graph = tgraphof(t, merge)
    remove_same_as(graph)
    merge_if_blocks(graph)
    assert len(graph.startblock.exits) == 3
    assert len(list(graph.iterblocks())) == 3
    interp = LLInterpreter(rtyper)
    for m in range(3):
        res = interp.eval_graph(graph, [0, m])
        assert res == m
    res = interp.eval_graph(graph, [1, 0])
    assert res == 4
    res = interp.eval_graph(graph, [2, 0])
    assert res == 6


def test_merge_with_or():
    def merge(n):
        if n == 5:
            return 4
        elif n == 14 or n == 2:
            return 16
        else:
            return 7
    do_test_merge(merge, [5, 6, 14, 2, 3, 123])


def test_dont_merge():
    def merge(n, m):
        r = -1
        if n == 0:
            r += m
        if n == 1:
            r += 2 * m
        else:
            r += 6
        return r
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(merge, [int, int])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    graph = tgraphof(t, merge)
    remove_same_as(graph)
    blocknum = len(list(graph.iterblocks()))
    merge_if_blocks(graph)
    assert blocknum == len(list(graph.iterblocks()))

def test_two_constants():
    def fn():
        r = range(10, 37, 4)
        r.reverse()
        return r[0]
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(fn, [])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    backend_optimizations(t, merge_if_blocks=True)
    graph = tgraphof(t, fn)
    blocknum = len(list(graph.iterblocks()))
    merge_if_blocks(graph)
    assert blocknum == len(list(graph.iterblocks()))

def test_same_cases():
    def fn(x):
        if x == 42:
            r = 1
        elif x == 42:
            r = 2
        else:
            r = 3
        return r
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(fn, [int])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    backend_optimizations(t, merge_if_blocks=True)
    graph = tgraphof(t, fn)
    assert len(graph.startblock.exits) == 2
    interp = LLInterpreter(rtyper)
    for i in [42, 43]:
        expected = fn(i)
        actual = interp.eval_graph(graph, [i])
        assert actual == expected

def test_replace_exitswitch_by_constant_bug():
    class X:
        pass
    def constant9():
        x = X()
        x.n = 3
        x.n = 9
        return x.n
    def fn():
        n = constant9()
        if n == 1: return 5
        elif n == 2: return 6
        elif n == 3: return 8
        elif n == 4: return -123
        elif n == 5: return 12973
        else: return n
    
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(fn, [])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    graph = t.graphs[0]
    remove_same_as(graph)
    merge_if_blocks_once(graph)
    from rpython.translator.backendopt import malloc, inline
    inline.auto_inlining(t, 20)
    malloc.remove_mallocs(t, t.graphs)
    from rpython.translator import simplify
    simplify.join_blocks(graph)

def test_switch_on_symbolic():
    symb1 = CDefinedIntSymbolic("1", 1)
    symb2 = CDefinedIntSymbolic("2", 2)
    symb3 = CDefinedIntSymbolic("3", 3)
    def fn(x):
        res = 0
        if x == symb1:
            res += x + 1
        elif x == symb2:
            res += x + 2
        elif x == symb3:
            res += x + 3
        res += 1
        return res
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(fn, [int])
    rtyper = t.buildrtyper()
    rtyper.specialize()
    graph = t.graphs[0]
    remove_same_as(graph)
    res = merge_if_blocks_once(graph)
    assert not res
    checkgraph(graph)

