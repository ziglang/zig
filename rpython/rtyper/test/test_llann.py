import py

from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import SomePtr, lltype_to_annotation
from rpython.conftest import option
from rpython.rtyper.annlowlevel import (annotate_lowlevel_helper,
    MixLevelHelperAnnotator, PseudoHighLevelCallable, llhelper,
    cast_instance_to_base_ptr, cast_base_ptr_to_instance)
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.lltypesystem.lltype import *
from rpython.rtyper.rclass import fishllattr, OBJECTPTR
from rpython.rtyper.test.test_llinterp import interpret
from rpython.translator.translator import TranslationContext


# helpers

def annotated_calls(ann, ops=('simple_call,')):
    for block in ann.annotated:
        for op in block.operations:
            if op.opname in ops:
                yield op


def derived(op, orig):
    if op.args[0].value.__name__.startswith(orig):
        return op.args[0].value
    else:
        return None


class TestLowLevelAnnotateTestCase:
    from rpython.annotator.annrpython import RPythonAnnotator

    def annotate(self, ll_function, argtypes):
        self.a = self.RPythonAnnotator()
        graph = annotate_lowlevel_helper(self.a, ll_function, argtypes)
        if option.view:
            self.a.translator.view()
        return self.a.binding(graph.getreturnvar())

    def test_simple(self):
        S = GcStruct("s", ('v', Signed))
        def llf():
            s = malloc(S)
            return s.v
        s = self.annotate(llf, [])
        assert s.knowntype == int

    def test_simple2(self):
        S = Struct("s", ('v', Signed))
        S2 = GcStruct("s2", ('a', S), ('b', S))
        def llf():
            s = malloc(S2)
            return s.a.v+s.b.v
        s = self.annotate(llf, [])
        assert s.knowntype == int

    def test_array(self):
        A = GcArray(('v', Signed))
        def llf():
            a = malloc(A, 1)
            return a[0].v
        s = self.annotate(llf, [])
        assert s.knowntype == int

    def test_array_longlong(self):
        from rpython.rlib.rarithmetic import r_longlong
        A = GcArray(('v', Signed))
        one = r_longlong(1)
        def llf():
            a = malloc(A, one)
            return a[0].v
        s = self.annotate(llf, [])
        assert s.knowntype == int

    def test_prim_array(self):
        A = GcArray(Signed)
        def llf():
            a = malloc(A, 1)
            return a[0]
        s = self.annotate(llf, [])
        assert s.knowntype == int

    def test_prim_array_setitem(self):
        A = GcArray(Signed)
        def llf():
            a = malloc(A, 1)
            a[0] = 3
            return a[0]
        s = self.annotate(llf, [])
        assert s.knowntype == int

    def test_cast_simple_widening(self):
        S2 = Struct("s2", ('a', Signed))
        S1 = Struct("s1", ('sub1', S2), ('sub2', S2))
        PS1 = Ptr(S1)
        PS2 = Ptr(S2)
        def llf(p1):
            p2 = p1.sub1
            p3 = cast_pointer(PS1, p2)
            return p3
        s = self.annotate(llf, [SomePtr(PS1)])
        assert isinstance(s, SomePtr)
        assert s.ll_ptrtype == PS1

    def test_cast_simple_widening_from_gc(self):
        S2 = GcStruct("s2", ('a', Signed))
        S1 = GcStruct("s1", ('sub1', S2), ('x', Signed))
        PS1 = Ptr(S1)
        def llf():
            p1 = malloc(S1)
            p2 = p1.sub1
            p3 = cast_pointer(PS1, p2)
            return p3
        s = self.annotate(llf, [])
        assert isinstance(s, SomePtr)
        assert s.ll_ptrtype == PS1

    def test_cast_pointer(self):
        S3 = GcStruct("s3", ('a', Signed))
        S2 = GcStruct("s3", ('sub', S3))
        S1 = GcStruct("s1", ('sub', S2))
        PS1 = Ptr(S1)
        PS2 = Ptr(S2)
        PS3 = Ptr(S3)
        def llf():
            p1 = malloc(S1)
            p2 = p1.sub
            p3 = p2.sub
            p12 = cast_pointer(PS1, p2)
            p13 = cast_pointer(PS1, p3)
            p21 = cast_pointer(PS2, p1)
            p23 = cast_pointer(PS2, p3)
            p31 = cast_pointer(PS3, p1)
            p32 = cast_pointer(PS3, p2)
            return p12, p13, p21, p23, p31, p32
        s = self.annotate(llf, [])
        assert [x.ll_ptrtype for x in s.items] == [PS1, PS1, PS2, PS2, PS3, PS3]


    def test_array_length(self):
        A = GcArray(('v', Signed))
        def llf():
            a = malloc(A, 1)
            return len(a)
        s = self.annotate(llf, [])
        assert s.knowntype == int

    def test_funcptr(self):
        F = FuncType((Signed,), Signed)
        PF = Ptr(F)
        def llf(p):
            return p(0)
        s = self.annotate(llf, [SomePtr(PF)])
        assert s.knowntype == int


    def test_ll_calling_ll(self):
        A = GcArray(Float)
        B = GcArray(Signed)
        def ll_make(T, n):
            x = malloc(T, n)
            return x
        def ll_get(T, x, i):
            return x[i]
        def llf():
            a = ll_make(A, 3)
            b = ll_make(B, 2)
            a[0] = 1.0
            b[1] = 3
            y0 = ll_get(A, a, 1)
            y1 = ll_get(B, b, 1)
            #
            a2 = ll_make(A, 4)
            a2[0] = 2.0
            return ll_get(A, a2, 1)
        s = self.annotate(llf, [])
        a = self.a
        assert s == annmodel.SomeFloat()

        seen = {}
        ngraphs = len(a.translator.graphs)

        vTs = []
        for call in annotated_calls(a):
            if derived(call, "ll_"):

                func, T = [x.value for x in call.args[0:2]]
                if (func, T) in seen:
                    continue
                seen[func, T] = True

                desc = a.bookkeeper.getdesc(func)
                g = desc.specialize([a.binding(x) for x in call.args[1:]])

                args = g.getargs()
                rv = g.getreturnvar()
                if func is ll_get:
                    vT, vp, vi = args
                    assert a.binding(vT) == a.bookkeeper.immutablevalue(T)
                    assert a.binding(vi).knowntype == int
                    assert a.binding(vp).ll_ptrtype.TO == T
                    assert a.binding(rv) == lltype_to_annotation(T.OF)
                elif func is ll_make:
                    vT, vn = args
                    assert a.binding(vT) == a.bookkeeper.immutablevalue(T)
                    assert a.binding(vn).knowntype == int
                    assert a.binding(rv).ll_ptrtype.TO == T
                else:
                    assert False, func
                vTs.append(vT)

        assert len(seen) == 4

        return a, vTs # reused by a test in test_rtyper

    def test_ll_calling_ll2(self):
        A = GcArray(Float)
        B = GcArray(Signed)
        def ll_make(T, n):
            x = malloc(T, n)
            return x
        def ll_get(x, i):
            return x[i]
        def makelen4(T):
            return ll_make(T, 4)
        def llf():
            a = ll_make(A, 3)
            b = ll_make(B, 2)
            a[0] = 1.0
            b[1] = 3
            y0 = ll_get(a, 1)
            y1 = ll_get(b, 1)
            #
            a2 = makelen4(A)
            a2[0] = 2.0
            return ll_get(a2, 1)
        s = self.annotate(llf, [])
        a = self.a
        assert s == annmodel.SomeFloat()

        seen = {}

        def q(v):
            s = a.binding(v)
            if s.is_constant():
                return s.const
            else:
                return s.ll_ptrtype

        vTs = []

        for call in annotated_calls(a):
            if derived(call, "ll_")  or derived(call, "makelen4"):

                func, T = [q(x) for x in call.args[0:2]]
                if (func, T) in seen:
                    continue
                seen[func, T] = True

                desc = a.bookkeeper.getdesc(func)
                g = desc.specialize([a.binding(x) for x in call.args[1:]])

                args = g.getargs()
                rv = g.getreturnvar()

                if func is ll_make:
                    vT, vn = args
                    assert a.binding(vT) == a.bookkeeper.immutablevalue(T)
                    assert a.binding(vn).knowntype == int
                    assert a.binding(rv).ll_ptrtype.TO == T
                    vTs.append(vT)
                elif func is makelen4:
                    vT, = args
                    assert a.binding(vT) == a.bookkeeper.immutablevalue(T)
                    assert a.binding(rv).ll_ptrtype.TO == T
                    vTs.append(vT)
                elif func is ll_get:
                    vp, vi = args
                    assert a.binding(vi).knowntype == int
                    assert a.binding(vp).ll_ptrtype == T
                    assert a.binding(rv) == lltype_to_annotation(
                        T.TO.OF)
                else:
                    assert False, func

        assert len(seen) == 5

        return a, vTs # reused by a test in test_rtyper

    def test_ll_stararg(self):
        A = GcArray(Float)
        B = GcArray(Signed)
        def ll_sum(*args):
            result = 0
            if len(args) > 0:
                result += args[0]
            if len(args) > 1:
                result += args[1]
            if len(args) > 2:
                result += args[2]
            if len(args) > 3:
                result += args[3]
            return result
        def llf():
            a = ll_sum()
            b = ll_sum(4, 5)
            c = ll_sum(2.5)
            d = ll_sum(4, 5.25)
            e = ll_sum(1000, 200, 30, 4)
            f = ll_sum(1000, 200, 30, 5)
            return a, b, c, d, e, f
        s = self.annotate(llf, [])
        assert isinstance(s, annmodel.SomeTuple)
        assert s.items[0].knowntype is int
        assert s.items[0].const == 0
        assert s.items[1].knowntype is int
        assert s.items[2].knowntype is float
        assert s.items[3].knowntype is float
        assert s.items[4].knowntype is int
        assert s.items[5].knowntype is int

    def test_str_vs_ptr(self):
        S = GcStruct('s', ('x', Signed))
        def ll_stuff(x):
            if x is None or isinstance(x, str):
                return 2
            else:
                return 3
        def llf():
            x = ll_stuff("hello")
            y = ll_stuff(nullptr(S))
            return x, y
        s = self.annotate(llf, [])
        assert isinstance(s, annmodel.SomeTuple)
        assert s.items[0].is_constant()
        assert s.items[0].const == 2
        assert s.items[1].is_constant()
        assert s.items[1].const == 3

    def test_getRuntimeTypeInfo(self):
        S = GcStruct('s', ('x', Signed), rtti=True)
        def llf():
            return getRuntimeTypeInfo(S)
        s = self.annotate(llf, [])
        assert isinstance(s, SomePtr)
        assert s.ll_ptrtype == Ptr(RuntimeTypeInfo)
        assert s.const == getRuntimeTypeInfo(S)

    def test_runtime_type_info(self):
        S = GcStruct('s', ('x', Signed), rtti=True)
        def llf(p):
            return runtime_type_info(p)
        s = self.annotate(llf, [SomePtr(Ptr(S))])
        assert isinstance(s, SomePtr)
        assert s.ll_ptrtype == Ptr(RuntimeTypeInfo)

    def test_cast_primitive(self):
        def llf(u):
            return cast_primitive(Signed, u)
        s = self.annotate(llf, [annmodel.SomeInteger(unsigned=True)])
        assert s.knowntype == int
        def llf(s):
            return cast_primitive(Unsigned, s)
        s = self.annotate(llf, [annmodel.SomeInteger()])
        assert s.unsigned == True

    def test_pbctype(self):
        TYPE = Void
        TYPE2 = Signed
        def g(lst):
            n = lst[0]
            if isinstance(TYPE, Number):
                result = 123
            else:
                result = 456
            if isinstance(TYPE2, Number):
                result += 1
            return result + n
        def llf():
            lst = [5]
            g(lst)
            lst.append(6)
        self.annotate(llf, [])

    def test_adtmeths(self):
        def h_length(s):
            return s.foo
        S = GcStruct("S", ('foo', Signed),
                     adtmeths={"h_length": h_length,
                               "stuff": 12})
        def llf():
            s = malloc(S)
            s.foo = 321
            return s.h_length()
        s = self.annotate(llf, [])
        assert s.knowntype == int and not s.is_constant()

        def llf():
            s = malloc(S)
            return s.stuff
        s = self.annotate(llf, [])
        assert s.is_constant() and s.const == 12


