import py
import sys, random
from rpython.rlib.rarithmetic import r_uint, intmask
from rpython.jit.metainterp.executor import execute, wrap_constant
from rpython.jit.metainterp.executor import execute_varargs, _execute_arglist
from rpython.jit.metainterp.resoperation import rop, opname, opclasses,\
     InputArgInt, InputArgFloat, InputArgRef
from rpython.jit.metainterp.history import ConstInt, ConstPtr, ConstFloat
from rpython.jit.metainterp.history import AbstractDescr
from rpython.jit.metainterp import history
from rpython.jit.codewriter import longlong
from rpython.jit.backend.model import AbstractCPU
from rpython.rtyper.lltypesystem import  llmemory, rffi

class FakeDescr(AbstractDescr):
    pass

class FakeCallDescr(FakeDescr):
    def get_result_type(self):
        return history.FLOAT

class FakeFieldDescr(FakeDescr):
    def is_pointer_field(self):
        return False
    def is_float_field(self):
        return True

class FakeArrayDescr(FakeDescr):
    def is_array_of_pointers(self):
        return False
    def is_array_of_floats(self):
        return True

class FakeResultR:
    _TYPE = llmemory.GCREF
    def __init__(self, *args):
        self.fakeargs = args

class FakeMetaInterp:
    pass

class FakeCPU(AbstractCPU):
    supports_floats = True

    def bh_new(self, descr):
        return FakeResultR('new', descr)

    def bh_arraylen_gc(self, array, descr):
        assert not array
        assert isinstance(descr, FakeDescr)
        return 55

    def bh_setfield_gc_f(self, struct, newvalue, fielddescr):
        self.fakesetfield = (struct, newvalue, fielddescr)

    def bh_setarrayitem_gc_f(self, array, index, newvalue, arraydescr):
        self.fakesetarrayitem = (array, index, newvalue, arraydescr)

    def bh_call_f(self, func, args_i, args_r, args_f, calldescr):
        self.fakecalled = (func, args_i, args_r, args_f, calldescr)
        return longlong.getfloatstorage(42.5)

    def bh_strsetitem(self, string, index, newvalue):
        self.fakestrsetitem = (string, index, newvalue)


boxfloat = InputArgFloat.fromfloat
constfloat = ConstFloat.fromfloat


def test_execute():
    cpu = FakeCPU()
    descr = FakeDescr()
    box = execute(cpu, None, rop.INT_ADD, None, InputArgInt(40), ConstInt(2))
    assert box == 42
    box = execute(cpu, None, rop.NEW, descr)
    assert box.fakeargs == ('new', descr)

def test_execute_varargs():
    cpu = FakeCPU()
    descr = FakeCallDescr()
    argboxes = [InputArgInt(99999), InputArgInt(321), constfloat(2.25), ConstInt(123),
                InputArgRef(), boxfloat(5.5)]
    box = execute_varargs(cpu, FakeMetaInterp(), rop.CALL_F, argboxes, descr)
    assert longlong.getrealfloat(box) == 42.5
    assert cpu.fakecalled == (99999, [321, 123],
                              [ConstPtr.value],
                              [longlong.getfloatstorage(2.25),
                               longlong.getfloatstorage(5.5)],
                              descr)

def test_execute_nonspec():
    cpu = FakeCPU()
    descr = FakeDescr()
    # cases with a descr
    # arity == -1
    argboxes = [InputArgInt(321), ConstInt(123)]
    box = _execute_arglist(cpu, FakeMetaInterp(), rop.CALL_F,
                           argboxes, FakeCallDescr())
    assert longlong.getrealfloat(box) == 42.5
    # arity == 0
    box = _execute_arglist(cpu, None, rop.NEW, [], descr)
    assert box.fakeargs == ('new', descr)
    # arity == 1
    box1 = InputArgRef()
    box = _execute_arglist(cpu, None, rop.ARRAYLEN_GC, [box1], descr)
    assert box == 55
    # arity == 2
    box2 = boxfloat(222.2)
    fielddescr = FakeFieldDescr()
    _execute_arglist(cpu, None, rop.SETFIELD_GC, [box1, box2], fielddescr)
    assert cpu.fakesetfield == (box1.getref_base(), box2.getfloatstorage(),
                                fielddescr)
    # arity == 3
    box3 = InputArgInt(33)
    arraydescr = FakeArrayDescr()
    _execute_arglist(cpu, None, rop.SETARRAYITEM_GC, [box1, box3, box2],
                    arraydescr)
    assert cpu.fakesetarrayitem == (box1.getref_base(), box3.getint(),
                                    box2.getfloatstorage(), arraydescr)
    # cases without descr
    # arity == 1
    box = _execute_arglist(cpu, None, rop.INT_INVERT, [box3])
    assert box == ~33
    # arity == 2
    box = _execute_arglist(cpu, None, rop.INT_LSHIFT, [box3, InputArgInt(3)])
    assert box == 33 << 3
    # arity == 3
    _execute_arglist(cpu, None, rop.STRSETITEM, [box1, InputArgInt(3), box3])
    assert cpu.fakestrsetitem == (box1.getref_base(), 3, box3.getint())

