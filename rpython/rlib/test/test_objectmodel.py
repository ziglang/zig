from collections import OrderedDict
import py
from rpython.rlib.objectmodel import (
    r_dict, UnboxedValue, Symbolic, compute_hash, compute_identity_hash,
    compute_unique_id, current_object_addr_as_int, we_are_translated,
    prepare_dict_update, reversed_dict, specialize, enforceargs, newlist_hint,
    resizelist_hint, is_annotation_constant, always_inline, NOT_CONSTANT,
    iterkeys_with_hash, iteritems_with_hash, contains_with_hash,
    setitem_with_hash, getitem_with_hash, delitem_with_hash, import_from_mixin,
    fetch_translated_config, try_inline, delitem_if_value_is, move_to_end,
    never_allocate, dont_inline, list_get_physical_size)
from rpython.translator.translator import TranslationContext, graphof
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.test.test_llinterp import interpret
from rpython.conftest import option

def strange_key_eq(key1, key2):
    return key1[0] == key2[0]   # only the 1st character is relevant
def strange_key_hash(key):
    return ord(key[0])

def play_with_r_dict(d):
    d['hello'] = 41
    d['hello'] = 42
    assert d['hi there'] == 42
    try:
        unexpected = d["dumb"]
    except KeyError:
        pass
    else:
        assert False, "should have raised, got %s" % unexpected
    assert len(d) == 1
    assert 'oops' not in d

    count = 0
    for x in d:
        assert x == 'hello'
        count += 1
    assert count == 1

    assert d.get('hola', -1) == 42
    assert d.get('salut', -1) == -1
    d1 = d.copy()
    del d['hu!']
    assert len(d) == 0
    assert d1.keys() == ['hello']
    d.update(d1)
    assert d.values() == [42]
    lst = d.items()
    assert len(lst) == 1 and len(lst[0]) == 2
    assert lst[0][0] == 'hello' and lst[0][1] == 42

    count = 0
    for x in d.iterkeys():
        assert x == 'hello'
        count += 1
    assert count == 1

    count = 0
    for x in d.itervalues():
        assert x == 42
        count += 1
    assert count == 1

    count = 0
    for x in d.iteritems():
        assert len(x) == 2 and x[0] == 'hello' and x[1] == 42
        count += 1
    assert count == 1

    d.clear()
    assert d.keys() == []
    return True   # for the tests below


def test_recursive_r_dict_repr():
    import operator
    rdic = r_dict(operator.eq, hash)
    rdic['x'] = rdic
    assert str(rdic) == "r_dict({'x': r_dict({...})})"
    assert repr(rdic) == "r_dict({'x': r_dict({...})})"

def func_r_dict():
    # NB. this test function is also annotated/rtyped by the next tests
    d = r_dict(strange_key_eq, strange_key_hash)
    return play_with_r_dict(d)

class Strange:
    def key_eq(strange, key1, key2):
        return key1[0] == key2[0]   # only the 1st character is relevant

    def key_hash(strange, key):
        return ord(key[0])

def func_r_dict_bm():
    # NB. this test function is also annotated by the next tests
    strange = Strange()
    d = r_dict(strange.key_eq, strange.key_hash)
    return play_with_r_dict(d)

def test_annotate_r_dict():
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(func_r_dict, [])
    #t.view()
    graph = graphof(t, strange_key_eq)
    assert a.binding(graph.getargs()[0]).knowntype == str
    assert a.binding(graph.getargs()[1]).knowntype == str
    graph = graphof(t, strange_key_hash)
    assert a.binding(graph.getargs()[0]).knowntype == str

def test_annotate_r_dict_bm():
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(func_r_dict_bm, [])
    #t.view()
    strange_key_eq = Strange.key_eq.im_func
    strange_key_hash = Strange.key_hash.im_func

    Strange_def = a.bookkeeper.getuniqueclassdef(Strange)

    graph = graphof(t, strange_key_eq)
    assert a.binding(graph.getargs()[0]).classdef == Strange_def
    assert a.binding(graph.getargs()[1]).knowntype == str
    assert a.binding(graph.getargs()[2]).knowntype == str
    graph = graphof(t, strange_key_hash)
    assert a.binding(graph.getargs()[0]).classdef == Strange_def
    assert a.binding(graph.getargs()[1]).knowntype == str


