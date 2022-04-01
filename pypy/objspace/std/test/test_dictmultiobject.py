# encoding: utf-8
import sys
import py

from pypy.objspace.std.dictmultiobject import (W_DictMultiObject,
    W_DictObject, BytesDictStrategy, ObjectDictStrategy, UnicodeDictStrategy,
    IntDictStrategy)
from pypy.objspace.std.longobject import W_LongObject
from rpython.rlib.rbigint import rbigint


class TestW_DictObject(object):
    def test_empty(self):
        d = self.space.newdict()
        assert not self.space.is_true(d)
        assert type(d.get_strategy()) is not ObjectDictStrategy

    def test_nonempty(self):
        space = self.space
        wNone = space.w_None
        d = self.space.newdict()
        d.initialize_content([(wNone, wNone)])
        assert space.is_true(d)
        i = space.getitem(d, wNone)
        equal = space.eq(i, wNone)
        assert space.is_true(equal)

    def test_setitem(self):
        space = self.space
        wk1 = space.wrap('key')
        wone = space.wrap(1)
        d = self.space.newdict()
        d.initialize_content([(space.wrap('zero'),space.wrap(0))])
        space.setitem(d,wk1,wone)
        wback = space.getitem(d,wk1)
        assert self.space.eq_w(wback,wone)

    def test_delitem(self):
        space = self.space
        wk1 = space.wrap('key')
        d = self.space.newdict()
        d.initialize_content( [(space.wrap('zero'),space.wrap(0)),
                               (space.wrap('one'),space.wrap(1)),
                               (space.wrap('two'),space.wrap(2))])
        space.delitem(d,space.wrap('one'))
        assert self.space.eq_w(space.getitem(d,space.wrap('zero')),space.wrap(0))
        assert self.space.eq_w(space.getitem(d,space.wrap('two')),space.wrap(2))
        self.space.raises_w(self.space.w_KeyError,
                            space.getitem,d,space.wrap('one'))

    def test_wrap_dict(self):
        assert isinstance(self.space.wrap({}), W_DictMultiObject)


    def test_dict_compare(self):
        w = self.space.wrap
        w0, w1, w2, w3 = map(w, range(4))
        def wd(items):
            d = self.space.newdict()
            d.initialize_content(items)
            return d
        wd1 = wd([(w0, w1), (w2, w3)])
        wd2 = wd([(w2, w3), (w0, w1)])
        assert self.space.eq_w(wd1, wd2)
        wd3 = wd([(w2, w2), (w0, w1)])
        assert not self.space.eq_w(wd1, wd3)
        wd4 = wd([(w3, w3), (w0, w1)])
        assert not self.space.eq_w(wd1, wd4)
        wd5 = wd([(w3, w3)])
        assert not self.space.eq_w(wd1, wd4)

    def test_dict_call(self):
        space = self.space
        w = space.wrap
        def wd(items):
            d = space.newdict()
            d.initialize_content(items)
            return d
        def mydict(w_args=w(()), w_kwds=w({})):
            return space.call(space.w_dict, w_args, w_kwds)
        def deepwrap(lp):
            return [[w(a),w(b)] for a,b in lp]
        d = mydict()
        assert self.space.eq_w(d, w({}))
        args = w(([['a',2],[23,45]],))
        d = mydict(args)
        assert self.space.eq_w(d, wd(deepwrap([['a',2],[23,45]])))
        d = mydict(args, w({'a':33, 'b':44}))
        assert self.space.eq_w(d, wd(deepwrap([['a',33],['b',44],[23,45]])))
        d = mydict(w_kwds=w({'a':33, 'b':44}))
        assert self.space.eq_w(d, wd(deepwrap([['a',33],['b',44]])))
        self.space.raises_w(space.w_TypeError, mydict, w((23,)))
        self.space.raises_w(space.w_ValueError, mydict, w(([[1,2,3]],)))

    def test_dict_pop(self):
        space = self.space
        w = space.wrap
        def mydict(w_args=w(()), w_kwds=w({})):
            return space.call(space.w_dict, w_args, w_kwds)
        d = mydict(w_kwds=w({"1":2, "3":4}))
        dd = mydict(w_kwds=w({"1":2, "3":4})) # means d.copy()
        pop = space.getattr(dd, w("pop"))
        result = space.call_function(pop, w("1"))
        assert self.space.eq_w(result, w(2))
        assert self.space.eq_w(space.len(dd), w(1))

        dd = mydict(w_kwds=w({"1":2, "3":4})) # means d.copy()
        pop = space.getattr(dd, w("pop"))
        result = space.call_function(pop, w("1"), w(44))
        assert self.space.eq_w(result, w(2))
        assert self.space.eq_w(space.len(dd), w(1))
        result = space.call_function(pop, w("1"), w(44))
        assert self.space.eq_w(result, w(44))
        assert self.space.eq_w(space.len(dd), w(1))

        self.space.raises_w(space.w_KeyError, space.call_function, pop, w(33))

    def test_get(self):
        space = self.space
        w = space.wrap
        def mydict(w_args=w(()), w_kwds=w({})):
            return space.call(space.w_dict, w_args, w_kwds)
        d = mydict(w_kwds=w({"1":2, "3":4}))
        get = space.getattr(d, w("get"))
        assert self.space.eq_w(space.call_function(get, w("1")), w(2))
        assert self.space.eq_w(space.call_function(get, w("1"), w(44)), w(2))
        assert self.space.eq_w(space.call_function(get, w("33")), w(None))
        assert self.space.eq_w(space.call_function(get, w("33"), w(44)), w(44))

    def test_fromkeys_fastpath(self):
        py.test.skip("doesn't make sense here")
        space = self.space
        w = space.wrap

        w_l = space.newlist([w("a"),w("b")])
        w_l.getitems = None
        w_d = space.call_method(space.w_dict, "fromkeys", w_l)

        assert space.eq_w(w_d.getitem_str("a"), space.w_None)
        assert space.eq_w(w_d.getitem_str("b"), space.w_None)

    def test_listview_bytes_dict(self):
        w = self.space.wrap
        wb = self.space.newbytes
        w_d = self.space.newdict()
        w_d.initialize_content([(wb("a"), w(1)), (wb("b"), w(2))])
        assert self.space.listview_bytes(w_d) == ["a", "b"]

    @py.test.mark.skip("possible re-enable later?")
    def test_listview_unicode_dict(self):
        w = self.space.wrap
        w_d = self.space.newdict()
        w_d.initialize_content([(w(u"a"), w(1)), (w(u"b"), w(2))])
        assert self.space.listview_ascii(w_d) == ["a", "b"]

    def test_listview_int_dict(self):
        w = self.space.wrap
        w_d = self.space.newdict()
        w_d.initialize_content([(w(1), w("a")), (w(2), w("b"))])
        assert self.space.listview_int(w_d) == [1, 2]

    def test_keys_on_string_unicode_int_dict(self, monkeypatch):
        w = self.space.wrap
        wb = self.space.newbytes

        w_d = self.space.newdict()
        w_d.initialize_content([(w(1), wb("a")), (w(2), wb("b"))])
        w_k = self.space.call_method(w_d, "keys")
        w_l = self.space.call_function(self.space.w_list, w_k)
        assert sorted(self.space.listview_int(w_l)) == [1,2]

        # make sure that list(d.keys()) calls newlist_bytes for byte dicts
        def not_allowed(*args):
            assert False, 'should not be called'
        monkeypatch.setattr(self.space, 'newlist', not_allowed)
        #
        w_d = self.space.newdict()
        w_d.initialize_content([(wb("a"), w(1)), (wb("b"), w(6))])
        w_k = self.space.call_method(w_d, "keys")
        w_l = self.space.call_function(self.space.w_list, w_k)
        assert sorted(self.space.listview_bytes(w_l)) == ["a", "b"]

        #---the rest is for listview_unicode(), which is disabled---
        # XXX: it would be nice if the test passed without monkeypatch.undo(),
        # but we need space.newlist_unicode for it
        # monkeypatch.undo()
        # w_d = self.space.newdict()
        # w_d.initialize_content([(w(u"a"), w(1)), (w(u"b"), w(6))])
        # w_l = self.space.call_method(w_d, "keys")
        # assert sorted(self.space.listview_unicode(w_l)) == [u"a", u"b"]

    def test_integer_strategy_with_w_long(self):
        space = self.space
        w = W_LongObject(rbigint.fromlong(42))
        w_longlong = W_LongObject(rbigint.fromlong(10**40))
        w_d = space.newdict()
        space.setitem(w_d, w, space.w_None)
        assert w_d.get_strategy() is space.fromcache(IntDictStrategy)
        #
        space.setitem(w_d, w_longlong, space.w_None)
        assert w_d.get_strategy() is space.fromcache(ObjectDictStrategy)
        #
        w_d = self.space.newdict()
        w_d.initialize_content([(w, space.w_None)])
        assert w_d.get_strategy() is space.fromcache(IntDictStrategy)
        #
        w_d = self.space.newdict()
        w_d.initialize_content([(w_longlong, space.w_None)])
        assert w_d.get_strategy() is space.fromcache(ObjectDictStrategy)


