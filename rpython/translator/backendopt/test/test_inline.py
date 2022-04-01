# XXX clean up these tests to use more uniform helpers
import py
from rpython.flowspace.model import Variable, Constant, checkgraph
from rpython.translator.backendopt import canraise
from rpython.translator.backendopt.inline import (simple_inline_function,
    CannotInline, auto_inlining, Inliner, collect_called_graphs,
    measure_median_execution_cost, instrument_inline_candidates,
    auto_inline_graphs)
from rpython.translator.translator import TranslationContext, graphof
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rlib.rarithmetic import ovfcheck
from rpython.translator.test.snippet import is_perfect_number
from rpython.translator.backendopt.all import INLINE_THRESHOLD_FOR_TEST
from rpython.conftest import option
from rpython.translator.backendopt import removenoops
from rpython.flowspace.model import summary

def sanity_check(t):
    # look for missing '.concretetype'
    for graph in t.graphs:
        checkgraph(graph)
        for node in graph.iterblocks():
            for v in node.inputargs:
                assert hasattr(v, 'concretetype')
            for op in node.operations:
                for v in op.args:
                    assert hasattr(v, 'concretetype')
                assert hasattr(op.result, 'concretetype')
        for node in graph.iterlinks():
            if node.exitcase is not None:
                assert hasattr(node, 'llexitcase')
            for v in node.args:
                assert hasattr(v, 'concretetype')
            if isinstance(node.last_exception, (Variable, Constant)):
                assert hasattr(node.last_exception, 'concretetype')
            if isinstance(node.last_exc_value, (Variable, Constant)):
                assert hasattr(node.last_exc_value, 'concretetype')


class CustomError1(Exception):
    def __init__(self):
        self.data = 123

class CustomError2(Exception):
    def __init__(self):
        self.data2 = 456

