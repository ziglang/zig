import sys

import py
import pytest

from rpython.flowspace.model import summary
from rpython.rlib.rarithmetic import r_longlong
from rpython.rtyper.lltypesystem.lltype import (typeOf, Signed, getRuntimeTypeInfo,
    identityhash)
from rpython.rtyper.error import TyperError
from rpython.rtyper.rclass import (IR_IMMUTABLE, IR_IMMUTABLE_ARRAY,
    IR_QUASIIMMUTABLE, IR_QUASIIMMUTABLE_ARRAY)
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.translator.translator import TranslationContext, graphof

from rpython.rtyper.annlowlevel import llstr, hlstr


class EmptyBase(object):
    pass

class Random:
    xyzzy = 12
    yadda = 21

# for method calls
class A:
    def f(self):
        return self.g()

    def g(self):
        return 42

class B(A):
    def g(self):
        return 1

class C(B):
    pass

class TestRclass(BaseRtypingTest):

    def test_instanceattr(self):
        def dummyfn():
            x = EmptyBase()
            x.a = 5
            x.a += 1
            return x.a
        res = self.interpret(dummyfn, [])
        assert res == 6

    def test_simple(self):
        def dummyfn():
            x = EmptyBase()
            return x
        res = self.interpret(dummyfn, [])
        assert self.is_of_instance_type(res)

    def test_classattr(self):
        def dummyfn():
            x = Random()
            return x.xyzzy
        res = self.interpret(dummyfn, [])
        assert res == 12

    def test_classattr_both(self):
        class A:
            a = 1
        class B(A):
            a = 2
        def pick(i):
            if i == 0:
                return A
            else:
                return B

        def dummyfn(i):
            C = pick(i)
            i = C()
            return C.a + i.a
        res = self.interpret(dummyfn, [0])
        assert res == 2
        res = self.interpret(dummyfn, [1])
        assert res == 4

    def test_classattr_both2(self):
        class Base(object):
            a = 0
        class A(Base):
            a = 1
        class B(Base):
            a = 2
        def pick(i):
            if i == 0:
                return A
            else:
                return B

        def dummyfn(i):
            C = pick(i)
            i = C()
            return C.a + i.a
        res = self.interpret(dummyfn, [0])
        assert res == 2
        res = self.interpret(dummyfn, [1])
        assert res == 4

    def test_runtime_exception(self):
        class MyExc(Exception):
            pass
        class Sub1(MyExc):
            pass
        class Sub2(MyExc):
            pass
        def pick(flag):
            if flag:
                return Sub1
            else:
                return Sub2
        def g(flag):
            ex = pick(flag)
            raise ex()
        def f(flag):
            try:
                g(flag)
            except Sub1:
                return 1
            except Sub2:
                return 2
            else:
                return 3
        assert self.interpret(f, [True]) == 1
        assert self.interpret(f, [False]) == 2

    def test_classattr_as_defaults(self):
        def dummyfn():
            x = Random()
            x.xyzzy += 1
            return x.xyzzy
        res = self.interpret(dummyfn, [])
        assert res == 13

    def test_overridden_classattr_as_defaults(self):
        class W_Root(object):
            pass
        class W_Thunk(W_Root):
            pass

        THUNK_PLACEHOLDER = W_Thunk()
        W_Root.w_thunkalias = None
        W_Thunk.w_thunkalias = THUNK_PLACEHOLDER

        def dummyfn(x):
            if x == 1:
                t = W_Thunk()
            elif x == 2:
                t = W_Thunk()
                t.w_thunkalias = W_Thunk()
            else:
                t = W_Root()
            return t.w_thunkalias is THUNK_PLACEHOLDER
        res = self.interpret(dummyfn, [1])
        assert res == True

    def test_prebuilt_instance(self):
        a = EmptyBase()
        a.x = 5
        def dummyfn():
            a.x += 1
            return a.x
        self.interpret(dummyfn, [])

    def test_recursive_prebuilt_instance(self):
        a = EmptyBase()
        b = EmptyBase()
        a.x = 5
        b.x = 6
        a.peer = b
        b.peer = a
        def dummyfn():
            return a.peer.peer.peer.x
        res = self.interpret(dummyfn, [])
        assert res == 6

    def test_recursive_prebuilt_instance_classattr(self):
        class Base:
            def m(self):
                return self.d.t.v
        class T1(Base):
            v = 3
        class T2(Base):
            v = 4
        class D:
            def _freeze_(self):
                return True

        t1 = T1()
        t2 = T2()
        T1.d = D()
        T2.d = D()
        T1.d.t = t1

        def call_meth(obj):
            return obj.m()
        def fn():
            return call_meth(t1) + call_meth(t2)
        assert self.interpret(fn, []) == 6

    def test_prebuilt_instances_with_void(self):
        def marker():
            return 42
        a = EmptyBase()
        a.nothing_special = marker
        def dummyfn():
            return a.nothing_special()
        res = self.interpret(dummyfn, [])
        assert res == 42

    def test_simple_method_call(self):
        def f(i):
            if i:
                a = A()
            else:
                a = B()
            return a.f()
        res = self.interpret(f, [True])
        assert res == 42
        res = self.interpret(f, [False])
        assert res == 1

    def test_isinstance(self):
        def f(i):
            if i == 0:
                o = None
            elif i == 1:
                o = A()
            elif i == 2:
                o = B()
            else:
                o = C()
            return 100*isinstance(o, A)+10*isinstance(o, B)+1*isinstance(o ,C)

        res = self.interpret(f, [1])
        assert res == 100
        res = self.interpret(f, [2])
        assert res == 110
        res = self.interpret(f, [3])
        assert res == 111

        res = self.interpret(f, [0])
        assert res == 0

    def test_method_used_in_subclasses_only(self):
        class A:
            def meth(self):
                return 123
        class B(A):
            pass
        def f():
            x = B()
            return x.meth()
        res = self.interpret(f, [])
        assert res == 123

    def test_method_both_A_and_B(self):
        class A:
            def meth(self):
                return 123
        class B(A):
            pass
        def f():
            a = A()
            b = B()
            return a.meth() + b.meth()
        res = self.interpret(f, [])
        assert res == 246

    def test_method_specialized_with_subclass(self):
        class A:
            def meth(self, n):
                return -1
            meth._annspecialcase_ = 'specialize:arg(1)'

        class B(A):
            pass

        def f():
            a = A()
            b = B()
            a.meth(1) # the self of this variant is annotated with A
            b.meth(2) # the self of this variant is annotated with B
            return 42

        res = self.interpret(f, [])
        assert res == 42

    def test_issubclass_type(self):
        class Abstract:
            pass
        class A(Abstract):
            pass
        class B(A):
            pass
        def f(i):
            if i == 0:
                c1 = A()
            else:
                c1 = B()
            return issubclass(type(c1), B)
        assert self.interpret(f, [0]) == False
        assert self.interpret(f, [1]) == True

        def g(i):
            if i == 0:
                c1 = A()
            else:
                c1 = B()
            return issubclass(type(c1), A)
        assert self.interpret(g, [0]) == True
        assert self.interpret(g, [1]) == True

    def test_staticmethod(self):
        class A(object):
            f = staticmethod(lambda x, y: x*y)
        def f():
            a = A()
            return a.f(6, 7)
        res = self.interpret(f, [])
        assert res == 42

    def test_staticmethod2(self):
        class A(object):
            f = staticmethod(lambda x, y: x*y)
        class B(A):
            f = staticmethod(lambda x, y: x+y)
        def f():
            b = B()
            return b.f(6, 7)
        res = self.interpret(f, [])
        assert res == 13

    def test_is(self):
        class A: pass
        class B(A): pass
        class C: pass
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
            return (0x0001*(a is b) | 0x0002*(a is c) | 0x0004*(a is d) |
                    0x0008*(a is e) | 0x0010*(b is c) | 0x0020*(b is d) |
                    0x0040*(b is e) | 0x0080*(c is d) | 0x0100*(c is e) |
                    0x0200*(d is e))
        res = self.interpret(f, [0])
        assert res == 0x0004
        res = self.interpret(f, [1])
        assert res == 0x0020
        res = self.interpret(f, [2])
        assert res == 0x0100
        res = self.interpret(f, [3])
        assert res == 0x0200

    def test_eq(self):
        class A: pass
        class B(A): pass
        class C: pass
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
            return (0x0001*(a == b) | 0x0002*(a == c) | 0x0004*(a == d) |
                    0x0008*(a == e) | 0x0010*(b == c) | 0x0020*(b == d) |
                    0x0040*(b == e) | 0x0080*(c == d) | 0x0100*(c == e) |
                    0x0200*(d == e))
        res = self.interpret(f, [0])
        assert res == 0x0004
        res = self.interpret(f, [1])
        assert res == 0x0020
        res = self.interpret(f, [2])
        assert res == 0x0100
        res = self.interpret(f, [3])
        assert res == 0x0200

    def test_istrue(self):
        class A:
            pass
        def f(i):
            if i == 0:
                a = A()
            else:
                a = None
            if a:
                return 1
            else:
                return 2
        res = self.interpret(f, [0])
        assert res == 1
        res = self.interpret(f, [1])
        assert res == 2

    def test_ne(self):
        class A: pass
        class B(A): pass
        class C: pass
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
            return (0x0001*(a != b) | 0x0002*(a != c) | 0x0004*(a != d) |
                    0x0008*(a != e) | 0x0010*(b != c) | 0x0020*(b != d) |
                    0x0040*(b != e) | 0x0080*(c != d) | 0x0100*(c != e) |
                    0x0200*(d != e))
        res = self.interpret(f, [0])
        assert res == ~0x0004 & 0x3ff
        res = self.interpret(f, [1])
        assert res == ~0x0020 & 0x3ff
        res = self.interpret(f, [2])
        assert res == ~0x0100 & 0x3ff
        res = self.interpret(f, [3])
        assert res == ~0x0200 & 0x3ff

    def test_class___name__(self):
        class ACLS(object): pass
        class Bcls(ACLS): pass
        class CCls(ACLS): pass
        def nameof(cls):
            return cls.__name__
        nameof._annspecialcase_ = "specialize:memo"
        def f(i):
            if i == 1: x = ACLS()
            elif i == 2: x = Bcls()
            else: x = CCls()
            return nameof(x.__class__)
        res = self.interpret(f, [1])
        assert ''.join(res.chars) == 'ACLS'
        res = self.interpret(f, [2])
        assert ''.join(res.chars) == 'Bcls'
        res = self.interpret(f, [3])
        assert ''.join(res.chars) == 'CCls'

    def test_compute_identity_hash(self):
        from rpython.rlib.objectmodel import compute_identity_hash
        class C:
            pass
        class D(C):
            pass
        c = C()
        d = D()
        #
        def f():
            d2 = D()
            return (compute_identity_hash(d2),
                    compute_identity_hash(c),
                    compute_identity_hash(d))

        self.interpret(f, [])
        # check does not crash

    def test_circular_hash_initialization(self):
        class B:
            pass
        class C(B):
            pass
        c1 = C()
        c1.somedict = {c1: True, C(): False}
        def f():
            B().somedict = {}      # force the attribute up
            c1.somedict[c1] = 123
            return len(c1.somedict)
        res = self.interpret(f, [])
        assert res == 2

    def test_type(self):
        class A:
            pass
        class B(A):
            pass
        def g(a):
            return type(a)
        def f(i):
            if i > 0:
                a = A()
            elif i < 0:
                a = B()
            else:
                a = None
            return g(a) is A    # should type(None) work?  returns None for now
        res = self.interpret(f, [1])
        assert res is True
        res = self.interpret(f, [-1])
        assert res is False
        res = self.interpret(f, [0])
        assert res is False

    def test_type_of_constant(self):
        class A:
            pass
        a = A()

        def f():
            return type(a) is A

        res = self.interpret(f, [])


    def test_void_fnptr(self):
        def g():
            return 42
        def f():
            e = EmptyBase()
            e.attr = g
            return e.attr()
        res = self.interpret(f, [])
        assert res == 42

    def test_getattr_on_classes(self):
        class A:
            def meth(self):
                return self.value + 42
        class B(A):
            def meth(self):
                shouldnt**be**seen
        class C(B):
            def meth(self):
                return self.value - 1
        def pick_class(i):
            if i > 0:
                return A
            else:
                return C
        def f(i):
            meth = pick_class(i).meth
            x = C()
            x.value = 12
            return meth(x)   # calls A.meth or C.meth, completely ignores B.meth
        res = self.interpret(f, [1])
        assert res == 54
        res = self.interpret(f, [0])
        assert res == 11

    def test_constant_bound_method(self):
        class C:
            value = 1
            def meth(self):
                return self.value
        meth = C().meth
        def f():
            return meth()
        res = self.interpret(f, [])
        assert res == 1

    def test_mixin(self):
        class Mixin(object):
            _mixin_ = True

            def m(self, v):
                return v

        class Base(object):
            pass

        class A(Base, Mixin):
            pass

        class B(Base, Mixin):
            pass

        class C(B):
            pass

        def f():
            a = A()
            v0 = a.m(2)
            b = B()
            v1 = b.m('x')
            c = C()
            v2 = c.m('y')
            return v0, v1, v2

        res = self.interpret(f, [])
        assert typeOf(res.item0) == Signed

    def test___class___attribute(self):
        class Base(object): pass
        class A(Base): pass
        class B(Base): pass
        class C(A): pass
        def seelater():
            C()
        def f(n):
            if n == 1:
                x = A()
            else:
                x = B()
            y = B()
            result = x.__class__, y.__class__
            seelater()
            return result
        def g():
            cls1, cls2 = f(1)
            return cls1 is A, cls2 is B

        res = self.interpret(g, [])
        assert res.item0
        assert res.item1


    def test_common_class_attribute(self):
        class A:
            def meth(self):
                return self.x
        class B(A):
            x = 42
        class C(A):
            x = 43
        def call_meth(a):
            return a.meth()
        def f():
            b = B()
            c = C()
            return call_meth(b) + call_meth(c)
        assert self.interpret(f, []) == 85

    def test_default_attribute_non_primitive(self):
        class A:
            x = (1, 2)
        def f():
            a = A()
            a.x = (3, 4)
            return a.x[0]
        assert self.interpret(f, []) == 3

    def test_filter_unreachable_methods(self):
        # this creates a family with 20 unreachable methods m(), all
        # hidden by a 21st method m().
        class Base:
            pass
        prev = Base
        for i in range(20):
            class Intermediate(prev):
                def m(self, value=i):
                    return value
            prev = Intermediate
        class Final(prev):
            def m(self):
                return -7
        def f():
            return Final().m()
        res = self.interpret(f, [])
        assert res == -7

    def test_instantiate_despite_abstract_methods(self):
        class A:
            pass
        class B(A):
            def foo(self):
                return 42
        def fn(n):
            # Although the code below is a bit strange, there are
            # subtle ways in which the same situation could occur.
            # One is shown by test_specialize_methods().
            if n < 10:
                x = B()
            else:
                x = A()
            if n < 7:
                return x.foo()
            else:
                return 100
        assert self.interpret(fn, [5]) == 42
        assert self.interpret(fn, [15]) == 100

    def test_specialize_methods(self):
        from rpython.rlib.objectmodel import specialize
        class A:
            @specialize.arg(1)
            def revealconst(self, T):
                return 3 * T
            revealconst.cls = 'A'
        class B(A):
            @specialize.arg(1)
            def revealconst(self, T):
                return 4 * T
            revealconst.cls = 'B'

        def fn():
            a = A()
            b = B()
            return a.revealconst(1) + b.revealconst(2) + a.revealconst(3)
        assert self.interpret(fn, []) == 3 + 8 + 9

    def test_hash_of_none(self):
        from rpython.rlib.objectmodel import compute_hash
        class A:
            pass
        def fn(x):
            if x:
                obj = A()
            else:
                obj = None
            return compute_hash(obj)
        res = self.interpret(fn, [0])
        assert res == 0

    def test_hash_of_only_none(self):
        from rpython.rlib.objectmodel import compute_hash
        def fn():
            obj = None
            return compute_hash(obj)
        res = self.interpret(fn, [])
        assert res == 0


    def test_immutable(self):
        class I(object):
            _immutable_ = True

            def __init__(self, v):
                self.v = v

        i = I(3)
        def f():
            return i.v

        t, typer, graph = self.gengraph(f, [], backendopt=True)
        assert summary(graph) == {}

    def test_immutable_fields(self):
        class A(object):
            _immutable_fields_ = ["x", "y[*]"]

            def __init__(self, x, y):
                self.x = x
                self.y = y

        def f():
            return A(3, [])
        t, typer, graph = self.gengraph(f, [])
        A_TYPE = graph.getreturnvar().concretetype.TO
        accessor = A_TYPE._hints["immutable_fields"]
        assert accessor.fields == {"inst_x": IR_IMMUTABLE,
                                   "inst_y": IR_IMMUTABLE_ARRAY}

    def test_immutable_fields_subclass_1(self):
        class A(object):
            _immutable_fields_ = ["x"]
            def __init__(self, x):
                self.x = x
        class B(A):
            def __init__(self, x, y):
                A.__init__(self, x)
                self.y = y

        def f():
            return B(3, 5)
        t, typer, graph = self.gengraph(f, [])
        B_TYPE = graph.getreturnvar().concretetype.TO
        accessor = B_TYPE._hints["immutable_fields"]
        assert accessor.fields == {"inst_x": IR_IMMUTABLE}

    def test_immutable_fields_subclass_2(self):
        class A(object):
            _immutable_fields_ = ["x"]
            def __init__(self, x):
                self.x = x
        class B(A):
            _immutable_fields_ = ["y"]
            def __init__(self, x, y):
                A.__init__(self, x)
                self.y = y

        def f():
            return B(3, 5)
        t, typer, graph = self.gengraph(f, [])
        B_TYPE = graph.getreturnvar().concretetype.TO
        accessor = B_TYPE._hints["immutable_fields"]
        assert accessor.fields == {"inst_x": IR_IMMUTABLE,
                                   "inst_y": IR_IMMUTABLE}

    def test_immutable_fields_only_in_subclass(self):
        class A(object):
            def __init__(self, x):
                self.x = x
        class B(A):
            _immutable_fields_ = ["y"]
            def __init__(self, x, y):
                A.__init__(self, x)
                self.y = y

        def f():
            return B(3, 5)
        t, typer, graph = self.gengraph(f, [])
        B_TYPE = graph.getreturnvar().concretetype.TO
        accessor = B_TYPE._hints["immutable_fields"]
        assert accessor.fields == {"inst_y": IR_IMMUTABLE}

    def test_immutable_forbidden_inheritance_1(self):
        from rpython.rtyper.rclass import ImmutableConflictError
        class A(object):
            pass
        class B(A):
            _immutable_fields_ = ['v']
        def f():
            A().v = 123
            B()             # crash: class B says 'v' is immutable,
                            # but it is defined on parent class A
        py.test.raises(ImmutableConflictError, self.gengraph, f, [])

    def test_immutable_forbidden_inheritance_2(self):
        from rpython.rtyper.rclass import ImmutableConflictError
        class A(object):
            pass
        class B(A):
            _immutable_ = True
        def f():
            A().v = 123
            B()             # crash: class B has _immutable_ = True
                            # but class A defines 'v' to be mutable
        py.test.raises(ImmutableConflictError, self.gengraph, f, [])

    def test_immutable_ok_inheritance_2(self):
        class A(object):
            _immutable_fields_ = ['v']
        class B(A):
            _immutable_ = True
        def f():
            A().v = 123
            B().w = 456
            return B()
        t, typer, graph = self.gengraph(f, [])
        B_TYPE = graph.getreturnvar().concretetype.TO
        assert B_TYPE._hints["immutable"]
        A_TYPE = B_TYPE.super
        accessor = A_TYPE._hints["immutable_fields"]
        assert accessor.fields == {"inst_v": IR_IMMUTABLE}

    def test_immutable_subclass_1(self):
        from rpython.rtyper.rclass import ImmutableConflictError
        class A(object):
            _immutable_ = True
        class B(A):
            pass
        def f():
            A()
            B().v = 123
            return B()
        py.test.raises(ImmutableConflictError, self.gengraph, f, [])

    def test_immutable_subclass_2(self):
        class A(object):
            pass
        class B(A):
            _immutable_ = True
        def f():
            A()
            B().v = 123
            return B()
        t, typer, graph = self.gengraph(f, [])
        B_TYPE = graph.getreturnvar().concretetype.TO
        assert B_TYPE._hints["immutable"]

    def test_immutable_subclass_void(self):
        class A(object):
            pass
        class B(A):
            _immutable_ = True
        def myfunc():
            pass
        def f():
            A().f = myfunc    # it's ok to add Void attributes to A
            B().v = 123       # even though only B is declared _immutable_
            return B()
        t, typer, graph = self.gengraph(f, [])
        B_TYPE = graph.getreturnvar().concretetype.TO
        assert B_TYPE._hints["immutable"]

    def test_quasi_immutable(self):
        class A(object):
            _immutable_fields_ = ['x', 'y', 'a?', 'b?']
        class B(A):
            pass
        def f():
            a = A()
            a.x = 42
            a.a = 142
            b = B()
            b.x = 43
            b.y = 41
            b.a = 44
            b.b = 45
            return B()
        t, typer, graph = self.gengraph(f, [])
        B_TYPE = graph.getreturnvar().concretetype.TO
        accessor = B_TYPE._hints["immutable_fields"]
        assert accessor.fields == {"inst_y": IR_IMMUTABLE,
                                   "inst_b": IR_QUASIIMMUTABLE}
        found = []
        for op in graph.startblock.operations:
            if op.opname == 'jit_force_quasi_immutable':
                found.append(op.args[1].value)
        assert found == ['mutate_a', 'mutate_a', 'mutate_b']

    def test_quasi_immutable_clashes_with_immutable(self):
        class A(object):
            _immutable_ = True
            _immutable_fields_ = ['a?']
        def f():
            a = A()
            a.x = 42
            a.a = 142
            return A()
        with py.test.raises(TyperError):
            self.gengraph(f, [])

    def test_quasi_immutable_array(self):
        class A(object):
            _immutable_fields_ = ['c?[*]']
        class B(A):
            pass
        def f():
            a = A()
            a.c = [3, 4, 5]
            return A()
        t, typer, graph = self.gengraph(f, [])
        A_TYPE = graph.getreturnvar().concretetype.TO
        accessor = A_TYPE._hints["immutable_fields"]
        assert accessor.fields == {"inst_c": IR_QUASIIMMUTABLE_ARRAY}
        found = []
        for op in graph.startblock.operations:
            if op.opname == 'jit_force_quasi_immutable':
                found.append(op.args[1].value)
        assert found == ['mutate_c']

    def test_bad_type_for_immutable_field_1(self):
        class A:
            _immutable_fields_ = ['lst[*]']
        def f(n):
            a = A()
            a.lst = n
            return a.lst

        with py.test.raises(TyperError):
            self.gengraph(f, [int])

    def test_bad_type_for_immutable_field_2(self):
        from rpython.rtyper.lltypesystem import lltype
        class A:
            _immutable_fields_ = ['lst[*]']
        ARRAY = lltype.GcArray(lltype.Signed)
        def f(n):
            a = A()
            a.lst = lltype.malloc(ARRAY, n)
            return a.lst

        with py.test.raises(TyperError):
            self.gengraph(f, [int])

    def test_bad_type_for_immutable_field_3(self):
        class A:
            _immutable_fields_ = ['lst?[*]']
        def f(n):
            a = A()
            a.lst = n
            return a.lst

        with py.test.raises(TyperError):
            self.gengraph(f, [int])

    def test_calling_object_init(self):
        class A(object):
            pass
        class B(A):
            def __init__(self):
                A.__init__(self)
        def f():
            B()
        self.gengraph(f, [])


    def test__del__(self):
        class A(object):
            def __init__(self):
                self.a = 2
            def __del__(self):
                self.a = 3
        def f():
            a = A()
            return a.a
        t = TranslationContext()
        t.buildannotator().build_types(f, [])
        t.buildrtyper().specialize()
        graph = graphof(t, f)
        TYPE = graph.startblock.operations[0].args[0].value
        RTTI = getRuntimeTypeInfo(TYPE)
        RTTI._obj.query_funcptr # should not raise
        destrptr = RTTI._obj.destructor_funcptr
        assert destrptr is not None

    def test_del_inheritance(self):
        from rpython.rlib import rgc
        class State:
            pass
        s = State()
        s.a_dels = 0
        s.b_dels = 0
        class A(object):
            def __del__(self):
                s.a_dels += 1
        class B(A):
            def __del__(self):
                s.b_dels += 1
        class C(A):
            pass
        def f():
            A()
            B()
            C()
            A()
            B()
            C()
            rgc.collect()
            return s.a_dels * 10 + s.b_dels
        res = f()
        assert res == 42
        t = TranslationContext()
        t.buildannotator().build_types(f, [])
        t.buildrtyper().specialize()
        graph = graphof(t, f)
        TYPEA = graph.startblock.operations[0].args[0].value
        RTTIA = getRuntimeTypeInfo(TYPEA)
        TYPEB = graph.startblock.operations[3].args[0].value
        RTTIB = getRuntimeTypeInfo(TYPEB)
        TYPEC = graph.startblock.operations[6].args[0].value
        RTTIC = getRuntimeTypeInfo(TYPEC)
        queryptra = RTTIA._obj.query_funcptr # should not raise
        queryptrb = RTTIB._obj.query_funcptr # should not raise
        queryptrc = RTTIC._obj.query_funcptr # should not raise
        destrptra = RTTIA._obj.destructor_funcptr
        destrptrb = RTTIB._obj.destructor_funcptr
        destrptrc = RTTIC._obj.destructor_funcptr
        assert destrptra == destrptrc
        assert typeOf(destrptra).TO.ARGS[0] != typeOf(destrptrb).TO.ARGS[0]
        assert destrptra is not None
        assert destrptrb is not None

    def test_del_forbidden(self):
        class A(object):
            def __del__(self):
                self.foo()
            def foo(self):
                self.bar()
            def bar(self):
                pass
            bar._dont_reach_me_in_del_ = True
        def f():
            a = A()
            a.foo()
            a.bar()
        t = TranslationContext()
        t.buildannotator().build_types(f, [])
        e = py.test.raises(TyperError, t.buildrtyper().specialize)
        print e.value

    def test_instance_repr(self):
        from rpython.rlib.objectmodel import current_object_addr_as_int
        class FooBar(object):
            pass
        def f():
            x = FooBar()
            # on lltype, the RPython-level repr of an instance contains the
            # current object address
            return current_object_addr_as_int(x), str(x)

        res = self.interpret(f, [])
        xid, xstr = self.ll_unpack_tuple(res, 2)
        xstr = self.ll_to_string(xstr)
        print xid, xstr
        assert 'FooBar' in xstr
        from rpython.rlib.rarithmetic import r_uint
        expected = hex(r_uint(xid)).lower().replace('l', '')
        assert expected in xstr

    def test_hash_via_type(self):
        from rpython.annotator import model as annmodel
        from rpython.rtyper import extregistry
        from rpython.rtyper.annlowlevel import cast_object_to_ptr
        from rpython.rlib.objectmodel import compute_identity_hash

        class Z(object):
            pass

        def my_gethash(z):
            not_implemented

        def ll_my_gethash(ptr):
            return identityhash(ptr)    # from lltype

        class MyGetHashEntry(extregistry.ExtRegistryEntry):
            _about_ = my_gethash
            def compute_result_annotation(self, s_instance):
                return annmodel.SomeInteger()
            def specialize_call(self, hop):
                [v_instance] = hop.inputargs(*hop.args_r)
                hop.exception_is_here()
                return hop.gendirectcall(ll_my_gethash, v_instance)

        def f(n):
            z = Z()
            got = my_gethash(z)
            expected = compute_identity_hash(z)
            return got - expected

        res = self.interpret(f, [5])
        assert res == 0

    def test_order_of_fields(self):
        class A(object):
            pass
        def f(n):
            a = A()
            a.as_int = n
            a.as_char = chr(n)
            a.as_unichar = unichr(n)
            a.as_double = n + 0.5
            a.as_bool = bool(n)
            a.as_void = None
            a.as_longlong = r_longlong(n)
            a.as_reference = A()
            return a

        res = self.interpret(f, [5])
        names = list(typeOf(res).TO._names)
        i = names.index('inst_as_int')
        c = names.index('inst_as_char')
        u = names.index('inst_as_unichar')
        d = names.index('inst_as_double')
        b = names.index('inst_as_bool')
        v = names.index('inst_as_void')
        l = names.index('inst_as_longlong')
        r = names.index('inst_as_reference')
        assert v == 1      # void fields are first
        assert sorted([c, b]) == [7, 8]
        if sys.maxint == 2147483647:
            assert sorted([u, i, r]) == [4, 5, 6]        # 32-bit types
            assert sorted([d, l]) == [2, 3]              # 64-bit types
        else:
            assert sorted([u]) == [6]                    # 32-bit types
            assert sorted([i, r, d, l]) == [2, 3, 4, 5]  # 64-bit types


    def test_iter(self):
        class Iterable(object):
            def __init__(self):
                self.counter = 0

            def __iter__(self):
                return self

            def next(self):
                if self.counter == 5:
                    raise StopIteration
                self.counter += 1
                return self.counter - 1

        def f():
            i = Iterable()
            s = 0
            for elem in i:
                s += elem
            return s

        assert self.interpret(f, []) == f()

    def test_iter_2_kinds(self):
        class BaseIterable(object):
            def __init__(self):
                self.counter = 0

            def __iter__(self):
                return self

            def next(self):
                if self.counter >= 5:
                    raise StopIteration
                self.counter += self.step
                return self.counter - 1

        class Iterable(BaseIterable):
            step = 1

        class OtherIter(BaseIterable):
            step = 2

        def f(k):
            if k:
                i = Iterable()
            else:
                i = OtherIter()
            s = 0
            for elem in i:
                s += elem
            return s

        assert self.interpret(f, [True]) == f(True)
        assert self.interpret(f, [False]) == f(False)

    @pytest.mark.xfail # XXX next support in rpython is broken!
    def test_iter_bug_exception(self):
        class Iterable(object):
            def __iter__(self):
                return self

            def next(self):
                raise TyperError

        def f():
            i = Iterable()
            it = iter(i)
            try:
                next(it)
            except StopIteration:
                return -7
            except TypeError:
                return -9
            return 12

        assert self.interpret(f, []) == f()

    def test_indexing(self):
        class A(object):
            def __init__(self, data):
                self.data = data

            def __getitem__(self, i):
                return self.data[i]

            def __setitem__(self, i, v):
                self.data[i] = v

            def __getslice__(self, start, stop):
                assert start >= 0
                assert stop >= 0
                return self.data[start:stop]

            def __setslice__(self, start, stop, v):
                assert start >= 0
                assert stop >= 0
                i = 0
                for n in range(start, stop):
                    self.data[n] = v[i]
                    i += 1

        def getitem(i):
            a = A("abcdefg")
            return a[i]

        def setitem(i, v):
            a = A([0] * 5)
            a[i] = v
            return a[i]

        def getslice(start, stop):
            a = A([1, 2, 3, 4, 5, 6])
            sum = 0
            for i in a[start:stop]:
                sum += i
            return sum

        def setslice(start, stop, i):
            a = A([0] * stop)
            a[start:stop] = range(start, stop)
            return a[i]

        assert self.interpret(getitem, [0]) == getitem(0)
        assert self.interpret(getitem, [1]) == getitem(1)
        assert self.interpret(setitem, [0, 5]) == setitem(0, 5)
        assert self.interpret(getslice, [0, 4]) == getslice(0, 4)
        assert self.interpret(getslice, [1, 4]) == getslice(1, 4)
        assert self.interpret(setslice, [4, 6, 5]) == setslice(4, 6, 5)

    def test_len(self):
        class A(object):
            def __len__(self):
                return 5

        def fn():
            a = A()
            return len(a)

        assert self.interpret(fn, []) == fn()

    def test_init_with_star_args(self):
        class Base(object):
            def __init__(self, a, b):
                self.a = a
                self.b = b
        class A(Base):
            def __init__(self, *args):
                Base.__init__(self, *args)
                self.c = -1
        cls = [Base, A]

        def f(k, a, b):
            return cls[k](a, b).b

        assert self.interpret(f, [1, 4, 7]) == 7

    def test_flatten_convert_const(self):
        # check that we can convert_const() a chain of more than 1000
        # instances
        class A(object):
            def __init__(self, next):
                self.next = next
        a = None
        for i in range(1500):
            a = A(a)
        def f():
            return a.next.next.next.next is not None
        assert self.interpret(f, []) == True

    def test_str_of_type(self):
        class A(object):
            pass

        class B(A):
            pass

        def f(i):
            if i:
                a = A()
            else:
                a = B()
            return str(type(a))
        assert "A" in hlstr(self.interpret(f, [1]))
        assert "B" in hlstr(self.interpret(f, [0]))

        def g(i):
            if i:
                a = A()
            else:
                a = B()
            return str(a.__class__)
        assert "A" in hlstr(self.interpret(g, [1]))
        assert "B" in hlstr(self.interpret(g, [0]))
