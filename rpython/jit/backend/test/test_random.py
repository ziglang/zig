import sys
import pytest
from rpython.rlib.rarithmetic import intmask, LONG_BIT
from rpython.jit.metainterp.history import BasicFailDescr, TreeLoop, BasicFinalDescr
from rpython.jit.metainterp.history import INT, ConstInt, JitCellToken
from rpython.jit.metainterp.history import REF, ConstPtr, TargetToken
from rpython.jit.metainterp.history import FLOAT, ConstFloat, Const, VOID
from rpython.jit.metainterp.resoperation import ResOperation, rop
from rpython.jit.metainterp.resoperation import InputArgInt, InputArgRef
from rpython.jit.metainterp.resoperation import InputArgFloat
from rpython.jit.metainterp.executor import _execute_arglist, wrap_constant
from rpython.jit.metainterp.resoperation import opname
from rpython.jit.codewriter import longlong
from rpython.rtyper.lltypesystem import lltype, llmemory, rstr
from rpython.rtyper import rclass


class DummyLoop(object):
    def __init__(self, subops):
        self.operations = subops

class FakeMetaInterp(object):
    ovf_flag = False
    
    def execute_raised(self, exc, constant=False):
        self._got_exc = exc


def getint(v):
    if isinstance(v, (ConstInt, InputArgInt)):
        return v.getint()
    else:
        return v._example_int

def getfloatstorage(v):
    if isinstance(v, (ConstFloat, InputArgFloat)):
        return v.getfloatstorage()
    else:
        return v._example_float

def getfloat(v):
    return longlong.getrealfloat(getfloatstorage(v))

def getref_base(v):
    if isinstance(v, (ConstPtr, InputArgRef)):
        return v.getref_base()
    else:
        return v._example_ref

def getref(PTR, v):
    return lltype.cast_opaque_ptr(PTR, getref_base(v))

def constbox(v):
    if v.type == INT:
        return ConstInt(getint(v))
    if v.type == FLOAT:
        return ConstFloat(getfloatstorage(v))
    if v.type == REF:
        return ConstPtr(getref_base(v))
    assert 0, v.type