def test_pseudohighlevelcallable():
    t = TranslationContext()
    t.buildannotator()
    rtyper = t.buildrtyper()
    rtyper.specialize()
    a = MixLevelHelperAnnotator(rtyper)

    class A:
        value = 5
        def double(self):
            return self.value * 2

    def fn1(a):
        a2 = A()
        a2.value = a.double()
        return a2

    s_A, r_A = a.s_r_instanceof(A)
    fn1ptr = a.delayedfunction(fn1, [s_A], s_A)
    pseudo = PseudoHighLevelCallable(fn1ptr, [s_A], s_A)

    def fn2(n):
        a = A()
        a.value = n
        a2 = pseudo(a)
        return a2.value

    graph = a.getgraph(fn2, [annmodel.SomeInteger()], annmodel.SomeInteger())
    a.finish()

    llinterp = LLInterpreter(rtyper)
    res = llinterp.eval_graph(graph, [21])
    assert res == 42


def test_llhelper():
    S = GcStruct('S', ('x', Signed), ('y', Signed))
    def f(s,z):
        return s.x*s.y+z

    def g(s):
        return s.x+s.y

    F = Ptr(FuncType([Ptr(S), Signed], Signed))
    G = Ptr(FuncType([Ptr(S)], Signed))

    def h(x, y, z):
        s = malloc(S)
        s.x = x
        s.y = y
        fptr = llhelper(F, f)
        gptr = llhelper(G, g)
        assert typeOf(fptr) == F
        return fptr(s, z)+fptr(s, z*2)+gptr(s)

    res = interpret(h, [8, 5, 2])
    assert res == 99

