from rpython.rtyper.test.test_llinterp import gengraph
from rpython.rtyper.lltypesystem import lltype
from rpython.tool.algo.regalloc import perform_register_allocation
from rpython.flowspace.model import Variable
from rpython.conftest import option


def is_int(v):
    return v.concretetype == lltype.Signed

def check_valid(graph, regalloc, consider_var):
    if getattr(option, 'view', False):
        graph.show()
    num_renamings = 0
    for block in graph.iterblocks():
        inputs = [v for v in block.inputargs if consider_var(v)]
        colors = [regalloc.getcolor(v) for v in inputs]
        print inputs, ':', colors
        assert len(inputs) == len(set(colors))
        in_use = dict(zip(colors, inputs))
        for op in block.operations:
            for v in op.args:
                if isinstance(v, Variable) and consider_var(v):
                    assert in_use[regalloc.getcolor(v)] is v
            if consider_var(op.result):
                in_use[regalloc.getcolor(op.result)] = op.result
        for link in block.exits:
            for i, v in enumerate(link.args):
                if consider_var(v):
                    assert in_use[regalloc.getcolor(v)] is v
                    w = link.target.inputargs[i]
                    if regalloc.getcolor(v) is not regalloc.getcolor(w):
                        print '\trenaming %s:%d -> %s:%d' % (
                            v, regalloc.getcolor(v), w, regalloc.getcolor(w))
                        num_renamings += 1
    return num_renamings


def test_loop_1():
    def f(a, b):
        while a > 0:
            b += a
            a -= 1
        return b
    t, rtyper, graph = gengraph(f, [int, int], viewbefore=False)
    regalloc = perform_register_allocation(graph, is_int)
    num_renamings = check_valid(graph, regalloc, is_int)
    assert num_renamings == 0

def test_loop_2():
    def f(a, b):
        while a > 0:
            b += a
            if b < 10:
                a, b = b, a
            a -= 1
        return b
    t, rtyper, graph = gengraph(f, [int, int], viewbefore=False)
    regalloc = perform_register_allocation(graph, is_int)
    num_renamings = check_valid(graph, regalloc, is_int)
    assert num_renamings == 2