class OperationBuilder(object):
    def __init__(self, cpu, loop, vars):
        self.cpu = cpu
        if not hasattr(cpu, '_faildescr_keepalive'):
            cpu._faildescr_keepalive = []
        self.fakemetainterp = FakeMetaInterp()
        self.loop = loop
        self.intvars = [box for box in vars if box.type == INT]
        self.boolvars = []   # subset of self.intvars
        self.ptrvars = []
        self.prebuilt_ptr_consts = []
        floatvars = [box for box in vars if box.type == FLOAT]
        if cpu.supports_floats:
            self.floatvars = floatvars
        else:
            assert floatvars == []
        self.should_fail_by = None
        self.counter = 0
        assert len(self.intvars) == len(dict.fromkeys(self.intvars))
        self.descr_counters = {}

    def fork(self, cpu, loop, vars):
        fork = self.__class__(cpu, loop, vars)
        fork.prebuilt_ptr_consts = self.prebuilt_ptr_consts
        fork.descr_counters = self.descr_counters
        return fork

    def do(self, opnum, argboxes, descr=None):
        self.fakemetainterp._got_exc = None
        op = ResOperation(opnum, argboxes, descr)
        argboxes = map(constbox, argboxes)
        result = _execute_arglist(self.cpu, self.fakemetainterp,
                                  opnum, argboxes, descr)
        if result is not None:
            if lltype.typeOf(result) == lltype.Signed:
                op._example_int = result
            elif isinstance(result, bool):
                op._example_int = int(result)
            elif lltype.typeOf(result) == longlong.FLOATSTORAGE:
                op._example_float = result
            elif isinstance(result, float):
                op._example_float = longlong.getfloatstorage(result)
            else:
                assert lltype.typeOf(result) == llmemory.GCREF
                op._example_ref = result
        self.loop.operations.append(op)
        return op

    def get_bool_var(self, r):
        if self.boolvars and r.random() < 0.8:
            return r.choice(self.boolvars)
        elif self.ptrvars and r.random() < 0.4:
            v, S = r.choice(self.ptrvars + self.prebuilt_ptr_consts)[:2]
            v2, S2 = r.choice(self.ptrvars + self.prebuilt_ptr_consts)[:2]
            if S == S2 and not (isinstance(v, ConstPtr) and
                                isinstance(v2, ConstPtr)):
                if r.random() < 0.5:
                    return self.do(rop.PTR_EQ, [v, v2])
                else:
                    return self.do(rop.PTR_NE, [v, v2])
        v = r.choice(self.intvars)
        if r.random() < 0.7:
            return self.do(rop.INT_IS_TRUE, [v])
        else:
            return self.do(rop.INT_IS_ZERO, [v])

    def subset_of_intvars(self, r):
        subset = []
        k = r.random()
        num = int(k * len(self.intvars))
        seen = {}
        for i in range(num):
            v = r.choice(self.intvars)
            if v not in seen:
                subset.append(v)
                seen[v] = True
        return subset

    def process_operation(self, s, op, names):
        args = []
        for v in op.getarglist():
            if v in names:
                args.append(names[v])
            elif isinstance(v, ConstPtr):
                assert not getref_base(v) # otherwise should be in the names
                args.append('ConstPtr(lltype.nullptr(llmemory.GCREF.TO))')
            elif isinstance(v, ConstFloat):
                args.append('ConstFloat(longlong.getfloatstorage(%r))'
                            % v.getfloat())
            elif isinstance(v, ConstInt):
                args.append('ConstInt(%s)' % v.getint())
            else:
                raise NotImplementedError(v)
        if op.getdescr() is None:
            descrstr = ''
        else:
            try:
                descrstr = ', ' + getattr(op.getdescr(), '_random_info')
            except AttributeError:
                if op.opnum == rop.LABEL:
                    descrstr = ', TargetToken()'
                else:
                    descrstr = ', descr=' + self.descr_counters.get(op.getdescr(), '...')
        print >>s, '        %s = ResOperation(rop.%s, [%s]%s),' % (
            names[op], opname[op.getopnum()], ', '.join(args), descrstr)

    def print_loop(self, output, fail_descr=None, fail_args=None):
        def update_names(ops):
            for op in ops:
                v = op
                if v not in names:
                    writevar(v, 'tmp')
                if op.is_guard() or op.opnum == rop.FINISH:
                    descr = op.getdescr()
                    no = len(self.descr_counters)
                    if op.is_guard():
                        name = 'faildescr%d' % no
                        clsname = 'BasicFailDescr'
                    else:
                        name = 'finishdescr%d' % no
                        clsname = 'BasicFinalDescr'
                    self.descr_counters[descr] = name
                    print >>s, "    %s = %s()" % (name, clsname)

        def print_loop_prebuilt(ops):
            for op in ops:
                for arg in op.getarglist():
                    if isinstance(arg, ConstPtr):
                        if arg not in names:
                            writevar(arg, 'const_ptr')

        def type_descr(TP):
            if TP in TYPE_NAMES:
                return TYPE_NAMES[TP]
            elif isinstance(TP, lltype.Primitive):
                return _type_descr(TP) # don't cache
            else:
                descr = _type_descr(TP)
                no = len(TYPE_NAMES)
                tp_name = 'S' + str(no)
                TYPE_NAMES[TP] = tp_name
                print >>s, '    %s = %s' % (tp_name, descr)
                return tp_name

        def _type_descr(TP):
            if isinstance(TP, lltype.Ptr):
                return "lltype.Ptr(%s)" % type_descr(TP.TO)
            if isinstance(TP, lltype.Struct):
                if TP._gckind == 'gc':
                    pref = 'Gc'
                else:
                    pref = ''
                fields = []
                for k in TP._names:
                    v = getattr(TP, k)
                    fields.append('("%s", %s)' % (k, type_descr(v)))
                return "lltype.%sStruct('Sx', %s)" % (pref,
                                                       ", ".join(fields))
            elif isinstance(TP, lltype.GcArray):
                return "lltype.GcArray(%s)" % (type_descr(TP.OF),)
            if TP._name.upper() == TP._name:
                return 'rffi.%s' % TP._name
            return 'lltype.%s' % TP._name

        s = output
        names = {None: 'None'}
        TYPE_NAMES = {
            rstr.STR: 'rstr.STR',
            rstr.UNICODE: 'rstr.UNICODE',
            rclass.OBJECT: 'rclass.OBJECT',
            rclass.OBJECT_VTABLE: 'rclass.OBJECT_VTABLE',
        }
        for op in self.loop.operations:
            descr = op.getdescr()
            if hasattr(descr, '_random_info'):
                tp_name = type_descr(descr._random_type)
                descr._random_info = descr._random_info.replace('...', tp_name)

        #
        def writevar(v, nameprefix, init=''):
            if nameprefix == 'const_ptr':
                if not getref_base(v):
                    return 'lltype.nullptr(llmemory.GCREF.TO)'
                TYPE = getref_base(v)._obj.ORIGTYPE
                cont = lltype.cast_opaque_ptr(TYPE, getref_base(v))
                if TYPE.TO._is_varsize():
                    if isinstance(TYPE.TO, lltype.GcStruct):
                        lgt = len(cont.chars)
                    else:
                        lgt = len(cont)
                    init = 'lltype.malloc(%s, %d)' % (TYPE_NAMES[TYPE.TO],
                                                      lgt)
                else:
                    init = 'lltype.malloc(%s)' % TYPE_NAMES[TYPE.TO]
                init = 'lltype.cast_opaque_ptr(llmemory.GCREF, %s)' % init
            names[v] = '%s%d' % (nameprefix, len(names))
            print >>s, '    %s = %s(%s)' % (names[v], v.__class__.__name__,
                                            init)
        #
        for v in self.intvars:
            writevar(v, 'v')
        for v in self.floatvars:
            writevar(v, 'f')
        for v, S in self.ptrvars:
            writevar(v, 'p')
        update_names(self.loop.operations)
        print_loop_prebuilt(self.loop.operations)
        #
        if fail_descr is None:
            print >>s, '    cpu = CPU(None, None)'
            print >>s, '    cpu.setup_once()'
        if hasattr(self.loop, 'inputargs'):
            print >>s, '    inputargs = [%s]' % (
                ', '.join([names[v] for v in self.loop.inputargs]))
        else:
            print >>s, '    inputargs = [%s]' % (
                ', '.join([names[v] for v in fail_args]))
        print >>s, '    operations = ['
        for op in self.loop.operations:
            self.process_operation(s, op, names)
        print >>s, '        ]'
        for i, op in enumerate(self.loop.operations):
            if op.is_guard():
                fa = ", ".join([names[v] for v in op.getfailargs()])
                print >>s, '    operations[%d].setfailargs([%s])' % (i, fa)
        if fail_descr is None:
            print >>s, '    looptoken = JitCellToken()'
            print >>s, '    cpu.compile_loop(inputargs, operations, looptoken)'
        else:
            print >>s, '    cpu.compile_bridge(%s, inputargs, operations, looptoken)' % self.descr_counters[fail_descr]
        if hasattr(self.loop, 'inputargs'):
            vals = []
            for i, v in enumerate(self.loop.inputargs):
                assert not isinstance(v, Const)
                if v.type == FLOAT:
                    vals.append("longlong.getfloatstorage(%r)" % getfloat(v))
                else:
                    vals.append("%r" % getint(v))
            print >>s, '    loop_args = [%s]' % ", ".join(vals)
        print >>s, '    frame = cpu.execute_token(looptoken, *loop_args)'
        if self.should_fail_by is None:
            fail_args = self.loop.operations[-1].getarglist()
        else:
            fail_args = self.should_fail_by.getfailargs()
        for i, v in enumerate(fail_args):
            if v.type == FLOAT:
                print >>s, ('    assert longlong.getrealfloat('
                    'cpu.get_float_value(frame, %d)) == %r' % (i, getfloatstorage(v)))
            else:
                print >>s, ('    assert cpu.get_int_value(frame, %d) == %d'
                            % (i, getint(v)))
        self.names = names
        s.flush()

    def getfaildescr(self, is_finish=False):
        if is_finish:
            descr = BasicFinalDescr()
        else:
            descr = BasicFailDescr()
        self.cpu._faildescr_keepalive.append(descr)
        return descr

