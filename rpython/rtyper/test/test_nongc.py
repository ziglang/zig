import py

from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import SomeAddress
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.rtyper.rtyper import RPythonTyper
from rpython.rlib.objectmodel import free_non_gc_object
from rpython.rtyper.test.test_llinterp import interpret as llinterpret

def interpret(f, args):
    return llinterpret(f, args, malloc_check=False)

def test_free_non_gc_object():
    class TestClass(object):
        _alloc_flavor_ = ""
        def __init__(self, a):
            self.a = a
        def method1(self):
            return self.a
        def method2(self):
            return 42
    class TestClass2(object):
        pass
    t = TestClass(1)
    assert t.method1() == 1
    assert t.method2() == 42
    free_non_gc_object(t)
    py.test.raises(RuntimeError, "t.method1()")
    py.test.raises(RuntimeError, "t.method2()")
    py.test.raises(RuntimeError, "t.a")
    py.test.raises(RuntimeError, "t.a = 1")
    py.test.raises(AssertionError, "free_non_gc_object(TestClass2())")

def test_alloc_flavor():
    class A:
        _alloc_flavor_ = "raw"
    def f():
        return A()
    a = RPythonAnnotator()
    #does not raise:
    s = a.build_types(f, [])
    Adef = a.bookkeeper.getuniqueclassdef(A)
    assert s.classdef == Adef
    rtyper = RPythonTyper(a)
    rtyper.specialize()
    assert (Adef, 'raw') in rtyper.instance_reprs
    assert (Adef, 'gc') not in rtyper.instance_reprs

def test_alloc_flavor_subclassing():
    class A:
        _alloc_flavor_ = "raw"
    class B(A):
        def __init__(self, a):
            self.a = a
    def f():
        return B(0)
    a = RPythonAnnotator()
    #does not raise:
    s = a.build_types(f, [])
    Adef = a.bookkeeper.getuniqueclassdef(A)
    Bdef = a.bookkeeper.getuniqueclassdef(B)
    assert s.classdef == Bdef
    rtyper = RPythonTyper(a)
    rtyper.specialize()
    assert (Adef, 'raw') in rtyper.instance_reprs
    assert (Adef, 'gc') not in rtyper.instance_reprs
    assert (Bdef, 'raw') in rtyper.instance_reprs
    assert (Bdef, 'gc') not in rtyper.instance_reprs

def test_unsupported():
    class A:
        _alloc_flavor_ = "raw"
    def f():
        return str(A())
    a = RPythonAnnotator()
    #does not raise:
    s = a.build_types(f, [])
    assert s.knowntype == str
    rtyper = RPythonTyper(a)
    py.test.raises(TypeError,rtyper.specialize) # results in an invalid cast

def test_isinstance():
    class A(object):
        _alloc_flavor_ = "raw"
    class B(A):
        pass
    class C(B):
        pass

    def f(i):
        if i == 0:
            o = None
        elif i == 1:
            o = A()
        elif i == 2:
            o = B()
        else:
            o = C()
        res = 100*isinstance(o, A) + 10*isinstance(o, B) + 1*isinstance(o, C)
        if i == 0:
            pass
        elif i == 1:
            assert isinstance(o, A)
            free_non_gc_object(o)
        elif i == 2:
            assert isinstance(o, B)
            free_non_gc_object(o)
        else:
            assert isinstance(o, C)
            free_non_gc_object(o)
        return res

    assert f(1) == 100
    assert f(2) == 110
    assert f(3) == 111
    assert f(0) == 0

    a = RPythonAnnotator()
    #does not raise:
    s = a.build_types(f, [int])
    assert s.knowntype == int
    rtyper = RPythonTyper(a)
    rtyper.specialize()
    res = interpret(f, [1])
    assert res == 100
    res = interpret(f, [2])
    assert res == 110
    res = interpret(f, [3])
    assert res == 111
    res = interpret(f, [0])
    assert res == 0

def test_is():
    class A:
        _alloc_flavor_ = "raw"
        pass
    class B(A): pass
    class C:
        _alloc_flavor_ = "raw"
    def f(i):
        a = A()
        b = B()
        c = C()
        d = None
        e = None
        if i == 0:
            d = a
        elif i == 1:
            d = b
        elif i == 2:
            e = c
        res =  (0x0001*(a is b) | 0x0002*(a is c) | 0x0004*(a is d) |
                0x0008*(a is e) | 0x0010*(b is c) | 0x0020*(b is d) |
                0x0040*(b is e) | 0x0080*(c is d) | 0x0100*(c is e) |
                0x0200*(d is e))
        free_non_gc_object(a)
        free_non_gc_object(b)
        free_non_gc_object(c)
        return res
    a = RPythonAnnotator()
    #does not raise:
    s = a.build_types(f, [int])
    assert s.knowntype == int
    rtyper = RPythonTyper(a)
    rtyper.specialize()
    res = interpret(f, [0])
    assert res == 0x0004
    res = interpret(f, [1])
    assert res == 0x0020
    res = interpret(f, [2])
    assert res == 0x0100
    res = interpret(f, [3])
    assert res == 0x0200

def test_is_mixing():
    class A:
        _alloc_flavor_ = "raw"
        pass
    class B(A): pass
    class C:
        pass
    def f(i):
        a = A()
        b = B()
        c = C()
        d = None
        e = None
        if i == 0:
            d = a
        elif i == 1:
            d = b
        elif i == 2:
            e = c
        res =  (0x0001*(a is b) | 0x0002*(a is c) | 0x0004*(a is d) |
                0x0008*(a is e) | 0x0010*(b is c) | 0x0020*(b is d) |
                0x0040*(b is e) | 0x0080*(c is d) | 0x0100*(c is e) |
                0x0200*(d is e))
        free_non_gc_object(a)
        free_non_gc_object(b)
        return res
    a = RPythonAnnotator()
    #does not raise:
    s = a.build_types(f, [int])
    assert s.knowntype == int
    rtyper = RPythonTyper(a)
    rtyper.specialize()
    res = interpret(f, [0])
    assert res == 0x0004
    res = interpret(f, [1])
    assert res == 0x0020
    res = interpret(f, [2])
    assert res == 0x0100
    res = interpret(f, [3])
    assert res == 0x0200

def test_rtype_nongc_object():
    class TestClass(object):
        _alloc_flavor_ = "raw"
        def __init__(self, a):
            self.a = a
        def method1(self):
            return self.a
    def malloc_and_free(a):
        ci = TestClass(a)
        b = ci.method1()
        free_non_gc_object(ci)
        return b
    a = RPythonAnnotator()
    #does not raise:
    s = a.build_types(malloc_and_free, [SomeAddress()])
    assert isinstance(s, SomeAddress)
    rtyper = RPythonTyper(a)
    rtyper.specialize()
