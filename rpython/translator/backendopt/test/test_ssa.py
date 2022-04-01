from rpython.translator.backendopt.ssa import *
from rpython.translator.translator import TranslationContext
from rpython.flowspace.model import (
    Block, Link, Variable, Constant, SpaceOperation, FunctionGraph)


def test_data_flow_families():
    def snippet_fn(xx, yy):
        while yy > 0:
            if 0 < xx:
                yy = yy - xx
            else:
                yy = yy + xx
        return yy
    t = TranslationContext()
    graph = t.buildflowgraph(snippet_fn)
    operations = []
    for block in graph.iterblocks():
        operations += block.operations

    variable_families = DataFlowFamilyBuilder(graph).get_variable_families()

    # we expect to find xx only once:
    v_xx = variable_families.find_rep(graph.getargs()[0])
    found = 0
    for op in operations:
        if op.opname in ('add', 'sub', 'lt'):
            assert variable_families.find_rep(op.args[1]) == v_xx
            found += 1
    assert found == 3


def test_SSI_to_SSA():
    def snippet_fn(v1, v2, v3):
        if v1:                             # v4 = is_true(v1)
            while v3:                      # v5 = is_true(v3)
                pass
            passed_over = 0
        else:
            v6 = snippet_fn(v3, v2, v1)    # v6 = simple_call(v3, v2, v1)
            passed_over = v6
        v7 = passed_over                   # v7 = inputarg
        return v7+v1                       # v8 = add(v7, v1)

    t = TranslationContext()
    graph = t.buildflowgraph(snippet_fn)
    SSI_to_SSA(graph)
    allvars = []
    for block in graph.iterblocks():
            allvars += [v.name for v in block.getvariables()]
    # see comments above for where the 8 remaining variables are expected to be
    assert len(dict.fromkeys(allvars)) == 8


def test_SSA_to_SSI():
    c = Variable('c')
    x = Variable('x')
    y = Variable('y')
    b1 = Block([c])
    b2 = Block([x])
    b3 = Block([])

    graph = FunctionGraph('x', b1)
    b2.operations.append(SpaceOperation('add', [x, c], y))
    b2.exitswitch = y

    b1.closeblock(Link([Constant(0)], b2))
    b2.closeblock(Link([y], b2), Link([], b3))
    b3.closeblock(Link([y, c], graph.exceptblock))
    SSA_to_SSI(graph)

    assert len(b1.inputargs) == 1
    assert len(b2.inputargs) == 2
    assert len(b3.inputargs) == 2

    assert b2.inputargs == b2.operations[0].args
    assert len(b1.exits[0].args) == 2
    assert b1.exits[0].args[1] is c
    assert len(b2.exits[0].args) == 2
    assert b2.exits[0].args == [y, b2.inputargs[1]]
    assert len(b2.exits[1].args) == 2
    assert len(b3.exits[0].args) == 2

    index = b3.inputargs.index(b3.exits[0].args[0])
    assert b2.exits[1].args[index] is b2.operations[0].result

    index = b3.inputargs.index(b3.exits[0].args[1])
    assert b2.exits[1].args[index] is b2.inputargs[1]


def test_SSA_to_SSI_2():
    x = Variable('x')
    y = Variable('y')
    z = Variable('z')
    b1 = Block([x])
    b2 = Block([y])
    b3 = Block([])

    b3.operations.append(SpaceOperation('hello', [y], z))
    b1.closeblock(Link([x], b2), Link([], b3))
    graph = FunctionGraph('x', b1)
    SSA_to_SSI(graph)

    assert b1.inputargs == [x]
    assert b2.inputargs == [y]
    assert b3.inputargs == [b3.operations[0].args[0]]
    assert b1.exits[0].args == [x]
    assert b1.exits[1].args == [x]
