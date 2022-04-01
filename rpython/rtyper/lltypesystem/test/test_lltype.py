import py
import sys
from rpython.rtyper.lltypesystem.lltype import *
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.tool.identity_dict import identity_dict
from rpython.tool import leakfinder
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.rtyper.rtyper import RPythonTyper

def isweak(p, T):
    try:
        typeOf(p)
    except TypeError:
        return True
    return False

def test_basics():
    S0 = GcStruct("s0", ('a', Signed), ('b', Signed))
    assert S0.a == Signed
    assert S0.b == Signed
    s0 = malloc(S0)
    print s0
    assert typeOf(s0) == Ptr(S0)
    py.test.raises(UninitializedMemoryAccess, "s0.a")
    s0.a = 1
    s0.b = s0.a
    assert s0.a == 1
    assert s0.b == 1
    assert typeOf(s0.a) == Signed
    # simple array
    Ar = GcArray(('v', Signed))
    x = malloc(Ar,0)
    print x
    assert len(x) == 0
    x = malloc(Ar,3)
    print x
    assert typeOf(x) == Ptr(Ar)
    assert isweak(x[0], Ar.OF)
    x[0].v = 1
    x[1].v = 2
    x[2].v = 3
    assert typeOf(x[0].v) == Signed
    assert [x[z].v for z in range(3)] == [1, 2, 3]
    #
    def define_list(T):
        List_typ = GcStruct("list",
                ("items", Ptr(GcArray(('item',T)))))
        def newlist():
            l = malloc(List_typ)
            items = malloc(List_typ.items.TO, 0)
            l.items = items
            return l

        def append(l, newitem):
            length = len(l.items)
            newitems = malloc(List_typ.items.TO, length+1)
            i = 0
            while i < length:
                newitems[i].item = l.items[i].item
                i += 1
            newitems[length].item = newitem
            l.items = newitems

        def item(l, i):
            return l.items[i].item

        return List_typ, newlist, append, item

    List_typ, inewlist, iappend, iitem = define_list(Signed)

    l = inewlist()
    assert typeOf(l) == Ptr(List_typ)
    iappend(l, 2)
    iappend(l, 3)
    assert len(l.items) == 2
    assert iitem(l, 0) == 2
    assert iitem(l, 1) == 3

    IWrap = GcStruct("iwrap", ('v', Signed))
    List_typ, iwnewlist, iwappend, iwitem = define_list(Ptr(IWrap))

    l = iwnewlist()
    assert typeOf(l) == Ptr(List_typ)
    iw2 = malloc(IWrap)
    iw3 = malloc(IWrap)
    iw2.v = 2
    iw3.v = 3
    assert iw3.v == 3
    iwappend(l, iw2)
    iwappend(l, iw3)
    assert len(l.items) == 2
    assert iwitem(l, 0).v == 2
    assert iwitem(l, 1).v == 3

    # not allowed
    S = Struct("s", ('v', Signed))
    List_typ, iwnewlistzzz, iwappendzzz, iwitemzzz = define_list(S) # works but
    l = iwnewlistzzz()
    S1 = GcStruct("strange", ('s', S))
    py.test.raises(TypeError, "iwappendzzz(l, malloc(S1).s)")

def test_varsizestruct():
    S1 = GcStruct("s1", ('a', Signed), ('rest', Array(('v', Signed))))
    py.test.raises(TypeError, "malloc(S1)")
    s1 = malloc(S1, 4)
    s1.a = 0
    assert s1.a == 0
    assert isweak(s1.rest, S1.rest)
    assert len(s1.rest) == 4
    assert isweak(s1.rest[0], S1.rest.OF)
    s1.rest[0].v = 0
    assert typeOf(s1.rest[0].v) == Signed
    assert s1.rest[0].v == 0
    py.test.raises(IndexError, "s1.rest[4]")
    py.test.raises(IndexError, "s1.rest[-1]")

    s1.a = 17
    s1.rest[3].v = 5
    assert s1.a == 17
    assert s1.rest[3].v == 5

    py.test.raises(TypeError, "Struct('invalid', ('rest', Array(('v', Signed))), ('a', Signed))")
    py.test.raises(TypeError, "Struct('invalid', ('rest', GcArray(('v', Signed))), ('a', Signed))")
    py.test.raises(TypeError, "Struct('invalid', ('x', Struct('s1', ('a', Signed), ('rest', Array(('v', Signed))))))")
    py.test.raises(TypeError, "Struct('invalid', ('x', S1))")