class TestInline(BaseRtypingTest):
    def translate(self, func, argtypes):
        t = TranslationContext()
        t.buildannotator().build_types(func, argtypes)
        t.buildrtyper().specialize()
        return t

    def check_inline(self, func, in_func, sig, entry=None,
                     inline_guarded_calls=False,
                     graph=False):
        if entry is None:
            entry = in_func
        t = self.translate(entry, sig)
        # inline!
        sanity_check(t)    # also check before inlining (so we don't blame it)
        if option.view:
            t.view()
        raise_analyzer = canraise.RaiseAnalyzer(t)
        inliner = Inliner(t, graphof(t, in_func), func,
                          t.rtyper.lltype_to_classdef_mapping(),
                          inline_guarded_calls,
                          raise_analyzer=raise_analyzer)
        inliner.inline_all()
        if option.view:
            t.view()
        sanity_check(t)
        interp = LLInterpreter(t.rtyper)
        def eval_func(args):
            return interp.eval_graph(graphof(t, entry), args)
        if graph:
            return eval_func, graphof(t, func)
        return eval_func

    def check_auto_inlining(self, func, sig, multiplier=None, call_count_check=False,
                            remove_same_as=False, heuristic=None, const_fold_first=False):
        t = self.translate(func, sig)
        if const_fold_first:
            from rpython.translator.backendopt.constfold import constant_fold_graph
            from rpython.translator.simplify import eliminate_empty_blocks
            for graph in t.graphs:
                constant_fold_graph(graph)
                eliminate_empty_blocks(graph)
        if option.view:
            t.view()
        # inline!
        sanity_check(t)    # also check before inlining (so we don't blame it)

        threshold = INLINE_THRESHOLD_FOR_TEST
        if multiplier is not None:
            threshold *= multiplier

        call_count_pred = None
        if call_count_check:
            call_count_pred = lambda lbl: True
            instrument_inline_candidates(t.graphs, threshold)

        if remove_same_as:
            for graph in t.graphs:
                removenoops.remove_same_as(graph)

        if heuristic is not None:
            kwargs = {"heuristic": heuristic}
        else:
            kwargs = {}
        auto_inlining(t, threshold, call_count_pred=call_count_pred, **kwargs)

        sanity_check(t)
        if option.view:
            t.view()
        interp = LLInterpreter(t.rtyper)
        def eval_func(args):
            return interp.eval_graph(graphof(t, func), args)
        return eval_func, t


    def test_inline_simple(self):
        def f(x, y):
            return (g(x, y) + 1) * x
        def g(x, y):
            if x > 0:
                return x * y
            else:
                return -x * y
        eval_func = self.check_inline(g, f, [int, int])
        result = eval_func([-1, 5])
        assert result == f(-1, 5)
        result = eval_func([2, 12])
        assert result == f(2, 12)

    def test_nothing_to_inline(self):
        def f():
            return 1
        def g():
            return 2
        eval_func = self.check_inline(g, f, [])
        assert eval_func([]) == 1

    def test_inline_big(self):
        def f(x):
            result = []
            for i in range(1, x+1):
                if is_perfect_number(i):
                    result.append(i)
            return result
        eval_func = self.check_inline(is_perfect_number, f, [int])
        result = eval_func([10])
        result = self.ll_to_list(result)
        assert len(result) == len(f(10))

    def test_inline_raising(self):
        def f(x):
            if x == 1:
                raise CustomError1
            return x
        def g(x):
            a = f(x)
            if x == 2:
                raise CustomError2
        def h(x):
            try:
                g(x)
            except CustomError1:
                return 1
            except CustomError2:
                return 2
            return x
        eval_func = self.check_inline(f,g, [int], entry=h)
        result = eval_func([0])
        assert result == 0
        result = eval_func([1])
        assert result == 1
        result = eval_func([2])
        assert result == 2

    def test_inline_several_times(self):
        def f(x):
            return (x + 1) * 2
        def g(x):
            if x:
                a = f(x) + f(x)
            else:
                a = f(x) + 1
            return a + f(x)
        eval_func = self.check_inline(f, g, [int])
        result = eval_func([0])
        assert result == g(0)
        result = eval_func([42])
        assert result == g(42)

    def test_always_inline(self):
        def f(x, y, z, k):
            p = (((x, y), z), k)
            return p[0][0][0] + p[-1]
        f._always_inline_ = True

        def g(x, y, z, k):
            a = f(x, y, z, k)
            return a
        eval_func, t = self.check_auto_inlining(g, [int, int, int, int], multiplier=0.1)
        graph = graphof(t, g)
        s = summary(graph)
        assert len(s) > 3

    def test_inline_exceptions(self):
        customError1 = CustomError1()
        customError2 = CustomError2()
        def f(x):
            if x == 0:
                raise customError1
            if x == 1:
                raise customError2
        def g(x):
            try:
                f(x)
            except CustomError1:
                return 2
            except CustomError2:
                return x+2
            return 1
        eval_func = self.check_inline(f, g, [int])
        result = eval_func([0])
        assert result == 2
        result = eval_func([1])
        assert result == 3
        result = eval_func([42])
        assert result == 1

    def test_inline_const_exceptions(self):
        valueError = ValueError()
        keyError = KeyError()
        def f(x):
            if x == 0:
                raise valueError
            if x == 1:
                raise keyError
        def g(x):
            try:
                f(x)
            except ValueError:
                return 2
            except KeyError:
                return x+2
            return 1
        eval_func = self.check_inline(f, g, [int])
        result = eval_func([0])
        assert result == 2
        result = eval_func([1])
        assert result == 3
        result = eval_func([42])
        assert result == 1

    def test_inline_exception_guarded(self):
        def h(x):
            if x == 1:
                raise CustomError1()
            elif x == 2:
                raise CustomError2()
            return 1
        def f(x):
            try:
                return h(x)
            except:
                return 87
        def g(x):
            try:
                return f(x)
            except CustomError1:
                return 2
        eval_func = self.check_inline(f, g, [int], inline_guarded_calls=True)
        result = eval_func([0])
        assert result == 1
        result = eval_func([1])
        assert result == 87
        result = eval_func([2])
        assert result == 87

    def test_inline_with_raising_non_call_op(self):
        class A:
            pass
        def f():
            return A()
        def g():
            try:
                a = f()
            except MemoryError:
                return 1
            return 2
        py.test.raises(CannotInline, self.check_inline, f, g, [])

    def test_inline_var_exception(self):
        def f(x):
            e = None
            if x == 0:
                e = CustomError1()
            elif x == 1:
                e = KeyError()
            if x == 0 or x == 1:
                raise e
        def g(x):
            try:
                f(x)
            except CustomError1:
                return 2
            except KeyError:
                return 3
            return 1

        eval_func, _ = self.check_auto_inlining(g, [int], multiplier=10)
        result = eval_func([0])
        assert result == 2
        result = eval_func([1])
        assert result == 3
        result = eval_func([42])
        assert result == 1

    def test_inline_nonraising_into_catching(self):
        def f(x):
            return x+1
        def g(x):
            try:
                return f(x)
            except KeyError:
                return 42
        eval_func = self.check_inline(f, g, [int])
        result = eval_func([7654])
        assert result == 7655

    def DONOTtest_call_call(self):
        # for reference.  Just remove this test if we decide not to support
        # catching exceptions while inlining a graph that contains further
        # direct_calls.
        def e(x):
            if x < 0:
                raise KeyError
            return x+1
        def f(x):
            return e(x)+2
        def g(x):
            try:
                return f(x)+3
            except KeyError:
                return -1
        eval_func = self.check_inline(f, g, [int])
        result = eval_func([100])
        assert result == 106
        result = eval_func(g, [-100])
        assert result == -1

    def test_for_loop(self):
        def f(x):
            result = 0
            for i in range(0, x):
                result += i
            return result
        t = self.translate(f, [int])
        sanity_check(t)    # also check before inlining (so we don't blame it)
        for graph in t.graphs:
            if graph.name.startswith('ll_rangenext'):
                break
        else:
            assert 0, "cannot find ll_rangenext_*() function"
        simple_inline_function(t, graph, graphof(t, f))
        sanity_check(t)
        interp = LLInterpreter(t.rtyper)
        result = interp.eval_graph(graphof(t, f), [10])
        assert result == 45

    def test_inline_constructor(self):
        class A:
            def __init__(self, x, y):
                self.bounds = (x, y)
            def area(self, height=10):
                return height * (self.bounds[1] - self.bounds[0])
        def f(i):
            a = A(117, i)
            return a.area()
        eval_func = self.check_inline(A.__init__.im_func, f, [int])
        result = eval_func([120])
        assert result == 30

    def test_cannot_inline_recursive_function(self):
        def factorial(n):
            if n > 1:
                return n * factorial(n-1)
            else:
                return 1
        def f(n):
            return factorial(n//2)
        py.test.raises(CannotInline, self.check_inline, factorial, f, [int])

    def test_auto_inlining_small_call_big(self):
        def leaf(n):
            total = 0
            i = 0
            while i < n:
                total += i
                if total > 100:
                    raise OverflowError
                i += 1
            return total
        def g(n):
            return leaf(n)
        def f(n):
            try:
                return g(n)
            except OverflowError:
                return -1
        eval_func, t = self.check_auto_inlining(f, [int], multiplier=10)
        f_graph = graphof(t, f)
        assert len(collect_called_graphs(f_graph, t)) == 0

        result = eval_func([10])
        assert result == 45
        result = eval_func([15])
        assert result == -1

    def test_auto_inlining_small_call_big_call_count(self):
        def leaf(n):
            total = 0
            i = 0
            while i < n:
                total += i
                if total > 100:
                    raise OverflowError
                i += 1
            return total
        def g(n):
            return leaf(n)
        def f(n):
            try:
                return g(n)
            except OverflowError:
                return -1
        eval_func, t = self.check_auto_inlining(f, [int], multiplier=10,
                                           call_count_check=True)
        f_graph = graphof(t, f)
        assert len(collect_called_graphs(f_graph, t)) == 0

        result = eval_func([10])
        assert result == 45
        result = eval_func([15])
        assert result == -1

    def test_inline_exception_catching(self):
        def f3():
            raise CustomError1
        def f2():
            try:
                f3()
            except CustomError1:
                return True
            else:
                return False
        def f():
            return f2()
        eval_func = self.check_inline(f2, f, [])
        result = eval_func([])
        assert result is True

    def test_inline_catching_different_exception(self):
        d = {1: 2}
        def f2(n):
            try:
                return ovfcheck(n+1)
            except OverflowError:
                raise
        def f(n):
            try:
                return f2(n)
            except ValueError:
                return -1
        eval_func = self.check_inline(f2, f, [int])
        result = eval_func([54])
        assert result == 55

    def test_inline_raiseonly(self):
        c = CustomError1()
        def f2(x):
            raise c
        def f(x):
            try:
                return f2(x)
            except CustomError1:
                return 42
        eval_func = self.check_inline(f2, f, [int])
        result = eval_func([98371])
        assert result == 42

    def test_measure_median_execution_cost(self):
        def f(x):
            x += 1
            x += 1
            x += 1
            while True:
                x += 1
                x += 1
                x += 1
                if x: break
                x += 1
                x += 1
                x += 1
                x += 1
                x += 1
            x += 1
            return x
        t = TranslationContext()
        graph = t.buildflowgraph(f)
        res = measure_median_execution_cost(graph)
        assert round(res, 5) == round(32.333333333, 5)

    def test_indirect_call_with_exception(self):
        class Dummy:
            pass
        def x1():
            return Dummy()   # can raise MemoryError
        def x2():
            return None
        def x3(x):
            if x:
                f = x1
            else:
                f = x2
            return f()
        def x4():
            try:
                x3(0)
                x3(1)
            except CustomError2:
                return 0
            return 1
        assert x4() == 1
        py.test.raises(CannotInline, self.check_inline, x3, x4, [])

    def test_list_iteration(self):
        def f():
            tot = 0
            for item in [1,2,3]:
                tot += item
            return tot

        eval_func, t = self.check_auto_inlining(f, [])
        f_graph = graphof(t, f)
        called_graphs = collect_called_graphs(f_graph, t)
        assert len(called_graphs) == 0

        result = eval_func([])
        assert result == 6

    def test_bug_in_find_exception_type(self):
        def h():
            pass
        def g(i):
            if i > 0:
                raise IndexError
            else:
                h()
        def f(i):
            try:
                g(i)
            except IndexError:
                pass

        eval_func, t = self.check_auto_inlining(f, [int], remove_same_as=True,
                                                const_fold_first=True)
        eval_func([-66])
        eval_func([282])

    def test_correct_keepalive_placement(self):
        def h(x):
            if not x:
                raise ValueError
            return 1
        def f(x):
            s = "a %s" % (x, )
            try:
                h(len(s))
            except ValueError:
                pass
            return -42
        eval_func, t = self.check_auto_inlining(f, [int])
        res = eval_func([42])
        assert res == -42

    def test_keepalive_hard_case(self):
        from rpython.rtyper.lltypesystem import lltype
        Y = lltype.Struct('y', ('n', lltype.Signed))
        X = lltype.GcStruct('x', ('y', Y))
        def g(x):
            if x:
                return 3
            else:
                return 4
        def f():
            x = lltype.malloc(X)
            x.y.n = 2
            y = x.y
            z1 = g(y.n)
            z = y.n
            return z+z1
        eval_func = self.check_inline(g, f, [])
        res = eval_func([])
        assert res == 5

    def test_auto_inline_graphs_from_anywhere(self):
        def leaf(n):
            return n
        def f(n):
            return leaf(n)
        t = self.translate(f, [int])
        f_graph = graphof(t, f)
        assert len(collect_called_graphs(f_graph, t)) == 1
        auto_inline_graphs(t, [f_graph], 32)
        assert len(collect_called_graphs(f_graph, t)) == 1
        auto_inline_graphs(t, [f_graph], 32, inline_graph_from_anywhere=True)
        assert len(collect_called_graphs(f_graph, t)) == 0

    def test_inline_all(self):
        def g(x):
            return x + 1
        def f(x):
            return g(x) * g(x+1) * g(x+2) * g(x+3) * g(x+4) * g(x+5)
        t = self.translate(f, [int])
        sanity_check(t)    # also check before inlining (so we don't blame it)
        simple_inline_function(t, graphof(t, g), graphof(t, f))
        sanity_check(t)
        assert summary(graphof(t, f)) == {'int_add': 11, 'int_mul': 5}
        interp = LLInterpreter(t.rtyper)
        result = interp.eval_graph(graphof(t, f), [10])
        assert result == f(10)

    def test_inline_all_exc(self):
        def g(x):
            if x < -100:
                raise ValueError
            return x + 1
        def f(x):
            n1 = g(x) * g(x+1)
            try:
                n2 = g(x+2) * g(x+3)
            except ValueError:
                n2 = 1
            n3 = g(x+4) * g(x+5)
            return n1 * n2 * n3
        t = self.translate(f, [int])
        sanity_check(t)    # also check before inlining (so we don't blame it)
        simple_inline_function(t, graphof(t, g), graphof(t, f))
        sanity_check(t)
        assert summary(graphof(t, f)) == {'int_add': 11, 'int_mul': 5,
                                          'cast_pointer': 12, 'getfield': 6,
                                          'int_lt': 6}
        interp = LLInterpreter(t.rtyper)
        result = interp.eval_graph(graphof(t, f), [10])
        assert result == f(10)
