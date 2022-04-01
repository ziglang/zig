import py
from pypy.interpreter.gateway import interp2app

class AppTestIdentityDict(object):

    def setup_class(cls):
        if cls.runappdirect:
            py.test.skip("interp2app doesn't work on appdirect")

    def w_uses_identity_strategy(self, obj):
        import __pypy__
        return "IdentityDictStrategy" in __pypy__.internal_repr(obj)

    def test_use_strategy(self):
        class X(object):
            pass
        d = {}
        x = X()
        d[x] = 1
        assert self.uses_identity_strategy(d)
        assert d[x] == 1

    def test_bad_item(self):
        class X(object):
            pass
        class Y(object):
            def __hash__(self):
                return 32

        d = {}
        x = X()
        y = Y()
        d[x] = 1
        assert self.uses_identity_strategy(d)
        d[y] = 2
        assert not self.uses_identity_strategy(d)
        assert d[x] == 1
        assert d[y] == 2

    def test_bad_key(self):
        class X(object):
            pass
        d = {}
        x = X()

        class Y(object):
            def __hash__(self):
                return hash(x) # to make sure we do x == y

            def __eq__(self, other):
                return True

        y = Y()
        d[x] = 1
        assert self.uses_identity_strategy(d)
        assert d[y] == 1
        assert not self.uses_identity_strategy(d)

    def test_iter(self):
        class X(object):
            pass
        x = X()
        d = {x: 1}
        assert self.uses_identity_strategy(d)
        assert list(iter(d)) == [x]

    def test_mutate_class_and_then_compare(self):
        class X(object):
            pass
        class Y(object):
            pass

        x = X()
        y = Y()
        d1 = {x: 1}
        d2 = {y: 1}
        assert self.uses_identity_strategy(d1)
        assert self.uses_identity_strategy(d2)
        #
        X.__hash__ = lambda self: hash(y)
        X.__eq__ = lambda self, other: True
        #
        assert d1 == d2
        assert self.uses_identity_strategy(d1)
        assert not self.uses_identity_strategy(d2)