def test_unboxed_value():
    class Base(object):
        __slots__ = ()

    class C(Base, UnboxedValue):
        __slots__ = 'smallint'

    assert C(17).smallint == 17
    assert C(17).get_untagged_value() == 17

    class A(UnboxedValue):
        __slots__ = ['value']

    assert A(12098).value == 12098
    assert A(12098).get_untagged_value() == 12098

def test_symbolic():
    py.test.skip("xxx no test here")

def test_symbolic_raises():
    s1 = Symbolic()
    s2 = Symbolic()
    py.test.raises(TypeError, "s1 < s2")
    py.test.raises(TypeError, "hash(s1)")

def test_compute_hash():
    from rpython.rlib.objectmodel import _hash_string, _hash_float, _hash_tuple
    assert compute_hash("Hello") == _hash_string("Hello")
    assert compute_hash(7) == 7
    assert compute_hash(-3.5) == _hash_float(-3.5)
    assert compute_hash(None) == 0
    assert compute_hash(("world", None, 7)) == _hash_tuple(("world", None, 7))
    #
    class Foo(object):
        def __hash__(self):
            return 42
    foo = Foo()
    h = compute_hash(foo)
    assert h == object.__hash__(foo)
    assert compute_hash(None) == 0

def test_compute_hash_float():
    from rpython.rlib.rfloat import INFINITY, NAN
    assert compute_hash(INFINITY) == 314159
    assert compute_hash(-INFINITY) == -271828
    assert compute_hash(NAN) == 0

def test_compute_identity_hash():
    class Foo(object):
        def __hash__(self):
            return 42
    foo = Foo()
    h = compute_identity_hash(foo)
    assert h == object.__hash__(foo)

def test_compute_unique_id():
    from rpython.rlib.rarithmetic import intmask
    class Foo(object):
        pass
    foo = Foo()
    x = compute_unique_id(foo)
    assert type(x) is int
    assert x == intmask(id(foo))

def test_current_object_addr_as_int():
    from rpython.rlib.rarithmetic import intmask
    class Foo(object):
        pass
    foo = Foo()
    assert current_object_addr_as_int(foo) == intmask(id(foo))