class AppTest_DictObject:
    def setup_class(cls):
        cls.w_on_pypy = cls.space.wrap("__pypy__" in sys.builtin_module_names)

    def test_equality(self):
        d = {1: 2}
        f = {1: 2}
        assert d == f
        assert d != {1: 3}

    def test_clear(self):
        d = {1: 2, 3: 4}
        d.clear()
        assert len(d) == 0

    def test_copy(self):
        d = {1: 2, 3: 4}
        dd = d.copy()
        assert d == dd
        assert not d is dd

    def test_get(self):
        d = {1: 2, 3: 4}
        assert d.get(1) == 2
        assert d.get(1, 44) == 2
        assert d.get(33) == None
        assert d.get(33, 44) == 44

    def test_pop(self):
        d = {1: 2, 3: 4}
        dd = d.copy()
        result = dd.pop(1)
        assert result == 2
        assert len(dd) == 1
        dd = d.copy()
        result = dd.pop(1, 44)
        assert result == 2
        assert len(dd) == 1
        result = dd.pop(1, 44)
        assert result == 44
        assert len(dd) == 1
        raises(KeyError, dd.pop, 33)

        assert d.pop("abc", None) is None
        raises(KeyError, d.pop, "abc")
        assert len(d) == 2

    def test_pop_empty_bug(self):
        d = {}
        assert d.pop(1, 2) == 2
        def f(**d): return d
        d = f()
        assert d.pop(1, 2) == 2

    def test_pop_kwargs(self):
        def kw(**d): return d
        d = kw(o=2, t=4)
        dd = d.copy()
        result = dd.pop("o")
        assert result == 2
        assert len(dd) == 1
        dd = d.copy()
        result = dd.pop("o", 44)
        assert result == 2
        assert len(dd) == 1
        result = dd.pop("o", 44)
        assert result == 44
        assert len(dd) == 1
        raises(KeyError, dd.pop, "33")

        assert d.pop("abc", None) is None
        raises(KeyError, d.pop, "abc")
        assert len(d) == 2

    def test_items(self):
        d = {1: 2, 3: 4}
        its = list(d.items())
        its.sort()
        assert its == [(1, 2), (3, 4)]

    def test_iteritems(self):
        d = {1: 2, 3: 4}
        dd = d.copy()
        for k, v in d.items():
            assert v == dd[k]
            del dd[k]
        assert not dd

    def test_iterkeys(self):
        d = {1: 2, 3: 4}
        dd = d.copy()
        for k in d.keys():
            del dd[k]
        assert not dd

    def test_itervalues(self):
        d = {1: 2, 3: 4}
        values = []
        for k in d.values():
            values.append(k)
        assert values == list(d.values())

    def test_reverse_keys(self):
        d = {1: 2, 3: 4}
        assert list(reversed(d)) == [3, 1]
        assert list(reversed(d.keys())) == [3, 1]

    def test_reverse_values(self):
        d = {1: 2, 3: 4}
        assert list(reversed(d.values())) == [4, 2]

    def test_reverse_items(self):
        d = {1: 2, 3: 4}
        assert list(reversed(d.items())) == [(3, 4), (1, 2)]

    def test_reversed_dict(self):
        import __pypy__
        def kw(**d): return d
        for d in [{}, {1: 2, 3: 4, 5: 6}, {"a": 5, "b": 2, "c": 6}, kw(a=1, b=2)]:
            assert list(__pypy__.reversed_dict(d)) == list(d.keys())[::-1]
        raises(TypeError, __pypy__.reversed_dict, 42)

    def test_reversed_dict_runtimeerror(self):
        import __pypy__
        d = {1: 2, 3: 4, 5: 6}
        it = __pypy__.reversed_dict(d)
        key = next(it)
        assert key in [1, 3, 5]   # on CPython, dicts are not ordered
        del d[key]
        raises(RuntimeError, next, it)

    def test_dict_popitem_first(self):
        import __pypy__
        d = {"a": 5}
        assert __pypy__.dict_popitem_first(d) == ("a", 5)
        raises(KeyError, __pypy__.dict_popitem_first, d)

        def kwdict(**k):
            return k
        d = kwdict(a=55)
        assert __pypy__.dict_popitem_first(d) == ("a", 55)
        raises(KeyError, __pypy__.dict_popitem_first, d)

    def test_delitem_if_value_is(self):
        import __pypy__
        class X:
            pass
        x2 = X()
        x3 = X()
        d = {2: x2, 3: x3}
        __pypy__.delitem_if_value_is(d, 2, x3)
        assert d == {2: x2, 3: x3}
        __pypy__.delitem_if_value_is(d, 2, x2)
        assert d == {3: x3}
        __pypy__.delitem_if_value_is(d, 2, x3)
        assert d == {3: x3}

    def test_move_to_end(self):
        import __pypy__
        raises(KeyError, __pypy__.move_to_end, {}, 'foo')
        raises(KeyError, __pypy__.move_to_end, {}, 'foo', last=True)
        raises(KeyError, __pypy__.move_to_end, {}, 'foo', last=False)
        def kwdict(**k):
            return k
        for last in [False, True]:
            for d, key in [({1: 2, 3: 4, 5: 6}, 3),
                           ({b"a": 5, b"b": 2, b"c": 6}, b"b"),
                           ({u"a": 5, u"b": 2, u"c": 6}, u"b"),
                           (kwdict(d=7, e=8, f=9), "e")]:
                other_keys = [k for k in d if k != key]
                __pypy__.move_to_end(d, key, last=last)
                if not self.on_pypy:
                    # when running tests on CPython, the underlying
                    # dicts are not ordered.  We don't get here if
                    # we're running tests on PyPy or with -A.
                    assert set(d.keys()) == set(other_keys + [key])
                elif last:
                    assert list(d) == other_keys + [key]
                else:
                    assert list(d) == [key] + other_keys
                raises(KeyError, __pypy__.move_to_end, d, key * 3, last=last)

    def test_keys(self):
        d = {1: 2, 3: 4}
        kys = list(d.keys())
        kys.sort()
        assert kys == [1, 3]

    def test_popitem(self):
        d = {1: 2, 3: 4}
        it = d.popitem()
        assert len(d) == 1
        assert it == (1, 2) or it == (3, 4)
        it1 = d.popitem()
        assert len(d) == 0
        assert (it != it1) and (it1 == (1, 2) or it1 == (3, 4))
        raises(KeyError, d.popitem)

    def test_popitem_2(self):
        class A(object):
            pass
        d = A().__dict__
        d['x'] = 5
        it1 = d.popitem()
        assert it1 == ('x', 5)
        raises(KeyError, d.popitem)

    def test_popitem3(self):
        #object
        d = {"a": 1, 2: 2, "c": 3}
        l = []
        while True:
            try:
                l.append(d.popitem())
            except KeyError:
                break;
        assert ("a", 1) in l
        assert (2, 2) in l
        assert ("c", 3) in l

        #string
        d = {"a": 1, "b":2, "c":3}
        l = []
        while True:
            try:
                l.append(d.popitem())
            except KeyError:
                break;
        assert ("a", 1) in l
        assert ("b", 2) in l
        assert ("c", 3) in l

    def test_setdefault(self):
        d = {1: 2, 3: 4}
        dd = d.copy()
        x = dd.setdefault(1, 99)
        assert d == dd
        assert x == 2
        x = dd.setdefault(33, 99)
        d[33] = 99
        assert d == dd
        assert x == 99

    def test_setdefault_fast(self):
        class Key(object):
            calls = 0
            def __hash__(self):
                self.calls += 1
                return object.__hash__(self)

        k = Key()
        d = {}
        d.setdefault(k, [])
        if self.on_pypy:
            assert k.calls == 1

        d.setdefault(k, 1)
        if self.on_pypy:
            assert k.calls == 2

        k = Key()
        d.setdefault(k, 42)
        if self.on_pypy:
            assert k.calls == 1

    def test_update(self):
        d = {1: 2, 3: 4}
        dd = d.copy()
        d.update({})
        assert d == dd
        d.update({3: 5, 6: 7})
        assert d == {1: 2, 3: 5, 6: 7}

    def test_update_iterable(self):
        d = {}
        d.update((('a',1),))
        assert d == {'a': 1}
        d.update([('a',2), ('c',3)])
        assert d == {'a': 2, 'c': 3}

    def test_update_nop(self):
        d = {}
        d.update()
        assert d == {}

    def test_update_kwargs(self):
        d = {}
        d.update(foo='bar', baz=1)
        assert d == {'foo': 'bar', 'baz': 1}

    def test_update_dict_and_kwargs(self):
        d = {}
        d.update({'foo': 'bar'}, baz=1)
        assert d == {'foo': 'bar', 'baz': 1}

    def test_update_keys_method(self):
        class Foo(object):
            def keys(self):
                return [4, 1]
            def __getitem__(self, key):
                return key * 10
        d = {}
        d.update(Foo())
        assert d == {1: 10, 4: 40}

    def test_values(self):
        d = {1: 2, 3: 4}
        vals = list(d.values())
        vals.sort()
        assert vals == [2, 4]

    def test_eq(self):
        d1 = {1: 2, 3: 4}
        d2 = {1: 2, 3: 4}
        d3 = {1: 2}
        bool = d1 == d2
        assert bool == True
        bool = d1 == d3
        assert bool == False
        bool = d1 != d2
        assert bool == False
        bool = d1 != d3
        assert bool == True

    def test_richcompare(self):
        import operator
        d1 = {1: 2, 3: 4}
        d2 = {1: 2, 3: 5}
        for op in 'lt', 'le', 'gt', 'ge':
            f = getattr(operator, op)
            raises(TypeError, f, d1, d2)

    def test_str_repr(self):
        assert '{}' == str({})
        assert '{1: 2}' == str({1: 2})
        assert "{'ba': 'bo'}" == str({'ba': 'bo'})
        # NOTE: the string repr depends on hash values of 1 and 'ba'!!!
        ok_reprs = ["{1: 2, 'ba': 'bo'}", "{'ba': 'bo', 1: 2}"]
        assert str({1: 2, 'ba': 'bo'}) in ok_reprs
        assert '{}' == repr({})
        assert '{1: 2}' == repr({1: 2})
        assert "{'ba': 'bo'}" == repr({'ba': 'bo'})
        assert str({1: 2, 'ba': 'bo'}) in ok_reprs

        # Now test self-containing dict
        d = {}
        d[0] = d
        assert str(d) == '{0: {...}}'

        # Mutating while repr'ing
        class Machiavelli(object):
            def __repr__(self):
                d.clear()
                return "42"
        d = {Machiavelli(): True}
        str(d)
        assert d == {}

    def test_new(self):
        d = dict()
        assert d == {}
        args = [['a', 2], [23, 45]]
        d = dict(args)
        assert d == {'a': 2, 23: 45}
        d = dict(args, a=33, b=44)
        assert d == {'a': 33, 'b': 44, 23: 45}
        d = dict(a=33, b=44)
        assert d == {'a': 33, 'b': 44}
        d = dict({'a': 33, 'b': 44})
        assert d == {'a': 33, 'b': 44}
        raises((TypeError, ValueError), dict, 23)
        raises((TypeError, ValueError), dict, [[1, 2, 3]])

    def test_fromkeys(self):
        assert {}.fromkeys([1, 2], 1) == {1: 1, 2: 1}
        assert {}.fromkeys([1, 2]) == {1: None, 2: None}
        assert {}.fromkeys([]) == {}
        assert {1: 0, 2: 0, 3: 0}.fromkeys([1, '1'], 'j') == (
                          {1: 'j', '1': 'j'})
        class D(dict):
            def __new__(cls):
                return E()
        class E(dict):
            pass
        assert isinstance(D.fromkeys([1, 2]), E)
        assert dict.fromkeys({"a": 2, "b": 3}) == {"a": None, "b": None}
        assert dict.fromkeys({"a": 2, 1: 3}) == {"a": None, 1: None}

    def test_str_uses_repr(self):
        class D(dict):
            def __repr__(self):
                return 'hi'
        assert repr(D()) == 'hi'
        assert str(D()) == 'hi'

    def test_overridden_setitem(self):
        class D(dict):
            def __setitem__(self, key, value):
                dict.__setitem__(self, key, 42)
        d = D([('x', 'foo')], y = 'bar')
        assert d['x'] == 'foo'
        assert d['y'] == 'bar'

        d.setdefault('z', 'baz')
        assert d['z'] == 'baz'

        d['foo'] = 'bar'
        assert d['foo'] == 42

        d.update({'w': 'foobar'})
        assert d['w'] == 'foobar'

        d = d.copy()
        assert d['x'] == 'foo'

        d3 = D.fromkeys(['x', 'y'], 'foo')
        assert d3['x'] == 42
        assert d3['y'] == 42

    def test_overridden_setitem_customkey(self):
        class D(dict):
            def __setitem__(self, key, value):
                dict.__setitem__(self, key, 42)
        class Foo(object):
            pass

        d = D()
        key = Foo()
        d[key] = 'bar'
        assert d[key] == 42

    def test_repr_with_overridden_items(self):
        class D(dict):
            def items(self):
                return []

        d = D([("foo", "foobar")])
        assert repr(d) == "{'foo': 'foobar'}"

    def test_popitem_with_overridden_delitem(self):
        class D(dict):
            def __delitem__(self, key):
                assert False
        d = D()
        d['a'] = 42
        item = d.popitem()
        assert item == ('a', 42)

    def test_dict_update_overridden_getitem(self):
        class D(dict):
            def __getitem__(self, key):
                return 42
        d1 = {}
        d2 = D(a='foo')
        d1.update(d2)
        assert d1['a'] == 'foo'
        # a bit of an obscure case: now (from r78295) we get the same result
        # as CPython does

    def test_index_keyerror_unpacking(self):
        d = {}
        for v1 in ['Q', (1,)]:
            try:
                d[v1]
            except KeyError as e:
                v2 = e.args[0]
                assert v1 == v2
            else:
                assert False, 'Expected KeyError'

    def test_del_keyerror_unpacking(self):
        d = {}
        for v1 in ['Q', (1,)]:
            try:
                del d[v1]
            except KeyError as e:
                v2 = e.args[0]
                assert v1 == v2
            else:
                assert False, 'Expected KeyError'

    def test_pop_keyerror_unpacking(self):
        d = {}
        for v1 in ['Q', (1,)]:
            try:
                d.pop(v1)
            except KeyError as e:
                v2 = e.args[0]
                assert v1 == v2
            else:
                assert False, 'Expected KeyError'

    def test_pop_switching_strategy(self):
        class Foo:
            def __hash__(self):
                return hash("a")
            def __eq__(self, other):
                return other == "a"
        d = {"a": 42}
        x = d.pop(Foo())
        assert x == 42 and len(d) == 0
        d = {"b": 43}
        raises(KeyError, d.pop, Foo())

    def test_no_len_on_dict_iter(self):
        iterable = {1: 2, 3: 4}
        raises(TypeError, len, iter(iterable))
        iterable = {"1": 2, "3": 4}
        raises(TypeError, len, iter(iterable))
        iterable = {}
        raises(TypeError, len, iter(iterable))

    def test_missing(self):
        class X(dict):
            def __missing__(self, x):
                assert x == 'hi'
                return 42
        assert X()['hi'] == 42

    def test_missing_more(self):
        def missing(self, x):
            assert x == 'hi'
            return 42
        class SpecialDescr(object):
            def __init__(self, impl):
                self.impl = impl
            def __get__(self, obj, owner):
                return self.impl.__get__(obj, owner)
        class X(dict):
            __missing__ = SpecialDescr(missing)
        assert X()['hi'] == 42

    def test_empty_dict(self):
        d = {}
        raises(KeyError, d.popitem)
        assert list(d.items()) == []
        assert list(d.values()) == []
        assert list(d.keys()) == []

    def test_bytes_keys(self):
        assert isinstance(list({b'a': 1})[0], bytes)

    def test_interned_keywords(self):
        skip("no longer works")
        # At some point in the past, we had kwargsdict automatically
        # intern every single key we get out of it.  That's a big
        # pointless waste of time.  So the following test fails now.
        assert list(dict(abcdef=1))[0] is 'abcdef'

    def test_dict_copy(self):
        class my_dict_1(dict):
            def keys(self):
                return iter(['b'])

        class my_dict_2(my_dict_1):
            __iter__ = 42

        d1 = my_dict_1({'a': 1, 'b': 2})
        assert dict(d1) == {'a': 1, 'b': 2}  # doesn't use overridden keys()

        d2 = my_dict_2({'a': 1, 'b': 2})
        assert dict(d2) == {'b': 2}  # uses overridden keys()

    def test_or(self):
        d = {'spam': 1, 'eggs': 2, 'cheese': 3}
        e = {'cheese': 'cheddar', 'aardvark': 'Ethel'}
        assert d | e == {'spam': 1, 'eggs': 2, 'cheese': 'cheddar', 'aardvark': 'Ethel'}
        assert e | d == {'cheese': 3, 'aardvark': 'Ethel', 'spam': 1, 'eggs': 2}
        assert d.__or__(None) is NotImplemented

    def test_ior(self):
        orig = d = {'spam': 1, 'eggs': 2, 'cheese': 3}
        e = {'cheese': 'cheddar', 'aardvark': 'Ethel'}
        d |= e
        assert orig == {'spam': 1, 'eggs': 2, 'cheese': 'cheddar', 'aardvark': 'Ethel'}

        d = orig = {"a": 6, "b": 7}
        d |= [("b", 43), ("c", -1j)]
        assert orig == {"a": 6, "b": 43, "c": -1j}


    def test_class_getitem(self):
        assert dict[int, str].__origin__ is dict
        assert dict[int, str].__args__ == (int, str)


