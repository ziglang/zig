import operator

from rpython.flowspace.test.test_objspace import Base
from rpython.rlib.unroll import unrolling_iterable


class TestUnroll(Base):
    def test_unroller(self):
        l = unrolling_iterable(range(10))
        def f(tot):
            for v in l:
                tot += v
            return tot*3
        assert f(0) == sum(l)*3

        graph = self.codetest(f)
        ops = self.all_operations(graph)
        assert ops == {'inplace_add': 10, 'mul': 1}

    def test_unroll_setattrs(self):
        values_names = unrolling_iterable(enumerate(['a', 'b', 'c']))
        def f(x):
            for v, name in values_names:
                setattr(x, name, v)

        graph = self.codetest(f)
        ops = self.all_operations(graph)
        assert ops == {'setattr': 3}

    def test_unroll_ifs(self):
        operations = unrolling_iterable([operator.lt,
                                         operator.le,
                                         operator.eq,
                                         operator.ne,
                                         operator.gt,
                                         operator.ge])
        def accept(n):
            "stub"
        def f(x, y):
            for op in operations:
                if accept(op):
                    op(x, y)

        graph = self.codetest(f)
        ops = self.all_operations(graph)
        assert ops == {'simple_call': 6,
                       'bool': 6,
                       'lt': 1,
                       'le': 1,
                       'eq': 1,
                       'ne': 1,
                       'gt': 1,
                       'ge': 1}

    def test_unroll_twice(self):
        operations = unrolling_iterable([1, 2, 3])
        def f(x):
            for num1 in operations:
                for num2 in operations:
                    x = x + (num1 + num2)
            return x

        graph = self.codetest(f)
        ops = self.all_operations(graph)
        assert ops['add'] == 9