class TestObjectModel(BaseRtypingTest):

    def test_we_are_translated(self):
        assert we_are_translated() is False

        def fn():
            return we_are_translated()
        res = self.interpret(fn, [])
        assert res is True

    def test_rtype_r_dict(self):
        res = self.interpret(func_r_dict, [])
        assert res is True

    def test_rtype_r_dict_bm(self):
        res = self.interpret(func_r_dict_bm, [])
        assert res is True

    def test_rtype_constant_r_dicts(self):
        d1 = r_dict(strange_key_eq, strange_key_hash)
        d1['hello'] = 666
        d2 = r_dict(strange_key_eq, strange_key_hash)
        d2['hello'] = 777
        d2['world'] = 888
        def fn(i):
            if i == 1:
                d = d1
            else:
                d = d2
            return len(d)
        res = self.interpret(fn, [1])
        assert res == 1
        res = self.interpret(fn, [2])
        assert res == 2

    def test_rtype_r_dict_singlefrozen_func(self):
        class FreezingClass(Strange):
            def _freeze_(self):
                return True
        obj = FreezingClass()
        def fn():
            d = r_dict(obj.key_eq, obj.key_hash)
            return play_with_r_dict(d)
        assert self.interpret(fn, []) is True

    def test_rtype_r_dict_singlefrozen_func_pbc(self):
        class FreezingClass(Strange):
            def _freeze_(self):
                return True
        obj = FreezingClass()
        pbc_d = r_dict(obj.key_eq, obj.key_hash)
        def fn():
            return play_with_r_dict(pbc_d)
        assert self.interpret(fn, []) is True

    def test_rtype_r_dict_exceptions(self):
        def raising_hash(obj):
            if obj.startswith("bla"):
                raise TypeError
            return 1
        def eq(obj1, obj2):
            return obj1 is obj2
        def f():
            d1 = r_dict(eq, raising_hash)
            d1['xxx'] = 1
            try:
                x = d1["blabla"]
            except Exception:
                return 42
            return x
        res = self.interpret(f, [])
        assert res == 42

        def f():
            d1 = r_dict(eq, raising_hash)
            d1['xxx'] = 1
            try:
                x = d1["blabla"]
            except TypeError:
                return 42
            return x
        res = self.interpret(f, [])
        assert res == 42

        def f():
            d1 = r_dict(eq, raising_hash)
            d1['xxx'] = 1
            try:
                d1["blabla"] = 2
            except TypeError:
                return 42
            return 0
        res = self.interpret(f, [])
        assert res == 42

    def test_access_in_try(self):
        h = lambda x: 1
        eq = lambda x, y: x == y

        def f(d):
            try:
                return d[2]
            except ZeroDivisionError:
                return 42
            return -1

        def g(n):
            d = r_dict(eq, h)
            d[1] = n
            d[2] = 2 * n
            return f(d)

        res = self.interpret(g, [3])
        assert res == 6

    def test_access_in_try_set(self):
        h = lambda x: 1
        eq = lambda x, y: x == y
        def f(d):
            try:
                d[2] = 77
            except ZeroDivisionError:
                return 42
            return -1
        def g(n):
            d = r_dict(eq, h)
            d[1] = n
            f(d)
            return d[2]
        res = self.interpret(g, [3])
        assert res == 77

    def test_r_dict_fast_functions(self):
        def fn():
            d1 = r_dict(strange_key_eq, strange_key_hash, simple_hash_eq=True)
            return play_with_r_dict(d1)
        res = self.interpret(fn, [])
        assert res

    def test_prepare_dict_update(self):
        def g(n):
            d = {}
            prepare_dict_update(d, n)
            return 42
        res = self.interpret(g, [3])
        assert res == 42     # "did not crash"

    def test_prepare_dict_update_2(self):
        def g(n):
            d = OrderedDict()
            prepare_dict_update(d, n)
            return 42
        res = self.interpret(g, [3])
        assert res == 42     # "did not crash"

    def test_reversed_dict(self):
        d1 = {2: 3, 4: 5, 6: 7}
        def g():
            n1 = 0
            for key in d1:
                n1 = n1 * 10 + key
            n2 = 0
            for key in reversed_dict(d1):
                n2 = n2 * 10 + key
            return n1 * 10000 + n2
        got = str(g())
        assert len(got) == 7 and got[3] == '0' and got[:3] == got[6:3:-1]
        got = str(self.interpret(g, []))
        assert len(got) == 7 and got[3] == '0' and got[:3] == got[6:3:-1]

    def test_compute_hash(self):
        class Foo(object):
            pass
        def f(i):
            assert compute_hash(i) == compute_hash(42)
            assert compute_hash(i + 1.0) == compute_hash(43.0)
            assert compute_hash("Hello" + str(i)) == compute_hash("Hello42")
            if i == 42:
                p = None
            else:
                p = Foo()
            assert compute_hash(p) == compute_hash(None)
            assert (compute_hash(("world", None, i, 7.5)) ==
                    compute_hash(("world", None, 42, 7.5)))
            q = Foo()
            assert compute_hash(q) == compute_identity_hash(q)
            from rpython.rlib.rfloat import INFINITY, NAN
            assert compute_hash(INFINITY) == 314159
            assert compute_hash(-INFINITY) == -271828
            assert compute_hash(NAN) == 0
            return i * 2
        res = self.interpret(f, [42])
        assert res == 84

    def test_isconstant(self):
        @specialize.arg_or_var(0)
        def f(arg):
            if is_annotation_constant(arg):
                return 1
            return 10

        def fn(arg):
            return f(arg) + f(3)

        assert self.interpret(fn, [15]) == 11

    def test_rtype_keepalive(self):
        from rpython.rlib import objectmodel
        def f():
            x = [1]
            y = ['b']
            objectmodel.keepalive_until_here(x, y)
            return 1

        res = self.interpret(f, [])
        assert res == 1

    def test_fetch_translated_config(self):
        assert fetch_translated_config() is None
        def f():
            return fetch_translated_config().translation.continuation
        res = self.interpret(f, [])
        assert res is False


def test_specialize_decorator():
    def f():
        pass

    specialize.memo()(f)

    assert f._annspecialcase_ == 'specialize:memo'

    specialize.arg(0)(f)

    assert f._annspecialcase_ == 'specialize:arg(0)'

    specialize.arg(1)(f)

    assert f._annspecialcase_ == 'specialize:arg(1)'

