"""
Extra tests for the pure Python PyPy _collections module
(not used in normal PyPy's)
"""
from pypy.module.test_lib_pypy.support import import_lib_pypy


class AppTestDeque:

    def setup_class(cls):
        space = cls.space
        cls.w_collections = import_lib_pypy(space, '_collections')
        cls.w_n = space.wrap(10)

    def w_get_deque(self):
        return self.collections.deque(range(self.n))

    def test_deque(self):
        d = self.get_deque()
        assert len(d) == self.n
        for i in range(self.n):
            assert i == d[i]
        for i in range(self.n-1, -1, -1):
            assert d.pop() == i
        assert len(d) == 0

    def test_deque_iter(self):
        d = self.get_deque()
        it = iter(d)
        raises(TypeError, len, it)
        assert next(it) == 0
        d.pop()
        raises(RuntimeError, next, it)

    def test_deque_reversed(self):
        d = self.get_deque()
        it = reversed(d)
        raises(TypeError, len, it)
        assert next(it) == self.n-1
        assert next(it) == self.n-2
        d.pop()
        raises(RuntimeError, next, it)

    def test_deque_remove(self):
        d = self.get_deque()
        raises(ValueError, d.remove, "foobar")

    def test_mutate_during_remove(self):
        collections = self.collections
        # Handle evil mutator
        class MutateCmp:
            def __init__(self, deque, result):
                self.deque = deque
                self.result = result
            def __eq__(self, other):
                self.deque.clear()
                return self.result

        for match in (True, False):
            d = collections.deque(['ab'])
            d.extend([MutateCmp(d, match), 'c'])
            raises(IndexError, d.remove, 'c')
            assert len(d) == 0

    def test_deque_unhashable(self):
        from collections import Hashable
        d = self.get_deque()
        raises(TypeError, hash, d)
        assert not isinstance(d, Hashable)

class AppTestDequeExtra:

    spaceconfig = dict(usemodules=('binascii', 'struct',))

    def setup_class(cls):
        cls.w_collections = import_lib_pypy(cls.space, '_collections')

    def test_remove_empty(self):
        collections = self.collections
        d = collections.deque([])
        raises(ValueError, d.remove, 1)

    def test_remove_mutating(self):
        collections = self.collections
        class MutatingCmp(object):
            def __eq__(self, other):
                d.clear()
                return True

        d = collections.deque([MutatingCmp()])
        raises(IndexError, d.remove, 1)

    def test_remove_failing(self):
        collections = self.collections
        class FailingCmp(object):
            def __eq__(self, other):
                assert False

        f = FailingCmp()
        d = collections.deque([1, 2, 3, f, 4, 5])
        d.remove(3)
        raises(AssertionError, d.remove, 4)
        assert d == collections.deque([1, 2, f, 4, 5])

    def test_maxlen(self):
        collections = self.collections
        d = collections.deque([], 3)
        d.append(1); d.append(2); d.append(3); d.append(4)
        assert list(d) == [2, 3, 4]
        assert repr(d) == "deque([2, 3, 4], maxlen=3)"

        import pickle
        d2 = pickle.loads(pickle.dumps(d))
        assert repr(d2) == "deque([2, 3, 4], maxlen=3)"

        import copy
        d3 = copy.copy(d)
        assert repr(d3) == "deque([2, 3, 4], maxlen=3)"

    def test_count(self):
        collections = self.collections
        d = collections.deque([1, 2, 2, 3, 2])
        assert d.count(2) == 3
        assert d.count(4) == 0

    def test_reverse(self):
        collections = self.collections
        d = collections.deque([1, 2, 2, 3, 2])
        d.reverse()
        assert list(d) == [2, 3, 2, 2, 1]

        d = collections.deque(range(100))
        d.reverse()
        assert list(d) == list(range(99, -1, -1))

    def test_subclass_with_kwargs(self):
        collections = self.collections
        class SubclassWithKwargs(collections.deque):
            def __init__(self, newarg=1):
                collections.deque.__init__(self)

        # SF bug #1486663 -- this used to erroneously raise a TypeError
        SubclassWithKwargs(newarg=1)

