import random
from rpython.tool.algo.unionfind import UnionFind
from rpython.translator.backendopt.graphanalyze import (Dependency,
    DependencyTracker, BoolGraphAnalyzer)


class FakeGraphAnalyzer:
    def __init__(self):
        self._analyzed_calls = UnionFind(lambda graph: Dependency(self))

    @staticmethod
    def bottom_result():
        return 0

    @staticmethod
    def join_two_results(result1, result2):
        return result1 | result2


def test_random_graphs():
    for _ in range(100):
        N = 10
        edges = [(random.randrange(N), random.randrange(N))
                     for i in range(N*N//3)]

        def expected(node1):
            prev = set()
            seen = set([node1])
            while len(seen) > len(prev):
                prev = set(seen)
                for a, b in edges:
                    if a in seen:
                        seen.add(b)
            return sum([1 << n for n in seen])

        def rectrack(n, tracker):
            if not tracker.enter(n):
                return tracker.get_cached_result(n)
            result = 1 << n
            for a, b in edges:
                if a == n:
                    result |= rectrack(b, tracker)
            tracker.leave_with(result)
            return result

        analyzer = FakeGraphAnalyzer()
        for n in range(N):
            tracker = DependencyTracker(analyzer)
            method1 = rectrack(n, tracker)
            method2 = expected(n)
            assert method1 == method2


def test_delayed_fnptr():
    from rpython.flowspace.model import SpaceOperation
    from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
    from rpython.translator.translator import TranslationContext
    t = TranslationContext()
    t.buildannotator()
    t.buildrtyper()
    annhelper = MixLevelHelperAnnotator(t.rtyper)
    def f():
        pass
    c_f = annhelper.constfunc(f, [], None)
    op = SpaceOperation('direct_call', [c_f], None)
    analyzer = BoolGraphAnalyzer(t)
    assert analyzer.analyze(op)


def test_null_fnptr():
    from rpython.flowspace.model import SpaceOperation, Constant
    from rpython.rtyper.lltypesystem.lltype import Void, FuncType, nullptr
    from rpython.translator.translator import TranslationContext
    t = TranslationContext()
    fnptr = nullptr(FuncType([], Void))
    op = SpaceOperation('direct_call', [Constant(fnptr)], None)
    analyzer = BoolGraphAnalyzer(t)
    assert not analyzer.analyze(op)