def test_enforceargs_decorator():
    @enforceargs(int, str, None)
    def f(a, b, c):
        return a, b, c
    f.foo = 'foo'
    assert f._annenforceargs_ == (int, str, None)
    assert f.__name__ == 'f'
    assert f.foo == 'foo'
    assert f(1, 'hello', 42) == (1, 'hello', 42)
    exc = py.test.raises(TypeError, "f(1, 2, 3)")
    assert exc.value.message == "f argument 'b' must be of type <type 'str'>"
    py.test.raises(TypeError, "f('hello', 'world', 3)")

def test_always_inline():
    @always_inline
    def f(a, b, c):
        return a, b, c
    assert f._always_inline_ is True

def test_try_inline():
    @try_inline
    def f(a, b, c):
        return a, b, c
    assert f._always_inline_ == "try"


def test_enforceargs_defaults():
    @enforceargs(int, int)
    def f(a, b=40):
        return a + b
    assert f(2) == 42

def test_enforceargs_keywords():
    @enforceargs(b=int)
    def f(a, b, c):
        return a + b
    assert f._annenforceargs_ == (None, int, None)

def test_enforceargs_int_float_promotion():
    @enforceargs(float)
    def f(x):
        return x
    # in RPython there is an implicit int->float promotion
    assert f(42) == 42

def test_enforceargs_complex_types():
    @enforceargs([int], {str: int})
    def f(a, b):
        return a, b
    x = [0, 1, 2]
    y = {'a': 1, 'b': 2}
    assert f(x, y) == (x, y)
    assert f([], {}) == ([], {})
    assert f(None, None) == (None, None)
    py.test.raises(TypeError, "f(['hello'], y)")
    py.test.raises(TypeError, "f(x, {'a': 'hello'})")
    py.test.raises(TypeError, "f(x, {0: 42})")

def test_enforceargs_no_typecheck():
    @enforceargs(int, str, None, typecheck=False)
    def f(a, b, c):
        return a, b, c
    assert f._annenforceargs_ == (int, str, None)
    assert f(1, 2, 3) == (1, 2, 3)  # no typecheck

def test_enforceargs_translates():
    from rpython.rtyper.lltypesystem import lltype
    @enforceargs(int, float)
    def f(a, b):
        return a, b
    graph = getgraph(f, [int, int])
    TYPES = [v.concretetype for v in graph.getargs()]
    assert TYPES == [lltype.Signed, lltype.Float]

def test_enforceargs_not_constant():
    from rpython.translator.translator import TranslationContext, graphof
    @enforceargs(NOT_CONSTANT)
    def f(a):
        return a
    def f42():
        return f(42)
    t = TranslationContext()
    a = t.buildannotator()
    s = a.build_types(f42, [])
    assert not hasattr(s, 'const')


def getgraph(f, argtypes):
    from rpython.translator.translator import TranslationContext, graphof
    from rpython.translator.backendopt.all import backend_optimizations
    t = TranslationContext()
    a = t.buildannotator()
    typer = t.buildrtyper()
    a.build_types(f, argtypes)
    typer.specialize()
    backend_optimizations(t)
    graph = graphof(t, f)
    if option.view:
        graph.show()
    return graph


def test_newlist():
    def f(z):
        x = newlist_hint(sizehint=38)
        if z < 0:
            x.append(1)
        return len(x)

    graph = getgraph(f, [int])
    for llop in graph.startblock.operations:
        if llop.opname == 'malloc_varsize':
            break
    assert llop.args[2].value == 38

def test_newlist_nonconst():
    def f(z):
        x = newlist_hint(sizehint=z)
        return len(x)

    graph = getgraph(f, [int])
    for llop in graph.startblock.operations:
        if llop.opname == 'malloc_varsize':
            break
    assert llop.args[2] is graph.startblock.inputargs[0]

def test_resizelist_hint():
    def f(z):
        x = []
        resizelist_hint(x, 39)
        return len(x)

    graph = getgraph(f, [int])
    for _, op in graph.iterblockops():
        if op.opname == 'direct_call':
            break
    call_name = op.args[0].value._obj.graph.name
    assert call_name.startswith('_ll_list_resize_hint')
    call_arg2 = op.args[2].value
    assert call_arg2 == 39

