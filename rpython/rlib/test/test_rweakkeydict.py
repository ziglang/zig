import py
from rpython.annotator.model import UnionError
from rpython.rlib import rgc
from rpython.rlib.rweakref import RWeakKeyDictionary
from rpython.rtyper.test.test_llinterp import interpret

class KX(object):
    pass

class KY(KX):
    pass

class VX(object):
    pass

class VY(VX):
    pass


def make_test(loop=100, prebuilt=None):
    def g(d):
        assert d.get(KX()) is None
        assert d.get(KY()) is None
        k1 = KX(); k2 = KX(); k3 = KX()
        v1 = VX(); v2 = VX(); v3 = VX()
        d.set(k1, v1)
        d.set(k2, v2)
        d.set(k3, v3)
        assert d.get(k1) is v1
        assert d.get(k2) is v2
        assert d.get(k3) is v3
        assert d.get(KX()) is None
        assert d.length() == 3
        return k1, k3, v1, v2, v3    # k2 dies
    def f():
        d = prebuilt
        if d is None:
            d = RWeakKeyDictionary(KX, VX)
        k1, k3, v1, v2, v3 = g(d)
        rgc.collect(); rgc.collect()
        assert d.get(k1) is v1
        assert d.get(k3) is v3
        assert d.get(k1) is not v2
        assert d.get(k3) is not v2
        assert d.length() == 2
        d.set(k1, None)
        assert d.get(k1) is None
        assert d.get(k3) is v3
        assert d.length() == 1
        # resizing should also work
        lots_of_keys = [KX() for i in range(loop)]
        for k in lots_of_keys:
            d.set(k, v1)
        for k in lots_of_keys:
            assert d.get(k) is v1
        assert d.get(k1) is None
        assert d.get(k3) is v3
        assert d.length() == loop + 1
        # a subclass
        ky = KY()
        vy = VY()
        d.set(ky, vy)
        assert d.get(ky) is vy
        assert d.length() == loop + 2
        # deleting by storing Nones
        for k in lots_of_keys:
            d.set(k, None)
        for k in lots_of_keys:
            assert d.get(k) is None
        assert d.get(k1) is None
        assert d.get(k3) is v3
        assert d.get(ky) is vy
        assert d.length() == 2
    return f

def test_RWeakKeyDictionary():
    make_test()()

def test_rpython_RWeakKeyDictionary():
    interpret(make_test(loop=12), [])

def test_rpython_prebuilt():
    f = make_test(loop=12, prebuilt=RWeakKeyDictionary(KX, VX))
    interpret(f, [])

def test_rpython_merge_RWeakKeyDictionary():
    empty = RWeakKeyDictionary(KX, VX)
    def f(n):
        k = KX()
        v = VX()
        if n:
            d = empty
        else:
            d = RWeakKeyDictionary(KX, VX)
            d.set(k, v)
        return d.get(k) is v
    assert f(0)
    assert interpret(f, [0])
    assert not f(1)
    assert not interpret(f, [1])


def test_rpython_merge_RWeakKeyDictionary2():
    class A(object):
        def __init__(self):
            self.d = RWeakKeyDictionary(KX, A)
        def f(self, key):
            a = A()
            self.d.set(key, a)
            return a
    empty = A()
    def f(x):
        a = A()
        if x:
            a = empty
        k = KX()
        a2 = a.f(k)
        assert a.d.get(k) is a2
    f(0)
    interpret(f, [0])
    f(1)
    interpret(f, [1])

@py.test.mark.xfail(
    reason="may fail with AssertionError, depending on annotation order")
def test_rpython_merge_RWeakKeyDictionary3():
    def g(x):
        if x:
            d = RWeakKeyDictionary(KX, VX)
        else:
            d = RWeakKeyDictionary(KY, VX)
        d.set(KX(), VX())

    with py.test.raises(UnionError):
        interpret(g, [1])

@py.test.mark.xfail(
    reason="may fail with AssertionError, depending on annotation order")
def test_rpython_merge_RWeakKeyDictionary4():
    def g(x):
        if x:
            d = RWeakKeyDictionary(KX, VX)
        else:
            d = RWeakKeyDictionary(KX, VY)
        d.set(KX(), VX())

    with py.test.raises(UnionError):
        interpret(g, [1])

@py.test.mark.xfail(reason="not implemented, messy")
def test_rpython_free_values():
    class VXDel:
        def __del__(self):
            state.freed.append(1)
    class State:
        pass
    state = State()
    state.freed = []
    #
    def add_me():
        k = KX()
        v = VXDel()
        d = RWeakKeyDictionary(KX, VXDel)
        d.set(k, v)
        return d
    def f():
        del state.freed[:]
        d = add_me()
        rgc.collect()
        # we want the dictionary to be really empty here.  It's hard to
        # ensure in the current implementation after just one collect(),
        # but at least two collects should be enough.
        rgc.collect()
        return len(state.freed)
    assert f() == 1
    assert interpret(f, []) == 1
