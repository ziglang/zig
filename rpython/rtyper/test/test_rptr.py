import sys

import py

from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import SomePtr
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.rlib.rarithmetic import is_valid_int
from rpython.rtyper.annlowlevel import annotate_lowlevel_helper, LowLevelAnnotatorPolicy
from rpython.rtyper.lltypesystem import llmemory, lltype
from rpython.rtyper.rtyper import RPythonTyper


# ____________________________________________________________

def ll_rtype(llfn, argtypes=[]):
    a = RPythonAnnotator()
    graph = annotate_lowlevel_helper(a, llfn, argtypes)
    s = a.binding(graph.getreturnvar())
    t = a.translator
    typer = RPythonTyper(a)
    typer.specialize()
    #t.view()
    t.checkgraphs()
    return s, t

def test_cast_pointer():
    S = lltype.GcStruct('s', ('x', lltype.Signed))
    S1 = lltype.GcStruct('s1', ('sub', S))
    S2 = lltype.GcStruct('s2', ('sub', S1))
    PS = lltype.Ptr(S)
    PS2 = lltype.Ptr(S2)
    def lldown(p):
        return lltype.cast_pointer(PS, p)
    s, t = ll_rtype(lldown, [SomePtr(PS2)])
    assert s.ll_ptrtype == PS
    def llup(p):
        return lltype.cast_pointer(PS2, p)
    s, t = ll_rtype(llup, [SomePtr(PS)])
    assert s.ll_ptrtype == PS2

def test_runtime_type_info():
    S = lltype.GcStruct('s', ('x', lltype.Signed), rtti=True)
    def ll_example(p):
        return (lltype.runtime_type_info(p),
                lltype.runtime_type_info(p) == lltype.getRuntimeTypeInfo(S))

    assert ll_example(lltype.malloc(S)) == (lltype.getRuntimeTypeInfo(S), True)
    s, t = ll_rtype(ll_example, [SomePtr(lltype.Ptr(S))])
    assert s == annmodel.SomeTuple([SomePtr(lltype.Ptr(lltype.RuntimeTypeInfo)),
                                    annmodel.SomeBool()])

from rpython.rtyper.test.test_llinterp import interpret, gengraph

def test_adtmeths():
    policy = LowLevelAnnotatorPolicy()

    def h_newstruct():
        return lltype.malloc(S)

    S = lltype.GcStruct('s', ('x', lltype.Signed),
                 adtmeths={"h_newstruct": h_newstruct})

    def f():
        return S.h_newstruct()

    s = interpret(f, [], policy=policy)

    assert lltype.typeOf(s) == lltype.Ptr(S)

    def h_alloc(n):
        return lltype.malloc(A, n)
    def h_length(a):
        return len(a)

    A = lltype.GcArray(lltype.Signed,
                adtmeths={"h_alloc": h_alloc,
                          "h_length": h_length,
                          'flag': True})

    def f():
        return A.h_alloc(10)

    a = interpret(f, [], policy=policy)

    assert lltype.typeOf(a) == lltype.Ptr(A)
    assert len(a) == 10


    def f():
        a = A.h_alloc(10)
        return a.h_length()

    res = interpret(f, [], policy=policy)
    assert res == 10

    def f():
        return A.flag
    res = interpret(f, [], policy=policy)
    assert res

def test_odd_ints():
    T = lltype.GcStruct('T')
    S = lltype.GcStruct('S', ('t', T))
    PT = lltype.Ptr(T)
    PS = lltype.Ptr(S)
    def fn(n):
        s = lltype.cast_int_to_ptr(PS, n)
        assert lltype.typeOf(s) == PS
        assert lltype.cast_ptr_to_int(s) == n
        t = lltype.cast_pointer(PT, s)
        assert lltype.typeOf(t) == PT
        assert lltype.cast_ptr_to_int(t) == n
        assert s == lltype.cast_pointer(PS, t)

    interpret(fn, [11521])

def test_odd_ints_opaque():
    T = lltype.GcStruct('T')
    Q = lltype.GcOpaqueType('Q')
    PT = lltype.Ptr(T)
    PQ = lltype.Ptr(Q)
    def fn(n):
        t = lltype.cast_int_to_ptr(PT, n)
        assert lltype.typeOf(t) == PT
        assert lltype.cast_ptr_to_int(t) == n
        o = lltype.cast_opaque_ptr(PQ, t)
        assert lltype.cast_ptr_to_int(o) == n

    fn(13)
    interpret(fn, [11521])