def test_substructure_ptr():
    S3 = Struct("s3", ('a', Signed))
    S2 = Struct("s2", ('s3', S3))
    S1 = GcStruct("s1", ('sub1', S2), ('sub2', S2))
    p1 = malloc(S1)
    assert isweak(p1.sub1, S2)
    assert isweak(p1.sub2, S2)
    assert isweak(p1.sub1.s3, S3)
    p2 = p1.sub1
    assert isweak(p2.s3, S3)

def test_gc_substructure_ptr():
    S1 = GcStruct("s2", ('a', Signed))
    S2 = Struct("s3", ('a', Signed))
    S0 = GcStruct("s1", ('sub1', S1), ('sub2', S2))
    p1 = malloc(S0)
    assert typeOf(p1.sub1) == Ptr(S1)
    assert isweak(p1.sub2, S2)

def test_cast_simple_widening():
    S2 = Struct("s2", ('a', Signed))
    S1 = Struct("s1", ('sub1', S2), ('sub2', S2))
    p1 = malloc(S1, immortal=True)
    p2 = p1.sub1
    p3 = p2
    assert typeOf(p3) == Ptr(S2)
    p4 = cast_pointer(Ptr(S1), p3)
    assert typeOf(p4) == Ptr(S1)
    assert p4 == p1
    py.test.raises(TypeError, "cast_pointer(Ptr(S1), p1.sub2)")
    SUnrelated = Struct("unrelated")
    py.test.raises(TypeError, "cast_pointer(Ptr(SUnrelated), p3)")
    S1bis = Struct("s1b", ('sub1', S2))
    p1b = malloc(S1bis, immortal=True)
    p2 = p1b.sub1
    py.test.raises(RuntimeError, "cast_pointer(Ptr(S1), p2)")

def test_cast_simple_widening2():
    S2 = GcStruct("s2", ('a', Signed))
    S1 = GcStruct("s1", ('sub1', S2))
    p1 = malloc(S1)
    p2 = p1.sub1
    assert typeOf(p2) == Ptr(S2)
    p3 = cast_pointer(Ptr(S1), p2)
    assert p3 == p1
    p2 = malloc(S2)
    py.test.raises(RuntimeError, "cast_pointer(Ptr(S1), p2)")

def test_cast_pointer():
    S3 = GcStruct("s3", ('a', Signed))
    S2 = GcStruct("s3", ('sub', S3))
    S1 = GcStruct("s1", ('sub', S2))
    p1 = malloc(S1)
    p2 = p1.sub
    p3 = p2.sub
    assert typeOf(p3) == Ptr(S3)
    assert typeOf(p2) == Ptr(S2)
    p12 = cast_pointer(Ptr(S1), p2)
    assert p12 == p1
    p13 = cast_pointer(Ptr(S1), p3)
    assert p13 == p1
    p21 = cast_pointer(Ptr(S2), p1)
    assert p21 == p2
    p23 = cast_pointer(Ptr(S2), p3)
    assert p23 == p2
    p31 = cast_pointer(Ptr(S3), p1)
    assert p31 == p3
    p32 = cast_pointer(Ptr(S3), p2)
    assert p32 == p3
    p3 = malloc(S3)
    p2 = malloc(S2)
    py.test.raises(RuntimeError, "cast_pointer(Ptr(S1), p3)")
    py.test.raises(RuntimeError, "cast_pointer(Ptr(S1), p2)")
    py.test.raises(RuntimeError, "cast_pointer(Ptr(S2), p3)")
    S0 = GcStruct("s0", ('sub', S1))
    p0 = malloc(S0)
    assert p0 == cast_pointer(Ptr(S0), p0)
    p3 = cast_pointer(Ptr(S3), p0)
    p03 = cast_pointer(Ptr(S0), p3)
    assert p0 == p03
    S1bis = GcStruct("s1b", ('sub', S2))
    assert S1bis != S1
    p1b = malloc(S1bis)
    p3 = p1b.sub.sub
    assert typeOf(p3) == Ptr(S3)
    assert p1b == cast_pointer(Ptr(S1bis), p3)
    py.test.raises(RuntimeError, "cast_pointer(Ptr(S1), p3)")