class CannotProduceOperation(Exception):
    pass

class AbstractOperation(object):
    def __init__(self, opnum, boolres=False):
        self.opnum = opnum
        self.boolres = boolres
    def filter(self, builder):
        pass
    def put(self, builder, args, descr=None):
        v_result = builder.do(self.opnum, args, descr=descr)
        if v_result is not None:
            if v_result.type == INT:
                builder.intvars.append(v_result)
                boolres = self.boolres
                if boolres == 'sometimes':
                    boolres = getint(v_result) in [0, 1]
                if boolres:
                    builder.boolvars.append(v_result)
            elif v_result.type == FLOAT:
                builder.floatvars.append(v_result)
                assert self.boolres != True
            elif v_result.type == VOID:
                assert self.boolres != True
            else:
                raise NotImplementedError(v_result)

class UnaryOperation(AbstractOperation):
    def produce_into(self, builder, r):
        self.put(builder, [r.choice(builder.intvars)])

class BooleanUnaryOperation(UnaryOperation):
    def produce_into(self, builder, r):
        v = builder.get_bool_var(r)
        self.put(builder, [v])

class ConstUnaryOperation(UnaryOperation):
    def produce_into(self, builder, r):
        if r.random() < 0.4:
            UnaryOperation.produce_into(self, builder, r)
        else:
            self.put(builder, [ConstInt(r.random_integer())])