def test_ptr():
    S = lltype.GcStruct('s')
    def ll_example():
        return lltype.malloc(lltype.Ptr(S).TO)

    p = interpret(ll_example, [])
    assert lltype.typeOf(p) == lltype.Ptr(S)

def test_cast_opaque_ptr():
    O = lltype.GcOpaqueType('O')
    Q = lltype.GcOpaqueType('Q')
    S = lltype.GcStruct('S', ('x', lltype.Signed))
    def fn():
        s = lltype.malloc(S)
        o = lltype.cast_opaque_ptr(lltype.Ptr(O), s)
        q = lltype.cast_opaque_ptr(lltype.Ptr(Q), o)
        p = lltype.cast_opaque_ptr(lltype.Ptr(S), q)
        return p == s
    res = interpret(fn, [])
    assert res is True

    O1 = lltype.OpaqueType('O')
    S1 = lltype.Struct('S1', ('x', lltype.Signed))
    s1 = lltype.malloc(S1, immortal=True)
    def fn1():
        o1 = lltype.cast_opaque_ptr(lltype.Ptr(O1), s1)
        p1 = lltype.cast_opaque_ptr(lltype.Ptr(S1), o1)
        return p1 == s1
    res = interpret(fn1, [])
    assert res is True

def test_address():
    S = lltype.GcStruct('S')
    p1 = lltype.nullptr(S)
    p2 = lltype.malloc(S)

    def g(p):
        return bool(llmemory.cast_ptr_to_adr(p))
    def fn(n):
        if n < 0:
            return g(p1)
        else:
            return g(p2)

    res = interpret(fn, [-5])
    assert res is False
    res = interpret(fn, [5])
    assert res is True

def test_cast_adr_to_int():
    S = lltype.Struct('S')
    p = lltype.malloc(S, immortal=True)
    def fn(n):
        a = llmemory.cast_ptr_to_adr(p)
        if n == 2:
            return llmemory.cast_adr_to_int(a, "emulated")
        elif n == 4:
            return llmemory.cast_adr_to_int(a, "symbolic")
        else:
            return llmemory.cast_adr_to_int(a, "forced")

    res = interpret(fn, [2])
    assert is_valid_int(res)
    assert res == lltype.cast_ptr_to_int(p)
    #
    res = interpret(fn, [4])
    assert isinstance(res, llmemory.AddressAsInt)
    assert llmemory.cast_int_to_adr(res) == llmemory.cast_ptr_to_adr(p)
    #
    res = interpret(fn, [6])
    assert is_valid_int(res)
    from rpython.rtyper.lltypesystem import rffi
    assert res == rffi.cast(lltype.Signed, p)

def test_flavored_malloc():
    T = lltype.GcStruct('T', ('y', lltype.Signed))
    def fn(n):
        p = lltype.malloc(T, flavor='gc')
        p.y = n
        return p.y

    res = interpret(fn, [232])
    assert res == 232

    S = lltype.Struct('S', ('x', lltype.Signed))
    def fn(n):
        p = lltype.malloc(S, flavor='raw')
        p.x = n
        result = p.x
        lltype.free(p, flavor='raw')
        return result

    res = interpret(fn, [23])
    assert res == 23

    S = lltype.Struct('S', ('x', lltype.Signed))
    def fn(n):
        p = lltype.malloc(S, flavor='raw', track_allocation=False)
        p.x = n
        result = p.x
        return result

    res = interpret(fn, [23])
    assert res == 23

    S = lltype.Struct('S', ('x', lltype.Signed))
    def fn(n):
        p = lltype.malloc(S, flavor='raw', track_allocation=False)
        p.x = n
        result = p.x
        lltype.free(p, flavor='raw', track_allocation=False)
        return result

    res = interpret(fn, [23])
    assert res == 23

def test_memoryerror():
    A = lltype.Array(lltype.Signed)
    def fn(n):
        try:
            a = lltype.malloc(A, n, flavor='raw')
        except MemoryError:
            return -42
        else:
            res = len(a)
            lltype.free(a, flavor='raw')
            return res

    res = interpret(fn, [123])
    assert res == 123

    res = interpret(fn, [sys.maxint])
    assert res == -42