class AppTest_DictMultiObject(AppTest_DictObject):

    def test_emptydict_unhashable(self):
        raises(TypeError, "{}[['x']]")
        raises(TypeError, "del {}[['x']]")

    def test_string_subclass_via_setattr(self):
        class A(object):
            pass
        class S(str):
            def __hash__(self):
                return 123
        a = A()
        s = S("abc")
        setattr(a, s, 42)
        key = next(iter(a.__dict__.keys()))
        assert key == s
        assert key is not s
        assert type(key) is str
        assert getattr(a, s) == 42

    def test_setattr_string_identify(self):
        class StrHolder(object):
            pass
        holder = StrHolder()
        class A(object):
            def __setattr__(self, attr, value):
                holder.seen = attr

        a = A()
        s = "abc"
        setattr(a, s, 123)
        assert holder.seen is s

    def test_internal_delitem(self):
        class K:
            def __hash__(self):
                return 42
            def __eq__(self, other):
                if is_equal[0]:
                    is_equal[0] -= 1
                    return True
                return False
        is_equal = [0]
        k1 = K()
        k2 = K()
        d = {k1: 1, k2: 2}
        k3 = K()
        is_equal = [1]
        try:
            x = d.pop(k3)
        except RuntimeError:
            # This used to give a Fatal RPython error: KeyError.
            # Now at least it should raise an app-level RuntimeError,
            # or just work.
            assert len(d) == 2
        else:
            assert (x == 1 or x == 2) and len(d) == 1