class SignExtOperation(AbstractOperation):
    def produce_into(self, builder, r):
        sizes = [1, 2]
        if sys.maxint > (1 << 32):
            sizes.append(4)
        self.put(builder, [r.choice(builder.intvars),
                           ConstInt(r.choice(sizes))])

class BinaryOperation(AbstractOperation):
    def __init__(self, opnum, and_mask=-1, or_mask=0, boolres=False):
        AbstractOperation.__init__(self, opnum, boolres=boolres)
        self.and_mask = and_mask
        self.or_mask = or_mask
    def produce_into(self, builder, r):
        k = r.random()
        if k < 0.2:
            v_first = ConstInt(r.random_integer())
        else:
            v_first = r.choice(builder.intvars)
        if k > 0.75:
            value = r.random_integer()
            v_second = ConstInt((value & self.and_mask) | self.or_mask)
        else:
            v = r.choice(builder.intvars)
            v_value = getint(v)
            if (v_value & self.and_mask) != v_value:
                v = builder.do(rop.INT_AND, [v, ConstInt(self.and_mask)])
            v_value = getint(v)
            if (v_value | self.or_mask) != v_value:
                v = builder.do(rop.INT_OR, [v, ConstInt(self.or_mask)])
            v_second = v
        self.put(builder, [v_first, v_second])

class AbstractOvfOperation(AbstractOperation):
    def produce_into(self, builder, r):
        fail_subset = builder.subset_of_intvars(r)
        original_intvars = builder.intvars[:]
        builder.fakemetainterp.ovf_flag = False
        super(AbstractOvfOperation, self).produce_into(builder, r)
        if builder.fakemetainterp.ovf_flag:   # overflow detected
            op = ResOperation(rop.GUARD_OVERFLOW, [])
            # the overflowed result should not be used any more, but can
            # be used on the failure path: recompute fail_subset including
            # the result, and then remove it from builder.intvars.
            fail_subset = builder.subset_of_intvars(r)
            builder.intvars[:] = original_intvars
        else:
            op = ResOperation(rop.GUARD_NO_OVERFLOW, [])
        op.setdescr(builder.getfaildescr())
        op.setfailargs(fail_subset)
        builder.loop.operations.append(op)

class BinaryOvfOperation(AbstractOvfOperation, BinaryOperation):
    pass

class AbstractFloatOperation(AbstractOperation):
    def filter(self, builder):
        if not builder.cpu.supports_floats:
            raise CannotProduceOperation

class BinaryFloatOperation(AbstractFloatOperation):
    def produce_into(self, builder, r):
        if not builder.floatvars:
            raise CannotProduceOperation
        k = r.random()
        if k < 0.18:
            v_first = ConstFloat(r.random_float_storage())
        else:
            v_first = r.choice(builder.floatvars)
        if k > 0.82:
            v_second = ConstFloat(r.random_float_storage())
        else:
            v_second = r.choice(builder.floatvars)
        if abs(getfloat(v_first)) > 1E100 or abs(getfloat(v_second)) > 1E100:
            raise CannotProduceOperation     # avoid infinities
        if abs(getfloat(v_second)) < 1E-100:
            raise CannotProduceOperation     # e.g. division by zero error
        self.put(builder, [v_first, v_second])

class UnaryFloatOperation(AbstractFloatOperation):
    def produce_into(self, builder, r):
        if not builder.floatvars:
            raise CannotProduceOperation
        self.put(builder, [r.choice(builder.floatvars)])

class ConstUnaryFloatOperation(UnaryFloatOperation):
    def produce_into(self, builder, r):
        if r.random() < 0.4:
            UnaryFloatOperation.produce_into(self, builder, r)
        else:
            self.put(builder, [ConstFloat(r.random_float_storage())])

class CastIntToFloatOperation(AbstractFloatOperation):
    def produce_into(self, builder, r):
        self.put(builder, [r.choice(builder.intvars)])

class CastLongLongToFloatOperation(AbstractFloatOperation):
    def produce_into(self, builder, r):
        if longlong.is_64_bit:
            self.put(builder, [r.choice(builder.intvars)])
        else:
            if not builder.floatvars:
                raise CannotProduceOperation
            self.put(builder, [r.choice(builder.floatvars)])

class CastFloatToIntOperation(AbstractFloatOperation):
    def produce_into(self, builder, r):
        if not builder.floatvars:
            raise CannotProduceOperation
        box = r.choice(builder.floatvars)
        if not (-sys.maxint-1 <= getfloat(box) <= sys.maxint):
            raise CannotProduceOperation      # would give an overflow
        self.put(builder, [box])

