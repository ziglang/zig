import py
from rpython.rtyper.lltypesystem.lloperation import LL_OPERATIONS, llop, void
from rpython.rtyper.lltypesystem import lltype, opimpl
from rpython.rtyper.llinterp import LLFrame
from rpython.rtyper.test.test_llinterp import interpret
from rpython.rtyper import rclass
from rpython.rlib.rarithmetic import LONGLONG_MASK, r_longlong, r_ulonglong

LL_INTERP_OPERATIONS = [name[3:] for name in LLFrame.__dict__.keys()
                                 if name.startswith('op_')]

# ____________________________________________________________

def test_canfold_opimpl_complete():
    for opname, llop in LL_OPERATIONS.items():
        assert opname == llop.opname
        if llop.canfold:
            func = opimpl.get_op_impl(opname)
            assert callable(func)

def test_llop_fold():
    assert llop.int_add(lltype.Signed, 10, 2) == 12
    assert llop.int_add(lltype.Signed, -6, -7) == -13
    S1 = lltype.GcStruct('S1', ('x', lltype.Signed), hints={'immutable': True})
    s1 = lltype.malloc(S1)
    s1.x = 123
    assert llop.getfield(lltype.Signed, s1, 'x') == 123
    S2 = lltype.GcStruct('S2', ('x', lltype.Signed))
    s2 = lltype.malloc(S2)
    s2.x = 123
    py.test.raises(TypeError, "llop.getfield(lltype.Signed, s2, 'x')")

def test_llop_interp():
    from rpython.rtyper.annlowlevel import LowLevelAnnotatorPolicy
    def llf(x, y):
        return llop.int_add(lltype.Signed, x, y)
    res = interpret(llf, [5, 7], policy=LowLevelAnnotatorPolicy())
    assert res == 12

def test_llop_with_voids_interp():
    from rpython.rtyper.annlowlevel import LowLevelAnnotatorPolicy
    S = lltype.GcStruct('S', ('x', lltype.Signed), ('y', lltype.Signed))
    name_y = void('y')
    def llf():
        s = lltype.malloc(S)
        llop.bare_setfield(lltype.Void, s, void('x'), 3)
        llop.bare_setfield(lltype.Void, s, name_y, 2)
        return s.x + s.y
    res = interpret(llf, [], policy=LowLevelAnnotatorPolicy())
    assert res == 5

def test_is_pure():
    from rpython.flowspace.model import Variable, Constant
    assert llop.bool_not.is_pure([Variable()])
    assert llop.debug_assert.is_pure([Variable()])
    assert not llop.int_add_ovf.is_pure([Variable(), Variable()])
    #
    S1 = lltype.GcStruct('S', ('x', lltype.Signed), ('y', lltype.Signed))
    v_s1 = Variable()
    v_s1.concretetype = lltype.Ptr(S1)
    assert not llop.setfield.is_pure([v_s1, Constant('x'), Variable()])
    assert not llop.getfield.is_pure([v_s1, Constant('y')])
    #
    A1 = lltype.GcArray(lltype.Signed)
    v_a1 = Variable()
    v_a1.concretetype = lltype.Ptr(A1)
    assert not llop.setarrayitem.is_pure([v_a1, Variable(), Variable()])
    assert not llop.getarrayitem.is_pure([v_a1, Variable()])
    assert llop.getarraysize.is_pure([v_a1])
    #
    S2 = lltype.GcStruct('S', ('x', lltype.Signed), ('y', lltype.Signed),
                         hints={'immutable': True})
    v_s2 = Variable()
    v_s2.concretetype = lltype.Ptr(S2)
    assert not llop.setfield.is_pure([v_s2, Constant('x'), Variable()])
    assert llop.getfield.is_pure([v_s2, Constant('y')])
    #
    A2 = lltype.GcArray(lltype.Signed, hints={'immutable': True})
    v_a2 = Variable()
    v_a2.concretetype = lltype.Ptr(A2)
    assert not llop.setarrayitem.is_pure([v_a2, Variable(), Variable()])
    assert llop.getarrayitem.is_pure([v_a2, Variable()])
    assert llop.getarraysize.is_pure([v_a2])
    #
    for kind in [rclass.IR_MUTABLE, rclass.IR_IMMUTABLE,
                 rclass.IR_IMMUTABLE_ARRAY, rclass.IR_QUASIIMMUTABLE,
                 rclass.IR_QUASIIMMUTABLE_ARRAY]:
        accessor = rclass.FieldListAccessor()
        S3 = lltype.GcStruct('S', ('x', lltype.Signed), ('y', lltype.Signed),
                             hints={'immutable_fields': accessor})
        accessor.initialize(S3, {'x': kind})
        v_s3 = Variable()
        v_s3.concretetype = lltype.Ptr(S3)
        assert not llop.setfield.is_pure([v_s3, Constant('x'), Variable()])
        assert not llop.setfield.is_pure([v_s3, Constant('y'), Variable()])
        assert llop.getfield.is_pure([v_s3, Constant('x')]) is kind
        assert not llop.getfield.is_pure([v_s3, Constant('y')])

