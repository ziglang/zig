import pytest
from pytest import raises, skip

class C:
    def foo(self):
        pass

MethodType = type(C().foo)  # avoid costly import from types

def test_attributes():
    globals()['__name__'] = 'mymodulename'
    def f(): pass
    assert hasattr(f, '__code__')
    assert f.__defaults__ == None
    f.__defaults__ = None
    assert f.__defaults__ == None
    assert f.__dict__ == {}
    assert type(f.__globals__) == dict
    assert f.__closure__ is None
    assert f.__doc__ == None
    assert f.__name__ == 'f'
    assert f.__module__ == 'mymodulename'

def test_qualname():
    def f():
        def g():
            pass
        return g
    assert f.__qualname__ == 'test_qualname.<locals>.f'
    assert f().__qualname__ == 'test_qualname.<locals>.f.<locals>.g'
    f.__qualname__ = 'qualname'
    assert f.__qualname__ == 'qualname'
    raises(TypeError, "f.__qualname__ = b'name'")

def test_qualname_method():
    class A:
        def f(self):
            pass
    assert A.f.__qualname__ == 'test_qualname_method.<locals>.A.f'

def test_qualname_global():
    def f():
        global inner_global
        def inner_global():
            def inner_function2():
                pass
            return inner_function2
        return inner_global
    assert f().__qualname__ == 'inner_global'
    assert f()().__qualname__ == 'inner_global.<locals>.inner_function2'

def test_classmethod_reduce():
    class X(object):
        @classmethod
        def y(cls):
            pass

    f, args = X.y.__reduce__()
    assert f(*args) == X.y
    # This is perhaps overly specific.  It's an attempt to be certain that
    # pickle will actually work with this implementation.
    assert f == getattr
    assert args == (X, "y")

def test_annotations():
    def f(): pass
    ann = f.__annotations__
    assert ann == {}
    assert f.__annotations__ is ann
    raises(TypeError, setattr, f, "__annotations__", 42)
    del f.__annotations__
    assert f.__annotations__ is not ann
    f.__annotations__ = ann
    assert f.__annotations__ is ann

def test_annotations_mangle():
    class X:
        def foo(self, __a:5, b:6):
            pass
    assert X.foo.__annotations__ == {'_X__a': 5, 'b': 6}

def test_kwdefaults():
    def f(*, kw=3): return kw
    assert f.__kwdefaults__ == {"kw" : 3}
    f.__kwdefaults__["kw"] = 4
    assert f() == 4
    f.__kwdefaults__ = {"kw" : 5}
    assert f() == 5
    del f.__kwdefaults__
    assert f.__kwdefaults__ is None
    raises(TypeError, f)
    assert f(kw=42) == 42
    def f(*, 日本=3): return kw
    assert f.__kwdefaults__ == {"日本" : 3}

def test_kw_nonascii():
    def f(日本: str=1):
        return 日本
    assert f.__annotations__ == {'日本': str}
    assert f() == 1
    assert f(日本='bar') == 'bar'

def test_code_is_ok():
    def f(): pass
    assert not hasattr(f.__code__, '__dict__')

def test_underunder_attributes():
    def f(): pass
    assert f.__name__ == 'f'
    assert f.__doc__ == None
    assert f.__dict__ == {}
    assert f.__code__.co_name == 'f'
    assert f.__defaults__ is None
    assert f.__globals__ is globals()
    assert hasattr(f, '__class__')

def test_classmethod():
    def f():
        pass
    assert classmethod(f).__func__ is f
    assert staticmethod(f).__func__ is f

def test_write___doc__():
    def f(): "hello"
    assert f.__doc__ == 'hello'
    f.__doc__ = 'good bye'
    assert f.__doc__ == 'good bye'
    del f.__doc__
    assert f.__doc__ == None

def test_write_module():
    def f(): "hello"
    f.__module__ = 'ab.c'
    assert f.__module__ == 'ab.c'
    del f.__module__
    assert f.__module__ is None

