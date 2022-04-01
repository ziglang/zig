import py
import pytest
import platform
import re
import sys
from rpython.jit.metainterp import resoperation as rop
from rpython.jit.metainterp.history import AbstractDescr, AbstractFailDescr
from rpython.jit.metainterp.history import ConstInt
from rpython.jit.backend.llsupport.symbolic import (WORD as INT_WORD,
        SIZEOF_FLOAT as FLOAT_WORD)
from rpython.jit.backend.llsupport.descr import ArrayDescr

def test_arity_mixins():
    cases = [
        (0, rop.NullaryOp),
        (1, rop.UnaryOp),
        (2, rop.BinaryOp),
        (3, rop.TernaryOp),
        (9, rop.N_aryOp)
        ]

    def test_case(n, cls):
        obj = cls()
        obj.initarglist(range(n))
        assert obj.getarglist() == range(n)
        for i in range(n):
            obj.setarg(i, i*2)
        assert obj.numargs() == n
        for i in range(n):
            assert obj.getarg(i) == i*2
        py.test.raises(IndexError, obj.getarg, n+1)
        py.test.raises(IndexError, obj.setarg, n+1, 0)

    for n, cls in cases:
        test_case(n, cls)

def test_concrete_classes():
    cls = rop.opclasses[rop.rop.INT_ADD]
    assert issubclass(cls, rop.PlainResOp)
    assert issubclass(cls, rop.BinaryOp)
    assert cls.getopnum.im_func(cls) == rop.rop.INT_ADD

    cls = rop.opclasses[rop.rop.CALL_N]
    assert issubclass(cls, rop.ResOpWithDescr)
    assert issubclass(cls, rop.N_aryOp)
    assert cls.getopnum.im_func(cls) == rop.rop.CALL_N

    cls = rop.opclasses[rop.rop.GUARD_TRUE]
    assert issubclass(cls, rop.GuardResOp)
    assert issubclass(cls, rop.UnaryOp)
    assert cls.getopnum.im_func(cls) == rop.rop.GUARD_TRUE

def test_mixins_in_common_base():
    INT_ADD = rop.opclasses[rop.rop.INT_ADD]
    assert len(INT_ADD.__bases__) == 1
    BinaryPlainResOp = INT_ADD.__bases__[0]
    assert BinaryPlainResOp.__name__ == 'BinaryPlainResOp'
    assert BinaryPlainResOp.__bases__ == (rop.BinaryOp, rop.PlainResOp)
    INT_SUB = rop.opclasses[rop.rop.INT_SUB]
    assert INT_SUB.__bases__[0] is BinaryPlainResOp

def test_instantiate():
    a = ConstInt(1)
    b = ConstInt(2)
    op = rop.ResOperation(rop.rop.INT_ADD, [a, b])
    assert op.getarglist() == [a, b]
    #assert re.match(".*= int_add(a, b)", repr(op))

    mydescr = AbstractDescr()
    op = rop.ResOperation(rop.rop.CALL_I, [a, b], descr=mydescr)
    assert op.getarglist() == [a, b]
    assert op.getdescr() is mydescr
    #assert re.match(".* = call\(a, b, descr=<.+>\)$", repr(op))

    mydescr = AbstractFailDescr()
    op = rop.ResOperation(rop.rop.GUARD_NO_EXCEPTION, [], descr=mydescr)
    #assert re.match("guard_no_exception\(descr=<.+>\)$", repr(op))

def test_can_malloc():
    assert rop.rop.can_malloc(rop.rop.NEW)
    assert rop.rop.can_malloc(rop.rop.CALL_N)
    assert not rop.rop.can_malloc(rop.rop.INT_ADD)

def test_get_deep_immutable_oplist():
    a = ConstInt(1)
    b = ConstInt(2)
    ops = [rop.ResOperation(rop.rop.INT_ADD, [a, b])]
    newops = rop.get_deep_immutable_oplist(ops)
    py.test.raises(TypeError, "newops.append('foobar')")
    py.test.raises(TypeError, "newops[0] = 'foobar'")
    py.test.raises(AssertionError, "newops[0].setarg(0, 'd')")
    py.test.raises(AssertionError, "newops[0].setdescr('foobar')")