class GuardOperation(AbstractOperation):
    def gen_guard(self, builder, r):
        v = builder.get_bool_var(r)
        op = ResOperation(self.opnum, [v])
        passing = ((self.opnum == rop.GUARD_TRUE and getint(v)) or
                   (self.opnum == rop.GUARD_FALSE and not getint(v)))
        return op, passing

    def produce_into(self, builder, r):
        op, passing = self.gen_guard(builder, r)
        builder.loop.operations.append(op)
        op.setdescr(builder.getfaildescr())
        op.setfailargs(builder.subset_of_intvars(r))
        if not passing:
            builder.should_fail_by = op
            builder.guard_op = op

class GuardPtrOperation(GuardOperation):
    def gen_guard(self, builder, r):
        if not builder.ptrvars:
            raise CannotProduceOperation
        box = r.choice(builder.ptrvars)[0]
        op = ResOperation(self.opnum, [box])
        passing = ((self.opnum == rop.GUARD_NONNULL and getref_base(box)) or
                   (self.opnum == rop.GUARD_ISNULL and not getref_base(box)))
        return op, passing

class GuardValueOperation(GuardOperation):
    def gen_guard(self, builder, r):
        v = r.choice(builder.intvars)
        if r.random() > 0.8:
            other = r.choice(builder.intvars)
        else:
            if r.random() < 0.75:
                value = getint(v)
            elif r.random() < 0.5:
                value = getint(v) ^ 1
            else:
                value = r.random_integer()
            other = ConstInt(value)
        op = ResOperation(self.opnum, [v, other])
        return op, (getint(v) == getint(other))

# ____________________________________________________________

OPERATIONS = []

for _op in [rop.INT_ADD,
            rop.INT_SUB,
            rop.INT_MUL,
            rop.INT_AND,
            rop.INT_OR,
            rop.INT_XOR,
            rop.UINT_MUL_HIGH,
            ]:
    OPERATIONS.append(BinaryOperation(_op))

for _op in [rop.INT_LT,
            rop.INT_LE,
            rop.INT_EQ,
            rop.INT_NE,
            rop.INT_GT,
            rop.INT_GE,
            rop.UINT_LT,
            rop.UINT_LE,
            rop.UINT_GT,
            rop.UINT_GE,
            ]:
    OPERATIONS.append(BinaryOperation(_op, boolres=True))

#OPERATIONS.append(BinaryOperation(rop.INT_FLOORDIV, ~3, 2))
#OPERATIONS.append(BinaryOperation(rop.INT_MOD, ~3, 2))
OPERATIONS.append(BinaryOperation(rop.INT_RSHIFT, LONG_BIT-1))
OPERATIONS.append(BinaryOperation(rop.INT_LSHIFT, LONG_BIT-1))
OPERATIONS.append(BinaryOperation(rop.UINT_RSHIFT, LONG_BIT-1))

OPERATIONS.append(GuardOperation(rop.GUARD_TRUE))
OPERATIONS.append(GuardOperation(rop.GUARD_TRUE))
OPERATIONS.append(GuardOperation(rop.GUARD_FALSE))
OPERATIONS.append(GuardOperation(rop.GUARD_FALSE))
OPERATIONS.append(GuardPtrOperation(rop.GUARD_NONNULL))
OPERATIONS.append(GuardPtrOperation(rop.GUARD_ISNULL))
OPERATIONS.append(GuardValueOperation(rop.GUARD_VALUE))

for _op in [rop.INT_NEG,
            rop.INT_INVERT,
            ]:
    OPERATIONS.append(UnaryOperation(_op))

OPERATIONS.append(UnaryOperation(rop.INT_IS_TRUE, boolres=True))
OPERATIONS.append(UnaryOperation(rop.INT_IS_ZERO, boolres=True))
OPERATIONS.append(ConstUnaryOperation(rop.SAME_AS_I, boolres='sometimes'))
OPERATIONS.append(ConstUnaryFloatOperation(rop.SAME_AS_F))
OPERATIONS.append(SignExtOperation(rop.INT_SIGNEXT))

for _op in [rop.INT_ADD_OVF,
            rop.INT_SUB_OVF,
            rop.INT_MUL_OVF,
            ]:
    OPERATIONS.append(BinaryOvfOperation(_op))

for _op in [rop.FLOAT_ADD,
            rop.FLOAT_SUB,
            rop.FLOAT_MUL,
            rop.FLOAT_TRUEDIV,
            ]:
    OPERATIONS.append(BinaryFloatOperation(_op))

for _op in [rop.FLOAT_NEG,
            rop.FLOAT_ABS,
            ]:
    OPERATIONS.append(UnaryFloatOperation(_op))