class AppTestDictViews:
    def test_dictview(self):
        d = {1: 2, 3: 4}
        assert len(d.keys()) == 2
        assert len(d.items()) == 2
        assert len(d.values()) == 2

    def test_dict_keys(self):
        d = {1: 10, "a": "ABC"}
        keys = d.keys()
        assert len(keys) == 2
        assert set(keys) == set([1, "a"])
        assert keys == set([1, "a"])
        assert keys == frozenset([1, "a"])
        assert keys != set([1, "a", "b"])
        assert keys != set([1, "b"])
        assert keys != set([1])
        assert keys != 42
        assert not keys == 42
        assert 1 in keys
        assert "a" in keys
        assert 10 not in keys
        assert "Z" not in keys
        raises(TypeError, "[] in keys")     # [] is unhashable
        raises(TypeError, keys.__contains__, [])
        assert d.keys() == d.keys()
        e = {1: 11, "a": "def"}
        assert d.keys() == e.keys()
        del e["a"]
        assert d.keys() != e.keys()

    def test_dict_items(self):
        d = {1: 10, "a": "ABC"}
        items = d.items()
        assert len(items) == 2
        assert set(items) == set([(1, 10), ("a", "ABC")])
        assert items == set([(1, 10), ("a", "ABC")])
        assert items == frozenset([(1, 10), ("a", "ABC")])
        assert items != set([(1, 10), ("a", "ABC"), "junk"])
        assert items != set([(1, 10), ("a", "def")])
        assert items != set([(1, 10)])
        assert items != 42
        assert not items == 42
        assert (1, 10) in items
        assert ("a", "ABC") in items
        assert (1, 11) not in items
        assert 1 not in items
        assert () not in items
        assert (1,) not in items
        assert (1, 2, 3) not in items
        raises(TypeError, "([], []) not in items")     # [] is unhashable
        raises(TypeError, items.__contains__, ([], []))
        assert d.items() == d.items()
        e = d.copy()
        assert d.items() == e.items()
        e["a"] = "def"
        assert d.items() != e.items()

    def test_dict_items_contains_with_identity(self):
        class BadEq(object):
            def __eq__(self, other):
                raise ZeroDivisionError
            def __hash__(self):
                return 7
        k = BadEq()
        v = BadEq()
        assert (k, v) in {k: v}.items()

    def test_dict_mixed_keys_items(self):
        d = {(1, 1): 11, (2, 2): 22}
        e = {1: 1, 2: 2}
        assert d.keys() == e.items()
        assert d.items() != e.keys()

    def test_dict_values(self):
        d = {1: 10, "a": "ABC"}
        values = d.values()
        assert set(values) == set([10, "ABC"])
        assert len(values) == 2
        assert not values == 42

    def test_dict_repr(self):
        d = {1: 10, "a": "ABC"}
        assert isinstance(repr(d), str)
        r = repr(d.items())
        assert isinstance(r, str)
        assert (r == "dict_items([('a', 'ABC'), (1, 10)])" or
                r == "dict_items([(1, 10), ('a', 'ABC')])")
        r = repr(d.keys())
        assert isinstance(r, str)
        assert (r == "dict_keys(['a', 1])" or
                r == "dict_keys([1, 'a'])")
        r = repr(d.values())
        assert isinstance(r, str)
        assert (r == "dict_values(['ABC', 10])" or
                r == "dict_values([10, 'ABC'])")
        d = {'日本': '日本国'}
        assert repr(d.items()) == "dict_items([('日本', '日本国')])"

    def test_recursive_repr(self):
        d = {1: 2}
        d[2] = d.values()
        assert repr(d) == '{1: 2, 2: dict_values([2, ...])}'

    def test_keys_set_operations(self):
        d1 = {'a': 1, 'b': 2}
        d2 = {'b': 3, 'c': 2}
        d3 = {'d': 4, 'e': 5}
        assert d1.keys() & d1.keys() == set('ab')
        assert d1.keys() & d2.keys() == set('b')
        assert d1.keys() & d3.keys() == set()
        assert d1.keys() & set(d1.keys()) == set('ab')
        assert d1.keys() & set(d2.keys()) == set('b')
        assert d1.keys() & set(d3.keys()) == set()

        assert d1.keys() | d1.keys() == set('ab')
        assert d1.keys() | d2.keys() == set('abc')
        assert d1.keys() | d3.keys() == set('abde')
        assert d1.keys() | set(d1.keys()) == set('ab')
        assert d1.keys() | set(d2.keys()) == set('abc')
        assert d1.keys() | set(d3.keys()) == set('abde')

        assert d1.keys() ^ d1.keys() == set()
        assert d1.keys() ^ d2.keys() == set('ac')
        assert d1.keys() ^ d3.keys() == set('abde')
        assert d1.keys() ^ set(d1.keys()) == set()
        assert d1.keys() ^ set(d2.keys()) == set('ac')
        assert d1.keys() ^ set(d3.keys()) == set('abde')

        assert d1.keys() - d1.keys() == set()
        assert d1.keys() - d2.keys() == set('a')
        assert d1.keys() - d3.keys() == set('ab')
        assert d1.keys() - set(d1.keys()) == set()
        assert d1.keys() - set(d2.keys()) == set('a')
        assert d1.keys() - set(d3.keys()) == set('ab')

        assert not d1.keys().isdisjoint(d1.keys())
        assert not d1.keys().isdisjoint(d2.keys())
        assert not d1.keys().isdisjoint(list(d2.keys()))
        assert not d1.keys().isdisjoint(set(d2.keys()))

        assert d1.keys().isdisjoint(['x', 'y', 'z'])
        assert d1.keys().isdisjoint(set(['x', 'y', 'z']))
        assert d1.keys().isdisjoint(set(['x', 'y']))
        assert d1.keys().isdisjoint(['x', 'y'])
        assert d1.keys().isdisjoint({})
        assert d1.keys().isdisjoint(d3.keys())

        de = {}
        assert de.keys().isdisjoint(set())
        assert de.keys().isdisjoint([])
        assert de.keys().isdisjoint(de.keys())
        assert de.keys().isdisjoint([1])


    def test_items_set_operations(self):
        d1 = {'a': 1, 'b': 2}
        d2 = {'a': 2, 'b': 2}
        d3 = {'d': 4, 'e': 5}
        assert d1.items() & d1.items() == set([('a', 1), ('b', 2)])
        assert d1.items() & d2.items() == set([('b', 2)])
        assert d1.items() & d3.items() == set()
        assert d1.items() & set(d1.items()) == set([('a', 1), ('b', 2)])
        assert d1.items() & set(d2.items()) == set([('b', 2)])
        assert d1.items() & set(d3.items()) == set()

        assert d1.items() | d1.items() == set([('a', 1), ('b', 2)])
        assert (d1.items() | d2.items() ==
                set([('a', 1), ('a', 2), ('b', 2)]))
        assert (d1.items() | d3.items() ==
                set([('a', 1), ('b', 2), ('d', 4), ('e', 5)]))
        assert (d1.items() | set(d1.items()) ==
                set([('a', 1), ('b', 2)]))
        assert (d1.items() | set(d2.items()) ==
                set([('a', 1), ('a', 2), ('b', 2)]))
        assert (d1.items() | set(d3.items()) ==
                set([('a', 1), ('b', 2), ('d', 4), ('e', 5)]))

        assert d1.items() ^ d1.items() == set()
        assert d1.items() ^ d2.items() == set([('a', 1), ('a', 2)])
        assert (d1.items() ^ d3.items() ==
                set([('a', 1), ('b', 2), ('d', 4), ('e', 5)]))

        assert d1.items() - d1.items() == set()
        assert d1.items() - d2.items() == set([('a', 1)])
        assert d1.items() - d3.items() == set([('a', 1), ('b', 2)])

        assert not d1.items().isdisjoint(d1.items())
        assert not d1.items().isdisjoint(d2.items())
        assert not d1.items().isdisjoint(list(d2.items()))
        assert not d1.items().isdisjoint(set(d2.items()))
        assert d1.items().isdisjoint(['x', 'y', 'z'])
        assert d1.items().isdisjoint(set(['x', 'y', 'z']))
        assert d1.items().isdisjoint(set(['x', 'y']))
        assert d1.items().isdisjoint({})
        assert d1.items().isdisjoint(d3.items())

        de = {}
        assert de.items().isdisjoint(set())
        assert de.items().isdisjoint([])
        assert de.items().isdisjoint(de.items())
        assert de.items().isdisjoint([1])

    def test_keys_set_operations_any_type(self):
        """
        d = {1: 'a', 2: 'b', 3: 'c'}
        assert d.keys() & {1} == {1}
        assert d.keys() & {1: 'foo'} == {1}
        assert d.keys() & [1, 2] == {1, 2}
        #
        assert {1} & d.keys() == {1}
        assert {1: 'foo'} & d.keys() == {1}
        assert [1, 2] & d.keys() == {1, 2}
        #
        assert d.keys() - {1} == {2, 3}
        assert {1, 4} - d.keys() == {4}
        #
        assert d.keys() == {1, 2, 3}
        assert {1, 2, 3} == d.keys()
        assert d.keys() == frozenset({1, 2, 3})
        assert frozenset({1, 2, 3}) == d.keys()
        assert not d.keys() != {1, 2, 3}
        assert not {1, 2, 3} != d.keys()
        assert not d.keys() != frozenset({1, 2, 3})
        assert not frozenset({1, 2, 3}) != d.keys()
        """

    def test_items_set_operations_any_type(self):
        """
        d = {1: 'a', 2: 'b', 3: 'c'}
        assert d.items() & {(1, 'a')} == {(1, 'a')}
        assert d.items() & {(1, 'a'): 'foo'} == {(1, 'a')}
        assert d.items() & [(1, 'a'), (2, 'b')] == {(1, 'a'), (2, 'b')}
        #
        assert {(1, 'a')} & d.items() == {(1, 'a')}
        assert {(1, 'a'): 'foo'} & d.items() == {(1, 'a')}
        assert [(1, 'a'), (2, 'b')] & d.items() == {(1, 'a'), (2, 'b')}
        #
        assert d.items() - {(1, 'a')} == {(2, 'b'), (3, 'c')}
        assert {(1, 'a'), 4} - d.items() == {4}
        #
        assert d.items() == {(1, 'a'), (2, 'b'), (3, 'c')}
        assert {(1, 'a'), (2, 'b'), (3, 'c')} == d.items()
        assert d.items() == frozenset({(1, 'a'), (2, 'b'), (3, 'c')})
        assert frozenset({(1, 'a'), (2, 'b'), (3, 'c')}) == d.items()
        assert not d.items() != {(1, 'a'), (2, 'b'), (3, 'c')}
        assert not {(1, 'a'), (2, 'b'), (3, 'c')} != d.items()
        assert not d.items() != frozenset({(1, 'a'), (2, 'b'), (3, 'c')})
        assert not frozenset({(1, 'a'), (2, 'b'), (3, 'c')}) != d.items()
        """

    def test_dictviewset_unhashable_values(self):
        class C:
            def __eq__(self, other):
                return True
        d = {1: C()}
        assert d.items() <= d.items()

    def test_compare_keys_and_items(self):
        d1 = {1: 2}
        d2 = {(1, 2): 'foo'}
        assert d1.items() == d2.keys()

    def test_keys_items_contained(self):
        def helper(fn):
            empty = fn(dict())
            empty2 = fn(dict())
            smaller = fn({1:1, 2:2})
            larger = fn({1:1, 2:2, 3:3})
            larger2 = fn({1:1, 2:2, 3:3})
            larger3 = fn({4:1, 2:2, 3:3})

            assert smaller <  larger
            assert smaller <= larger
            assert larger >  smaller
            assert larger >= smaller

            assert not smaller >= larger
            assert not smaller >  larger
            assert not larger  <= smaller
            assert not larger  <  smaller

            assert not smaller <  larger3
            assert not smaller <= larger3
            assert not larger3 >  smaller
            assert not larger3 >= smaller

            # Inequality strictness
            assert larger2 >= larger
            assert larger2 <= larger
            assert not larger2 > larger
            assert not larger2 < larger

            assert larger == larger2
            assert smaller != larger

            # There is an optimization on the zero-element case.
            assert empty == empty2
            assert not empty != empty2
            assert not empty == smaller
            assert empty != smaller

            # With the same size, an elementwise compare happens
            assert larger != larger3
            assert not larger == larger3

        helper(lambda x: x.keys())
        helper(lambda x: x.items())

    def test_pickle(self):
        d = {1: 1, 2: 2, 3: 3}
        it = iter(d)
        first = next(it)
        reduced = it.__reduce__()
        rebuild, args = reduced
        new = rebuild(*args)
        items = set(new)
        assert len(items) == 2
        items.add(first)
        assert items == set(d)

    def test_contains(self):
        logger = []

        class Foo(object):

            def __init__(self, value, name=None):
                self.value = value
                self.name = name or value

            def __repr__(self):
                return '<Foo %s>' % self.name

            def __eq__(self, other):
                logger.append((self, other))
                return self.value == other.value

            def __hash__(self):
                return 42  # __eq__ will be used given all objects' hashes clash

        foo1, foo2, foo3 = Foo(1), Foo(2), Foo(3)
        foo42 = Foo(42)
        foo_dict = {foo1: 1, foo2: 1, foo3: 1}
        del logger[:]
        foo42 in foo_dict
        logger_copy = set(logger[:])  # prevent re-evaluation during pytest error print
        assert logger_copy == {(foo3, foo42), (foo2, foo42), (foo1, foo42)}

        del logger[:]
        foo2_bis = Foo(2, '2 bis')
        foo2_bis in foo_dict
        logger_copy = set(logger[:])  # prevent re-evaluation during pytest error print
        assert (foo2, foo2_bis) in logger_copy
        assert logger_copy.issubset({(foo1, foo2_bis), (foo2, foo2_bis), (foo3, foo2_bis)})

    def test_pickle(self):
        d = {1: 1, 2: 2, 3: 3}
        it = iter(d)
        first = next(it)
        reduced = it.__reduce__()
        rebuild, args = reduced
        new = rebuild(*args)
        items = list(new)
        assert len(items) == 2
        items.insert(0, first)
        assert items == list(d)

    def test_pickle_reversed(self):
        for meth in dict.keys, dict.values, dict.items:
            d = {1: 1, 2: 2, 3: 4}
            it = iter(reversed(meth(d)))
            first = next(it)
            reduced = it.__reduce__()
            rebuild, args = reduced
            new = rebuild(*args)
            items = list(new)
            assert len(items) == 2
            items.insert(0, first)
            assert items == list(reversed(meth(d)))