def test_examples():
    A1 = GcArray(('v', Signed))
    S = GcStruct("s", ('v', Signed))
    St = GcStruct("st", ('v', Signed),('trail', Array(('v', Signed))))

    PA1 = Ptr(A1)
    PS = Ptr(S)
    PSt = Ptr(St)

    ex_pa1 = PA1._example()
    ex_ps  = PS._example()
    ex_pst = PSt._example()

    assert typeOf(ex_pa1) == PA1
    assert typeOf(ex_ps) == PS
    assert typeOf(ex_pst) == PSt

    assert ex_pa1[0].v == 0
    assert ex_ps.v == 0
    assert ex_pst.v == 0
    assert ex_pst.trail[0].v == 0

def test_functions():
    F = FuncType((Signed,), Signed)
    py.test.raises(TypeError, "Struct('x', ('x', F))")

    PF = Ptr(F)
    pf = PF._example()
    assert pf(0) == 0
    py.test.raises(TypeError, pf, 0, 0)
    py.test.raises(TypeError, pf, 'a')

def test_truargs():
    F = FuncType((Void, Signed, Void, Unsigned), Float)
    assert Void not in F._trueargs()

def test_inconsistent_gc_containers():
    A = GcArray(('y', Signed))
    S = GcStruct('b', ('y', Signed))
    py.test.raises(TypeError, "Struct('a', ('x', S))")
    py.test.raises(TypeError, "GcStruct('a', ('x', Signed), ('y', S))")
    py.test.raises(TypeError, "Array(('x', S))")
    py.test.raises(TypeError, "GcArray(('x', S))")
    py.test.raises(TypeError, "Struct('a', ('x', A))")
    py.test.raises(TypeError, "GcStruct('a', ('x', A))")

def test_forward_reference():
    F = GcForwardReference()
    S = GcStruct('abc', ('x', Ptr(F)))
    F.become(S)
    assert S.x == Ptr(S)
    py.test.raises(TypeError, "GcForwardReference().become(Struct('abc'))")
    ForwardReference().become(Struct('abc'))
    hash(S)

def test_nullptr():
    S = Struct('s')
    p0 = nullptr(S)
    assert not p0
    assert typeOf(p0) == Ptr(S)


def test_nullptr_cast():
    S = Struct('s')
    p0 = nullptr(S)
    assert not p0
    S1 = Struct("s1", ('s', S))
    p10 = cast_pointer(Ptr(S1), p0)
    assert typeOf(p10) == Ptr(S1)
    assert not p10

def test_nullptr_opaque_cast():
    S = Struct('S')
    p0 = nullptr(S)
    O1 = OpaqueType('O1')
    O2 = OpaqueType('O2')
    p1 = cast_opaque_ptr(Ptr(O1), p0)
    assert not p1
    p2 = cast_opaque_ptr(Ptr(O2), p1)
    assert not p2
    p3 = cast_opaque_ptr(Ptr(S), p2)
    assert not p3


def test_hash():
    S = ForwardReference()
    S.become(Struct('S', ('p', Ptr(S))))
    assert S == S
    hash(S)   # assert no crash, and force the __cached_hash computation
    S1 = Struct('S', ('p', Ptr(S)))
    assert S1 == S
    assert S == S1
    assert hash(S1) == hash(S)

def test_array_with_non_container_elements():
    As = GcArray(Signed)
    a = malloc(As, 3)
    assert typeOf(a) == Ptr(As)
    py.test.raises(UninitializedMemoryAccess, "a[0]")
    a[1] = 3
    assert a[1] == 3
    S = GcStruct('s', ('x', Signed))
    s = malloc(S)
    py.test.raises(TypeError, "a[1] = s")
    S = GcStruct('s', ('x', Signed))
    py.test.raises(TypeError, "Array(S)")
    py.test.raises(TypeError, "Array(As)")
    S = Struct('s', ('x', Signed))
    A = GcArray(S)
    a = malloc(A, 2)
    s = S._container_example() # should not happen anyway
    py.test.raises(TypeError, "a[0] = s")
    S = Struct('s', ('last', Array(S)))
    py.test.raises(TypeError, "Array(S)")

