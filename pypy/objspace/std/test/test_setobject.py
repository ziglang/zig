# -*- encoding: utf-8 -*-
"""
The main test for the set implementation is located
in the stdlibs test/test_set.py which is located in lib-python
go there and invoke::

    ../../../pypy/bin/pyinteractive.py test_set.py

This file just contains some basic tests that make sure, the implementation
is not too wrong.
"""
from pypy.objspace.std.setobject import W_SetObject, W_FrozensetObject, IntegerSetStrategy
from pypy.objspace.std.setobject import _initialize_set
from pypy.objspace.std.listobject import W_ListObject

letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

class W_SubSetObject(W_SetObject):pass

class TestW_SetObject:

    def setup_method(self, method):
        self.word = self.space.wrap('simsalabim')
        self.otherword = self.space.wrap('madagascar')
        self.letters = self.space.wrap(letters)
        self.true = self.space.w_True
        self.false = self.space.w_False

    def test_and(self):
        s = W_SetObject(self.space)
        _initialize_set(self.space, s, self.word)
        t0 = W_SetObject(self.space)
        _initialize_set(self.space, t0, self.otherword)
        t1 = W_FrozensetObject(self.space, self.otherword)
        r0 = s.descr_and(self.space, t0)
        r1 = s.descr_and(self.space, t1)
        assert r0.descr_eq(self.space, r1) == self.true
        sr = s.descr_intersection(self.space, [self.otherword])
        assert r0.descr_eq(self.space, sr) == self.true

    def test_compare(self):
        s = W_SetObject(self.space)
        _initialize_set(self.space, s, self.word)
        t = W_SetObject(self.space)
        _initialize_set(self.space, t, self.word)
        assert self.space.eq_w(s,t)
        u = self.space.wrap(set('simsalabim'))
        assert self.space.eq_w(s,u)

    def test_space_newset(self):
        s = self.space.newset()
        assert self.space.text_w(self.space.repr(s)) == 'set()'
        # check that the second time we don't get 'set(...)'
        assert self.space.text_w(self.space.repr(s)) == 'set()'

    def test_intersection_order(self):
        # theses tests make sure that intersection is done in the correct order
        # (smallest first)
        space = self.space
        a = W_SetObject(self.space)
        _initialize_set(self.space, a, self.space.wrap("abcdefg"))
        a.intersect = None

        b = W_SetObject(self.space)
        _initialize_set(self.space, b, self.space.wrap("abc"))

        result = a.descr_intersection(space, [b])
        assert space.is_true(self.space.eq(result, W_SetObject(space, self.space.wrap("abc"))))

        c = W_SetObject(self.space)
        _initialize_set(self.space, c, self.space.wrap("e"))

        d = W_SetObject(self.space)
        _initialize_set(self.space, d, self.space.wrap("ab"))

        # if ordering works correct we should start with set e
        a.get_storage_copy = None
        b.get_storage_copy = None
        d.get_storage_copy = None

        result = a.descr_intersection(space, [d,c,b])
        assert space.is_true(self.space.eq(result, W_SetObject(space, self.space.wrap(""))))

    def test_create_set_from_list(self):
        from pypy.interpreter.baseobjspace import W_Root
        from pypy.objspace.std.setobject import BytesSetStrategy, ObjectSetStrategy, AsciiSetStrategy
        from pypy.objspace.std.floatobject import W_FloatObject

        w = self.space.wrap
        wb = self.space.newbytes
        intstr = self.space.fromcache(IntegerSetStrategy)
        tmp_func = intstr.get_storage_from_list
        # test if get_storage_from_list is no longer used
        intstr.get_storage_from_list = None

        w_list = W_ListObject(self.space, [w(1), w(2), w(3)])
        w_set = W_SetObject(self.space)
        _initialize_set(self.space, w_set, w_list)
        assert w_set.strategy is intstr
        assert intstr.unerase(w_set.sstorage) == {1:None, 2:None, 3:None}

        w_list = W_ListObject(self.space, [wb("1"), wb("2"), wb("3")])
        w_set = W_SetObject(self.space)
        _initialize_set(self.space, w_set, w_list)
        assert w_set.strategy is self.space.fromcache(BytesSetStrategy)
        assert w_set.strategy.unerase(w_set.sstorage) == {"1":None, "2":None, "3":None}

        w_list = self.space.iter(W_ListObject(self.space, [w(u"1"), w(u"2"), w(u"3")]))
        w_set = W_SetObject(self.space)
        _initialize_set(self.space, w_set, w_list)
        assert w_set.strategy is self.space.fromcache(AsciiSetStrategy)
        assert w_set.strategy.unerase(w_set.sstorage) == {u"1":None, u"2":None, u"3":None}

        w_list = W_ListObject(self.space, [w("1"), w(2), w("3")])
        w_set = W_SetObject(self.space)
        _initialize_set(self.space, w_set, w_list)
        assert w_set.strategy is self.space.fromcache(ObjectSetStrategy)
        for item in w_set.strategy.unerase(w_set.sstorage):
            assert isinstance(item, W_Root)

        w_list = W_ListObject(self.space, [w(1.0), w(2.0), w(3.0)])
        w_set = W_SetObject(self.space)
        _initialize_set(self.space, w_set, w_list)
        assert w_set.strategy is self.space.fromcache(ObjectSetStrategy)
        for item in w_set.strategy.unerase(w_set.sstorage):
            assert isinstance(item, W_FloatObject)

        # changed cached object, need to change it back for other tests to pass
        intstr.get_storage_from_list = tmp_func

    def test_listview_bytes_int_on_set(self):
        w = self.space.wrap
        wb = self.space.newbytes

        w_a = W_SetObject(self.space)
        _initialize_set(self.space, w_a, wb("abcdefg"))
        assert sorted(self.space.listview_int(w_a)) == [97, 98, 99, 100, 101, 102, 103]
        assert self.space.listview_bytes(w_a) is None

        w_b = W_SetObject(self.space)
        _initialize_set(self.space, w_b, self.space.newlist([w(1),w(2),w(3),w(4),w(5)]))
        assert sorted(self.space.listview_int(w_b)) == [1,2,3,4,5]
        assert self.space.listview_bytes(w_b) is None

    def test_cpyext_add_frozen(self, space):
        t1 = W_FrozensetObject(space)
        assert space.len_w(t1) == 0
        res = t1.cpyext_add_frozen(space.newint(1))
        assert res
        assert space.len_w(t1) == 1