def test_getfield_pure():
    S1 = lltype.GcStruct('S', ('x', lltype.Signed), ('y', lltype.Signed))
    S2 = lltype.GcStruct('S', ('x', lltype.Signed), ('y', lltype.Signed),
                         hints={'immutable': True})
    accessor = rclass.FieldListAccessor()
    #
    s1 = lltype.malloc(S1); s1.x = 45
    py.test.raises(TypeError, llop.getfield, lltype.Signed, s1, 'x')
    s2 = lltype.malloc(S2); s2.x = 45
    assert llop.getfield(lltype.Signed, s2, 'x') == 45
    #
    py.test.raises(TypeError, llop.getinteriorfield, lltype.Signed, s1, 'x')
    assert llop.getinteriorfield(lltype.Signed, s2, 'x') == 45
    #
    for kind in [rclass.IR_MUTABLE, rclass.IR_IMMUTABLE,
                 rclass.IR_IMMUTABLE_ARRAY, rclass.IR_QUASIIMMUTABLE,
                 rclass.IR_QUASIIMMUTABLE_ARRAY]:
        #
        S3 = lltype.GcStruct('S', ('x', lltype.Signed), ('y', lltype.Signed),
                             hints={'immutable_fields': accessor})
        accessor.initialize(S3, {'x': kind})
        s3 = lltype.malloc(S3); s3.x = 46; s3.y = 47
        if kind in [rclass.IR_IMMUTABLE, rclass.IR_IMMUTABLE_ARRAY]:
            assert llop.getfield(lltype.Signed, s3, 'x') == 46
            assert llop.getinteriorfield(lltype.Signed, s3, 'x') == 46
        else:
            py.test.raises(TypeError, llop.getfield, lltype.Signed, s3, 'x')
            py.test.raises(TypeError, llop.getinteriorfield,
                           lltype.Signed, s3, 'x')
        py.test.raises(TypeError, llop.getfield, lltype.Signed, s3, 'y')
        py.test.raises(TypeError, llop.getinteriorfield,
                       lltype.Signed, s3, 'y')

def test_cast_float_to_ulonglong():
    f = 12350000000000000000.0
    py.test.raises(OverflowError, r_longlong, f)
    r_longlong(f / 2)   # does not raise OverflowError
    #
    x = llop.cast_float_to_ulonglong(lltype.UnsignedLongLong, f)
    assert x == r_ulonglong(f)

# ___________________________________________________________________________
# This tests that the LLInterpreter and the LL_OPERATIONS tables are in sync.

def test_table_complete():
    for opname in LL_INTERP_OPERATIONS:
        assert opname in LL_OPERATIONS

def test_llinterp_complete():
    for opname, llop in LL_OPERATIONS.items():
        if llop.canrun:
            continue
        assert opname in LL_INTERP_OPERATIONS