def test_new():
    def f(): return 42
    FuncType = type(f)
    f2 = FuncType(f.__code__, f.__globals__, 'f2', None, None)
    assert f2() == 42

    def g(x):
        def f():
            return x
        return f
    f = g(42)
    with raises(TypeError):
        FuncType(f.__code__, f.__globals__, 'f2', None, None)

def test_write_code():
    def f():
        return 42
    def g():
        return 41
    assert f() == 42
    assert g() == 41
    with raises(TypeError):
        f.__code__ = 1
    f.__code__ = g.__code__
    assert f() == 41
    def get_h(f=f):
        def h():
            return f() # a closure
        return h
    h = get_h()
    with raises(ValueError):
        f.__code__ = h.__code__

def test_write_code_builtin_forbidden():
    def f(*args):
        return 42
    with raises(TypeError):
        dir.__code__ = f.__code__
    with raises(TypeError):
        list.append.__code__ = f.__code__

def test_write_attributes_builtin_forbidden():
    for func in [dir, dict.get]:
        with raises(TypeError):
            func.__defaults__ = (1, )
        with raises(TypeError):
            del func.__defaults__
        with raises(TypeError):
            func.__doc__ = ""
        with raises(TypeError):
            del func.__doc__
        with raises(TypeError):
            func.__name__ = ""
        with raises(TypeError):
            func.__module__ = ""
        with raises(TypeError):
            del func.__module__

def test_write_attributes_builtin_forbidden_py3():
    for func in [dir, dict.get]:
        with raises(TypeError):
            func.__qualname__ = "abc"
        with raises(TypeError):
            func.__annotations__ = {}
            del func.__annotations__


def test_func_nonascii():
    def 日本():
        pass
    assert repr(日本).startswith(
        '<function test_func_nonascii.<locals>.日本 at ')
    assert 日本.__name__ == '日本'

def test_simple_call():
    def func(arg1, arg2):
        return arg1, arg2
    res = func(23,42)
    assert res[0] == 23
    assert res[1] == 42

def test_simple_call_default():
    def func(arg1, arg2=11, arg3=111):
        return arg1, arg2, arg3
    res = func(1)
    assert res[0] == 1
    assert res[1] == 11
    assert res[2] == 111
    res = func(1, 22)
    assert res[0] == 1
    assert res[1] == 22
    assert res[2] == 111
    res = func(1, 22, 333)
    assert res[0] == 1
    assert res[1] == 22
    assert res[2] == 333

    with raises(TypeError):
        func()
    with raises(TypeError):
        func(1, 2, 3, 4)

def test_simple_varargs():
    def func(arg1, *args):
        return arg1, args
    res = func(23,42)
    assert res[0] == 23
    assert res[1] == (42,)

    res = func(23, *(42,))
    assert res[0] == 23
    assert res[1] == (42,)

def test_simple_kwargs():
    def func(arg1, **kwargs):
        return arg1, kwargs
    res = func(23, value=42)
    assert res[0] == 23
    assert res[1] == {'value': 42}

    res = func(23, **{'value': 42})
    assert res[0] == 23
    assert res[1] == {'value': 42}

def test_kwargs_sets_wrong_positional_raises():
    def func(arg1):
        pass
    with raises(TypeError):
        func(arg2=23)

def test_kwargs_sets_positional():
    def func(arg1):
        return arg1
    res = func(arg1=42)
    assert res == 42

def test_kwargs_sets_positional_mixed():
    def func(arg1, **kw):
        return arg1, kw
    res = func(arg1=42, something=23)
    assert res[0] == 42
    assert res[1] == {'something': 23}

def test_kwargs_sets_positional_twice():
    def func(arg1, **kw):
        return arg1, kw
    with raises(TypeError):
        func(42, {'arg1': 23})