OPERATIONS.append(CastFloatToIntOperation(rop.CAST_FLOAT_TO_INT))
OPERATIONS.append(CastIntToFloatOperation(rop.CAST_INT_TO_FLOAT))
OPERATIONS.append(CastFloatToIntOperation(rop.CONVERT_FLOAT_BYTES_TO_LONGLONG))
OPERATIONS.append(CastLongLongToFloatOperation(rop.CONVERT_LONGLONG_BYTES_TO_FLOAT))

OperationBuilder.OPERATIONS = OPERATIONS

# ____________________________________________________________

def do_assert(condition, error_message):
    if condition:
        return
    seed = pytest.config.option.randomseed
    message = "%s\nPython: %s\nRandom seed: %r" % (
        error_message,
        sys.executable,
        seed)
    raise AssertionError(message)

def Random():
    import random
    seed = pytest.config.option.randomseed
    print
    print 'Random seed value is %d.' % (seed,)
    print
    r = random.Random(seed)
    def get_random_integer():
        while True:
            result = int(r.expovariate(0.05))
            if result <= sys.maxint:
                break
        if r.randrange(0, 5) <= 1:
            result = -result
        if result not in (0, -1) and r.random() < 0.1:
            # occasionally produce a very large integer.  The algo is such
            # that it's likely we get a special value, e.g. sys.maxint or
            # -sys.maxint-1.
            while intmask(result << 2) == (result << 2):
                result = (result << 2) | (result & 0x3)
        return result
    def get_random_char():
        return chr(get_random_integer() % 256)
    def get_random_float():
        x = float(get_random_integer())
        k = r.random() * 1.2
        if k < 1.0:
            x += k
        return x
    def get_random_float_storage():
        x = get_random_float()
        return longlong.getfloatstorage(x)
    r.random_integer = get_random_integer
    r.random_char = get_random_char
    r.random_float = get_random_float
    r.random_float_storage = get_random_float_storage
    return r

def get_cpu():
    if pytest.config.option.backend == 'llgraph':
        from rpython.jit.backend.llgraph.runner import LLGraphCPU
        return LLGraphCPU(None)
    elif pytest.config.option.backend == 'cpu':
        from rpython.jit.backend.detect_cpu import getcpuclass
        return getcpuclass()(None, None)
    else:
        assert 0, "unknown backend %r" % pytest.config.option.backend

# ____________________________________________________________

