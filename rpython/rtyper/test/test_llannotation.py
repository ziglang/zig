import py.test
from rpython.annotator.model import (
    SomeInteger, SomeBool, SomeChar, union, SomeImpossibleValue,
    UnionError, SomeInstance, SomeSingleFloat)
from rpython.rlib.rarithmetic import r_uint, r_singlefloat
from rpython.rtyper.llannotation import (
    SomePtr, annotation_to_lltype, ll_to_annotation)
from rpython.rtyper.lltypesystem import lltype
import rpython.rtyper.rtyper  # make sure to import the world

class C(object):
    pass

class DummyClassDef:
    def __init__(self, cls=C):
        self.cls = cls
        self.name = cls.__name__
        self.classdesc = cls

def test_ll_to_annotation():
    s_z = ll_to_annotation(lltype.Signed._defl())
    s_s = SomeInteger()
    s_u = SomeInteger(nonneg=True, unsigned=True)
    assert s_z.contains(s_s)
    assert not s_z.contains(s_u)
    s_uz = ll_to_annotation(lltype.Unsigned._defl())
    assert s_uz.contains(s_u)
    assert ll_to_annotation(lltype.Bool._defl()).contains(SomeBool())
    assert ll_to_annotation(lltype.Char._defl()).contains(SomeChar())
    S = lltype.GcStruct('s')
    A = lltype.GcArray()
    s_p = ll_to_annotation(lltype.malloc(S))
    assert isinstance(s_p, SomePtr) and s_p.ll_ptrtype == lltype.Ptr(S)
    s_p = ll_to_annotation(lltype.malloc(A, 0))
    assert isinstance(s_p, SomePtr) and s_p.ll_ptrtype == lltype.Ptr(A)

def test_annotation_to_lltype():
    s_i = SomeInteger()
    s_pos = SomeInteger(nonneg=True)
    s_1 = SomeInteger(nonneg=True)
    s_1.const = 1
    s_m1 = SomeInteger(nonneg=False)
    s_m1.const = -1
    s_u = SomeInteger(nonneg=True, unsigned=True)
    s_u1 = SomeInteger(nonneg=True, unsigned=True)
    s_u1.const = r_uint(1)
    assert annotation_to_lltype(s_i) == lltype.Signed
    assert annotation_to_lltype(s_pos) == lltype.Signed
    assert annotation_to_lltype(s_1) == lltype.Signed
    assert annotation_to_lltype(s_m1) == lltype.Signed
    assert annotation_to_lltype(s_u) == lltype.Unsigned
    assert annotation_to_lltype(s_u1) == lltype.Unsigned
    assert annotation_to_lltype(SomeBool()) == lltype.Bool
    assert annotation_to_lltype(SomeChar()) == lltype.Char
    PS = lltype.Ptr(lltype.GcStruct('s'))
    s_p = SomePtr(ll_ptrtype=PS)
    assert annotation_to_lltype(s_p) == PS
    si0 = SomeInstance(DummyClassDef(), True)
    with py.test.raises(ValueError):
        annotation_to_lltype(si0)
    s_singlefloat = SomeSingleFloat()
    s_singlefloat.const = r_singlefloat(0.0)
    assert annotation_to_lltype(s_singlefloat) == lltype.SingleFloat

def test_ll_union():
    PS1 = lltype.Ptr(lltype.GcStruct('s'))
    PS2 = lltype.Ptr(lltype.GcStruct('s'))
    PS3 = lltype.Ptr(lltype.GcStruct('s3'))
    PA1 = lltype.Ptr(lltype.GcArray())
    PA2 = lltype.Ptr(lltype.GcArray())

    assert union(SomePtr(PS1), SomePtr(PS1)) == SomePtr(PS1)
    assert union(SomePtr(PS1), SomePtr(PS2)) == SomePtr(PS2)
    assert union(SomePtr(PS1), SomePtr(PS2)) == SomePtr(PS1)

    assert union(SomePtr(PA1), SomePtr(PA1)) == SomePtr(PA1)
    assert union(SomePtr(PA1), SomePtr(PA2)) == SomePtr(PA2)
    assert union(SomePtr(PA1), SomePtr(PA2)) == SomePtr(PA1)

    assert union(SomePtr(PS1), SomeImpossibleValue()) == SomePtr(PS1)
    assert union(SomeImpossibleValue(), SomePtr(PS1)) == SomePtr(PS1)

    with py.test.raises(UnionError):
        union(SomePtr(PA1), SomePtr(PS1))
    with py.test.raises(UnionError):
        union(SomePtr(PS1), SomePtr(PS3))
    with py.test.raises(UnionError):
        union(SomePtr(PS1), SomeInteger())
    with py.test.raises(UnionError):
        union(SomeInteger(), SomePtr(PS1))