class AppTestStrategies(object):
    def setup_class(cls):
        if cls.runappdirect:
            py.test.skip("__repr__ doesn't work on appdirect")

    def w_get_strategy(self, obj):
        import __pypy__
        r = __pypy__.internal_repr(obj)
        return r[r.find("(") + 1: r.find(")")]

    def test_empty_to_string(self):
        d = {}
        assert "EmptyDictStrategy" in self.get_strategy(d)
        d[b"a"] = 1
        assert "BytesDictStrategy" in self.get_strategy(d)

        class O(object):
            pass
        o = O()
        d = o.__dict__ = {}
        assert "EmptyDictStrategy" in self.get_strategy(d)
        o.a = 1
        assert "UnicodeDictStrategy" in self.get_strategy(d)

    def test_empty_to_unicode(self):
        d = {}
        assert "EmptyDictStrategy" in self.get_strategy(d)
        d[u"a"] = 1
        assert "UnicodeDictStrategy" in self.get_strategy(d)
        assert d["a"] == 1
        #assert d[b"a"] == 1 # this works in py2, but not in py3
        assert list(d.keys()) == ["a"]
        assert type(list(d.keys())[0]) is str

    def test_setitem_str_nonascii(self):
        d = {}
        assert "EmptyDictStrategy" in self.get_strategy(d)
        d[u"a"] = 1
        assert "UnicodeDictStrategy" in self.get_strategy(d)
        exec("a = 1", d)
        assert d["a"] == 1
        assert "UnicodeDictStrategy" in self.get_strategy(d)
        exec("ä = 2", d)
        assert "UnicodeDictStrategy" in self.get_strategy(d)
        assert d["a"] == 1
        assert d["ä"] == 2

        d = {}
        d[u"ä"] = 1
        assert "UnicodeDictStrategy" in self.get_strategy(d)

    def test_empty_to_int(self):
        d = {}
        d[1] = "hi"
        assert "IntDictStrategy" in self.get_strategy(d)

    def test_iter_dict_length_change(self):
        d = {1: 2, 3: 4, 5: 6}
        it = iter(d.items())
        d[7] = 8
        # 'd' is now length 4
        raises(RuntimeError, next, it)

    def test_iter_dict_strategy_only_change_1(self):
        d = {1: 2, 3: 4, 5: 6}
        it = d.items()
        class Foo(object):
            def __eq__(self, other):
                return False
            def __hash__(self):
                return 0
        assert d.get(Foo()) is None    # this changes the strategy of 'd'
        lst = list(it)  # but iterating still works
        assert sorted(lst) == [(1, 2), (3, 4), (5, 6)]

    def test_iter_dict_strategy_only_change_2(self):
        d = {1: 2, 3: 4, 5: 6}
        it = d.items()
        d['foo'] = 'bar'
        del d[1]
        # on default the strategy changes and thus we get the RuntimeError
        # (commented below). On py3k, we Int and String strategies don't work
        # yet, and thus we get the "correct" behavior
        items = list(it)
        assert set(items) == set([(3, 4), (5, 6), ('foo', 'bar')])
        # 'd' is still length 3, but its strategy changed.  we are
        # getting a RuntimeError because iterating over the old storage
        # gives us (1, 2), but 1 is not in the dict any longer.
        #raises(RuntimeError, list, it)

    def test_bytes_to_object(self):
        d = {b'a': 'b'}
        d[object()] = None
        assert b'a' in list(d)


