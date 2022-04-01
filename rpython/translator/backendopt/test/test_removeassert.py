from rpython.flowspace.model import summary
from rpython.translator.backendopt.removeassert import remove_asserts
from rpython.translator.backendopt.constfold import constant_fold_graph
from rpython.translator.backendopt.test import test_constfold
from rpython.translator.backendopt.test.test_constfold import check_graph


def get_graph(fn, signature):
    graph, t = test_constfold.get_graph(fn, signature)
    constant_fold_graph(graph)
    return graph, t

def contains_raise(graph):
    for link in graph.iterlinks():
        if link.target is graph.exceptblock:
            return True
    else:
        return False

def check(fn, args, expected_result, remaining_raise=False):
    signature = [int] * len(args)   # for now
    graph, t = get_graph(fn, signature)
    remove_asserts(t, [graph])
    assert contains_raise(graph) == remaining_raise
    check_graph(graph, args, expected_result, t)
    return t, graph


def test_simple():
    def fn(n):
        assert n >= 1
        return n-1
    check(fn, [125], 124)

def test_simple_melting_away():
    def fn(n):
        assert n >= 1
        return n-1
    graph, t = get_graph(fn, [int])
    assert summary(graph) == {'int_ge': 1, 'int_sub': 1}
    remove_asserts(t, [graph])
    assert summary(graph) == {'int_ge': 1, 'debug_assert': 1, 'int_sub': 1}
    check_graph(graph, [1], 0, t)
    from rpython.translator.backendopt.removenoops import remove_debug_assert
    remove_debug_assert(graph)
    assert summary(graph) == {'int_ge': 1, 'int_sub': 1}
    from rpython.translator.simplify import transform_dead_op_vars
    transform_dead_op_vars(graph)
    assert summary(graph) == {'int_sub': 1}

def test_and():
    def fn(n):
        assert n >= 1 and n < 10
        return n-1
    check(fn, [1], 0)

def test_or():
    def fn(n):
        assert n >= 1 or n % 2 == 0
        return n-1
    check(fn, [-120], -121)

def test_isinstance():
    class A:
        pass
    class B(A):
        pass
    def g(n):
        if n > 10:
            return A()
        else:
            b = B()
            b.value = 321
            return b
    def fn(n):
        x = g(n)
        assert isinstance(x, B)
        return x.value
    t, graph = check(fn, [5], 321)
    assert summary(graph)['debug_assert'] == 1
    from rpython.translator.backendopt.removenoops import remove_debug_assert
    remove_debug_assert(graph)
    assert "debug_assert" not in summary(graph)
    from rpython.translator.simplify import transform_dead_op_vars
    transform_dead_op_vars(graph, t)
    assert summary(graph)["direct_call"] == 1

def test_with_exception():
    def g(n):
        if n < 0:
            raise ValueError
    def fn(n):
        try:
            g(n)
            assert False
        except ValueError:
            return 42
    check(fn, [-8], 42, remaining_raise=True)


