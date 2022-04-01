import py
from rpython.annotator.model import UnionError
from rpython.rlib import rgc, nonconst
from rpython.rlib.rweakref import RWeakValueDictionary
from rpython.rtyper.test.test_llinterp import interpret
from rpython.translator.c.test.test_genc import compile

class X(object):
    pass

class Y(X):
    pass


def make_test(loop=100, keyclass=str):
    if keyclass is str:
        make_key = str
        keys = ["abc", "def", "ghi", "hello"]
    elif keyclass is int:
        make_key = int
        keys = [123, 456, 789, 1234]

    def g(d):
        assert d.get(keys[3]) is None
        x1 = X(); x2 = X(); x3 = X()
        d.set(keys[0], x1)
        d.set(keys[1], x2)
        d.set(keys[2], x3)
        assert d.get(keys[0]) is x1
        assert d.get(keys[1]) is x2
        assert d.get(keys[2]) is x3
        assert d.get(keys[3]) is None
        return x1, x3    # x2 dies
    def f():
        d = RWeakValueDictionary(keyclass, X)
        x1, x3 = g(d)
        rgc.collect(); rgc.collect()
        assert d.get(keys[0]) is x1
        assert d.get(keys[1]) is None
        assert d.get(keys[2]) is x3
        assert d.get(keys[3]) is None
        d.set(keys[0], None)
        assert d.get(keys[0]) is None
        assert d.get(keys[1]) is None
        assert d.get(keys[2]) is x3
        assert d.get(keys[3]) is None
        # resizing should also work
        for i in range(loop):
            d.set(make_key(i), x1)
        for i in range(loop):
            assert d.get(make_key(i)) is x1
        assert d.get(keys[0]) is None
        assert d.get(keys[1]) is None
        assert d.get(keys[2]) is x3
        assert d.get(keys[3]) is None
        # a subclass
        y = Y()
        d.set(keys[3], y)
        assert d.get(keys[3]) is y
        # storing a lot of Nones
        for i in range(loop, loop*2-5):
            d.set(make_key(1000 + i), x1)
        for i in range(loop):
            d.set(make_key(i), None)
        for i in range(loop):
            assert d.get(make_key(i)) is None
        assert d.get(keys[0]) is None
        assert d.get(keys[1]) is None
        assert d.get(keys[2]) is x3
        assert d.get(keys[3]) is y
        for i in range(loop, loop*2-5):
            assert d.get(make_key(1000 + i)) is x1
    return f

def test_RWeakValueDictionary():
    make_test()()

def test_RWeakValueDictionary_int():
    make_test(keyclass=int)()

def test_rpython_RWeakValueDictionary():
    interpret(make_test(loop=12), [])

def test_rpython_RWeakValueDictionary_int():
    interpret(make_test(loop=12, keyclass=int), [])

def test_rpython_prebuilt():
    d = RWeakValueDictionary(str, X)
    living = [X() for i in range(8)]
    for i in range(8):
        d.set(str(i), living[i])
    #
    def f():
        x = X()
        for i in range(8, 13):
            d.set(str(i), x)
        for i in range(0, 8):
            assert d.get(str(i)) is living[i]
        for i in range(8, 13):
            assert d.get(str(i)) is x
        assert d.get("foobar") is None
    #
    f()
    interpret(f, [])

def test_rpython_merge_RWeakValueDictionary():
    empty = RWeakValueDictionary(str, X)
    def f(n):
        x = X()
        if n:
            d = empty
        else:
            d = RWeakValueDictionary(str, X)
            d.set("a", x)
        return d.get("a") is x
    assert f(0)
    assert interpret(f, [0])
    assert not f(1)
    assert not interpret(f, [1])


def test_rpython_merge_RWeakValueDictionary2():
    class A(object):
        def __init__(self):
            self.d = RWeakValueDictionary(str, A)
        def f(self, key):
            a = A()
            self.d.set(key, a)
            return a
    empty = A()
    def f(x):
        a = A()
        if x:
            a = empty
        a2 = a.f("a")
        assert a.d.get("a") is a2
    f(0)
    interpret(f, [0])
    f(1)
    interpret(f, [1])


@py.test.mark.xfail(
    reason="may fail with AssertionError, depending on annotation order")
def test_rpython_merge_RWeakValueDictionary3():
    def g(x):
        if x:
            d = RWeakValueDictionary(str, X)
        else:
            d = RWeakValueDictionary(str, Y)
        d.set("x", X())

    with py.test.raises(UnionError):
        interpret(g, [1])


def test_rpython_RWeakValueDictionary_or_None():
    def g(d, key):
        if d is None:
            return None
        return d.get(key)
    def f(n):
        x = X()
        if n:
            d = None
        else:
            d = RWeakValueDictionary(str, X)
            d.set("a", x)
        return g(d, "a") is x
    assert f(0)
    assert interpret(f, [0])
    assert not f(1)
    assert not interpret(f, [1])


def test_bogus_makekey():
    class X: pass
    class Y: pass
    def g():
        X(); Y()
        RWeakValueDictionary(str, X).get("foobar")
        RWeakValueDictionary(int, Y).get(42)
    interpret(g, [])

def test_key_instance():
    class K(object):
        pass
    keys = [K(), K(), K()]

    def g(d):
        assert d.get(keys[3]) is None
        x1 = X(); x2 = X(); x3 = X()
        d.set(keys[0], x1)
        d.set(keys[1], x2)
        d.set(keys[2], x3)
        assert d.get(keys[0]) is x1
        assert d.get(keys[1]) is x2
        assert d.get(keys[2]) is x3
        assert d.get(keys[3]) is None
        return x1, x3    # x2 dies
    def f():
        keys.append(K())
        d = RWeakValueDictionary(K, X)
        x1, x3 = g(d)
        rgc.collect(); rgc.collect()
        assert d.get(keys[0]) is x1
        assert d.get(keys[1]) is None
        assert d.get(keys[2]) is x3
        assert d.get(keys[3]) is None
        d.set(keys[0], None)
        assert d.get(keys[0]) is None
        assert d.get(keys[1]) is None
        assert d.get(keys[2]) is x3
        assert d.get(keys[3]) is None
    f()
    interpret(f, [])

def test_translation_prebuilt_1():
    class K:
        pass
    d = RWeakValueDictionary(K, X)
    k1 = K(); k2 = K()
    x1 = X(); x2 = X()
    d.set(k1, x1)
    d.set(k2, x2)
    def f():
        assert d.get(k1) is x1
        assert d.get(k2) is x2
    f()
    fc = compile(f, [], gcpolicy="boehm", rweakref=True)
    fc()

def test_translation_prebuilt_2():
    from rpython.rlib import rsiphash
    d = RWeakValueDictionary(str, X)
    k1 = "key1"; k2 = "key2"
    x1 = X(); x2 = X()
    d.set(k1, x1)
    d.set(k2, x2)
    def f():
        rsiphash.enable_siphash24()
        i = nonconst.NonConstant(1)
        assert d.get("key%d" % (i,)) is x1
        assert d.get("key%d" % (i+1,)) is x2
    fc = compile(f, [], gcpolicy="boehm", rweakref=True)
    fc()