class FakeString(str):

    hash_count = 0

    def unwrap(self, space):
        self.unwrapped = True
        return str(self)

    def __hash__(self):
        self.hash_count += 1
        return str.__hash__(self)

class FakeUnicode(unicode):

    hash_count = 0

    def unwrap(self, space):
        self.unwrapped = True
        return unicode(self)

    def __hash__(self):
        self.hash_count += 1
        return unicode.__hash__(self)

    def hash_w(self):
        return hash(self)

    def eq_w(self, other):
        return self == other

    def is_ascii(self):
        return True

    def unwrapped(self):
        return True

# the minimal 'space' needed to use a W_DictMultiObject
class FakeSpace:
    hash_count = 0
    def hash_w(self, obj):
        self.hash_count += 1
        return hash(obj)
    def unwrap(self, x):
        return x
    def is_true(self, x):
        return x
    def is_(self, x, y):
        return x is y
    is_w = is_
    def eq(self, x, y):
        return x == y
    eq_w = eq
    def newlist(self, l):
        return l
    def newlist_bytes(self, l):
        return l
    def newlist_text(self, l):
        return l
    def newlist_unicode(self, l):
        return l
    DictObjectCls = W_DictObject
    def type(self, w_obj):
        if isinstance(w_obj, FakeString):
            return str
        if isinstance(w_obj, FakeUnicode):
            return unicode
        return type(w_obj)
    w_unicode = unicode
    w_text = unicode
    w_bytes = str

    def text_w(self, u):
        assert isinstance(u, unicode)
        return FakeUnicode(u).encode('utf8')

    def bytes_w(self, string):
        assert isinstance(string, str)
        return string

    def utf8_w(self, u):
        if isinstance(u, unicode):
            u = u.encode('utf8')
        assert isinstance(u, str)
        return u

    def int_w(self, integer, allow_conversion=True):
        assert isinstance(integer, int)
        return integer

    def float_w(self, fl, allow_conversion=True):
        assert isinstance(fl, float)
        return fl

    def wrap(self, obj):
        if isinstance(obj, str):
            return FakeUnicode(obj.decode('ascii'))
        return obj

    def newtext(self, string):
        if isinstance(string, str):
            return FakeUnicode(string.decode('utf-8'))
        assert isinstance(string, unicode)
        return FakeUnicode(string)

    def newutf8(self, obj, lgt):
        return obj

    def newbytes(self, obj):
        return obj

    def new_interned_str(self, s):
        return s.decode('utf-8')

    newint = newfloat = wrap

    def isinstance_w(self, obj, klass):
        return isinstance(obj, klass)
    isinstance = isinstance_w

    def newtuple(self, l):
        return tuple(l)

    def newdict(self, module=False, instance=False):
        return W_DictObject.allocate_and_init_instance(
                self, module=module, instance=instance)

    def view_as_kwargs(self, w_d):
        return w_d.view_as_kwargs() # assume it's a multidict

    def finditem_str(self, w_dict, s):
        return w_dict.getitem_str(s) # assume it's a multidict

    def setitem_str(self, w_dict, s, w_value):
        return w_dict.setitem_str(s, w_value) # assume it's a multidict

    def delitem(self, w_dict, w_s):
        return w_dict.delitem(w_s) # assume it's a multidict

    def allocate_instance(self, cls, type):
        return object.__new__(cls)

    def fromcache(self, cls):
        return cls(self)

    def _side_effects_ok(self):
        return True

    w_StopIteration = StopIteration
    w_None = None
    w_NoneType = type(None, None)
    w_int = int
    w_bool = bool
    w_float = float
    StringObjectCls = FakeString
    UnicodeObjectCls = FakeUnicode
    IntObjectCls = int
    FloatObjectCls = float
    w_dict = W_DictObject
    iter = iter
    fixedview = list
    listview  = list