def test_kwargs_nondict_mapping():
    class Mapping:
        def keys(self):
            return ('a', 'b')
        def __getitem__(self, key):
            return key
    def func(arg1, **kw):
        return arg1, kw
    res = func(23, **Mapping())
    assert res[0] == 23
    assert res[1] == {'a': 'a', 'b': 'b'}
    with raises(TypeError) as excinfo:
        func(42, **[])
    assert ('argument after ** must be a mapping, not list' in
        str(excinfo.value))

def test_default_arg():
    def func(arg1,arg2=42):
        return arg1, arg2
    res = func(arg1=23)
    assert res[0] == 23
    assert res[1] == 42

def test_defaults_keyword_overrides():
    def func(arg1=42, arg2=23):
        return arg1, arg2
    res = func(arg1=23)
    assert res[0] == 23
    assert res[1] == 23

def test_defaults_keyword_override_but_leaves_empty_positional():
    def func(arg1,arg2=42):
        return arg1, arg2
    with raises(TypeError):
        func(arg2=23)

def test_kwargs_disallows_same_name_twice():
    def func(arg1, **kw):
        return arg1, kw
    with raises(TypeError):
        func(42, **{'arg1': 23})

def test_kwargs_bound_blind():
    class A(object):
        def func(self, **kw):
            return self, kw
    func = A().func
    with raises(TypeError):
        func(self=23)
    with raises(TypeError):
        func(**{'self': 23})

def test_kwargs_confusing_name():
    def func(self):    # 'self' conflicts with the interp-level
        return self*7  # argument to call_function()
    res = func(self=6)
    assert res == 42

def test_get():
    def func(self): return self
    obj = object()
    meth = func.__get__(obj, object)
    assert meth() == obj

@pytest.mark.skipif(True, reason="XXX issue #2083")
def test_none_get_interaction():
    assert type(None).__repr__(None) == 'None'

def test_none_get_interaction_2():
    f = None.__repr__
    assert f() == 'None'

def test_no_get_builtin():
    assert not hasattr(dir, '__get__')
    class A(object):
        ord = ord
    a = A()
    assert a.ord('a') == 97

def test_builtin_as_special_method_is_not_bound():
    class A(object):
        __getattr__ = len
    a = A()
    assert a.a == 1
    assert a.ab == 2
    assert a.abcdefghij == 10

def test_call_builtin():
    s = 'hello'
    with raises(TypeError):
        len()
    assert len(s) == 5
    with raises(TypeError):
        len(s, s)
    with raises(TypeError):
        len(s, s, s)
    assert len(*[s]) == 5
    assert len(s, *[]) == 5
    with raises(TypeError):
        len(some_unknown_keyword=s)
    with raises(TypeError):
        len(s, some_unknown_keyword=s)
    with raises(TypeError):
        len(s, s, some_unknown_keyword=s)

def test_call_error_message():
    try:
        len()
    except TypeError as e:
        msg = str(e)
        msg = msg.replace('one', '1') # CPython puts 'one', PyPy '1'
        assert "len() missing 1 required positional argument: 'obj'" in msg
    else:
        assert 0, "did not raise"

    try:
        len(1, 2)
    except TypeError as e:
        msg = str(e)
        msg = msg.replace('one', '1') # CPython puts 'one', PyPy '1'
        assert "len() takes 1 positional argument but 2 were given" in msg
    else:
        assert 0, "did not raise"

def test_unicode_docstring():
    def f():
        "hi"
    assert f.__doc__ == "hi"
    assert type(f.__doc__) is str

def test_issue1293():
    def f1(): "doc f1"
    def f2(): "doc f2"
    f1.__code__ = f2.__code__
    assert f1.__doc__ == "doc f1"

def test_subclassing():
    # cannot subclass 'function' or 'builtin_function'
    def f():
        pass
    with raises(TypeError):
        type('Foo', (type(f),), {})
    with raises(TypeError):
        type('Foo', (type(len),), {})

def test_lambda_docstring():
    # Like CPython, (lambda:"foo") has a docstring of "foo".
    # But let's not test that.  Just test that (lambda:42) does not
    # have 42 as docstring.
    f = lambda: 42
    assert f.__doc__ is None