class AppTestAppSetTest:

    def setup_class(self):
        w_fakeint = self.space.appexec([], """():
            class FakeInt(object):
                def __init__(self, value):
                    self.value = value
                def __hash__(self):
                    return hash(self.value)

                def __eq__(self, other):
                    if other == self.value:
                        return True
                    return False
            return FakeInt
            """)
        self.w_FakeInt = w_fakeint

    def test_fakeint(self):
        f1 = self.FakeInt(4)
        assert f1 == 4
        assert hash(f1) == hash(4)

    def test_simple(self):
        a = set([1,2,3])
        b = set()
        b.add(4)
        c = a.union(b)
        assert c == set([1,2,3,4])

    def test_generator(self):
        def foo():
            for i in [1,2,3,4,5]:
                yield i
        b = set(foo())
        assert b == set([1,2,3,4,5])

        a = set(x for x in [1,2,3])
        assert a == set([1,2,3])

    def test_generator2(self):
        def foo():
            for i in [1,2,3]:
                yield i
        class A(set):
            pass
        a = A([1,2,3,4,5])
        b = a.difference(foo())
        assert b == set([4,5])

    def test_or(self):
        a = set([0,1,2])
        b = a | set([1,2,3])
        assert b == set([0,1,2,3])

        # test inplace or
        a |= set([1,2,3])
        assert a == b

    def test_clear(self):
        a = set([1,2,3])
        a.clear()
        assert a == set()

    def test_sub(self):
        a = set([1,2,3,4,5])
        b = set([2,3,4])
        a - b == [1,5]
        a.__sub__(b) == [1,5]

        #inplace sub
        a = set([1,2,3,4])
        b = set([1,4])
        a -= b
        assert a == set([2,3])

    def test_issubset(self):
        a = set([1,2,3,4])
        b = set([2,3])
        assert b.issubset(a)
        c = [1,2,3,4]
        assert b.issubset(c)

        a = set([1,2,3,4])
        b = set(['1','2'])
        assert not b.issubset(a)

    def test_issuperset(self):
        a = set([1,2,3,4])
        b = set([2,3])
        assert a.issuperset(b)
        c = [2,3]
        assert a.issuperset(c)

        c = [1,1,1,1,1]
        assert a.issuperset(c)
        assert set([1,1,1,1,1]).issubset(a)

        a = set([1,2,3])
        assert a.issuperset(a)
        assert not a.issuperset(set([1,2,3,4,5]))

    def test_inplace_and(test):
        a = set([1,2,3,4])
        b = set([0,2,3,5,6])
        a &= b
        assert a == set([2,3])

    def test_discard_remove(self):
        a = set([1,2,3,4,5])
        a.remove(1)
        assert a == set([2,3,4,5])
        a.discard(2)
        assert a == set([3,4,5])

        raises(KeyError, "a.remove(6)")

    def test_pop(self):
        b = set()
        raises(KeyError, "b.pop()")

        a = set([1,2,3,4,5])
        for i in range(5):
            a.pop()
        assert a == set()
        raises(KeyError, "a.pop()")

    def test_symmetric_difference(self):
        a = set([1,2,3])
        b = set([3,4,5])
        c = a.symmetric_difference(b)
        assert c == set([1,2,4,5])

        a = set([1,2,3])
        b = [3,4,5]
        c = a.symmetric_difference(b)
        assert c == set([1,2,4,5])

        a = set([1,2,3])
        b = set('abc')
        c = a.symmetric_difference(b)
        assert c == set([1,2,3,'a','b','c'])

    def test_symmetric_difference_update(self):
        a = set([1,2,3])
        b = set([3,4,5])
        a.symmetric_difference_update(b)
        assert a == set([1,2,4,5])

        a = set([1,2,3])
        b = [3,4,5]
        a.symmetric_difference_update(b)
        assert a == set([1,2,4,5])

        a = set([1,2,3])
        b = set([3,4,5])
        a ^= b
        assert a == set([1,2,4,5])

    def test_subtype(self):
        class subset(set):pass
        a = subset()
        b = a | set('abc')
        assert type(b) is set

    def test_init_new_behavior(self):
        s = set.__new__(set, 'abc')
        assert s == set()                # empty
        s.__init__('def')
        assert s == set('def')
        #
        s = frozenset.__new__(frozenset, 'abc')
        assert s == frozenset('abc')     # non-empty
        s.__init__('def')
        assert s == frozenset('abc')     # the __init__ is ignored

    def test_subtype_bug(self):
        class subset(set): pass
        b = subset('abc')
        subset.__new__ = lambda *args: foobar   # not called
        b = b.copy()
        assert type(b) is set
        assert set(b) == set('abc')
        #
        class frozensubset(frozenset): pass
        b = frozensubset('abc')
        frozensubset.__new__ = lambda *args: foobar   # not called
        b = b.copy()
        assert type(b) is frozenset
        assert frozenset(b) == frozenset('abc')

    def test_union(self):
        a = set([4, 5])
        b = a.union([5, 7])
        assert sorted(b) == [4, 5, 7]
        c = a.union([5, 7], [1], set([9,7]), frozenset([2]), frozenset())
        assert sorted(c) == [1, 2, 4, 5, 7, 9]
        d = a.union()
        assert d == a

    def test_bytes_items(self):
        s = set([b'hello'])
        assert s.pop() == b'hello'

    def test_set_literal(self):
        """
        assert {b'a'}.pop() == b'a'
        """

    def test_compare(self):
        assert set('abc') != 'abc'
        raises(TypeError, "set('abc') < 42")
        assert not (set('abc') < set('def'))
        assert not (set('abc') <= frozenset('abd'))
        assert not (set('abc') < frozenset('abd'))
        assert not (set('abc') >= frozenset('abd'))
        assert not (set('abc') > frozenset('abd'))
        assert set('abc') <= frozenset('abc')
        assert set('abc') >= frozenset('abc')
        assert set('abc') <= frozenset('abcd')
        assert set('abc') >= frozenset('ab')
        assert set('abc') < frozenset('abcd')
        assert set('abc') > frozenset('ab')
        assert not (set('abc') < frozenset('abc'))
        assert not (set('abc') > frozenset('abc'))
        assert not set() == 42
        assert set() != 42
        assert (set('abc') == frozenset('abc'))
        assert (set('abc') == set('abc'))
        assert (frozenset('abc') == frozenset('abc'))
        assert (frozenset('abc') == set('abc'))
        assert not (set('abc') != frozenset('abc'))
        assert not (set('abc') != set('abc'))
        assert not (frozenset('abc') != frozenset('abc'))
        assert not (frozenset('abc') != set('abc'))
        assert not (set('abc') == frozenset('abcd'))
        assert not (set('abc') == set('abcd'))
        assert not (frozenset('abc') == frozenset('abcd'))
        assert not (frozenset('abc') == set('abcd'))
        assert (set('abc') != frozenset('abcd'))
        assert (set('abc') != set('abcd'))
        assert (frozenset('abc') != frozenset('abcd'))
        assert (frozenset('abc') != set('abcd'))
        assert set() != set('abc')
        assert set('abc') != set('abd')

    def test_compare_other(self):
        class TestRichSetCompare:
            def __gt__(self, some_set):
                self.gt_called = True
                return False
            def __lt__(self, some_set):
                self.lt_called = True
                return False
            def __ge__(self, some_set):
                self.ge_called = True
                return False
            def __le__(self, some_set):
                self.le_called = True
                return False

        # This first tries the builtin rich set comparison, which doesn't know
        # how to handle the custom object. Upon returning NotImplemented, the
        # corresponding comparison on the right object is invoked.
        myset = set(range(3))

        myobj = TestRichSetCompare()
        myset < myobj
        assert myobj.gt_called

        myobj = TestRichSetCompare()
        myset > myobj
        assert myobj.lt_called

        myobj = TestRichSetCompare()
        myset <= myobj
        assert myobj.ge_called

        myobj = TestRichSetCompare()
        myset >= myobj
        assert myobj.le_called

    def test_libpython_equality(self):
        for thetype in [frozenset, set]:
            word = "aaaaaaaaawfpasrtarspawparst"
            otherword = "ZZZZZZZXCVZXCVSRTD"
            s = thetype(word)
            assert s == set(word)
            assert s, frozenset(word)
            assert not s == word
            assert s != set(otherword)
            assert s != frozenset(otherword)
            assert s != word

    def test_copy(self):
        s1 = set('abc')
        s2 = s1.copy()
        assert s1 is not s2
        assert s1 == s2
        assert type(s2) is set
        s1 = frozenset('abc')
        s2 = s1.copy()
        assert s1 is s2
        assert s1 == s2
        class myfrozen(frozenset):
            pass
        s1 = myfrozen('abc')
        s2 = s1.copy()
        assert s1 is not s2
        assert s1 == s2
        assert type(s2) is frozenset

    def test_update(self):
        s1 = set('abc')
        s1.update(set('abcd'))
        assert s1 == set('abcd')
        s1 = set('abc')
        s1.update(frozenset('fro'))
        assert s1 == set('abcfro')
        s1 = set('abc')
        s1.update('def')
        assert s1 == set('abcdef')
        s1 = set('abc')
        s1.update()
        assert s1 == set('abc')
        s1 = set('abc')
        s1.update('d', 'ef', frozenset('g'))
        assert s1 == set('abcdefg')
        s1 = set()
        s1.update(set('abcd'))
        assert s1 == set('abcd')
        s1 = set([1, 2.0, "3"])
        s1.update(set(["3", 4, 5.0]))

    def test_update_not_iterable_error(self):
        with raises(TypeError) as e:
            set().update(1)
        assert "'int' object is not iterable" in str(e.value)

    def test_recursive_repr(self):
        class A(object):
            def __init__(self, s):
                self.s = s
            def __repr__(self):
                return repr(self.s)

        s = set([1, 2, 3])
        s.add(A(s))
        therepr = repr(s)
        assert therepr.startswith("{")
        assert therepr.endswith("}")
        inner = set(therepr[1:-1].split(", "))
        assert inner == set(["1", "2", "3", "set(...)"])

    def test_recursive_repr_frozenset(self):
        class A(object):
            def __repr__(self):
                return repr(self.s)
        a = A()
        s = frozenset([1, 2, 3, a])
        a.s = s
        therepr = repr(s)
        assert therepr.startswith("frozenset({")
        assert therepr.endswith("})")
        inner = set(therepr[11:-2].split(", "))
        assert inner == set(["1", "2", "3", "frozenset(...)"])

    def test_keyerror_has_key(self):
        s = set()
        try:
            s.remove(1)
        except KeyError as e:
            assert e.args[0] == 1
        else:
            assert 0, "should raise"

    def test_subclass_with_hash(self):
        # Bug #1257731
        class H(set):
            def __hash__(self):
                return int(id(self) & 0x7fffffff)
        s = H()
        f = set([s])
        print(f)
        assert s in f
        f.remove(s)
        f.add(s)
        f.discard(s)

    def test_autoconvert_to_frozen__contains(self):
        s = set([frozenset([1,2])])

        assert set([1,2]) in s

    def test_autoconvert_to_frozen_remove(self):
        s = set([frozenset([1,2])])

        s.remove(set([1,2]))
        assert len(s) == 0
        raises(KeyError, s.remove, set([1,2]))

    def test_autoconvert_to_frozen_discard(self):
        s = set([frozenset([1,2])])

        s.discard(set([1,2]))
        assert len(s) == 0
        s.discard(set([1,2]))

    def test_autoconvert_to_frozen_onlyon_type_error(self):
        class A(set):
            def __hash__(self):
                return id(self)

        s = A([1, 2, 3])
        s2 = set([2, 3, s])
        assert A() not in s2
        s2.add(frozenset())
        assert A() not in s2
        raises(KeyError, s2.remove, A())

    def test_autoconvert_key_error(self):
        s = set([frozenset([1, 2]), frozenset([3, 4])])
        key = set([2, 3])
        try:
            s.remove(key)
        except KeyError as e:
            assert e.args[0] is key

    def test_contains(self):
        letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        word = 'teleledningsanka'
        s = set(word)
        for c in letters:
            assert (c in s) == (c in word)
        raises(TypeError, s.__contains__, [])

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
        foo_set = {foo1, foo2, foo3}
        del logger[:]
        foo42 in foo_set
        logger_copy = set(logger[:])  # prevent re-evaluation during pytest error print
        assert logger_copy == {(foo3, foo42), (foo2, foo42), (foo1, foo42)}

        del logger[:]
        foo2_bis = Foo(2, '2 bis')
        foo2_bis in foo_set
        logger_copy = set(logger[:])  # prevent re-evaluation during pytest error print
        assert (foo2, foo2_bis) in logger_copy
        assert logger_copy.issubset({(foo1, foo2_bis), (foo2, foo2_bis), (foo3, foo2_bis)})

    def test_remove(self):
        s = set('abc')
        s.remove('a')
        assert 'a' not in s
        raises(KeyError, s.remove, 'a')
        raises(TypeError, s.remove, [])
        s.add(frozenset('def'))
        assert set('def') in s
        s.remove(set('def'))
        assert set('def') not in s
        raises(KeyError, s.remove, set('def'))

    def test_remove_keyerror_unpacking(self):
        # bug:  www.python.org/sf/1576657
        s = set()
        for v1 in ['Q', (1,)]:
            try:
                s.remove(v1)
            except KeyError as e:
                v2 = e.args[0]
                assert v1 == v2
            else:
                assert False, 'Expected KeyError'

    def test_singleton_empty_frozenset(self):
        class Frozenset(frozenset):
            pass
        f = frozenset()
        F = Frozenset()
        efs = [f, Frozenset(f)]
        # All empty frozenset subclass instances should have different ids
        assert len(set(map(id, efs))) == len(efs)

    def test_subclass_union(self):
        for base in [set, frozenset]:
            class subset(base):
                def __init__(self, *args):
                    self.x = args
            s = subset([2])
            assert s.x == ([2],)
            t = s | base([5])
            assert type(t) is base, 'base is %s, type(t) is %s' % (base, type(t))
            assert not hasattr(t, 'x')

    def test_reverse_ops(self):
        assert set.__rxor__
        assert frozenset.__rxor__
        assert set.__ror__
        assert frozenset.__ror__
        assert set.__rand__
        assert frozenset.__rand__
        assert set.__rsub__
        assert frozenset.__rsub__

        # actual behaviour test
        for base in [set, frozenset]:
            class S(base):
                def __xor__(self, other):
                    if type(other) is not S:
                        return NotImplemented
                    return 1
                __or__ = __and__ = __sub__ = __xor__
            assert S([1, 2, 3]) ^ S([2, 3, 4]) == 1
            assert S([1, 2, 3]) ^ {2, 3, 4} == {1, 4}
            assert {1, 2, 3} ^ S([2, 3, 4]) == {1, 4}

            assert S([1, 2, 3]) & S([2, 3, 4]) == 1
            assert S([1, 2, 3]) & {2, 3, 4} == {2, 3}
            assert {1, 2, 3} & S([2, 3, 4]) == {2, 3}

            assert S([1, 2, 3]) | S([2, 3, 4]) == 1
            assert S([1, 2, 3]) | {2, 3, 4} == {1, 2, 3, 4}
            assert {1, 2, 3} | S([2, 3, 4]) == {1, 2, 3, 4}

            assert S([1, 2, 3]) - S([2, 3, 4]) == 1
            assert S([1, 2, 3]) - {2, 3, 4} == {1}
            assert {1, 2, 3} - S([2, 3, 4]) == {1}

    def test_isdisjoint(self):
        assert set([1,2,3]).isdisjoint(set([4,5,6]))
        assert set([1,2,3]).isdisjoint(frozenset([4,5,6]))
        assert set([1,2,3]).isdisjoint([4,5,6])
        assert set([1,2,3]).isdisjoint((4,5,6))
        assert not set([1,2,5]).isdisjoint(set([4,5,6]))
        assert not set([1,2,5]).isdisjoint(frozenset([4,5,6]))
        assert not set([1,2,5]).isdisjoint([4,5,6])
        assert not set([1,2,5]).isdisjoint((4,5,6))
        assert set([1,2,3]).isdisjoint(set([3.5,4.0]))

    def test_intersection(self):
        assert set([1,2,3]).intersection(set([2,3,4])) == set([2,3])
        assert set([1,2,3]).intersection(frozenset([2,3,4])) == set([2,3])
        assert set([1,2,3]).intersection([2,3,4]) == set([2,3])
        assert set([1,2,3]).intersection((2,3,4)) == set([2,3])
        assert frozenset([1,2,3]).intersection(set([2,3,4])) == frozenset([2,3])
        assert frozenset([1,2,3]).intersection(frozenset([2,3,4]))== frozenset([2,3])
        assert frozenset([1,2,3]).intersection([2,3,4]) == frozenset([2,3])
        assert frozenset([1,2,3]).intersection((2,3,4)) == frozenset([2,3])
        assert set([1,2,3,4]).intersection([2,3,4,5], set((1,2,3))) == set([2,3])
        assert frozenset([1,2,3,4]).intersection((2,3,4,5), [1,2,3]) == \
                   frozenset([2,3])
        s = set([1,2,3])
        assert s.intersection() == s
        assert s.intersection() is not s

    def test_intersection_swap(self):
        s1 = s3 = set([1,2,3,4,5])
        s2 = set([2,3,6,7])
        s1 &= s2
        assert s1 == set([2,3])
        assert s3 == set([2,3])

    def test_intersection_generator(self):
        def foo():
            for i in range(5):
                yield i

        s1 = s2 = set([1,2,3,4,5,6])
        assert s1.intersection(foo()) == set([1,2,3,4])
        s1.intersection_update(foo())
        assert s1 == set([1,2,3,4])
        assert s2 == set([1,2,3,4])

    def test_intersection_string(self):
        s = set([1,2,3])
        o = 'abc'
        assert s.intersection(o) == set()

    def test_intersection_float(self):
        a = set([1,2,3])
        b = set([3.0,4.0,5.0])
        c = a.intersection(b)
        assert c == set([3.0])

    def test_difference(self):
        assert set([1,2,3]).difference(set([2,3,4])) == set([1])
        assert set([1,2,3]).difference(frozenset([2,3,4])) == set([1])
        assert set([1,2,3]).difference([2,3,4]) == set([1])
        assert set([1,2,3]).difference((2,3,4)) == set([1])
        assert frozenset([1,2,3]).difference(set([2,3,4])) == frozenset([1])
        assert frozenset([1,2,3]).difference(frozenset([2,3,4]))== frozenset([1])
        assert frozenset([1,2,3]).difference([2,3,4]) == frozenset([1])
        assert frozenset([1,2,3]).difference((2,3,4)) == frozenset([1])
        assert set([1,2,3,4]).difference([4,5], set((0,1))) == set([2,3])
        assert frozenset([1,2,3,4]).difference((4,5), [0,1]) == frozenset([2,3])
        s = set([1,2,3])
        assert s.difference() == s
        assert s.difference() is not s
        assert set([1,2,3]).difference(set([2,3,4,'5'])) == set([1])
        assert set([1,2,3,'5']).difference(set([2,3,4])) == set([1,'5'])
        assert set().difference(set([1,2,3])) == set()

    def test_difference_bug(self):
        a = set([1,2,3])
        b = set([])
        c = a - b
        c.remove(2)
        assert c == set([1, 3])
        assert a == set([1, 2, 3])

        a = set([1,2,3])
        b = set(["a", "b", "c"])
        c = a - b
        c.remove(2)
        assert c == set([1, 3])
        assert a == set([1, 2, 3])

    def test_intersection_update(self):
        s = set([1,2,3,4,7])
        s.intersection_update([0,1,2,3,4,5,6])
        assert s == set([1,2,3,4])
        s.intersection_update((2,3,4,5), frozenset([0,1,2,3]))
        assert s == set([2,3])
        s.intersection_update()
        assert s == set([2,3])

    def test_difference_update(self):
        s = set([1,2,3,4,7])
        s.difference_update([0,7,8,9])
        assert s == set([1,2,3,4])
        s.difference_update((0,1), frozenset([4,5,6]))
        assert s == set([2,3])
        s.difference_update()
        assert s == set([2,3])
        s.difference_update(s)
        assert s == set([])

    def test_empty_empty(self):
        assert set() == set([])

    def test_empty_difference(self):
        e = set()
        x = set([1,2,3])
        assert e.difference(x) == set()
        assert x.difference(e) == x

        e.difference_update(x)
        assert e == set()
        x.difference_update(e)
        assert x == set([1,2,3])

        assert e.symmetric_difference(x) == x
        assert x.symmetric_difference(e) == x

        e.symmetric_difference_update(e)
        assert e == e
        e.symmetric_difference_update(x)
        assert e == x

        x.symmetric_difference_update(set())
        assert x == set([1,2,3])

    def test_fastpath_with_strategies(self):
        a = set([1,2,3])
        b = set(["a","b","c"])
        assert a.difference(b) == a
        assert b.difference(a) == b

        a = set([1,2,3])
        b = set(["a","b","c"])
        assert a.intersection(b) == set()
        assert b.intersection(a) == set()

        a = set([1,2,3])
        b = set(["a","b","c"])
        assert not a.issubset(b)
        assert not b.issubset(a)

        a = set([1,2,3])
        b = set(["a","b","c"])
        assert a.isdisjoint(b)
        assert b.isdisjoint(a)

    def test_empty_intersect(self):
        e = set()
        x = set([1,2,3])
        assert e.intersection(x) == e
        assert x.intersection(e) == e
        assert e & x == e
        assert x & e == e

        e.intersection_update(x)
        assert e == set()
        e &= x
        assert e == set()
        x.intersection_update(e)
        assert x == set()

    def test_empty_issuper(self):
        e = set()
        x = set([1,2,3])
        assert e.issuperset(e) == True
        assert e.issuperset(x) == False
        assert x.issuperset(e) == True

        assert e.issuperset(set())
        assert e.issuperset([])

    def test_empty_issubset(self):
        e = set()
        x = set([1,2,3])
        assert e.issubset(e) == True
        assert e.issubset(x) == True
        assert x.issubset(e) == False
        assert e.issubset([])

    def test_empty_isdisjoint(self):
        e = set()
        x = set([1,2,3])
        assert e.isdisjoint(e) == True
        assert e.isdisjoint(x) == True
        assert x.isdisjoint(e) == True

    def test_empty_unhashable(self):
        s = set()
        raises(TypeError, s.difference, [[]])
        raises(TypeError, s.difference_update, [[]])
        raises(TypeError, s.intersection, [[]])
        raises(TypeError, s.intersection_update, [[]])
        raises(TypeError, s.symmetric_difference, [[]])
        raises(TypeError, s.symmetric_difference_update, [[]])
        raises(TypeError, s.update, [[]])

    def test_super_with_generator(self):
        def foo():
            for i in [1,2,3]:
                yield i
        set([1,2,3,4,5]).issuperset(foo())

    def test_isdisjoint_with_generator(self):
        def foo():
            for i in [1,2,3]:
                yield i
        set([1,2,3,4,5]).isdisjoint(foo())

    def test_fakeint_and_equals(self):
        s1 = set([1,2,3,4])
        s2 = set([1,2,self.FakeInt(3), 4])
        assert s1 == s2

    def test_fakeint_and_discard(self):
        # test with object strategy
        s = set([1, 2, 'three', 'four'])
        s.discard(self.FakeInt(2))
        assert s == set([1, 'three', 'four'])

        s.remove(self.FakeInt(1))
        assert s == set(['three', 'four'])
        raises(KeyError, s.remove, self.FakeInt(16))

        # test with int strategy
        s = set([1,2,3,4])
        s.discard(self.FakeInt(4))
        assert s == set([1,2,3])
        s.remove(self.FakeInt(3))
        assert s == set([1,2])
        raises(KeyError, s.remove, self.FakeInt(16))

    def test_fakeobject_and_has_key(self):
        s = set([1,2,3,4,5])
        assert 5 in s
        assert self.FakeInt(5) in s

    def test_fakeobject_and_pop(self):
        s = set([1,2,3,self.FakeInt(4),5])
        assert s.pop()
        assert s.pop()
        assert s.pop()
        assert s.pop()
        assert s.pop()
        assert s == set([])

    def test_fakeobject_and_difference(self):
        s = set([1,2,'3',4])
        s.difference_update([self.FakeInt(1), self.FakeInt(2)])
        assert s == set(['3',4])

        s = set([1,2,3,4])
        s.difference_update([self.FakeInt(1), self.FakeInt(2)])
        assert s == set([3,4])

    def test_frozenset_behavior(self):
        s = set([1,2,3,frozenset([4])])
        raises(TypeError, s.difference_update, [1,2,3,set([4])])

        s = set([1,2,3,frozenset([4])])
        s.discard(set([4]))
        assert s == set([1,2,3])

    def test_discard_unhashable(self):
        s = set([1,2,3,4])
        raises(TypeError, s.discard, [1])

    def test_discard_evil_compare(self):
        class Evil(object):
            def __init__(self, value):
                self.value = value
            def __hash__(self):
                return hash(self.value)
            def __eq__(self, other):
                if isinstance(other, frozenset):
                    raise TypeError
                if other == self.value:
                    return True
                return False
        s = set([1,2, Evil(frozenset([1]))])
        raises(TypeError, s.discard, set([1]))

    def test_create_set_from_set(self):
        # no sharing
        x = set([1,2,3])
        y = set(x)
        a = x.pop()
        assert y == set([1,2,3])
        assert len(x) == 2
        assert x.union(set([a])) == y

    def test_never_change_frozenset(self):
        a = frozenset([1,2])
        b = a.copy()
        assert a is b

        a = frozenset([1,2])
        b = a.union(set([3,4]))
        assert b == set([1,2,3,4])
        assert a == set([1,2])

        a = frozenset()
        b = a.union(set([3,4]))
        assert b == set([3,4])
        assert a == set()

        a = frozenset([1,2])#multiple
        b = a.union(set([3,4]),[5,6])
        assert b == set([1,2,3,4,5,6])
        assert a == set([1,2])

        a = frozenset([1,2,3])
        b = a.difference(set([3,4,5]))
        assert b == set([1,2])
        assert a == set([1,2,3])

        a = frozenset([1,2,3])#multiple
        b = a.difference(set([3]), [2])
        assert b == set([1])
        assert a == set([1,2,3])

        a = frozenset([1,2,3])
        b = a.symmetric_difference(set([3,4,5]))
        assert b == set([1,2,4,5])
        assert a == set([1,2,3])

        a = frozenset([1,2,3])
        b = a.intersection(set([3,4,5]))
        assert b == set([3])
        assert a == set([1,2,3])

        a = frozenset([1,2,3])#multiple
        b = a.intersection(set([2,3,4]), [2])
        assert b == set([2])
        assert a == set([1,2,3])

        raises(AttributeError, "frozenset().update()")
        raises(AttributeError, "frozenset().difference_update()")
        raises(AttributeError, "frozenset().symmetric_difference_update()")
        raises(AttributeError, "frozenset().intersection_update()")

    def test_intersection_obj(self):
        class Obj:
            def __getitem__(self, i):
                return [5, 3, 4][i]
        s = set([10,3,2]).intersection(Obj())
        assert list(s) == [3]

    def test_iter_set_length_change(self):
        s = set([1, 3, 5])
        it = iter(s)
        s.add(7)
        # 's' is now length 4
        raises(RuntimeError, it.__next__)

    def test_iter_set_strategy_only_change_1(self):
        s = set([1, 3, 5])
        it = iter(s)
        class Foo(object):
            def __eq__(self, other):
                return False
            def __hash__(self):
                return 0
        assert Foo() not in s      # this changes the strategy of 'd'
        lst = list(s)  # but iterating still works
        assert sorted(lst) == [1, 3, 5]

    def test_iter_set_strategy_only_change_2(self):
        # on py3k the IntStrategy doesn't work yet. So, we use the
        # StringSetStrategy for this test
        s = set(['1', '3', '5'])
        it = iter(s)
        s.add(42) # change the strategy
        s.remove('1')
        # 's' is still length 3, but its strategy changed.  we are
        # getting a RuntimeError because iterating over the old storage
        # gives us 1, but 1 is not in the set any longer.
        raises(RuntimeError, list, it)

    def test_iter_bytes_strategy(self):
        l = [b'a', b'b']
        s = set(l)
        n = next(iter(s))
        assert type(n) is bytes
        assert n in l

    def test_unicodestrategy(self):
        s = 'àèìòù'
        myset = set([s])
        s2 = myset.pop()
        assert s2 == s

    def test_preserve_identity_of_strings(self):
        s = 'hello'
        myset = set([s])
        s2 = myset.pop()
        assert s2 == s
        assert s2 is s

    def test_intersect_frozenset_set(self):
        # worked before
        assert type(frozenset([2]) & set([1, 2])) is frozenset
        # did not work before because of an optimization that swaps both
        # operands when the first set is larger than the second
        assert type(frozenset([1, 2]) & set([2])) is frozenset

    def test_update_bug_strategy(self):
        from __pypy__ import strategy
        s = set([1, 2, 3])
        assert strategy(s) == "IntegerSetStrategy"
        s.update(set())
        assert strategy(s) == "IntegerSetStrategy"
        #
        s = set([1, 2, 3])
        s |= set()
        assert strategy(s) == "IntegerSetStrategy"
        #
        s = set([1, 2, 3]).difference(set())
        assert strategy(s) == "IntegerSetStrategy"
        #
        s = set([1, 2, 3])
        s.difference_update(set())
        assert strategy(s) == "IntegerSetStrategy"
        #
        s = set([1, 2, 3]).symmetric_difference(set())
        assert strategy(s) == "IntegerSetStrategy"
        #
        s = set([1, 2, 3])
        s.symmetric_difference_update(set())
        assert strategy(s) == "IntegerSetStrategy"
        #
        s = set([1, 2, 3]).intersection(set())
        assert strategy(s) == "EmptySetStrategy"
        #
        s = set([1, 2, 3])
        s.intersection_update(set())
        assert strategy(s) == "EmptySetStrategy"

    def test_weird_exception_from_iterable(self):
        def f():
           raise ValueError
           yield 1
        raises(ValueError, set, f())

    def test_pickle(self):
        d = {1, 2, 3}
        it = iter(d)
        first = next(it)
        reduced = it.__reduce__()
        rebuild, args = reduced
        assert rebuild is iter
        new = rebuild(*args)
        items = set(new)
        assert len(items) == 2
        items.add(first)
        assert items == set(d)

    def test_unicode_bug_in_listview_utf8(self):
        l1 = set(u'\u1234\u2345')
        assert l1 == set([u'\u1234', '\u2345'])

    def test_frozenset_init_does_nothing(self):
        f = frozenset([1, 2, 3])
        f.__init__(4, 5, 6)
        assert f == frozenset([1, 2, 3])

    def test_error_message_wrong_self(self):
        e = raises(TypeError, frozenset.copy, 42)
        assert "frozenset" in str(e.value)
        if hasattr(frozenset.copy, 'im_func'):
            e = raises(TypeError, frozenset.copy.im_func, 42)
            assert "'frozenset' object expected, got 'int' instead" in str(e.value)
        if hasattr(set.copy, 'im_func'):
            e = raises(TypeError, set.copy.im_func, 42)
            assert "'set' object expected, got 'int' instead" in str(e.value)

    def test_cant_mutate_frozenset_via_set(self):
        x = frozenset()
        raises(TypeError, set.add, x, 1)
        raises(TypeError, set.__ior__, x, set([2]))

    def test_class_getitem(self):
        for cls in set, frozenset:
            assert set[int, str].__origin__ is set
            assert set[int, str].__args__ == (int, str)

    def test_frozenset_hash_like_cpython(self):
        import sys
        if sys.maxsize != 2**63 - 1:
            skip("64 bit only")
        assert hash(frozenset()) == 133146708735736
        h = hash(frozenset([1, 2, 9]))
        assert h == (-5390384031640186368)