def test_immortal_parent():
    S1 = GcStruct('substruct', ('x', Signed))
    S  = GcStruct('parentstruct', ('s1', S1))
    p = malloc(S, immortal=True)
    p1 = p.s1
    p1.x = 5
    del p
    p = cast_pointer(Ptr(S), p1)
    assert p.s1.x == 5

def test_getRuntimeTypeInfo():
    S = GcStruct('s', ('x', Signed))
    py.test.raises(ValueError, "getRuntimeTypeInfo(S)")
    S = GcStruct('s', ('x', Signed), rtti=True)
    pinfx = getRuntimeTypeInfo(S)
    pinf0 = attachRuntimeTypeInfo(S)   # no-op, really
    assert pinf0._obj.about == S
    assert pinf0 == pinfx
    pinf = getRuntimeTypeInfo(S)
    assert pinf == pinf0
    pinf1 = getRuntimeTypeInfo(S)
    assert pinf == pinf1
    Z = GcStruct('z', ('x', Unsigned), rtti=True)
    assert getRuntimeTypeInfo(Z) != pinf0
    Sbis = GcStruct('s', ('x', Signed), rtti=True)
    assert getRuntimeTypeInfo(Sbis) != pinf0
    assert Sbis != S # the attached runtime type info distinguishes them
    Ster = GcStruct('s', ('x', Signed), rtti=True)
    assert Sbis != Ster # the attached runtime type info distinguishes them

def test_getRuntimeTypeInfo_destrpointer():
    S = GcStruct('s', ('x', Signed), rtti=True)
    def f(s):
        s.x = 1
    def type_info_S(p):
        return getRuntimeTypeInfo(S)
    qp = functionptr(FuncType([Ptr(S)], Ptr(RuntimeTypeInfo)),
                     "type_info_S",
                     _callable=type_info_S)
    dp = functionptr(FuncType([Ptr(S)], Void),
                     "destructor_funcptr",
                     _callable=f)
    pinf0 = attachRuntimeTypeInfo(S, qp, destrptr=dp)
    assert pinf0._obj.about == S
    pinf = getRuntimeTypeInfo(S)
    assert pinf == pinf0
    pinf1 = getRuntimeTypeInfo(S)
    assert pinf == pinf1
    assert pinf._obj.destructor_funcptr == dp
    assert pinf._obj.query_funcptr == qp

def test_runtime_type_info():
    S = GcStruct('s', ('x', Signed), rtti=True)
    attachRuntimeTypeInfo(S)
    s = malloc(S)
    s.x = 0
    assert runtime_type_info(s) == getRuntimeTypeInfo(S)
    S1 = GcStruct('s1', ('sub', S), ('x', Signed), rtti=True)
    attachRuntimeTypeInfo(S1)
    s1 = malloc(S1)
    s1.sub.x = 0
    s1.x = 0
    assert runtime_type_info(s1) == getRuntimeTypeInfo(S1)
    assert runtime_type_info(s1.sub) == getRuntimeTypeInfo(S1)
    assert runtime_type_info(cast_pointer(Ptr(S), s1)) == getRuntimeTypeInfo(S1)
    def dynamic_type_info_S(p):
        if p.x == 0:
            return getRuntimeTypeInfo(S)
        else:
            return getRuntimeTypeInfo(S1)
    fp = functionptr(FuncType([Ptr(S)], Ptr(RuntimeTypeInfo)),
                     "dynamic_type_info_S",
                     _callable=dynamic_type_info_S)
    attachRuntimeTypeInfo(S, fp)
    assert s.x == 0
    assert runtime_type_info(s) == getRuntimeTypeInfo(S)
    s.x = 1
    py.test.raises(RuntimeError, "runtime_type_info(s)")
    assert s1.sub.x == 0
    py.test.raises(RuntimeError, "runtime_type_info(s1.sub)")
    s1.sub.x = 1
    assert runtime_type_info(s1.sub) == getRuntimeTypeInfo(S1)

