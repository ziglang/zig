from rpython.translator.translator import TranslationContext
from rpython.translator.backendopt.innerloop import find_inner_loops
from rpython.conftest import option

def test_simple_loop():
    def snippet_fn(x, y):
        while y > 0:
            y -= x
        return y
    t = TranslationContext()
    graph = t.buildflowgraph(snippet_fn)
    if option.view:
        t.view()
    loops = find_inner_loops(graph)
    assert len(loops) == 1
    loop = loops[0]
    assert loop.headblock.operations[0].opname == 'gt'
    assert len(loop.links) == 2
    assert loop.links[0] in loop.headblock.exits
    assert loop.links[1] in loop.links[0].target.exits
    assert loop.links[1].target is loop.headblock

def test_two_loops():
    def snippet_fn(x, y):
        while y > 0:
            y -= x
        while y < 0:
            y += x
        return y
    t = TranslationContext()
    graph = t.buildflowgraph(snippet_fn)
    if option.view:
        t.view()
    loops = find_inner_loops(graph)
    assert len(loops) == 2
    assert loops[0].headblock is not loops[1].headblock
    for loop in loops:
        assert loop.headblock.operations[0].opname in ('gt', 'lt')
        assert len(loop.links) == 2
        assert loop.links[0] in loop.headblock.exits
        assert loop.links[1] in loop.links[0].target.exits
        assert loop.links[1].target is loop.headblock

def test_nested_loops():
    def snippet_fn(x, z):
        y = 0
        while y <= 10:
            while z < y:
                z += y
            y += 1
        return z
    t = TranslationContext()
    graph = t.buildflowgraph(snippet_fn)
    if option.view:
        t.view()
    loops = find_inner_loops(graph)
    assert len(loops) == 1
    loop = loops[0]
    assert loop.headblock.operations[0].opname == 'lt'
    assert len(loop.links) == 2
    assert loop.links[0] in loop.headblock.exits
    assert loop.links[1] in loop.links[0].target.exits
    assert loop.links[1].target is loop.headblock