class RandomLoop(object):
    dont_generate_more = False

    def __init__(self, cpu, builder_factory, r, startvars=None, output=None):
        self.cpu = cpu
        self.output = output
        if startvars is None:
            startvars = []
            if cpu.supports_floats:
                # pick up a single threshold for the whole 'inputargs', so
                # that some loops have no or mostly no FLOATs while others
                # have a lot of them
                k = r.random()
                # but make sure there is at least one INT
                at_least_once = r.randrange(0, pytest.config.option.n_vars)
            else:
                k = -1
                at_least_once = 0
            for i in range(pytest.config.option.n_vars):
                if r.random() < k and i != at_least_once:
                    startvars.append(InputArgFloat(r.random_float_storage()))
                else:
                    startvars.append(InputArgInt(r.random_integer()))
            allow_delay = True
        else:
            allow_delay = False
        assert len(dict.fromkeys(startvars)) == len(startvars)
        self.startvars = startvars
        self.prebuilt_ptr_consts = []
        self.r = r
        self.subloops = []
        self.build_random_loop(cpu, builder_factory, r, startvars, allow_delay)

    def build_random_loop(self, cpu, builder_factory, r, startvars,
                          allow_delay):

        loop = TreeLoop('test_random_function')
        loop.inputargs = startvars[:]
        loop.operations = []
        loop._jitcelltoken = JitCellToken()
        builder = builder_factory(cpu, loop, startvars[:])
        if allow_delay:
            needs_a_label = True
        else:
            self.insert_label(loop, 0, r)
            needs_a_label = False
        self.generate_ops(builder, r, loop, startvars, needs_a_label=needs_a_label)
        self.builder = builder
        self.loop = loop
        dump(loop)
        cpu.compile_loop(loop.inputargs, loop.operations, loop._jitcelltoken)
        if self.output:
            builder.print_loop(self.output)

    def insert_label(self, loop, position, r):
        assert not hasattr(loop, '_targettoken')
        for i in range(position):
            op = loop.operations[i]
            if (not rop.has_no_side_effect(op.opnum)
                    or op.type not in (INT, FLOAT)):
                position = i
                break       # cannot move the LABEL later
            randompos = r.randrange(0, len(self.startvars)+1)
            self.startvars.insert(randompos, op)
        loop._targettoken = TargetToken()
        loop.operations.insert(position, ResOperation(rop.LABEL, self.startvars,
                                                      loop._targettoken))

    def generate_ops(self, builder, r, loop, startvars, needs_a_label=False):
        block_length = pytest.config.option.block_length
        istart = 0

        for i in range(block_length):
            istart = len(loop.operations)
            try:
                op = r.choice(builder.OPERATIONS)
                op.filter(builder)
                op.produce_into(builder, r)
            except CannotProduceOperation:
                pass
            if builder.should_fail_by is not None:
                break
            if needs_a_label and r.random() < 0.2:
                self.insert_label(loop, istart, r)
                needs_a_label = False
        if needs_a_label:
            self.insert_label(loop, istart, r)

        endvars = []
        used_later = {}
        for op in loop.operations:
            for v in op.getarglist():
                used_later[v] = True
        for v in startvars:
            if v not in used_later:
                endvars.append(v)
        r.shuffle(endvars)
        endvars = endvars[:1]
        loop.operations.append(ResOperation(rop.FINISH, endvars,
                                    descr=builder.getfaildescr(is_finish=True)))
        if builder.should_fail_by:
            self.should_fail_by = builder.should_fail_by
            self.guard_op = builder.guard_op
        else:
            self.should_fail_by = loop.operations[-1]
            self.guard_op = None
        self.prebuilt_ptr_consts.extend(builder.prebuilt_ptr_consts)
        endvars = self.get_fail_args()
        self.expected = {}
        for v in endvars:
            if v.type == INT:
                self.expected[v] = getint(v)
            elif v.type == FLOAT:
                self.expected[v] = getfloatstorage(v)
            else:
                assert 0, v.type

    def runjitcelltoken(self):
        if self.startvars == self.loop.inputargs:
            return self.loop._jitcelltoken
        if not hasattr(self, '_initialjumploop_celltoken'):
            self._initialjumploop_celltoken = JitCellToken()
            args = []
            for box in self.startvars:
                if box not in self.loop.inputargs:
                    box = constbox(box)
                args.append(box)
            self.cpu.compile_loop(self.loop.inputargs,
                                  [ResOperation(rop.JUMP, args,
                                                descr=self.loop._targettoken)],
                                  self._initialjumploop_celltoken)
        return self._initialjumploop_celltoken

    def get_fail_args(self):
        if self.should_fail_by.is_guard():
            assert self.should_fail_by.getfailargs() is not None
            return self.should_fail_by.getfailargs()
        else:
            assert self.should_fail_by.getopnum() == rop.FINISH
            return self.should_fail_by.getarglist()

    def clear_state(self):
        for v, S, fields in self.prebuilt_ptr_consts:
            container = getref_base(v)._obj.container
            for name, value in fields.items():
                if isinstance(name, str):
                    setattr(container, name, value)
                elif isinstance(value, dict):
                    item = container.getitem(name)
                    for key1, value1 in value.items():
                        setattr(item, key1, value1)
                else:
                    container.setitem(name, value)

    def run_loop(self):
        cpu = self.builder.cpu
        self.clear_state()
        # disable check for now
        # exc = cpu.grab_exc_value()
        # assert not exc

        arguments = []
        for box in self.loop.inputargs:
            if box.type == INT:
                arguments.append(getint(box))
            elif box.type == FLOAT:
                arguments.append(getfloatstorage(box))
            else:
                assert 0, box.type
        deadframe = cpu.execute_token(self.runjitcelltoken(), *arguments)
        fail = cpu.get_latest_descr(deadframe)
        do_assert(fail is self.should_fail_by.getdescr(),
                  "Got %r, expected %r" % (fail,
                                           self.should_fail_by.getdescr()))
        for i, v in enumerate(self.get_fail_args()):
            if v not in self.expected:
                assert v.getopnum() == rop.SAME_AS_I   # special case
                assert isinstance(v.getarg(0), ConstInt)
                self.expected[v] = getint(v.getarg(0))
            if v.type == FLOAT:
                value = cpu.get_float_value(deadframe, i)
            else:
                value = cpu.get_int_value(deadframe, i)
            do_assert(value == self.expected[v],
                "Got %r, expected %r for value #%d" % (value,
                                                       self.expected[v],
                                                       i)
                )
        exc = cpu.grab_exc_value(deadframe)
        if (self.guard_op is not None and
            rop.is_guard_exception(self.guard_op.getopnum())):
            if self.guard_op.getopnum() == rop.GUARD_NO_EXCEPTION:
                do_assert(exc,
                          "grab_exc_value() should not be %r" % (exc,))
        else:
            do_assert(not exc,
                      "unexpected grab_exc_value(): %r" % (exc,))

    def build_bridge(self):
        def exc_handling(guard_op):
            # operations need to start with correct GUARD_EXCEPTION
            if guard_op._exc_box is None:
                op = ResOperation(rop.GUARD_NO_EXCEPTION, [])
            else:
                op = ResOperation(rop.GUARD_EXCEPTION, [guard_op._exc_box])
            op.setdescr(self.builder.getfaildescr())
            op.setfailargs([])
            return op

        if self.dont_generate_more:
            return False
        r = self.r
        guard_op = self.guard_op
        fail_args = guard_op.getfailargs()
        fail_descr = guard_op.getdescr()
        op = self.should_fail_by
        if not op.getfailargs():
            return False
        for _fail_box in fail_args:
            _fail_box.set_forwarded(None)
        # generate the branch: a sequence of operations that ends in a FINISH
        subloop = DummyLoop([])
        self.subloops.append(subloop)   # keep around for debugging
        if rop.is_guard_exception(guard_op.getopnum()):
            subloop.operations.append(exc_handling(guard_op))
        bridge_builder = self.builder.fork(self.builder.cpu, subloop,
                                           op.getfailargs()[:])
        self.generate_ops(bridge_builder, r, subloop, op.getfailargs()[:])
        # note that 'self.guard_op' now points to the guard that will fail in
        # this new bridge, while 'guard_op' still points to the guard that
        # has just failed.

        if r.random() < 0.1 and self.guard_op is None:
            # Occasionally, instead of ending in a FINISH, we end in a jump
            # to another loop.  We don't do it, however, if the new bridge's
            # execution will hit 'self.guard_op', but only if it executes
            # to the FINISH normally.  (There is no point to the extra
            # complexity, as we might get the same effect by two calls
            # to build_bridge().)

            # First make up the other loop...
            #
            # New restriction: must have the same argument count and types
            # as the original loop
            subset = []
            for box in self.loop.inputargs:
                srcbox = r.choice(fail_args)
                if srcbox.type != box.type:
                    if box.type == INT:
                        srcbox = ConstInt(r.random_integer())
                    elif box.type == FLOAT:
                        srcbox = ConstFloat(r.random_float_storage())
                    else:
                        raise AssertionError(box.type)
                subset.append(srcbox)
            #
            args = []
            for x in subset:
                if x.type == INT:
                    args.append(InputArgInt(getint(x)))
                elif x.type == FLOAT:
                    args.append(InputArgFloat(getfloatstorage(x)))
                else:
                    assert 0, x.type
            rl = RandomLoop(self.builder.cpu, self.builder.fork,
                                     r, args)
            # done
            self.should_fail_by = rl.should_fail_by
            self.expected = rl.expected
            assert len(rl.loop.inputargs) == len(args)
            # The new bridge's execution will end normally at its FINISH.
            # Just replace the FINISH with the JUMP to the new loop.
            jump_op = ResOperation(rop.JUMP, subset,
                                   descr=rl.loop._targettoken)
            subloop.operations[-1] = jump_op
            self.guard_op = rl.guard_op
            self.prebuilt_ptr_consts += rl.prebuilt_ptr_consts
            self.loop._jitcelltoken.record_jump_to(rl.loop._jitcelltoken)
            self.dont_generate_more = True
        if r.random() < .05:
            return False
        dump(subloop)
        self.builder.cpu.compile_bridge(fail_descr, fail_args,
                                        subloop.operations,
                                        self.loop._jitcelltoken)

        if self.output:
            bridge_builder.print_loop(self.output, fail_descr, fail_args)
        return True

