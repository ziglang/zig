import py, sys

from rpython.rlib.rarithmetic import r_longlong, intmask, is_valid_int
from rpython.flowspace.model import SpaceOperation, Variable, Constant
from rpython.flowspace.model import Block, Link
from rpython.translator.unsimplify import varoftype
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.jit.codewriter.jtransform import Transformer, NotSupported
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.codewriter.test.test_jtransform import const
from rpython.jit.codewriter import longlong


class FakeRTyper:
    pass

class FakeBuiltinCallControl:
    def guess_call_kind(self, op):
        return 'builtin'
    def getcalldescr(self, op, oopspecindex=None, extraeffect=None, extradescr=None, **kwargs):
        assert oopspecindex is not None    # in this test
        return 'calldescr-%d' % oopspecindex
    def calldescr_canraise(self, calldescr):
        return False

class FakeCPU:
    supports_longlong = True
    def __init__(self):
        self.rtyper = FakeRTyper()


def test_functions():
    xll = longlong.getfloatstorage(3.5)
    assert longlong.getrealfloat(xll) == 3.5
    assert is_valid_int(longlong.gethash(xll))


class TestLongLong:
    def setup_class(cls):
        if longlong.is_64_bit:
            py.test.skip("only for 32-bit platforms")

    def do_check(self, opname, oopspecindex, ARGS, RESULT):
        vlist = [varoftype(ARG) for ARG in ARGS]
        v_result = varoftype(RESULT)
        op = SpaceOperation(opname, vlist, v_result)
        tr = Transformer(FakeCPU(), FakeBuiltinCallControl())
        op1 = tr.rewrite_operation(op)
        if isinstance(op1, list):
            [op1] = op1
        #
        def is_llf(TYPE):
            return (TYPE == lltype.SignedLongLong or
                    TYPE == lltype.UnsignedLongLong or
                    TYPE == lltype.Float)
        if is_llf(RESULT):
            assert op1.opname == 'residual_call_irf_f'
        else:
            assert op1.opname == 'residual_call_irf_i'
        gotindex = getattr(EffectInfo,
                           'OS_' + op1.args[0].value.upper().lstrip('U'))
        assert gotindex == oopspecindex
        assert list(op1.args[1]) == [v for v in vlist
                                     if not is_llf(v.concretetype)]
        assert list(op1.args[2]) == []
        assert list(op1.args[3]) == [v for v in vlist
                                     if is_llf(v.concretetype)]
        assert op1.args[4] == 'calldescr-%d' % oopspecindex
        assert op1.result == v_result

    def test_is_true(self):
        for opname, T in [('llong_is_true', lltype.SignedLongLong),
                          ('ullong_is_true', lltype.UnsignedLongLong)]:
            v = varoftype(T)
            v_result = varoftype(lltype.Bool)
            op = SpaceOperation(opname, [v], v_result)
            tr = Transformer(FakeCPU(), FakeBuiltinCallControl())
            oplist = tr.rewrite_operation(op)
            assert len(oplist) == 2
            assert oplist[0].opname == 'residual_call_irf_f'
            assert oplist[0].args[0].value == opname.split('_')[0]+'_from_int'
            assert list(oplist[0].args[1]) == [const(0)]
            assert list(oplist[0].args[2]) == []
            assert list(oplist[0].args[3]) == []
            assert oplist[0].args[4] == 'calldescr-84'
            v_x = oplist[0].result
            assert isinstance(v_x, Variable)
            assert v_x.concretetype is T
            assert oplist[1].opname == 'residual_call_irf_i'
            assert oplist[1].args[0].value == 'llong_ne'
            assert list(oplist[1].args[1]) == []
            assert list(oplist[1].args[2]) == []
            assert list(oplist[1].args[3]) == [v, v_x]
            assert oplist[1].args[4] == 'calldescr-76'
            assert oplist[1].result == v_result

    def test_llong_neg(self):
        T = lltype.SignedLongLong
        v = varoftype(T)
        v_result = varoftype(T)
        op = SpaceOperation('llong_neg', [v], v_result)
        tr = Transformer(FakeCPU(), FakeBuiltinCallControl())
        oplist = tr.rewrite_operation(op)
        assert len(oplist) == 2
        assert oplist[0].opname == 'residual_call_irf_f'
        assert oplist[0].args[0].value == 'llong_from_int'
        assert list(oplist[0].args[1]) == [const(0)]
        assert list(oplist[0].args[2]) == []
        assert list(oplist[0].args[3]) == []
        assert oplist[0].args[4] == 'calldescr-84'
        v_x = oplist[0].result
        assert isinstance(v_x, Variable)
        assert oplist[1].opname == 'residual_call_irf_f'
        assert oplist[1].args[0].value == 'llong_sub'
        assert list(oplist[1].args[1]) == []
        assert list(oplist[1].args[2]) == []
        assert list(oplist[1].args[3]) == [v_x, v]
        assert oplist[1].args[4] == 'calldescr-71'
        assert oplist[1].result == v_result

    def test_unary_op(self):
        for opname, oopspecindex in [
                ('llong_invert',   EffectInfo.OS_LLONG_INVERT),
                ('ullong_invert',  EffectInfo.OS_LLONG_INVERT),
                ]:
            if opname.startswith('u'):
                T = lltype.UnsignedLongLong
            else:
                T = lltype.SignedLongLong
            self.do_check(opname, oopspecindex, [T], T)

    def test_comparison(self):
        for opname, oopspecindex in [
                ('llong_lt',  EffectInfo.OS_LLONG_LT),
                ('llong_le',  EffectInfo.OS_LLONG_LE),
                ('llong_eq',  EffectInfo.OS_LLONG_EQ),
                ('llong_ne',  EffectInfo.OS_LLONG_NE),
                ('llong_gt',  EffectInfo.OS_LLONG_GT),
                ('llong_ge',  EffectInfo.OS_LLONG_GE),
                ('ullong_lt', EffectInfo.OS_LLONG_ULT),
                ('ullong_le', EffectInfo.OS_LLONG_ULE),
                ('ullong_eq', EffectInfo.OS_LLONG_EQ),
                ('ullong_ne', EffectInfo.OS_LLONG_NE),
                ('ullong_gt', EffectInfo.OS_LLONG_UGT),
                ('ullong_ge', EffectInfo.OS_LLONG_UGE),
                ]:
            if opname.startswith('u'):
                T = lltype.UnsignedLongLong
            else:
                T = lltype.SignedLongLong
            self.do_check(opname, oopspecindex, [T, T], lltype.Bool)

    def test_binary_op(self):
        for opname, oopspecindex in [
                ('llong_add',    EffectInfo.OS_LLONG_ADD),
                ('llong_sub',    EffectInfo.OS_LLONG_SUB),
                ('llong_mul',    EffectInfo.OS_LLONG_MUL),
                ('llong_and',    EffectInfo.OS_LLONG_AND),
                ('llong_or',     EffectInfo.OS_LLONG_OR),
                ('llong_xor',    EffectInfo.OS_LLONG_XOR),
                ('ullong_add',   EffectInfo.OS_LLONG_ADD),
                ('ullong_sub',   EffectInfo.OS_LLONG_SUB),
                ('ullong_mul',   EffectInfo.OS_LLONG_MUL),
                ('ullong_and',   EffectInfo.OS_LLONG_AND),
                ('ullong_or',    EffectInfo.OS_LLONG_OR),
                ('ullong_xor',   EffectInfo.OS_LLONG_XOR),
                ]:
            if opname.startswith('u'):
                T = lltype.UnsignedLongLong
            else:
                T = lltype.SignedLongLong
            self.do_check(opname, oopspecindex, [T, T], T)

    def test_shifts(self):
        for opname, oopspecindex in [
                ('llong_lshift',  EffectInfo.OS_LLONG_LSHIFT),
                ('llong_rshift',  EffectInfo.OS_LLONG_RSHIFT),
                ('ullong_lshift', EffectInfo.OS_LLONG_LSHIFT),
                ('ullong_rshift', EffectInfo.OS_LLONG_URSHIFT),
                ]:
            if opname.startswith('u'):
                T = lltype.UnsignedLongLong
            else:
                T = lltype.SignedLongLong
            self.do_check(opname, oopspecindex, [T, lltype.Signed], T)

    def test_casts(self):
        self.do_check('cast_int_to_longlong', EffectInfo.OS_LLONG_FROM_INT,
                      [lltype.Signed], lltype.SignedLongLong)
        self.do_check('cast_uint_to_longlong', EffectInfo.OS_LLONG_FROM_UINT,
                      [lltype.Unsigned], lltype.SignedLongLong)
        self.do_check('truncate_longlong_to_int', EffectInfo.OS_LLONG_TO_INT,
                      [lltype.SignedLongLong], lltype.Signed)
        self.do_check('cast_float_to_longlong', EffectInfo.OS_LLONG_FROM_FLOAT,
                      [lltype.Float], lltype.SignedLongLong)
        self.do_check('cast_float_to_ulonglong', EffectInfo.OS_LLONG_FROM_FLOAT,
                      [lltype.Float], lltype.UnsignedLongLong)
        self.do_check('cast_longlong_to_float', EffectInfo.OS_LLONG_TO_FLOAT,
                      [lltype.SignedLongLong], lltype.Float)
        self.do_check('cast_ulonglong_to_float', EffectInfo.OS_LLONG_U_TO_FLOAT,
                      [lltype.UnsignedLongLong], lltype.Float)
        for T1 in [lltype.SignedLongLong, lltype.UnsignedLongLong]:
            for T2 in [lltype.Signed, lltype.Unsigned]:
                self.do_check('cast_primitive', EffectInfo.OS_LLONG_TO_INT,
                              [T1], T2)
                self.do_check('force_cast', EffectInfo.OS_LLONG_TO_INT,
                              [T1], T2)
                if T2 == lltype.Signed:
                    expected = EffectInfo.OS_LLONG_FROM_INT
                else:
                    expected = EffectInfo.OS_LLONG_FROM_UINT
                self.do_check('cast_primitive', expected, [T2], T1)
                self.do_check('force_cast', expected, [T2], T1)
        #
        for T1 in [lltype.SignedLongLong, lltype.UnsignedLongLong]:
            for T2 in [lltype.SignedLongLong, lltype.UnsignedLongLong]:
                vlist = [varoftype(T1)]
                v_result = varoftype(T2)
                op = SpaceOperation('force_cast', vlist, v_result)
                tr = Transformer(FakeCPU(), FakeBuiltinCallControl())
                op1 = tr.rewrite_operation(op)
                assert op1 is None

    def test_constants(self):
        for TYPE in [lltype.SignedLongLong, lltype.UnsignedLongLong]:
            v_x = varoftype(TYPE)
            vlist = [v_x, const(rffi.cast(TYPE, 7))]
            v_result = varoftype(TYPE)
            op = SpaceOperation('llong_add', vlist, v_result)
            tr = Transformer(FakeCPU(), FakeBuiltinCallControl())
            op1 = tr.rewrite_operation(op)
            #
            assert op1.opname == 'residual_call_irf_f'
            assert list(op1.args[1]) == []
            assert list(op1.args[2]) == []
            assert list(op1.args[3]) == vlist
            assert op1.result == v_result