# ints

def _int_binary_operations():
    minint = -sys.maxint-1
    # Test cases.  Note that for each operation there should be at least
    # one case in which the two input arguments are equal.
    for opnum, testcases in [
        (rop.INT_ADD, [(10, -2, 8),
                       (-60, -60, -120)]),
        (rop.INT_SUB, [(10, -2, 12),
                       (133, 133, 0)]),
        (rop.INT_MUL, [(-6, -3, 18),
                       (15, 15, 225)]),
        (rop.INT_AND, [(0xFF00, 0x0FF0, 0x0F00),
                       (-111, -111, -111)]),
        (rop.INT_OR, [(0xFF00, 0x0FF0, 0xFFF0),
                      (-111, -111, -111)]),
        (rop.INT_XOR, [(0xFF00, 0x0FF0, 0xF0F0),
                       (-111, -111, 0)]),
        (rop.INT_LSHIFT, [(10, 4, 10<<4),
                          (-5, 2, -20),
                          (-5, 0, -5),
                          (3, 3, 24)]),
        (rop.INT_RSHIFT, [(-17, 2, -5),
                          (19, 1, 9),
                          (3, 3, 0)]),
        (rop.UINT_RSHIFT, [(-1, 4, intmask(r_uint(-1) >> r_uint(4))),
                           ( 1, 4, intmask(r_uint(1) >> r_uint(4))),
                           ( 3, 3, 0)]),
        (rop.UINT_MUL_HIGH, [(5, 6, 0),
                             (0xffff, 0xffff, 0),
                             (-1, -1, -2),
                             (-1, 123, 122)]),
        ]:
        for x, y, z in testcases:
            yield opnum, [x, y], z

def _int_comparison_operations():
    cpu = FakeCPU()            
    random_numbers = [-sys.maxint-1, -1, 0, 1, sys.maxint]
    def pick():
        r = random.randrange(-99999, 100000)
        if r & 1:
            return r
        else:
            return random_numbers[r % len(random_numbers)]
    minint = -sys.maxint-1
    for opnum, operation in [
        (rop.INT_LT, lambda x, y: x <  y),
        (rop.INT_LE, lambda x, y: x <= y),
        (rop.INT_EQ, lambda x, y: x == y),
        (rop.INT_NE, lambda x, y: x != y),
        (rop.INT_GT, lambda x, y: x >  y),
        (rop.INT_GE, lambda x, y: x >= y),
        (rop.UINT_LT, lambda x, y: r_uint(x) <  r_uint(y)),
        (rop.UINT_LE, lambda x, y: r_uint(x) <= r_uint(y)),
        (rop.UINT_GT, lambda x, y: r_uint(x) >  r_uint(y)),
        (rop.UINT_GE, lambda x, y: r_uint(x) >= r_uint(y)),
        ]:
        for i in range(20):
            x = pick()
            if i == 1:      # there should be at least one case
                y = x       # where the two arguments are equal
            else:
                y = pick()
            z = int(operation(x, y))
            yield opnum, [x, y], z

def _int_unary_operations():
    minint = -sys.maxint-1
    for opnum, testcases in [
        (rop.INT_IS_TRUE, [(0, 0), (1, 1), (2, 1), (-1, 1), (minint, 1)]),
        (rop.INT_NEG, [(0, 0), (123, -123), (-23127, 23127)]),
        (rop.INT_INVERT, [(0, ~0), (-1, ~(-1)), (123, ~123)]),
        (rop.INT_IS_ZERO, [(0, 1), (1, 0), (2, 0), (-1, 0), (minint, 0)]),
        ]:
        for x, y in testcases:
            yield opnum, [x], y

def get_int_tests():
    for opnum, args, retvalue in (
            list(_int_binary_operations()) +
            list(_int_comparison_operations()) +
            list(_int_unary_operations())):
        yield opnum, [InputArgInt(x) for x in args], retvalue
        if len(args) > 1:
            assert len(args) == 2
            yield opnum, [InputArgInt(args[0]), ConstInt(args[1])], retvalue
            yield opnum, [ConstInt(args[0]), InputArgInt(args[1])], retvalue
            if args[0] == args[1]:
                commonbox = InputArgInt(args[0])
                yield opnum, [commonbox, commonbox], retvalue


def test_int_ops():
    cpu = FakeCPU()
    for opnum, boxargs, retvalue in get_int_tests():
        r = _execute_arglist(cpu, None, opnum, boxargs)
        assert r == retvalue

# floats