class Config:
    class objspace:
        class std:
            methodcachesizeexp = 11
            withmethodcachecounter = False

FakeSpace.config = Config()


class TestDictImplementation:
    def setup_method(self,method):
        self.space = FakeSpace()

    def test_stressdict(self):
        from random import randint
        d = self.space.newdict()
        N = 10000
        pydict = {}
        for i in range(N):
            x = randint(-N, N)
            d.descr_setitem(self.space, x, i)
            pydict[x] = i
        for key, value in pydict.iteritems():
            assert value == d.descr_getitem(self.space, key)

class BaseTestRDictImplementation:
    FakeString = FakeUnicode
    _str_devolves = False

    def setup_method(self,method):
        self.fakespace = FakeSpace()
        self.string = self.wrapstrorunicode("fish")
        self.string2 = self.wrapstrorunicode("fish2")
        self.impl = self.get_impl()

    def wrapstrorunicode(self, obj):
        return self.fakespace.wrap(obj)

    def get_impl(self):
        strategy = self.StrategyClass(self.fakespace)
        storage = strategy.get_empty_storage()
        w_dict = self.fakespace.allocate_instance(W_DictObject, None)
        W_DictObject.__init__(w_dict, self.fakespace, strategy, storage)
        return w_dict

    def fill_impl(self):
        self.impl.setitem(self.string, 1000)
        self.impl.setitem(self.string2, 2000)

    def check_not_devolved(self):
        #XXX check if strategy changed!?
        assert type(self.impl.get_strategy()) is self.StrategyClass
        #assert self.impl.r_dict_content is None

    def test_popitem(self):
        self.fill_impl()
        assert self.impl.length() == 2
        a, b = self.impl.popitem()
        assert self.impl.length() == 1
        if a == self.string:
            assert b == 1000
            assert self.impl.getitem(self.string2) == 2000
        else:
            assert a == self.string2
            assert b == 2000
            if not self._str_devolves:
                result = self.impl.getitem_str(self.string.encode('utf-8'))
            else:
                result = self.impl.getitem(self.string)
            assert result == 1000
        self.check_not_devolved()

    def test_setitem(self):
        self.impl.setitem(self.string, 1000)
        assert self.impl.length() == 1
        assert self.impl.getitem(self.string) == 1000
        if not self._str_devolves:
            result = self.impl.getitem_str(self.string.encode('utf-8'))
        else:
            result = self.impl.getitem(self.string)
        assert result == 1000
        self.check_not_devolved()

    def test_delitem(self):
        self.fill_impl()
        assert self.impl.length() == 2
        self.impl.delitem(self.string2)
        assert self.impl.length() == 1
        self.impl.delitem(self.string)
        assert self.impl.length() == 0
        self.check_not_devolved()

    def test_clear(self):
        self.fill_impl()
        assert self.impl.length() == 2
        self.impl.clear()
        assert self.impl.length() == 0
        self.check_not_devolved()


    def test_keys(self):
        self.fill_impl()
        keys = self.impl.w_keys() # wrapped lists = lists in the fake space
        keys.sort()
        assert keys == [self.string, self.string2]
        self.check_not_devolved()

    def test_values(self):
        self.fill_impl()
        values = self.impl.values()
        values.sort()
        assert values == [1000, 2000]
        self.check_not_devolved()

    def test_items(self):
        self.fill_impl()
        items = self.impl.items()
        items.sort()
        assert items == zip([self.string, self.string2], [1000, 2000])
        self.check_not_devolved()

    def test_iter(self):
        self.fill_impl()
        iteratorimplementation = self.impl.iteritems()
        items = []
        while 1:
            item = iteratorimplementation.next_item()
            if item == (None, None):
                break
            items.append(item)
        items.sort()
        assert items == zip([self.string, self.string2], [1000, 2000])
        self.check_not_devolved()

    def test_devolve(self):
        impl = self.impl
        for x in xrange(100):
            impl.setitem(self.fakespace.text_w(unicode(x)), x)
            impl.setitem(x, x)
        assert type(impl.get_strategy()) is ObjectDictStrategy


    setdefault_hash_count = 1

    def test_setdefault_fast(self):
        on_pypy = "__pypy__" in sys.builtin_module_names
        impl = self.impl
        key = self.FakeString(self.string)
        x = impl.setdefault(key, 1)
        assert x == 1
        if on_pypy and self.FakeString is FakeString:
            assert key.hash_count == self.setdefault_hash_count
        x = impl.setdefault(key, 2)
        assert x == 1
        if on_pypy and self.FakeString is FakeString:
            assert key.hash_count == self.setdefault_hash_count + 1

    def test_fallback_evil_key(self):
        class F(object):
            def __hash__(self):
                return hash("s")
            def __eq__(self, other):
                return other == "s"

        d = self.get_impl()
        w_key = FakeString("s")
        d.setitem(w_key, 12)
        assert d.getitem(w_key) == 12
        assert d.getitem(F()) == d.getitem(w_key)

        d = self.get_impl()
        x = d.setdefault(w_key, 12)
        assert x == 12
        x = d.setdefault(F(), 12)
        assert x == 12

        d = self.get_impl()
        x = d.setdefault(F(), 12)
        assert x == 12

        d = self.get_impl()
        d.setitem(w_key, 12)
        d.delitem(F())

        assert w_key not in d.w_keys()
        assert F() not in d.w_keys()