def test_flavor_malloc():
    def isweak(p, T):
        return p._weak and typeOf(p).TO == T
    S = Struct('s', ('x', Signed))
    py.test.raises(TypeError, malloc, S)
    p = malloc(S, flavor="raw")
    assert typeOf(p).TO == S
    assert not isweak(p, S)
    p.x = 2
    free(p, flavor="raw")
    py.test.raises(RuntimeError, "p.x")
    T = GcStruct('T', ('y', Signed))
    p = malloc(T, flavor="gc")
    assert typeOf(p).TO == T
    assert not isweak(p, T)

def test_opaque():
    O = OpaqueType('O')
    p1 = opaqueptr(O, 'p1', hello="world")
    assert typeOf(p1) == Ptr(O)
    assert p1._obj.hello == "world"
    assert parentlink(p1._obj) == (None, None)
    S = GcStruct('S', ('stuff', O))
    p2 = malloc(S)
    assert typeOf(p2) == Ptr(S)
    assert typeOf(p2.stuff) == Ptr(O)
    assert parentlink(p2.stuff._obj) == (p2._obj, 'stuff')

def test_cast_opaque_ptr():
    O = GcOpaqueType('O')
    Q = GcOpaqueType('Q')
    S = GcStruct('S', ('x', Signed))
    s = malloc(S)
    o = cast_opaque_ptr(Ptr(O), s)
    assert typeOf(o).TO == O
    q = cast_opaque_ptr(Ptr(Q), o)
    assert typeOf(q).TO == Q
    p = cast_opaque_ptr(Ptr(S), q)
    assert typeOf(p).TO == S
    assert p == s
    O1 = OpaqueType('O')
    S1 = Struct('S1', ('x', Signed))
    s1 = malloc(S1, immortal=True)
    o1 = cast_opaque_ptr(Ptr(O1), s1)
    assert typeOf(o1).TO == O1
    p1 = cast_opaque_ptr(Ptr(S1), o1)
    assert typeOf(p1).TO == S1
    assert p1 == s1
    py.test.raises(TypeError, "cast_opaque_ptr(Ptr(S), o1)")
    py.test.raises(TypeError, "cast_opaque_ptr(Ptr(O1), s)")
    S2 = Struct('S2', ('z', Signed))
    py.test.raises(InvalidCast, "cast_opaque_ptr(Ptr(S2), o1)")

    BIG = GcStruct('BIG', ('s', S))
    UNRELATED = GcStruct('UNRELATED')
    big = malloc(BIG)
    unrelated = malloc(UNRELATED)
    p1 = cast_opaque_ptr(Ptr(O), big)
    p2 = cast_opaque_ptr(Ptr(O), big)
    assert p1 == p2
    p3 = cast_opaque_ptr(Ptr(O), big.s)
    assert p1 == p3
    p4 = cast_opaque_ptr(Ptr(O), unrelated)
    assert p1 != p4
    assert p3 != p4

def test_is_atomic():
    U = Struct('inlined', ('z', Signed))
    A = Ptr(RuntimeTypeInfo)
    P = Ptr(GcStruct('p'))
    Q = GcStruct('q', ('i', Signed), ('u', U), ('p', P))
    O = OpaqueType('O')
    F = GcForwardReference()
    assert A._is_atomic() is True
    assert P._is_atomic() is False
    assert Q.i._is_atomic() is True
    assert Q.u._is_atomic() is True
    assert Q.p._is_atomic() is False
    assert Q._is_atomic() is False
    assert O._is_atomic() is False
    assert F._is_atomic() is False

def test_adtmeths():
    def h_newstruct():
        return malloc(S)

    S = GcStruct('s', ('x', Signed),
                 adtmeths={"h_newstruct": h_newstruct})

    s = S.h_newstruct()

    assert typeOf(s) == Ptr(S)

    def h_alloc(n):
        return malloc(A, n)

    def h_length(a):
        return len(a)

    A = GcArray(Signed,
                adtmeths={"h_alloc": h_alloc,
                          "h_length": h_length,
                          "stuff": 12})

    a = A.h_alloc(10)

    assert typeOf(a) == Ptr(A)
    assert len(a) == 10

    assert a.h_length() == 10
    assert a._lookup_adtmeth("h_length")() == 10
    assert a.stuff == 12
    assert a._lookup_adtmeth("stuff") == 12