def test_call_ptr():
    def f(x, y, z):
        return x+y+z
    FTYPE = lltype.FuncType([lltype.Signed, lltype.Signed, lltype.Signed], lltype.Signed)
    fptr = lltype.functionptr(FTYPE, "f", _callable=f)

    def g(x, y, z):
        tot = 0
        tot += fptr(x, y, z)
        tot += fptr(*(x, y, z))
        tot += fptr(x, *(x, z))
        return tot

    res = interpret(g, [1, 2, 4])
    assert res == g(1, 2, 4)

    def wrong(x, y):
        fptr(*(x, y))

    py.test.raises(TypeError, "interpret(wrong, [1, 2])")


def test_ptr_str():
    def f():
        return str(p)

    S = lltype.GcStruct('S', ('x', lltype.Signed))
    p = lltype.malloc(S)

    res = interpret(f, [])
    assert res.chars[0] == '0'
    assert res.chars[1] == 'x'


def test_first_subfield_access_is_cast_pointer():
    B = lltype.GcStruct("B", ('x', lltype.Signed))
    C = lltype.GcStruct("C", ('super', B), ('y', lltype.Signed))
    def f():
        c = lltype.malloc(C)
        c.super.x = 1
        c.y = 2
        return c.super.x + c.y
    s, t = ll_rtype(f, [])
    from rpython.translator.translator import graphof
    from rpython.flowspace.model import summary
    graph = graphof(t, f)
    graphsum = summary(graph)
    assert 'getsubstruct' not in graphsum
    assert 'cast_pointer' in graphsum



def test_interior_ptr():
    S = lltype.Struct("S", ('x', lltype.Signed))
    T = lltype.GcStruct("T", ('s', S))
    def f():
        t = lltype.malloc(T)
        t.s.x = 1
        return t.s.x
    res = interpret(f, [])
    assert res == 1

def test_interior_ptr_with_index():
    S = lltype.Struct("S", ('x', lltype.Signed))
    T = lltype.GcArray(S)
    def f():
        t = lltype.malloc(T, 1)
        t[0].x = 1
        return t[0].x
    res = interpret(f, [])
    assert res == 1

def test_interior_ptr_convert():
    S = lltype.Struct("S", ("x", lltype.Signed))
    T = lltype.GcArray(S)
    def f(i):
        t = lltype.malloc(T, 2)
        if i:
            x = t[0]
        else:
            x = t[1]
        x.x = 3
        return t[0].x

    res = interpret(f, [13])
    assert res == 3

def test_interior_ptr_with_field_and_index():
    S = lltype.Struct("S", ('x', lltype.Signed))
    T = lltype.GcStruct("T", ('items', lltype.Array(S)))
    def f():
        t = lltype.malloc(T, 1)
        t.items[0].x = 1
        return t.items[0].x
    res = interpret(f, [])
    assert res == 1

def test_interior_ptr_with_index_and_field():
    S = lltype.Struct("S", ('x', lltype.Signed))
    T = lltype.Struct("T", ('s', S))
    U = lltype.GcArray(T)
    def f():
        u = lltype.malloc(U, 1)
        u[0].s.x = 1
        return u[0].s.x
    res = interpret(f, [])
    assert res == 1

def test_interior_ptr_len():
    S = lltype.Struct("S", ('x', lltype.Signed))
    T = lltype.GcStruct("T", ('items', lltype.Array(S)))
    def f():
        t = lltype.malloc(T, 1)
        return len(t.items)
    res = interpret(f, [])
    assert res == 1

def test_interior_ptr_with_setitem():
    T = lltype.GcStruct("T", ('s', lltype.Array(lltype.Signed)))
    def f():
        t = lltype.malloc(T, 1)
        t.s[0] = 1
        return t.s[0]
    res = interpret(f, [])
    assert res == 1

def test_isinstance_ptr():
    S = lltype.GcStruct("S", ('x', lltype.Signed))
    def f(n):
        x = isinstance(lltype.Signed, lltype.Ptr)
        return x + (lltype.typeOf(x) is lltype.Ptr(S)) + len(n)
    def lltest():
        f([])
        return f([1])
    s, t = ll_rtype(lltest, [])
    assert s.is_constant() == False

def test_staticadtmeths():
    ll_func = lltype.staticAdtMethod(lambda x: x + 42)
    S = lltype.GcStruct('S', adtmeths={'ll_func': ll_func})
    def f():
        return lltype.malloc(S).ll_func(5)
    s, t = ll_rtype(f, [])
    graphf = t.graphs[0]
    for op in graphf.startblock.operations:
        assert op.opname != 'getfield'