class TestUnicodeDictImplementation(BaseTestRDictImplementation):
    StrategyClass = UnicodeDictStrategy

    def test_str_shortcut(self):
        self.fill_impl()
        s = self.FakeString(self.string)
        assert self.impl.getitem(s) == 1000
        assert s.unwrapped

    def test_view_as_kwargs(self):
        self.fill_impl()
        assert self.fakespace.view_as_kwargs(self.impl) == (["fish", "fish2"], [1000, 2000])

    def test_setitem_str(self):
        self.impl.setitem_str(self.fakespace.text_w(self.string), 1000)
        assert self.impl.length() == 1
        assert self.impl.getitem(self.string) == 1000
        assert self.impl.getitem_str(str(self.string)) == 1000
        self.check_not_devolved()

    def test_setitem_str(self):
        self.impl.setitem_str(self.fakespace.text_w(self.string), 1000)
        assert self.impl.length() == 1
        assert self.impl.getitem(self.string) == 1000
        assert self.impl.getitem_str(str(self.string)) == 1000
        self.check_not_devolved()

class TestBytesDictImplementation(BaseTestRDictImplementation):
    StrategyClass = BytesDictStrategy
    FakeString = FakeString
    _str_devolves = True

    def wrapstrorunicode(self, obj):
        return self.fakespace.newbytes(obj)


class BaseTestDevolvedDictImplementation(BaseTestRDictImplementation):
    def fill_impl(self):
        BaseTestRDictImplementation.fill_impl(self)
        self.impl.get_strategy().switch_to_object_strategy(self.impl)

    def check_not_devolved(self):
        pass

class TestDevolvedUnicodeDictImplementation(BaseTestDevolvedDictImplementation):
    StrategyClass = UnicodeDictStrategy


def test_module_uses_strdict():
    from pypy.objspace.std.celldict import ModuleDictStrategy
    fakespace = FakeSpace()
    d = fakespace.newdict(module=True)
    assert type(d.get_strategy()) is ModuleDictStrategy