def test_adt_typemethod():
    def h_newstruct(S):
        return malloc(S)
    h_newstruct = typeMethod(h_newstruct)

    S = GcStruct('s', ('x', Signed),
                 adtmeths={"h_newstruct": h_newstruct})

    s = S.h_newstruct()

    assert typeOf(s) == Ptr(S)

    Sprime = GcStruct('s', ('x', Signed),
                      adtmeths={"h_newstruct": h_newstruct})

    assert S == Sprime

class Frozen(object):
    def _freeze_(self):
        return True

@py.test.mark.parametrize('x', [
    1, sys.maxint, 1.5, 'a', 'abc', u'abc', None, [],
    lambda: None,
    {1.23: 'abc'},
    (1, 'x', [2, 3.],),
    Frozen(),])
def test_typeOf_const(x):
    a = RPythonAnnotator()
    bk = a.bookkeeper
    rtyper = RPythonTyper(a)
    s_x = bk.immutablevalue(x)
    r_x = rtyper.getrepr(s_x)
    assert typeOf(r_x.convert_const(x)) == r_x.lowleveltype

def test_cast_primitive():
    cases = [
        (Float, 1, 1.0),
        (Float, r_singlefloat(2.1), float(r_singlefloat(2.1))),
        (Signed, 1.0, 1),
        (Unsigned, 1.0, 1),
        (Signed, r_uint(-1), -1),
        (Unsigned, -1, r_uint(-1)),
        (Char, ord('a'), 'a'),
        (Char, False,  chr(0)),
        (Signed, 'x', ord('x')),
        (Unsigned, u"x", ord(u'x')),
    ]
    for TGT, orig_val, expect in cases:
        res = cast_primitive(TGT, orig_val)
        assert typeOf(res) == TGT
        assert res == expect
    res = cast_primitive(SingleFloat, 2.1)
    assert isinstance(res, r_singlefloat)
    assert float(res) == float(r_singlefloat(2.1))

def test_cast_identical_array_ptr_types():
    A = GcArray(Signed)
    PA = Ptr(A)
    a = malloc(A, 2)
    assert cast_pointer(PA, a) == a

def test_array_with_no_length():
    A = GcArray(Signed, hints={'nolength': True})
    a = malloc(A, 10)
    py.test.raises(TypeError, len, a)

def test_dissect_ll_instance():
    assert list(dissect_ll_instance(1)) == [(Signed, 1)]
    GcS = GcStruct("S", ('x', Signed))
    s = malloc(GcS)
    s.x = 1
    assert list(dissect_ll_instance(s)) == [(Ptr(GcS), s), (GcS, s._obj), (Signed, 1)]

    A = GcArray(('x', Signed))
    a = malloc(A, 10)
    for i in range(10):
        a[i].x = i
    expected = [(Ptr(A), a), (A, a._obj)]
    for t in [((A.OF, a._obj.items[i]), (Signed, i)) for i in range(10)]:
        expected.extend(t)
    assert list(dissect_ll_instance(a)) == expected

    R = GcStruct("R", ('r', Ptr(GcForwardReference())))
    R.r.TO.become(R)

    r = malloc(R)
    r.r = r
    r_expected = [(Ptr(R), r), (R, r._obj)]
    assert list(dissect_ll_instance(r)) == r_expected

    B = GcArray(Ptr(R))
    b = malloc(B, 2)
    b[0] = b[1] = r
    b_expected = [(Ptr(B), b), (B, b._obj)]
    assert list(dissect_ll_instance(b)) == b_expected + r_expected

    memo = identity_dict()
    assert list(dissect_ll_instance(r, None, memo)) == r_expected
    assert list(dissect_ll_instance(b, None, memo)) == b_expected