def test_resizelist_hint_len():
    def f(i):
        l = [44]
        resizelist_hint(l, i)
        return len(l)

    r = interpret(f, [29])
    assert r == 1

def test_list_get_physical_size():
    def f(z):
        l = [z, z + 1]
        if z:
            l.append(z)
        return list_get_physical_size(l)

    r = interpret(f, [29])
    assert r == 6

    # now with fixed-sized list
    def f(z):
        l = [z, z + 1]
        return list_get_physical_size(l)

    r = interpret(f, [29])
    assert r == 2

def test_iterkeys_with_hash():
    def f(i):
        d = {i + .0: 5, i + .5: 6}
        total = 0
        for k, h in iterkeys_with_hash(d):
            total += k * h
        total -= (i + 0.0) * compute_hash(i + 0.0)
        total -= (i + 0.5) * compute_hash(i + 0.5)
        return total

    assert f(29) == 0.0
    r = interpret(f, [29])
    assert r == 0.0

def test_iteritems_with_hash():
    def f(i):
        d = {i + .0: 5, i + .5: 6}
        total = 0
        for k, v, h in iteritems_with_hash(d):
            total += k * h * v
        total -= (i + 0.0) * compute_hash(i + 0.0) * 5
        total -= (i + 0.5) * compute_hash(i + 0.5) * 6
        return total

    assert f(29) == 0.0
    r = interpret(f, [29])
    assert r == 0.0

def test_contains_with_hash():
    def f(i):
        d = {i + .5: 5}
        assert contains_with_hash(d, i + .5, compute_hash(i + .5))
        assert not contains_with_hash(d, i + .3, compute_hash(i + .3))
        return 0

    f(29)
    interpret(f, [29])

def test_setitem_with_hash():
    def f(i):
        d = {}
        setitem_with_hash(d, i + .5, compute_hash(i + .5), 42)
        setitem_with_hash(d, i + .6, compute_hash(i + .6), -612)
        return d[i + .5]

    assert f(29) == 42
    res = interpret(f, [27])
    assert res == 42

def test_getitem_with_hash():
    def f(i):
        d = {i + .5: 42, i + .6: -612}
        return getitem_with_hash(d, i + .5, compute_hash(i + .5))

    assert f(29) == 42
    res = interpret(f, [27])
    assert res == 42

def test_delitem_with_hash():
    def f(i):
        d = {i + .5: 42, i + .6: -612}
        delitem_with_hash(d, i + .5, compute_hash(i + .5))
        try:
            delitem_with_hash(d, i + .5, compute_hash(i + .5))
        except KeyError:
            pass
        else:
            raise AssertionError
        return 0

    f(29)
    interpret(f, [27])

def test_delitem_if_value_is():
    class X:
        pass
    def f(i):
        x42 = X()
        x612 = X()
        d = {i + .5: x42, i + .6: x612}
        delitem_if_value_is(d, i + .5, x612)
        assert (i + .5) in d
        delitem_if_value_is(d, i + .5, x42)
        assert (i + .5) not in d
        delitem_if_value_is(d, i + .5, x612)
        assert (i + .5) not in d
        return 0

    f(29)
    interpret(f, [27])

def test_rdict_with_hash():
    def f(i):
        d = r_dict(strange_key_eq, strange_key_hash)
        h = strange_key_hash("abc")
        assert h == strange_key_hash("aXX") and strange_key_eq("abc", "aXX")
        setitem_with_hash(d, "abc", h, i)
        assert getitem_with_hash(d, "aXX", h) == i
        try:
            getitem_with_hash(d, "bYY", strange_key_hash("bYY"))
        except KeyError:
            pass
        else:
            raise AssertionError
        return 0

    assert f(29) == 0
    interpret(f, [27])

def test_rordereddict_move_to_end():
    d = OrderedDict()
    d['key1'] = 'val1'
    d['key2'] = 'val2'
    d['key3'] = 'val3'
    move_to_end(d, 'key1')
    assert d.items() == [('key2', 'val2'), ('key3', 'val3'), ('key1', 'val1')]
    move_to_end(d, 'key1', last=False)
    assert d.items() == [('key1', 'val1'), ('key2', 'val2'), ('key3', 'val3')]