def _float_binary_operations():
    # Test cases.  Note that for each operation there should be at least
    # one case in which the two input arguments are equal.
    for opnum, testcases in [
        (rop.FLOAT_ADD, [(10.5, -2.25, 8.25),
                         (5.25, 5.25, 10.5)]),
        (rop.FLOAT_SUB, [(10.5, -2.25, 12.75),
                         (5.25, 5.25, 0.0)]),
        (rop.FLOAT_MUL, [(-6.5, -3.5, 22.75),
                         (1.5, 1.5, 2.25)]),
        (rop.FLOAT_TRUEDIV, [(118.75, 12.5, 9.5),
                             (-6.5, -6.5, 1.0)]),
        ]:
        for x, y, z in testcases:
            yield (opnum, [x, y], 'float', z)

def _float_comparison_operations():
    # Test cases.  Note that for each operation there should be at least
    # one case in which the two input arguments are equal.
    for y in [-522.25, 10.125, 22.6]:
        yield (rop.FLOAT_LT, [10.125, y], 'int', 10.125 < y)
        yield (rop.FLOAT_LE, [10.125, y], 'int', 10.125 <= y)
        yield (rop.FLOAT_EQ, [10.125, y], 'int', 10.125 == y)
        yield (rop.FLOAT_NE, [10.125, y], 'int', 10.125 != y)
        yield (rop.FLOAT_GT, [10.125, y], 'int', 10.125 > y)
        yield (rop.FLOAT_GE, [10.125, y], 'int', 10.125 >= y)
    yield (rop.FLOAT_EQ, [0.0, -0.0], 'int', 0.0 == -0.0)

def _float_unary_operations():
    yield (rop.FLOAT_NEG, [-5.9], 'float', 5.9)
    yield (rop.FLOAT_NEG, [15.9], 'float', -15.9)
    yield (rop.FLOAT_ABS, [-5.9], 'float', 5.9)
    yield (rop.FLOAT_ABS, [15.9], 'float', 15.9)
    yield (rop.CAST_FLOAT_TO_INT, [-5.9], 'int', -5)
    yield (rop.CAST_FLOAT_TO_INT, [5.9], 'int', 5)
    yield (rop.CAST_INT_TO_FLOAT, [123], 'float', 123.0)
    yield (rop.CAST_INT_TO_FLOAT, [-123], 'float', -123.0)

def get_float_tests(cpu):
    if not cpu.supports_floats:
        py.test.skip("requires float support from the backend")
    for opnum, args, rettype, retvalue in (
            list(_float_binary_operations()) +
            list(_float_comparison_operations()) +
            list(_float_unary_operations())):
        boxargs = []
        for x in args:
            if isinstance(x, float):
                boxargs.append(boxfloat(x))
            else:
                boxargs.append(InputArgInt(x))
        yield opnum, boxargs, rettype, retvalue
        if len(args) > 1:
            assert len(args) == 2
            yield opnum, [boxargs[0], wrap_constant(boxargs[1].getvalue())], rettype, retvalue
            yield opnum, [wrap_constant(boxargs[0].getvalue()), boxargs[1]], rettype, retvalue
            if (isinstance(args[0], float) and
                isinstance(args[1], float) and
                args[0] == args[1]):
                commonbox = boxfloat(args[0])
                yield opnum, [commonbox, commonbox], rettype, retvalue

def test_float_ops():
    cpu = FakeCPU()
    for opnum, boxargs, rettype, retvalue in get_float_tests(cpu):
        res = _execute_arglist(cpu, None, opnum, boxargs)
        if rettype == 'float':
            res = longlong.getrealfloat(res)
        assert res == retvalue

def make_args_for_op(op, a, b):
    n=opname[op]
    if n[0:3] == 'INT' or n[0:4] == 'UINT':
        arg1 = ConstInt(a)
        arg2 = ConstInt(b)
    elif n[0:5] == 'FLOAT':
        arg1 = constfloat(float(a))
        arg2 = constfloat(float(b))
    elif n[0:3] == 'PTR':
        arg1 = ConstPtr(rffi.cast(llmemory.GCREF, a))
        arg2 = ConstPtr(rffi.cast(llmemory.GCREF, b))
    else:
        raise NotImplementedError(
            "Don't know how to make args for " + n)
    return arg1, arg2


def test_opboolinvers():
    cpu = FakeCPU()
    for op1 in opclasses:
        if op1 is None or op1.boolinverse == -1:
            continue
        op2 = opclasses[op1.boolinverse].opnum
        op1 = op1.opnum
        for a in (1,2,3):
            for b in (1,2,3):
                arg1, arg2 = make_args_for_op(op1, a, b)
                box1 = execute(cpu, None, op1, None, arg1, arg2)
                box2 = execute(cpu, None, op2, None, arg1, arg2)
                assert box1 == (not box2)

def test_opboolreflex():
    cpu = FakeCPU()
    for op1 in opclasses:
        if op1 is None or op1.boolreflex == -1:
            continue
        op2 = opclasses[op1.boolreflex].opnum
        op1 = op1.opnum
        for a in (1,2,3):
            for b in (1,2,3):
                arg1, arg2 = make_args_for_op(op1, a, b)
                box1 = execute(cpu, None, op1, None, arg1, arg2)
                box2 = execute(cpu, None, op2, None, arg2, arg1)
                assert box1 == box2