def test_fixedsizearray():
    A = FixedSizeArray(Signed, 5)
    assert A.OF == Signed
    assert A.length == 5
    assert A.item0 == A.item1 == A.item2 == A.item3 == A.item4 == Signed
    assert A._names == ('item0', 'item1', 'item2', 'item3', 'item4')
    a = malloc(A, immortal=True)
    a[0] = 5
    a[4] = 83
    assert a[0] == 5
    assert a[4] == 83
    assert a.item4 == 83
    py.test.raises(IndexError, "a[5] = 183")
    py.test.raises(IndexError, "a[-1]")
    assert len(a) == 5

    S = GcStruct('S', ('n1', Signed),
                      ('a', A),
                      ('n2', Signed))
    s = malloc(S)
    s.a[3] = 17
    assert s.a[3] == 17
    assert len(s.a) == 5
    py.test.raises(TypeError, "s.a = a")

def test_direct_arrayitems():
    for a in [malloc(GcArray(Signed), 5),
              malloc(FixedSizeArray(Signed, 5), immortal=True)]:
        a[0] = 0
        a[1] = 10
        a[2] = 20
        a[3] = 30
        a[4] = 40
        b0 = direct_arrayitems(a)
        assert typeOf(b0) == Ptr(FixedSizeArray(Signed, 1))
        b1 = direct_ptradd(b0, 1)
        b2 = direct_ptradd(b1, 1)
        b3 = direct_ptradd(b0, 3)
        assert b0[0] == 0
        assert b0[1] == 10
        assert b0[4] == 40
        assert b1[0] == 10
        assert b1[1] == 20
        assert b2[0] == 20
        assert b2[1] == 30
        assert b3[-2] == 10
        assert b3[0] == 30
        assert b3[1] == 40
        assert b2[-2] == 0
        assert b1[3] == 40
        b2[0] = 23
        assert a[2] == 23
        b1[1] += 1
        assert a[2] == 24
        py.test.raises(IndexError, "b0[-1]")
        py.test.raises(IndexError, "b3[2]")
        py.test.raises(IndexError, "b1[4]")

def test_direct_fieldptr():
    S = GcStruct('S', ('x', Signed), ('y', Signed))
    s = malloc(S)
    a = direct_fieldptr(s, 'y')
    a[0] = 34
    assert s.y == 34
    py.test.raises(IndexError, "a[1]")

def test_odd_ints():
    T = GcStruct('T')
    S = GcStruct('S', ('t', T))
    s = cast_int_to_ptr(Ptr(S), 21)
    assert typeOf(s) == Ptr(S)
    assert cast_ptr_to_int(s) == 21
    t = cast_pointer(Ptr(T), s)
    assert typeOf(t) == Ptr(T)
    assert cast_ptr_to_int(t) == 21
    assert s == cast_pointer(Ptr(S), t)

def test_str_of_dead_ptr():
    S = Struct('S', ('x', Signed))
    T = GcStruct('T', ('s', S))
    t = malloc(T)
    s = t.s
    del t
    import gc
    gc.collect()
    repr(s)

def test_name_clash():
    import re
    fn = lltype.__file__
    if fn.lower().endswith('pyc') or fn.lower().endswith('pyo'):
        fn = fn[:-1]
    f = open(fn, 'r')
    data = f.read()
    f.close()
    words = dict.fromkeys(re.compile(r"[a-zA-Z][_a-zA-Z0-9]*").findall(data))
    words = words.keys()
    S = GcStruct('name_clash', *[(word, Signed) for word in words])
    s = malloc(S)
    for i, word in enumerate(words):
        setattr(s, word, i)
    for i, word in enumerate(words):
        assert getattr(s, word) == i

def test_subarray_keeps_array_alive():
    A = Array(Signed)
    ptr = malloc(A, 10, immortal=True)
    ptr2 = direct_arrayitems(ptr)
    del ptr
    import gc; gc.collect(); gc.collect()
    ptr2[0] = 5    # crashes if the array was deallocated

def test_identityhash():
    S = GcStruct('S', ('x', Signed))
    S2 = GcStruct('S2', ('super', S))
    S3 = GcStruct('S3', ('super', S2))

    py.test.raises(AssertionError, identityhash, nullptr(S2))

    s3 = malloc(S3)
    hash3 = identityhash(s3.super)
    assert hash3 == identityhash(s3)
    assert hash3 == identityhash(s3.super)
    assert hash3 == identityhash(s3.super.super)

    from rpython.rtyper.lltypesystem import llmemory
    p3 = cast_opaque_ptr(llmemory.GCREF, s3)
    assert hash3 == identityhash(p3)

    A = GcArray(Signed)
    a = malloc(A, 3)
    hash1 = identityhash(a)
    assert hash1 == identityhash(a)
    p = cast_opaque_ptr(llmemory.GCREF, a)
    assert hash1 == identityhash(p)