def dump(loop):
    print >> sys.stderr, loop
    if hasattr(loop, 'inputargs'):
        print >> sys.stderr, '\t', loop.inputargs
    for op in loop.operations:
        if op.is_guard():
            print >> sys.stderr, '\t', op, op.getfailargs()
        else:
            print >> sys.stderr, '\t', op

def check_random_function(cpu, BuilderClass, r, num=None, max=None):
    if pytest.config.option.output:
        output = open(pytest.config.option.output, "w")
    else:
        output = None
    loop = RandomLoop(cpu, BuilderClass, r, output=output)
    while True:
        loop.run_loop()
        if loop.guard_op is not None:
            if not loop.build_bridge():
                break
        else:
            break
    if num is not None:
        print '    # passed (%d/%d).' % (num + 1, max)
    else:
        print '    # passed.'
    if pytest.config.option.output:
        output.close()
    print

def test_random_function(BuilderClass=OperationBuilder):
    r = Random()
    cpu = get_cpu()
    cpu.setup_once()
    if pytest.config.option.repeat == -1:
        while 1:
            check_random_function(cpu, BuilderClass, r)
    else:
        for i in range(pytest.config.option.repeat):
            check_random_function(cpu, BuilderClass, r, i,
                                  pytest.config.option.repeat)
