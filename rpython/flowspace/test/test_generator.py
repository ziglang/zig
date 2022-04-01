from rpython.conftest import option
from rpython.flowspace.objspace import build_flow
from rpython.flowspace.model import Variable
from rpython.flowspace.generator import (
    make_generator_entry_graph, get_variable_names)
from rpython.translator.simplify import join_blocks


# ____________________________________________________________

def f_gen(n):
    i = 0
    while i < n:
        yield i
        i += 1

class GeneratorIterator(object):
    def __init__(self, entry):
        self.current = entry
    def next(self):
        e = self.current
        self.current = None
        if isinstance(e, Yield1):
            n = e.n_0
            i = e.i_0
            i += 1
        else:
            n = e.n_0
            i = 0
        if i < n:
            e = Yield1()
            e.n_0 = n
            e.i_0 = i
            self.current = e
            return i
        raise StopIteration

    def __iter__(self):
        return self

class AbstractPosition(object):
    _immutable_ = True
class Entry1(AbstractPosition):
    _immutable_ = True
class Yield1(AbstractPosition):
    _immutable_ = True

def f_explicit(n):
    e = Entry1()
    e.n_0 = n
    return GeneratorIterator(e)

def test_explicit():
    assert list(f_gen(10)) == list(f_explicit(10))

def test_get_variable_names():
    lst = get_variable_names([Variable('a'), Variable('b_'), Variable('a')])
    assert lst == ['g_a', 'g_b', 'g_a_']

# ____________________________________________________________


class TestGenerator:

    def test_replace_graph_with_bootstrap(self):
        def func(n, x, y, z):
            yield n
            yield n
        #
        graph = make_generator_entry_graph(func)
        if option.view:
            graph.show()
        block = graph.startblock
        ops = block.operations
        assert ops[0].opname == 'simple_call' # e = Entry1()
        assert ops[1].opname == 'setattr'     # e.g_n = n
        assert ops[1].args[1].value == 'g_n'
        assert ops[2].opname == 'setattr'     # e.g_x = x
        assert ops[2].args[1].value == 'g_x'
        assert ops[3].opname == 'setattr'     # e.g_y = y
        assert ops[3].args[1].value == 'g_y'
        assert ops[4].opname == 'setattr'     # e.g_z = z
        assert ops[4].args[1].value == 'g_z'
        assert ops[5].opname == 'simple_call' # g = GeneratorIterator(e)
        assert ops[5].args[1] == ops[0].result
        assert len(ops) == 6
        assert len(block.exits) == 1
        assert block.exits[0].target is graph.returnblock

    def test_tweak_generator_graph(self):
        def f(n, x, y, z):
            z *= 10
            yield n + 1
            z -= 10
        #
        graph = make_generator_entry_graph(f)
        func1 = graph._tweaked_func
        if option.view:
            graph.show()
        GeneratorIterator = graph._tweaked_func._generator_next_method_of_
        assert hasattr(GeneratorIterator, 'next')
        #
        graph_next = build_flow(GeneratorIterator.next.im_func)
        join_blocks(graph_next)
        if option.view:
            graph_next.show()
        #
        graph1 = build_flow(func1)
        if option.view:
            graph1.show()

    def test_automatic(self):
        def f(n, x, y, z):
            z *= 10
            yield n + 1
            z -= 10
        #
        graph = build_flow(f)
        if option.view:
            graph.show()
        block = graph.startblock
        assert len(block.exits) == 1
        assert block.exits[0].target is graph.returnblock