def test_immutable_hint():
    S = GcStruct('S', ('x', lltype.Signed))
    assert S._immutable_field('x') == False
    #
    S = GcStruct('S', ('x', lltype.Signed), hints={'immutable': True})
    assert S._immutable_field('x') == True
    #
    class FieldListAccessor(object):
        def __init__(self, fields):
            self.fields = fields
    S = GcStruct('S', ('x', lltype.Signed),
                 hints={'immutable_fields': FieldListAccessor({'x': 1234})})
    assert S._immutable_field('x') == 1234

def test_typedef():
    T = Typedef(Signed, 'T')
    assert T == Signed
    assert Signed == T
    T2 = Typedef(T, 'T2')
    assert T2 == T
    assert T2.OF is Signed
    py.test.raises(TypeError, Ptr, T)
    assert rffi.CArrayPtr(T) == rffi.CArrayPtr(Signed)
    assert rffi.CArrayPtr(Signed) == rffi.CArrayPtr(T)

    F = FuncType((T,), T)
    assert F.RESULT == Signed
    assert F.ARGS == (Signed,)

def test_cannot_inline_random_stuff_in_gcstruct():
    S = GcStruct('S')
    GcStruct('X', ('a', S))    # works
    py.test.raises(TypeError, GcStruct, 'X', ('a', Signed), ('b', S))
    GcStruct('X', ('a', Array(Signed)))   # works
    py.test.raises(TypeError, GcStruct, 'X', ('a', Array(Signed)),
                                             ('b', Signed))
    Struct('X', ('a', Array(Signed, hints={'nolength': True})))   # works
    py.test.raises(TypeError, GcStruct, 'X',
                   ('a', Array(Signed, hints={'nolength': True})))
    GcStruct('X', ('a', OpaqueType('foo')))   # works
    py.test.raises(TypeError, GcStruct, 'X', ('a', GcOpaqueType('foo')))


class TestTrackAllocation:
    def test_automatic_tracking(self):
        # calls to start_tracking_allocations/stop_tracking_allocations
        # should occur automatically from pypy/conftest.py.  Check that.
        assert leakfinder.TRACK_ALLOCATIONS

    def test_track_allocation(self):
        """A malloc'd buffer fills the ALLOCATED dictionary"""
        assert leakfinder.TRACK_ALLOCATIONS
        assert not leakfinder.ALLOCATED
        buf = malloc(Array(Signed), 1, flavor="raw")
        assert len(leakfinder.ALLOCATED) == 1
        assert leakfinder.ALLOCATED.keys() == [buf._obj]
        free(buf, flavor="raw")
        assert not leakfinder.ALLOCATED

    def test_str_from_buffer(self):
        """gc-managed memory does not need to be freed"""
        size = 50
        raw_buf, gc_buf, case_num = rffi.alloc_buffer(size)
        for i in range(size): raw_buf[i] = 'a'
        rstr = rffi.str_from_buffer(raw_buf, gc_buf, case_num, size, size)
        rffi.keep_buffer_alive_until_here(raw_buf, gc_buf, case_num)
        assert not leakfinder.ALLOCATED

    def test_leak_traceback(self):
        """Test info stored for allocated items"""
        buf = malloc(Array(Signed), 1, flavor="raw")
        traceback = leakfinder.ALLOCATED.values()[0]
        lines = traceback.splitlines()
        assert 'malloc(' in lines[-1] and 'flavor="raw")' in lines[-1]

        # The traceback should not be too long
        print traceback

        free(buf, flavor="raw")

    def test_no_tracking(self):
        p1 = malloc(Array(Signed), 1, flavor='raw', track_allocation=False)
        p2 = malloc(Array(Signed), 1, flavor='raw', track_allocation=False)
        free(p2, flavor='raw', track_allocation=False)
        # p1 is not freed

    def test_scoped_allocator(self):
        with scoped_alloc(Array(Signed), 1) as array:
            array[0] = -42
            x = array[0]
        assert x == -42
