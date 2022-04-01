from rpython.jit.metainterp.history import *
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib.rfloat import NAN, INFINITY
from rpython.jit.metainterp.resoperation import InputArgInt
from rpython.jit.codewriter import longlong
from rpython.translator.c.test.test_standalone import StandaloneTests


def test_repr():
    S = lltype.GcStruct('S')
    T = lltype.GcStruct('T', ('header', S))
    t = lltype.malloc(T)
    s = lltype.cast_pointer(lltype.Ptr(S), t)
    const = ConstPtr(lltype.cast_opaque_ptr(llmemory.GCREF, s))
    assert const._getrepr_() == "*T"

def test_same_constant():
    c1a = ConstInt(0)
    c1b = ConstInt(0)
    c2a = ConstPtr(lltype.nullptr(llmemory.GCREF.TO))
    c2b = ConstPtr(lltype.nullptr(llmemory.GCREF.TO))
    c3a = Const._new(0.0)
    c3b = Const._new(0.0)
    assert     c1a.same_constant(c1b)
    assert not c1a.same_constant(c2b)
    assert not c1a.same_constant(c3b)
    assert not c2a.same_constant(c1b)
    assert     c2a.same_constant(c2b)
    assert not c2a.same_constant(c3b)
    assert not c3a.same_constant(c1b)
    assert not c3a.same_constant(c2b)
    assert     c3a.same_constant(c3b)

def test_same_constant_float():
    c1 = Const._new(12.34)
    c2 = Const._new(12.34)
    c3 = Const._new(NAN)
    c4 = Const._new(NAN)
    c5 = Const._new(INFINITY)
    c6 = Const._new(INFINITY)
    assert c1.same_constant(c2)
    assert c3.same_constant(c4)
    assert c5.same_constant(c6)
    assert not c1.same_constant(c4)
    assert not c1.same_constant(c6)
    assert not c3.same_constant(c2)
    assert not c3.same_constant(c6)
    assert not c5.same_constant(c2)
    assert not c5.same_constant(c4)

def test_float_nonnull():
    c1 = Const._new(0.0)
    c2 = Const._new(1.0)
    c3 = Const._new(INFINITY)
    c4 = Const._new(-INFINITY)
    c5 = Const._new(NAN)
    c6 = Const._new(-0.0)
    assert not c1.nonnull()
    assert c2.nonnull()
    assert c3.nonnull()
    assert c4.nonnull()
    assert c5.nonnull()
    assert c6.nonnull()

def test_frontendop():
    f = FrontendOp(42)
    assert f.get_position() == 42
    f = FrontendOp(-56)
    assert f.get_position() == -56
    f.set_position(6519)
    assert f.get_position() == 6519

def fresh_ref():
    S = lltype.GcStruct('S')
    s = lltype.malloc(S)
    return lltype.cast_opaque_ptr(llmemory.GCREF, s)

def duplicate_ref(x):
    s = x._obj.container._as_ptr()
    return lltype.cast_opaque_ptr(llmemory.GCREF, s)

def test_ref_dict():
    d = new_ref_dict()
    ref1 = fresh_ref()
    ref2 = fresh_ref()
    ref3 = fresh_ref()
    d[ref1] = 123
    d[ref2] = 456
    d[ref3] = 789
    ref1b = duplicate_ref(ref1)
    ref2b = duplicate_ref(ref2)
    ref3b = duplicate_ref(ref3)
    assert d[ref1b] == 123
    assert d[ref2b] == 456
    assert d[ref3b] == 789

class TestZTranslated(StandaloneTests):
    def test_ztranslated_same_constant_float(self):
        def fn(args):
            n = INFINITY
            c1 = ConstFloat(longlong.getfloatstorage(n - INFINITY))
            c2 = ConstFloat(longlong.getfloatstorage(n - INFINITY))
            c3 = ConstFloat(longlong.getfloatstorage(12.34))
            if c1.same_constant(c2):
                print "ok!"
            return 0

        t, cbuilder = self.compile(fn)
        data = cbuilder.cmdexec('')
        assert "ok!\n" in data
