# encoding: utf-8
import py
from pypy.objspace.std.test.test_dictmultiobject import FakeSpace, W_DictObject
from pypy.objspace.std.kwargsdict import *

space = FakeSpace()
strategy = KwargsDictStrategy(space)

def test_create():
    a, b, c = space.newtext('a'), space.newtext('b'), space.newtext('c')
    keys = [a, b, c]
    values = [1, 2, 3]
    storage = strategy.erase((keys, values))
    d = W_DictObject(space, strategy, storage)
    assert d.getitem(a) == 1
    assert d.getitem(b) == 2
    assert d.getitem(c) == 3
    assert d.w_keys() == keys
    assert d.values() == values

def test_set_existing():
    a, b, c = space.newtext('a'), space.newtext('b'), space.newtext('c')
    keys = [a, b, c]
    values = [1, 2, 3]
    storage = strategy.erase((keys, values))
    d = W_DictObject(space, strategy, storage)
    assert d.getitem(a) == 1
    assert d.getitem(b) == 2
    assert d.getitem(c) == 3
    assert d.setitem(a, 4) is None
    assert d.getitem(a) == 4
    assert d.getitem(b) == 2
    assert d.getitem(c) == 3
    assert d.setitem(b, 5) is None
    assert d.getitem(a) == 4
    assert d.getitem(b) == 5
    assert d.getitem(c) == 3
    assert d.setitem(c, 6) is None
    assert d.getitem(a) == 4
    assert d.getitem(b) == 5
    assert d.getitem(c) == 6
    assert d.w_keys() == keys
    assert d.values() == values
    assert values == [4, 5, 6]


def test_set_new():
    a, b, c, d = space.newtext('a'), space.newtext('b'), space.newtext('c'), space.newtext('d')
    keys = [a, b, c]
    values = [1, 2, 3]
    storage = strategy.erase((keys, values))
    di = W_DictObject(space, strategy, storage)
    assert di.getitem(a) == 1
    assert di.getitem(b) == 2
    assert di.getitem(c) == 3
    assert di.getitem(d) is None
    assert di.setitem(d, 4) is None
    assert di.getitem(a) == 1
    assert di.getitem(b) == 2
    assert di.getitem(c) == 3
    assert di.getitem(d) == 4
    assert di.w_keys() == [a, b, c, d]
    assert di.values() == [1, 2, 3, 4]

def test_limit_size():
    storage = strategy.get_empty_storage()
    d = W_DictObject(space, strategy, storage)
    for i in range(100):
        assert d.setitem_str("d%s" % i, 4) is None
    assert d.get_strategy() is not strategy
    assert "UnicodeDictStrategy" == d.get_strategy().__class__.__name__

def test_limit_size_non_ascii():
    storage = strategy.get_empty_storage()
    d = W_DictObject(space, strategy, storage)
    for i in range(100):
        assert d.setitem_str("ה%s" % i, 4) is None
    assert d.get_strategy() is not strategy
    assert "UnicodeDictStrategy" == d.get_strategy().__class__.__name__

def test_view_as_kwargs():
    from pypy.objspace.std.dictmultiobject import EmptyDictStrategy
    a, b, c = space.newtext('a'), space.newtext('b'), space.newtext('c')
    strategy = KwargsDictStrategy(space)
    keys = [a, b, c]
    values = [1, 2, 3]
    storage = strategy.erase((keys, values))
    d = W_DictObject(space, strategy, storage)
    assert space.view_as_kwargs(d) == (keys, values)

    strategy = EmptyDictStrategy(space)
    storage = strategy.get_empty_storage()
    d = W_DictObject(space, strategy, storage)
    assert space.view_as_kwargs(d) == ([], [])

def test_from_empty_to_kwargs():
    strategy = EmptyKwargsDictStrategy(space)
    storage = strategy.get_empty_storage()
    d = W_DictObject(space, strategy, storage)
    d.setitem_str("a", 3)
    assert isinstance(d.get_strategy(), KwargsDictStrategy)


from pypy.objspace.std.test.test_dictmultiobject import BaseTestRDictImplementation, BaseTestDevolvedDictImplementation
def get_impl(self):
    storage = strategy.erase(([], []))
    return W_DictObject(space, strategy, storage)

class TestKwargsDictImplementation(BaseTestRDictImplementation):
    StrategyClass = KwargsDictStrategy
    get_impl = get_impl
    def test_delitem(self):
        pass # delitem devolves for now

    def test_setdefault_fast(self):
        pass # not based on hashing at all

class TestDevolvedKwargsDictImplementation(BaseTestDevolvedDictImplementation):
    get_impl = get_impl
    StrategyClass = KwargsDictStrategy

    def test_setdefault_fast(self):
        pass # not based on hashing at all


class AppTestKwargsDictStrategy(object):
    def setup_class(cls):
        if cls.runappdirect:
            py.test.skip("__repr__ doesn't work on appdirect")

    def w_get_strategy(self, obj):
        import __pypy__
        r = __pypy__.internal_repr(obj)
        return r[r.find("(") + 1: r.find(")")]

    def test_create(self):
        def f(**args):
            return args
        d = f(a=1)
        assert "KwargsDictStrategy" in self.get_strategy(d)
        d = f()
        assert "EmptyKwargsDictStrategy" in self.get_strategy(d)

    def test_iterator(self):
        def f(**args):
            return args

        assert dict.fromkeys(f(a=2, b=3)) == {"a": None, "b": None}
        assert sorted(f(a=2, b=3).values()) == [2, 3]

    def test_setdefault(self):
        def f(**args):
            return args
        d = f(a=1, b=2)
        a = d.setdefault("a", 0)
        assert a == 1
        a = d.setdefault("b", 0)
        assert a == 2
        a = d.setdefault("c", 3)
        assert a == 3
        assert "KwargsDictStrategy" in self.get_strategy(d)

    def test_iteritems_bug(self):
        def f(**args):
            return args

        d = f(a=2, b=3, c=4)
        for key, value in d.items():
            None in d

    def test_unicode(self):
        """
        def f(**kwargs):
            return kwargs

        d = f(λ=True)
        assert list(d) == ['λ']
        assert next(iter(d)) == 'λ'
        assert "KwargsDictStrategy" in self.get_strategy(d)

        d['foo'] = 'bar'
        assert sorted(d) == ['foo', 'λ']
        assert "KwargsDictStrategy" in self.get_strategy(d)

        d = f(λ=True)
        o = object()
        d[o] = 'baz'
        assert set(d) == set(['λ', o])
        assert "ObjectDictStrategy" in self.get_strategy(d)
        """

    def test_reversed(self):
        def f(**args):
            return args

        d = f(a=2, b=3, c=4)
        assert list(reversed(d)) == ['c', 'b', 'a']
        assert list(reversed(d.keys())) == ['c', 'b', 'a']
        assert list(reversed(d.values())) == [4, 3, 2]
        assert list(reversed(d.items())) == [('c', 4), ('b', 3), ('a', 2)]

    def test_popitem_bug(self):
        def f(**args):
            return args
        d = f(a=1, b=2)
        x = d.popitem()
        assert x == ('b', 2)
        x = d.popitem()
        assert x == ('a', 1)
        raises(KeyError, d.popitem)
