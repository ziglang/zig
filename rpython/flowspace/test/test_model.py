import inspect

from rpython.flowspace.model import *


def sample_function(i):
    sum = 0
    while i > 0:
        sum = sum + i
        i = i - 1
    return sum

class pieces:
    """ The manually-built graph corresponding to the sample_function().
    """
    i0 = Variable("i0")
    i1 = Variable("i1")
    i2 = Variable("i2")
    i3 = Variable("i3")
    sum1 = Variable("sum1")
    sum2 = Variable("sum2")
    sum3 = Variable("sum3")

    conditionres = Variable("conditionres")
    conditionop = SpaceOperation("gt", [i1, Constant(0)], conditionres)
    addop = SpaceOperation("add", [sum2, i2], sum3)
    decop = SpaceOperation("sub", [i2, Constant(1)], i3)
    startblock = Block([i0])
    headerblock = Block([i1, sum1])
    whileblock = Block([i2, sum2])

    graph = FunctionGraph("f", startblock)
    startblock.closeblock(Link([i0, Constant(0)], headerblock))
    headerblock.operations.append(conditionop)
    headerblock.exitswitch = conditionres
    headerblock.closeblock(Link([sum1], graph.returnblock, False),
                           Link([i1, sum1], whileblock, True))
    whileblock.operations.append(addop)
    whileblock.operations.append(decop)
    whileblock.closeblock(Link([i3, sum3], headerblock))

    graph.func = sample_function

graph = pieces.graph

# ____________________________________________________________

def test_checkgraph():
    checkgraph(graph)

def test_copygraph():
    graph2 = copygraph(graph)
    checkgraph(graph2)

def test_graphattributes():
    assert graph.startblock is pieces.startblock
    assert graph.returnblock is pieces.headerblock.exits[0].target
    assert graph.getargs() == [pieces.i0]
    assert [graph.getreturnvar()] == graph.returnblock.inputargs
    assert graph.source == inspect.getsource(sample_function)

def test_iterblocks():
    assert list(graph.iterblocks()) == [pieces.startblock,
                                        pieces.headerblock,
                                        graph.returnblock,
                                        pieces.whileblock]

def test_iterlinks():
    assert list(graph.iterlinks()) == [pieces.startblock.exits[0],
                                       pieces.headerblock.exits[0],
                                       pieces.headerblock.exits[1],
                                       pieces.whileblock.exits[0]]

def test_mkentrymap():
    entrymap = mkentrymap(graph)
    startlink = entrymap[graph.startblock][0]
    assert entrymap == {
        pieces.startblock:  [startlink],
        pieces.headerblock: [pieces.startblock.exits[0],
                             pieces.whileblock.exits[0]],
        graph.returnblock:  [pieces.headerblock.exits[0]],
        pieces.whileblock:  [pieces.headerblock.exits[1]],
        }

def test_blockattributes():
    block = pieces.whileblock
    assert block.getvariables() == [pieces.i2,
                                    pieces.sum2,
                                    pieces.sum3,
                                    pieces.i3]
    assert block.getconstants() == [Constant(1)]

def test_renamevariables():
    block = pieces.whileblock
    v = Variable()
    block.renamevariables({pieces.sum2: v})
    assert block.getvariables() == [pieces.i2,
                                    v,
                                    pieces.sum3,
                                    pieces.i3]
    block.renamevariables({v: pieces.sum2})
    assert block.getvariables() == [pieces.i2,
                                    pieces.sum2,
                                    pieces.sum3,
                                    pieces.i3]

def test_variable():
    v = Variable()
    assert v.name[0] == 'v' and v.name[1:].isdigit()
    assert not v.renamed
    v.rename("foobar")
    name1 = v.name
    assert name1.startswith('foobar_')
    assert name1.split('_', 1)[1].isdigit()
    assert v.renamed
    v.rename("not again")
    assert v.name == name1
    v2 = Variable(v)
    assert v2.renamed
    assert v2.name.startswith("foobar_") and v2.name != v.name
    assert v2.name.split('_', 1)[1].isdigit()
