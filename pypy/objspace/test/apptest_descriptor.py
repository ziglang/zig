def test_non_data_descr():
    class X(object):
        def f(self):
            return 42
    x = X()
    assert x.f() == 42
    x.f = 43
    assert x.f == 43
    del x.f
    assert x.f() == 42

def test_set_without_get():
    class Descr(object):

        def __init__(self, name):
            self.name = name

        def __set__(self, obj, value):
            obj.__dict__[self.name] = value
    descr = Descr("a")

    class X(object):
        a = descr

    x = X()
    assert x.a is descr
    x.a = 42
    assert x.a == 42

def test_failing_get():
    # when __get__() raises AttributeError,
    # __getattr__ is called...
    class X(object):
        def get_v(self):
            raise AttributeError
        v = property(get_v)

        def __getattr__(self, name):
            if name == 'v':
                return 42
    x = X()
    assert x.v == 42

    # ... but the __dict__ is not searched
    class Y(object):
        def get_w(self):
            raise AttributeError
        def set_w(self, value):
            raise AttributeError
        w = property(get_w, set_w)
    y = Y()
    y.__dict__['w'] = 42
    raises(AttributeError, getattr, y, 'w')

def test_member():
    class X(object):
        def __init__(self):
            self._v = 0
        def get_v(self):
            return self._v
        def set_v(self, v):
            self._v = v
        v = property(get_v, set_v)
    x = X()
    assert x.v  == 0
    assert X.v.__get__(x) == 0
    x.v = 1
    assert x.v == 1
    X.v.__set__(x, 0)
    assert x.v == 0
    raises(AttributeError, delattr, x, 'v')
    raises(AttributeError, X.v.__delete__, x)

def test_invalid_unicode_identifier():
    skip("utf-8 encoding before translation accepts lone surrogates, "
        "because it is Python 2.7, but after translation it does not. "
        "Moreover, CPython 3.x accepts such unicode attributes anyway. "
        "This makes this test half-wrong for now.")
    class X(object):
        pass
    x = X()
    raises(AttributeError, setattr, x, '\ud800', 1)
    raises(AttributeError, getattr, x, '\ud800')
    raises(AttributeError, delattr, x, '\ud800')
    raises(AttributeError, getattr, x, '\uDAD1\uD51E')

def test_special_methods_returning_strings():
    class A(object):
        seen = []
        def __str__(self):
            self.seen.append(1)
        def __repr__(self):
            self.seen.append(2)
        def __oct__(self):
            self.seen.append(3)
        def __hex__(self):
            self.seen.append(4)

    inst = A()
    raises(TypeError, str, inst)
    raises(TypeError, repr, inst)
    raises(TypeError, oct, inst)
    raises(TypeError, hex, inst)
    assert A.seen == [1,2] # __oct__ and __hex__ are no longer called

def test_hash():
    class A(object):
        pass
    hash(A())

    class B(object):
        def __eq__(self, other): pass
    assert B.__hash__ is None
    raises(TypeError, "hash(B())") # because we define __eq__ but not __hash__

    class E(object):
        def __hash__(self):
            return "something"
    raises(TypeError, hash, E())

    class G:
        def __hash__(self):
            return 1
    assert isinstance(hash(G()), int)

    # don't return a subclass of int, either
    class myint(int):
        pass
    class I(object):
        def __hash__(self):
            return myint(15)
    assert hash(I()) == 15
    assert type(hash(I())) is int

    # check hashing of -1 to -2
    class myint(int):
        pass
    class myfloat(float):
        pass
    class myHashClass(object):
        def __hash__(self):
            return -1
    class myHashClass3(object):
        def __hash__(self):
            return -10**100

    assert hash(-1) == -2
    assert hash(-1.0) == -2
    assert hash(-1 + 0j) == -2
    assert hash(myint(-1)) == -2
    assert hash(myfloat(-1.0)) == -2
    assert hash(myHashClass()) == -2
    assert hash(myHashClass3()) == hash(-10**100)

def test_descr_funny_new():
    class C(object):
        @classmethod
        def __new__(*args):
            return args

    assert C.__new__(1,2) == (C, 1, 2)
    assert C(1,2) == (C, C, 1, 2)

def test_issue3255():
    class MagicCaller(object):
        def __get__(self, *args):
            raise Exception("should not be called")
        def __call__(self, *args):
            return lambda attr: attr
    class Descriptor(object):
        __get__ = MagicCaller()
    class X(object):
        __getattribute__ = Descriptor()
    assert X().foo == "foo"