class AppTestDefaultDict:

    def setup_class(cls):
        cls.w_collections = import_lib_pypy(cls.space, '_collections')

    def test_basic(self):
        collections = self.collections
        d1 = collections.defaultdict()
        assert d1.default_factory is None
        d1.default_factory = list
        d1[12].append(42)
        assert d1 == {12: [42]}
        d1[12].append(24)
        assert d1 == {12: [42, 24]}
        d1[13]
        d1[14]
        assert d1 == {12: [42, 24], 13: [], 14: []}
        assert d1[12] is not d1[13] is not d1[14]
        d2 = collections.defaultdict(list, foo=1, bar=2)
        assert d2.default_factory == list
        assert d2 == {"foo": 1, "bar": 2}
        assert d2["foo"] == 1
        assert d2["bar"] == 2
        assert d2[42] == []
        assert "foo" in d2
        assert "foo" in d2.keys()
        assert "bar" in d2
        assert "bar" in d2.keys()
        assert 42 in d2
        assert 42 in d2.keys()
        assert 12 not in d2
        assert 12 not in d2.keys()
        d2.default_factory = None
        assert d2.default_factory == None
        raises(KeyError, d2.__getitem__, 15)
        raises(TypeError, collections.defaultdict, 1)

    def test_constructor(self):
        collections = self.collections
        assert collections.defaultdict(None) == {}
        assert collections.defaultdict(None, {1: 2}) == {1: 2}

    def test_missing(self):
        collections = self.collections
        d1 = collections.defaultdict()
        raises(KeyError, d1.__missing__, 42)
        d1.default_factory = list
        assert d1.__missing__(42) == []

    def test_repr(self):
        collections = self.collections
        d1 = collections.defaultdict()
        assert d1.default_factory == None
        assert repr(d1) == "defaultdict(None, {})"
        d1[11] = 41
        assert repr(d1) == "defaultdict(None, {11: 41})"
        d2 = collections.defaultdict(int)
        assert d2.default_factory == int
        d2[12] = 42
        assert repr(d2) == "defaultdict(<class 'int'>, {12: 42})"
        def foo(): return 43
        d3 = collections.defaultdict(foo)
        assert d3.default_factory is foo
        d3[13]
        assert repr(d3) == "defaultdict(%s, {13: 43})" % repr(foo)
        d4 = collections.defaultdict(int)
        d4[14] = collections.defaultdict()
        assert repr(d4) == "defaultdict(%s, {14: defaultdict(None, {})})" % repr(int)

    def test_recursive_repr(self):
        collections = self.collections
        # Issue2045: stack overflow when default_factory is a bound method
        class sub(collections.defaultdict):
            def __init__(self):
                self.default_factory = self._factory
            def _factory(self):
                return []
        sub._factory.__qualname__ = "FACTORY"
        d = sub()
        assert repr(d).startswith(
            "sub(<bound method FACTORY of sub(...")

    def test_copy(self):
        collections = self.collections
        d1 = collections.defaultdict()
        d2 = d1.copy()
        assert type(d2) == collections.defaultdict
        assert d2.default_factory == None
        assert d2 == {}
        d1.default_factory = list
        d3 = d1.copy()
        assert type(d3) == collections.defaultdict
        assert d3.default_factory == list
        assert d3 == {}
        d1[42]
        d4 = d1.copy()
        assert type(d4) == collections.defaultdict
        assert d4.default_factory == list
        assert d4 == {42: []}
        d4[12]
        assert d4 == {42: [], 12: []}

    def test_shallow_copy(self):
        import copy
        collections = self.collections
        def foobar():
            return list
        d1 = collections.defaultdict(foobar, {1: 1})
        d2 = copy.copy(d1)
        assert d2.default_factory == foobar
        assert d2 == d1
        d1.default_factory = list
        d2 = copy.copy(d1)
        assert d2.default_factory == list
        assert d2 == d1

    def test_deep_copy(self):
        import copy
        collections = self.collections
        def foobar():
            return list
        d1 = collections.defaultdict(foobar, {1: [1]})
        d2 = copy.deepcopy(d1)
        assert d2.default_factory == foobar
        assert d2 == d1
        assert d1[1] is not d2[1]
        d1.default_factory = list
        d2 = copy.deepcopy(d1)
        assert d2.default_factory == list
        assert d2 == d1