def test_simple_call():
    class A(object):
        def func(self, arg2):
            return self, arg2
    a = A()
    res = a.func(42)
    assert res[0] is a
    assert res[1] == 42

def test_simple_varargs():
    class A(object):
        def func(self, *args):
            return self, args
    a = A()
    res = a.func(42)
    assert res[0] is a
    assert res[1] == (42,)

    res = a.func(*(42,))
    assert res[0] is a
    assert res[1] == (42,)

def test_obscure_varargs():
    class A(object):
        def func(*args):
            return args
    a = A()
    res = a.func(42)
    assert res[0] is a
    assert res[1] == 42

    res = a.func(*(42,))
    assert res[0] is a
    assert res[1] == 42

def test_simple_kwargs():
    class A(object):
        def func(self, **kwargs):
            return self, kwargs
    a = A()

    res = a.func(value=42)
    assert res[0] is a
    assert res[1] == {'value': 42}

    res = a.func(**{'value': 42})
    assert res[0] is a
    assert res[1] == {'value': 42}

def test_get():
    def func(self): return self
    class Object(object): pass
    obj = Object()
    # Create bound method from function
    obj.meth = func.__get__(obj, Object)
    assert obj.meth() == obj
    # Create bound method from method
    meth2 = obj.meth.__get__(obj, Object)
    assert meth2() == obj

def test_get_get():
    # sanxiyn's test from email
    def m(self): return self
    class C(object): pass
    class D(C): pass
    C.m = m
    D.m = C.m
    c = C()
    assert c.m() == c
    d = D()
    assert d.m() == d

def test_method_eq():
    class C(object):
        def m(): pass
    c = C()
    assert C.m == C.m
    assert c.m == c.m
    assert not (C.m == c.m)
    assert not (c.m == C.m)
    c2 = C()
    assert (c.m == c2.m) is False
    assert (c.m != c2.m) is True
    assert (c.m != c.m) is False

def test_method_eq_bug():
    # method equality is based on the identity of the underlying instances, not
    # equality
    class A:
        def __eq__(self, other):
            return True
        def f(self): pass

    assert A().f != A().f

def test_method_hash():
    class C(object):
        def m(): pass
    class D(C):
        pass
    c = C()
    assert hash(C.m) == hash(D.m)
    assert hash(c.m) == hash(c.m)

def test_method_repr():
    class A(object):
        def f(self):
            pass
    assert repr(A().f).startswith("<bound method %s.f of <" %
                                    A.__qualname__)
    assert repr(A().f).endswith(">>")

def test_method_repr_2():
    class ClsA(object):
        def f(self):
            pass
    class ClsB(ClsA):
        pass
    r = repr(ClsB().f)
    assert "ClsA.f of <" in r
    assert repr(type(ClsA.f)) == "<class 'function'>"
    assert repr(type(ClsA().f)) == "<class 'method'>"


def test_method_call():
    class C(object):
        def __init__(self, **kw):
            pass
    c = C(type='test')

def test_method_w_callable():
    class A(object):
        def __call__(self, x):
            return x
    im = MethodType(A(), 3)
    assert im() == 3

def test_method_w_callable_call_function():
    class A(object):
        def __call__(self, x, y):
            return x+y
    im = MethodType(A(), 3)
    assert list(map(im, [4])) == [7]


class CallableBadGetattr:
    def __getattr__(self, name):
        # Ensure that __getattr__ doesn't get called
        raise RuntimeError

    def __call__(self, a, b, c):
        return a, b, c

def test_custom_callable_errors():
    fn = CallableBadGetattr()
    with raises(TypeError) as excinfo:
        fn(*1)
    assert excinfo.value.args[0].startswith('CallableBadGetattr object')
    with raises(TypeError) as excinfo:
        fn()
    assert excinfo.value.args[0].startswith('__call__()')
    assert fn(1, 2, 3) == (1, 2, 3)

def test_invalid_creation():
    def f(): pass
    with raises(TypeError):
        MethodType(f, None)

