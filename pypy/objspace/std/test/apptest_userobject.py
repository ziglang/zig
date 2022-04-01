import sys
import gc
from _io import StringIO

def test_emptyclass():
    class empty(object): pass
    inst = empty()
    assert isinstance(inst, empty)
    inst.attr = 23
    assert inst.attr == 23

def test_method():
    class A(object):
        def f(self, v):
            return v*42
    a = A()
    assert a.f('?') == '??????????????????????????????????????????'

def test_unboundmethod():
    class A(object):
        def f(self, v):
            return v*17
    a = A()
    assert A.f(a, '!') == '!!!!!!!!!!!!!!!!!'

def test_subclassing():
    for base in tuple, list, dict, str, int, float:
        class subclass(base): pass
        stuff = subclass()
        assert isinstance(stuff, base)
        assert subclass.__base__ is base

def test_subclasstuple():
    class subclass(tuple): pass
    stuff = subclass()
    assert isinstance(stuff, tuple)
    stuff.attr = 23
    assert stuff.attr ==23
    assert len(stuff) ==0
    result = stuff + (1,2,3)
    assert len(result) ==3

def test_subsubclass():
    class base(object):
        baseattr = 12
    class derived(base):
        derivedattr = 34
    inst = derived()
    assert isinstance(inst, base)
    assert inst.baseattr ==12
    assert inst.derivedattr ==34

def test_descr_get():
    class C(object):
        class desc(object):
            def __get__(self, ob, cls=None):
                return 42
        prop = desc()
    assert C().prop == 42

def test_descr_set():
    class C(object):
        class desc(object):
            def __set__(self, ob, val):
                ob.wibble = val
        prop = desc()
    c = C()
    c.prop = 32
    assert c.wibble == 32

def test_descr_delete():
    class C(object):
        class desc(object):
            def __set__(self, ob, val):
                oogabooga
            def __delete__(self, ob):
                ob.wibble = 22
        prop = desc()
    c = C()
    del c.prop
    assert c.wibble == 22

def test_class_setattr():
    class C(object):
        pass
    C.a = 1
    assert hasattr(C, 'a')
    assert C.a == 1

def test_add():
    class C(object):
        def __add__(self, other):
            return self, other
    c1 = C()
    assert c1+3 == (c1, 3)

def test_call():
    class C(object):
        def __call__(self, *args):
            return args
    c1 = C()
    assert c1() == ()
    assert c1(5) == (5,)
    assert c1("hello", "world") == ("hello", "world")

def test_getattribute():
    class C(object):
        def __getattribute__(self, name):
            return '->' + name
    c1 = C()
    assert c1.a == '->a'
    c1.a = 5
    assert c1.a == '->a'

def test_getattr():
    class C(object):
        def __getattr__(self, name):
            return '->' + name
    c1 = C()
    assert c1.a == '->a'
    c1.a = 5
    assert c1.a == 5

def test_dict():
    class A(object):
        pass
    class B(A):
        pass
    assert not '__dict__' in object.__dict__
    assert '__dict__' in A.__dict__
    assert not '__dict__' in B.__dict__
    a = A()
    a.x = 5
    assert a.__dict__ == {'x': 5}
    a.__dict__ = {'y': 6}
    assert a.y == 6
    assert not hasattr(a, 'x')

def test_del():
    lst = []
    class A(object):
        def __del__(self):
            lst.append(42)
    A()
    gc.collect()
    assert lst == [42]

def test_del_exception():
    class A(object):
        def __del__(self):
            raise ValueError('foo bar')
    prev = sys.stderr
    try:
        sys.stderr = StringIO()
        A()
        gc.collect()
        res = sys.stderr.getvalue()
        sys.stderr = StringIO()
        A()
        gc.collect()
        res2 = sys.stderr.getvalue()
        A.__del__ = lambda a, b, c: None  # will get "not enough arguments"
        sys.stderr = StringIO()
        A()
        gc.collect()
        res3 = sys.stderr.getvalue()
    finally:
        sys.stderr = prev
    def check_tb(x, traceback=True):
        # print('----\n%s----\n' % (x,))
        assert x.startswith('Exception ignored in: <function ')
        if traceback:
            assert '>\nTraceback (most recent call last):\n  File "' in x
            assert " in __del__\n" in x
            assert x.endswith("\nValueError: foo bar\n")
        else:
            assert 'TypeError: <lambda>() missing 2 required pos' in x
    check_tb(res)
    check_tb(res2)
    check_tb(res3, traceback=False)

def test_instance_overrides_meth():
    class C(object):
        def m(self):
            return "class"
    assert C().m() == 'class'
    c = C()
    c.m = lambda: "instance"
    res = c.m()
    assert res == "instance"

def test_override_builtin_methods():
    class myint(int):
        def __add__(self, other):
            return 'add'
        def __rsub__(self, other):
            return 'rsub'
    assert myint(3) + 5 == 'add'
    assert 5 + myint(3) == 8
    assert myint(3) - 5 == -2
    assert 5 - myint(3) == 'rsub'

def test_repr():
    class Foo(object):
        pass
    Foo.__module__ = 'a.b.c'
    Foo.__qualname__ = 'd.Foo'
    s = repr(Foo())
    assert s.startswith('<a.b.c.d.Foo object at ')

def test_repr_nonascii():
    Japan = type('日本', (), dict(__module__='日本国'))
    s = repr(Japan())
    assert s.startswith('<日本国.日本 object at ')

def test_del_attr():
    class Foo(object):
        def __init__(self):
            self.x = 3

    foo = Foo()
    del foo.x

    raises(AttributeError, "del foo.x")

    class Foo:
        def __init__(self):
            self.x = 3

    foo = Foo()
    del foo.x
    raises(AttributeError, "del foo.x")

def test_del_attr_class():
    class Foo:
        pass

    raises(AttributeError, "del Foo.x")