def test_r_dict_move_to_end():
    d = r_dict(strange_key_eq, strange_key_hash)
    d['1key'] = 'val1'
    d['2key'] = 'val2'
    d['3key'] = 'val3'
    # does not crash, we can't check that it actually moves to end on CPython
    move_to_end(d, '1key')
    move_to_end(d, '1key', last=False)

def test_import_from_mixin():
    class M:    # old-style
        def f(self):
            pass
    class A:    # old-style
        import_from_mixin(M)
    assert A.f.im_func is not M.f.im_func

    class M(object):
        def f(self):
            pass
    class A:    # old-style
        import_from_mixin(M)
    assert A.f.im_func is not M.f.im_func

    class M:    # old-style
        def f(self):
            pass
    class A(object):
        import_from_mixin(M)
    assert A.f.im_func is not M.f.im_func

    class M(object):
        def f(self):
            pass
    class A(object):
        import_from_mixin(M)
    assert A.f.im_func is not M.f.im_func

    class MBase(object):
        a = 42
        b = 43
        c = 1000
        def f(self):
            return "hi"
        def g(self):
            return self.c - 1

    class M(MBase):
        a = 84
        def f(self):
            return "there"

    class A(object):
        import_from_mixin(M)
        c = 88

    assert A.f.im_func is not M.f.im_func
    assert A.f.im_func is not MBase.f.im_func
    assert A.g.im_func is not MBase.g.im_func
    assert A().f() == "there"
    assert A.a == 84
    assert A.b == 43
    assert A.c == 88
    assert A().g() == 87

    try:
        class B(object):
            a = 63
            import_from_mixin(M)
    except Exception as e:
        assert ("would overwrite the value already defined locally for 'a'"
                in str(e))
    else:
        raise AssertionError("failed to detect overwritten attribute")

    class M(object):
        def __str__(self):
            return "m!"
    class A(object):
        import_from_mixin(M)
    class B(object):
        import_from_mixin(M, special_methods=['__str__'])
    assert str(A()).startswith('<')
    assert str(B()) == "m!"

    class M(object):
        pass
    class A(object):
        def __init__(self):
            self.foo = 42
    class B(A):
        import_from_mixin(M)
    assert B().foo == 42

    d = dict(__name__='foo')
    exec("""class M(object):
                @staticmethod
                def f(): pass
    """, d)
    M = d['M']
    class A(object):
        import_from_mixin(M)
    assert A.f is not M.f
    assert A.f.__module__ != M.f.__module__


def test_import_from_mixin_immutable_fields():
    class A(object):
        _immutable_fields_ = ['a']

    class B(object):
        _immutable_fields_ = ['b']
        import_from_mixin(A)

    assert B._immutable_fields_ == ['b', 'a']
    assert A._immutable_fields_ == ['a']

    class B(object):
        import_from_mixin(A)

    assert B._immutable_fields_ == ['a']

    class C(A):
        _immutable_fields_ = ['c']

    class B(object):
        import_from_mixin(C)

    assert B._immutable_fields_ == ['c', 'a']

    class B(object):
        _immutable_fields_ = ['b']
        import_from_mixin(C)

    assert B._immutable_fields_ == ['b', 'c', 'a']

    class B(object):
        _immutable_fields_ = ['b']

    class BA(B):
        import_from_mixin(C)

    assert BA._immutable_fields_ == ['c', 'a']


def test_never_allocate():
    from rpython.translator.c.test.test_genc import compile as c_compile
    from rpython.memory.gctransform.transform import GCTransformError

    @never_allocate
    class MyClass(object):
        def __init__(self, x):
            self.x = x + 1

    @dont_inline
    def allocate_MyClass(x):
        return MyClass(x)

    def f(x):
        # this fails because the allocation of MyClass can't be
        # constant-folded (because it's inside a @dont_inline function)
        return allocate_MyClass(x).x

    def g(x):
        # this works because MyClass is constant folded, so the GC transformer
        # never sees a malloc(MyClass)
        return MyClass(x).x

    # test what happens if MyClass escapes
    with py.test.raises(GCTransformError) as exc:
        c_compile(f, [int])
    assert '[function allocate_MyClass]' in str(exc)
    assert 'was marked as @never_allocate' in str(exc)

    # test that it works in the "normal" case
    compiled_g = c_compile(g, [int])
    assert compiled_g(41) == 42