def test_empty_arg_kwarg_call():
    def f():
        pass

    with raises(TypeError):
        f(*0)
    with raises(TypeError):
        f(**0)

def test_method_equal():
    class A(object):
        def m(self):
            pass

    class X(object):
        def __eq__(self, other):
            return True

    assert A().m == X()
    assert X() == A().m

def test_method_equals_with_identity():
    class CallableBadEq(object):
        def __call__(self):
            pass
        def __eq__(self, other):
            raise ZeroDivisionError
    func = CallableBadEq()
    meth = MethodType(func, object)
    assert meth == meth
    assert meth == MethodType(func, object)

def test_method_identity():
    import sys
    class A(object):
        def m(self):
            pass
        def n(self):
            pass

    class B(A):
        pass

    class X(object):
        def __eq__(self, other):
            return True

    a = A()
    a2 = A()
    x = a.m; y = a.m
    assert x is not y
    assert id(x) != id(y)
    assert x == y
    assert x is not a.n
    assert id(x) != id(a.n)
    assert x is not a2.m
    assert id(x) != id(a2.m)

    if '__pypy__' in sys.builtin_module_names:
        assert A.m is A.m
        assert id(A.m) == id(A.m)
    assert A.m == A.m
    x = A.m
    assert x is not A.n
    assert id(x) != id(A.n)
    assert x is B.m
    assert id(x) == id(B.m)

def test_posonly():
    def posonlyfunc(a, b, c, /, d):
        return (a, b, c, d)

    assert posonlyfunc(1, 2, 3, 4) == (1, 2, 3, 4)
    with raises(TypeError):
        posonlyfunc(a=1, b=2, c=3, d=4)

def test_posonly_default():
    def posonlyfunc(a, b=(), /, **kwds):
        return a, b, kwds
    assert posonlyfunc(1) == (1, (), {})
    assert posonlyfunc(1, 2) == (1, 2, {})
    assert posonlyfunc(1, 2, a=4, b=5) == (1, 2, {'a': 4, 'b': 5})

def test_posonly_annotations():
    def posonlyfunc(x: int, /):
        pass
    print(posonlyfunc.__annotations__)
    assert posonlyfunc.__annotations__ == {"x": int}

def global_inner_has_pos_only():
    def f(x: int, /): ...
    return f

def test_posonly_annotations_crash():
    assert global_inner_has_pos_only().__annotations__ == {"x": int}

def test_classmethod_of_random_callable():
    class Callable:
        def __call__(self, cls):
            print(cls)
            assert cls is Class
            return "foo"
    class Class:
        f = classmethod(Callable())
    assert Class().f() == "foo"


def test_classmethod_of_other_descriptor():
    class BoundWrapper:
        def __init__(self, wrapped):
            self.__wrapped__ = wrapped

        def __call__(self, *args, **kwargs):
            return self.__wrapped__(*args, **kwargs)

    class Wrapper:
        def __init__(self, wrapped):
            self.__wrapped__ = wrapped

        def __get__(self, instance, owner):
            bound_function = self.__wrapped__.__get__(instance, owner)
            return BoundWrapper(bound_function)

    def decorator(wrapped):
        return Wrapper(wrapped)

    class Class:
        @decorator
        @classmethod
        def inner(cls):
            # This should already work.
            assert cls is Class
            return 'spam'

        @classmethod
        @decorator
        def outer(cls):
            # Raised TypeError with a message saying that the 'Wrapper'
            # object is not callable.
            assert cls is Class
            return 'eggs'

    assert Class.inner() == 'spam'
    assert Class.outer() == 'eggs'
    assert Class().inner() == 'spam'
    assert Class().outer() == 'eggs'

def test_duplicate_key_kwargs():
    def f(**d): pass
    class A:
        def keys(self): return ['a', 'a', 'b']
        def items(self): return [('a', None), ('a', None), ('b', None)]
        def __getitem__(self, key): 1
        def __len__(self): return 3
    with pytest.raises(TypeError):
        f(**A())