def test_llhelper_multiple_functions():
    S = GcStruct('S', ('x', Signed), ('y', Signed))
    def f(s):
        return s.x - s.y
    def g(s):
        return s.x + s.y

    F = Ptr(FuncType([Ptr(S)], Signed))

    myfuncs = [f, g]

    def h(x, y, z):
        s = malloc(S)
        s.x = x
        s.y = y
        fptr = llhelper(F, myfuncs[z])
        assert typeOf(fptr) == F
        return fptr(s)

    res = interpret(h, [80, 5, 0])
    assert res == 75
    res = interpret(h, [80, 5, 1])
    assert res == 85


def test_cast_instance_to_base_ptr():
    class A:
        def __init__(self, x, y):
            self.x = x
            self.y = y

    def f(x, y):
        if x > 20:
            a = None
        else:
            a = A(x, y)
        a1 = cast_instance_to_base_ptr(a)
        return a1

    res = interpret(f, [5, 10])
    assert typeOf(res) == OBJECTPTR
    assert fishllattr(res, 'x') == 5
    assert fishllattr(res, 'y') == 10

    res = interpret(f, [25, 10])
    assert res == nullptr(OBJECTPTR.TO)


def test_cast_base_ptr_to_instance():
    class A:
        def __init__(self, x, y):
            self.x = x
            self.y = y

    def f(x, y):
        if x > 20:
            a = None
        else:
            a = A(x, y)
        a1 = cast_instance_to_base_ptr(a)
        b = cast_base_ptr_to_instance(A, a1)
        return a is b

    assert f(5, 10) is True
    assert f(25, 10) is True

    res = interpret(f, [5, 10])
    assert res is True
    res = interpret(f, [25, 10])
    assert res is True
