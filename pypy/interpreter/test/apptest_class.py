import pytest

def test_class():
    class C(object):
        pass
    assert C.__class__ == type
    c = C()
    assert c.__class__ == C

def test_metaclass_explicit():
    class M(type):
        pass
    class C(metaclass=M):
        pass
    assert C.__class__ == M
    c = C()
    assert c.__class__ == C

def test_metaclass_inherited():
    class M(type):
        pass
    class B(metaclass=M):
        pass
    class C(B):
        pass
    assert C.__class__ == M
    c = C()
    assert c.__class__ == C

def test_method():
    class C(object):
        def meth(self):
            return 1
    c = C()
    assert c.meth() == 1

def test_method_exc():
    class C(object):
        def meth(self):
            raise RuntimeError
    c = C()
    pytest.raises(RuntimeError, c.meth)

def test_class_attr():
    class C(object):
        a = 42
    c = C()
    assert c.a == 42
    assert C.a == 42

def test_class_attr_inherited():
    class C(object):
        a = 42
    class D(C):
        pass
    d = D()
    assert d.a == 42
    assert D.a == 42

def test___new__():
    class A(object):
        pass
    assert isinstance(A(), A)
    assert isinstance(object.__new__(A), A)
    assert isinstance(A.__new__(A), A)

def test_int_subclass():
    class R(int):
        pass
    x = R(5)
    assert type(x) == R
    assert x == 5
    assert type(int(x)) == int
    assert int(x) == 5

def test_float_subclass():
    class R(float):
        pass
    x = R(5.5)
    assert type(x) == R
    assert x == 5.5
    assert type(float(x)) == float
    assert float(x) == 5.5

def test_meth_doc():
    class C(object):
        def meth_no_doc(self):
            pass
        def meth_doc(self):
            """this is a docstring"""
            pass
    c = C()
    assert C.meth_no_doc.__doc__ == None
    assert c.meth_no_doc.__doc__ == None
    assert C.meth_doc.__doc__ == """this is a docstring"""
    assert c.meth_doc.__doc__ == """this is a docstring"""

def test_getattribute():
    class C(object):
        def __getattribute__(self, attr):
            if attr == 'one':
                return 'two'
            return super(C, self).__getattribute__(attr)
    c = C()
    assert c.one == "two"
    pytest.raises(AttributeError, getattr, c, "two")

def test___class__():
    class C(object):
        def get_class(self):
            return __class__
    assert C().get_class()

def test_qualname():
    class C:
        class D:
            pass
    assert C.__qualname__ == 'test_qualname.<locals>.C'
    assert C.D.__qualname__ == 'test_qualname.<locals>.C.D'
    assert not hasattr(C(), '__qualname__')

def test_nonsensical_base_error_message():
    with raises(TypeError) as exc:
        class Foo('base'):
            pass
    assert str(exc.value).startswith(
        "metaclass found to be 'str', but calling <class 'str'> "
        "with args ('Foo', ('base',), ...) raised ")
    #
    def foo_func(): pass
    with pytest.raises(TypeError) as exc:
        class Foo(foo_func):
            pass
    assert str(exc.value).startswith(
        "metaclass found to be 'function', but calling <class 'function'> "
        "with args ('Foo', (<function test_nonsensical_base_error_message"
        ".<locals>.foo_func at ")

    with pytest.raises(TypeError) as exc:
        class Foo(object, object):
            pass
    assert str(exc.value).startswith(
        "duplicate base class 'object'")
