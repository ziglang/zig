from rpython.flowspace.model import *
import py

def test_mingraph():
    g = FunctionGraph("g", Block([]))
    g.startblock.closeblock(Link([Constant(1)], g.returnblock))
    checkgraph(g)

def template():
    g = FunctionGraph("g", Block([]))
    g.startblock.closeblock(Link([Constant(1)], g.returnblock))
    checkgraph(g)
    py.test.raises(AssertionError, checkgraph, g)


def test_exitlessblocknotexitblock():
    g = FunctionGraph("g", Block([]))
    py.test.raises(AssertionError, checkgraph, g)


def test_nonvariableinputarg():
    b = Block([Constant(1)])
    g = FunctionGraph("g", b)
    g.startblock.closeblock(Link([Constant(1)], g.returnblock))

    py.test.raises(AssertionError, checkgraph, g)

def test_multiplydefinedvars():
    v = Variable()
    g = FunctionGraph("g", Block([v, v]))
    g.startblock.closeblock(Link([v], g.returnblock))
    py.test.raises(AssertionError, checkgraph, g)

    v = Variable()
    b = Block([v])
    b.operations.append(SpaceOperation("add", [Constant(1), Constant(2)], v))
    g = FunctionGraph("g", b)
    g.startblock.closeblock(Link([v], g.returnblock))

    py.test.raises(AssertionError, checkgraph, g)

def test_varinmorethanoneblock():
    v = Variable()
    g = FunctionGraph("g", Block([]))
    g.startblock.operations.append(SpaceOperation("pos", [Constant(1)], v))
    b = Block([v])
    g.startblock.closeblock(Link([v], b))
    b.closeblock(Link([v], g.returnblock))
    py.test.raises(AssertionError, checkgraph, g)
    
def test_useundefinedvar():
    v = Variable()
    g = FunctionGraph("g", Block([]))
    g.startblock.closeblock(Link([v], g.returnblock))
    py.test.raises(AssertionError, checkgraph, g)

    v = Variable()
    g = FunctionGraph("g", Block([]))
    g.startblock.exitswitch = v
    g.startblock.closeblock(Link([Constant(1)], g.returnblock))
    py.test.raises(AssertionError, checkgraph, g)

def test_invalid_arg():
    v = Variable()
    g = FunctionGraph("g", Block([]))
    g.startblock.operations.append(SpaceOperation("pos", [1], v))
    g.startblock.closeblock(Link([v], g.returnblock))
    py.test.raises(AssertionError, checkgraph, g)

def test_invalid_links():
    g = FunctionGraph("g", Block([]))
    g.startblock.closeblock(Link([Constant(1)], g.returnblock), Link([Constant(1)], g.returnblock))
    py.test.raises(AssertionError, checkgraph, g)

    v = Variable()
    g = FunctionGraph("g", Block([v]))
    g.startblock.exitswitch = v
    g.startblock.closeblock(Link([Constant(1)], g.returnblock, True),
                            Link([Constant(1)], g.returnblock, True))
    py.test.raises(AssertionError, checkgraph, g)

    v = Variable()
    g = FunctionGraph("g", Block([v]))
    g.startblock.exitswitch = v
    g.startblock.closeblock(Link([Constant(1)], g.returnblock))
    py.test.raises(AssertionError, checkgraph, g)