VARI = rop.InputArgInt()
VARF = rop.InputArgFloat()
args = [ (rop.rop.INT_SIGNEXT, [VARI, ConstInt(2)], {'from': INT_WORD, 'to': 2, 'cast_to': ('i', 2) }),
         (rop.rop.CAST_FLOAT_TO_INT, [VARF], {'from': 8, 'to': 4}),
         (rop.rop.CAST_SINGLEFLOAT_TO_FLOAT, [VARI], {'from': 4, 'to': 8}),
         (rop.rop.CAST_FLOAT_TO_SINGLEFLOAT, [VARF], {'from': 8, 'to': 4}),
        ]
if not platform.machine().startswith('x86'):
    del args[1]
    args.append((rop.rop.CAST_FLOAT_TO_INT, [VARF], {'from': 8, 'to': 8}))
@py.test.mark.parametrize('opnum,args,kwargs', args)
@pytest.mark.skipif("sys.maxint == 2**31-1")
def test_cast_ops(opnum, args, kwargs):
    op = rop.ResOperation(opnum, args)
    assert op.is_typecast()
    assert op.cast_from_bytesize() == kwargs['from']
    assert op.cast_to_bytesize() == kwargs['to']
    if 'cast_to' in kwargs:
        assert op.cast_to() == kwargs['cast_to']
del args

def test_unpack_1():
    op = rop.ResOperation(rop.rop.VEC_UNPACK_I,
            [rop.InputArgVector(), ConstInt(0), ConstInt(1)])
    assert (op.type, op.is_vector()) == ('i', False)
    op = rop.ResOperation(rop.rop.VEC_UNPACK_I,
            [rop.InputArgVector(), ConstInt(0), ConstInt(2)])
    assert (op.type, op.is_vector()) == ('i', True)

def test_load_singlefloat():
    descr = ArrayDescr(8,4, None, 'S', concrete_type='f')
    args = [rop.InputArgInt(), ConstInt(0)]
    baseop = rop.ResOperation(rop.rop.RAW_LOAD_I, args, descr=descr)
    baseop.set_forwarded(rop.VectorizationInfo(baseop))
    op = rop.VecOperation(rop.rop.VEC_LOAD_I, args + [ConstInt(1), ConstInt(0)],
                          baseop, 4, descr=descr)
    assert (op.type, op.datatype, op.bytesize, op.is_vector()) == ('i', 'i', 4, True)

def test_vec_store():
    descr = ArrayDescr(0,8, None, 'F', concrete_type='f')
    vec = rop.InputArgVector()
    args = [rop.InputArgRef(), ConstInt(0), vec]
    baseop = rop.ResOperation(rop.rop.RAW_STORE,  args, descr=descr)
    baseop.set_forwarded(rop.VectorizationInfo(baseop))
    op = rop.VecOperation(rop.rop.VEC_STORE, args + [ConstInt(1), ConstInt(0)],
                          baseop, 2, descr=descr)
    assert (op.type, op.datatype, op.bytesize, op.is_vector()) == ('v', 'v', 8, True)

def test_vec_guard():
    vec = rop.InputArgVector()
    vec.bytesize = 4
    vec.type = vec.datatype = 'i'
    vec.sigend = True
    baseop = rop.ResOperation(rop.rop.GUARD_TRUE, [vec])
    baseop.set_forwarded(rop.VectorizationInfo(baseop))
    op = rop.VecOperation(rop.rop.VEC_GUARD_TRUE, [vec], baseop, 4)
    assert (op.type, op.datatype, op.bytesize, op.is_vector()) == ('v', 'v', 0, False)

def test_types():
    op = rop.ResOperation(rop.rop.INT_ADD, [ConstInt(0),ConstInt(1)])
    op.set_forwarded(rop.VectorizationInfo(op))
    baseop = rop.ResOperation(rop.rop.CAST_FLOAT_TO_SINGLEFLOAT, [op])
    baseop.set_forwarded(rop.VectorizationInfo(baseop))
    op = rop.VecOperation(rop.rop.VEC_CAST_FLOAT_TO_SINGLEFLOAT, [op], baseop, 2)
    assert op.type == 'i'
    assert op.datatype == 'i'
    assert op.bytesize == 4
