import sys
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.annlowlevel import (
    cast_gcref_to_instance, cast_instance_to_gcref)
from rpython.rlib.objectmodel import (
    we_are_translated, Symbolic, compute_unique_id, specialize, r_dict)
from rpython.rlib.rarithmetic import r_int64, is_valid_int
from rpython.rlib.rarithmetic import LONG_BIT, intmask, r_uint
from rpython.rlib.jit import Counters

from rpython.conftest import option

from rpython.jit.metainterp.resoperation import ResOperation, rop,\
    AbstractValue, oparity, AbstractResOp, IntOp, RefOp, FloatOp,\
    opclasses
from rpython.jit.metainterp.support import ptr2int, int2adr
from rpython.jit.codewriter import longlong
import weakref
from rpython.jit.metainterp import jitexc

# ____________________________________________________________

INT   = 'i'
REF   = 'r'
FLOAT = 'f'
STRUCT = 's'
HOLE  = '_'
VOID  = 'v'
VECTOR = 'V'

FAILARGS_LIMIT = 1000

class SwitchToBlackhole(jitexc.JitException):
    def __init__(self, reason, raising_exception=False):
        self.reason = reason
        self.raising_exception = raising_exception
        # ^^^ must be set to True if the SwitchToBlackhole is raised at a
        #     point where the exception on metainterp.last_exc_value
        #     is supposed to be raised.  The default False means that it
        #     should just be copied into the blackhole interp, but not raised.

def getkind(TYPE, supports_floats=True,
                  supports_longlong=True,
                  supports_singlefloats=True):
    if TYPE is lltype.Void:
        return "void"
    elif isinstance(TYPE, lltype.Primitive):
        if TYPE is lltype.Float and supports_floats:
            return 'float'
        if TYPE is lltype.SingleFloat and supports_singlefloats:
            return 'int'     # singlefloats are stored in an int
        if TYPE in (lltype.Float, lltype.SingleFloat):
            raise NotImplementedError("type %s not supported" % TYPE)
        if (TYPE != llmemory.Address and
            rffi.sizeof(TYPE) > rffi.sizeof(lltype.Signed)):
            if supports_longlong and TYPE is not lltype.LongFloat:
                assert rffi.sizeof(TYPE) == 8
                return 'float'
            raise NotImplementedError("type %s is too large" % TYPE)
        return "int"
    elif isinstance(TYPE, lltype.Ptr):
        if TYPE.TO._gckind == 'raw':
            return "int"
        else:
            return "ref"
    else:
        raise NotImplementedError("type %s not supported" % TYPE)
getkind._annspecialcase_ = 'specialize:memo'

def repr_pointer(box):
    from rpython.rtyper.lltypesystem import rstr
    try:
        T = box.value._obj.container._normalizedcontainer(check=False)._TYPE
        if T is rstr.STR:
            return repr(box._get_str())
        return '*%s' % (T._name,)
    except AttributeError:
        return box.value

def repr_object(box):
    try:
        TYPE = box.value.obj._TYPE
        return repr(TYPE)
    except AttributeError:
        return box.value

def repr_rpython(box, typechars):
    return '%s/%s' % (box._get_hash_(), typechars,
                        ) #compute_unique_id(box))


class AbstractDescr(AbstractValue):
    __slots__ = ('descr_index', 'ei_index')
    llopaque = True
    descr_index = -1
    ei_index = sys.maxint

    def repr_of_descr(self):
        return '%r' % (self,)

    def hide(self, cpu):
        return cast_instance_to_gcref(self)

    @staticmethod
    def show(cpu, descr_gcref):
        return cast_gcref_to_instance(AbstractDescr, descr_gcref)

    def get_vinfo(self):
        raise NotImplementedError

DONT_CHANGE = AbstractDescr()

class AbstractFailDescr(AbstractDescr):
    index = -1
    final_descr = False

    _attrs_ = ('adr_jump_offset', 'rd_locs', 'rd_loop_token', 'rd_vector_info')

    rd_vector_info = None

    def handle_fail(self, deadframe, metainterp_sd, jitdriver_sd):
        raise NotImplementedError
    def compile_and_attach(self, metainterp, new_loop, orig_inputargs):
        raise NotImplementedError

    def exits_early(self):
        # is this guard either a guard_early_exit resop,
        # or it has been moved before an guard_early_exit
        return False

    def loop_version(self):
        # compile a loop version out of this guard?
        return False

    def attach_vector_info(self, info):
        from rpython.jit.metainterp.resume import VectorInfo
        assert isinstance(info, VectorInfo)
        info.prev = self.rd_vector_info
        self.rd_vector_info = info

class BasicFinalDescr(AbstractFailDescr):
    final_descr = True

    def __init__(self, identifier=None):
        self.identifier = identifier      # for testing


class BasicFailDescr(AbstractFailDescr):
    def __init__(self, identifier=None):
        self.identifier = identifier      # for testing

    def make_a_counter_per_value(self, op, index):
        pass # for testing


@specialize.argtype(0)
def newconst(value):
    if value is None:
        return ConstPtr(lltype.nullptr(llmemory.GCREF.TO))
    elif lltype.typeOf(value) == lltype.Signed:
        return ConstInt(value)
    elif isinstance(value, bool):
        return ConstInt(int(value))
    elif lltype.typeOf(value) == longlong.FLOATSTORAGE:
        return ConstFloat(value)
    else:
        assert lltype.typeOf(value) == llmemory.GCREF
        return ConstPtr(value)

class MissingValue(object):
    "NOT_RPYTHON"


class Const(AbstractValue):
    _attrs_ = ()

    @staticmethod
    def _new(x):
        "NOT_RPYTHON"
        T = lltype.typeOf(x)
        kind = getkind(T)
        if kind == "int":
            if isinstance(T, lltype.Ptr):
                intval = ptr2int(x)
            else:
                intval = lltype.cast_primitive(lltype.Signed, x)
            return ConstInt(intval)
        elif kind == "float":
            return ConstFloat(longlong.getfloatstorage(x))
        else:
            raise NotImplementedError(kind)

    def constbox(self):
        return self

    def same_box(self, other):
        return self.same_constant(other)

    def same_constant(self, other):
        raise NotImplementedError

    def repr(self, memo):
        return self.repr_rpython()

    def is_constant(self):
        return True

    def __repr__(self):
        return 'Const(%s)' % self._getrepr_()


class ConstInt(Const):
    type = INT
    value = 0
    _attrs_ = ('value',)

    def __init__(self, value):
        if not we_are_translated():
            if is_valid_int(value):
                value = int(value)    # bool -> int
            else:
                assert isinstance(value, Symbolic)
        self.value = value

    def getint(self):
        return self.value

    getvalue = getint

    def getaddr(self):
        return int2adr(self.value)

    def _get_hash_(self):
        return make_hashable_int(self.value)

    def same_constant(self, other):
        if isinstance(other, ConstInt):
            return self.value == other.value
        return False

    def nonnull(self):
        return self.value != 0

    def _getrepr_(self):
        return self.value

    def repr_rpython(self):
        return repr_rpython(self, 'ci')

CONST_FALSE = ConstInt(0)
CONST_TRUE  = ConstInt(1)

class ConstFloat(Const):
    type = FLOAT
    value = longlong.ZEROF
    _attrs_ = ('value',)

    def __init__(self, valuestorage):
        assert lltype.typeOf(valuestorage) is longlong.FLOATSTORAGE
        self.value = valuestorage

    @staticmethod
    def fromfloat(x):
        return ConstFloat(longlong.getfloatstorage(x))

    def getfloatstorage(self):
        return self.value

    def getfloat(self):
        return longlong.getrealfloat(self.value)

    getvalue = getfloatstorage

    def _get_hash_(self):
        return longlong.gethash(self.value)

    def same_constant(self, other):
        if isinstance(other, ConstFloat):
            # careful in this comparison: if self.value and other.value
            # are both NaN, stored as regular floats (i.e. on 64-bit),
            # then just using "==" would say False: two NaNs are always
            # different from each other.  Conversely, "0.0 == -0.0" but
            # they are not the same constant.
            return (longlong.extract_bits(self.value) ==
                    longlong.extract_bits(other.value))
        return False

    def nonnull(self):
        return bool(longlong.extract_bits(self.value))

    def _getrepr_(self):
        return self.getfloat()

    def repr_rpython(self):
        return repr_rpython(self, 'cf')

CONST_FZERO = ConstFloat(longlong.ZEROF)

class ConstPtr(Const):
    type = REF
    value = lltype.nullptr(llmemory.GCREF.TO)
    _attrs_ = ('value',)

    def __init__(self, value):
        assert lltype.typeOf(value) == llmemory.GCREF
        self.value = value

    def getref_base(self):
        return self.value

    getvalue = getref_base

    def getref(self, PTR):
        return lltype.cast_opaque_ptr(PTR, self.getref_base())
    getref._annspecialcase_ = 'specialize:arg(1)'

    def _get_hash_(self):
        if self.value:
            return lltype.identityhash(self.value)
        else:
            return 0

    def same_constant(self, other):
        if isinstance(other, ConstPtr):
            return self.value == other.value
        return False

    def nonnull(self):
        return bool(self.value)

    _getrepr_ = repr_pointer

    def repr_rpython(self):
        return repr_rpython(self, 'cp')

    def _get_str(self):    # for debugging only
        from rpython.rtyper.annlowlevel import hlstr
        from rpython.rtyper.lltypesystem import rstr
        try:
            return hlstr(lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR),
                                                self.value))
        except lltype.UninitializedMemoryAccess:
            return '<uninitialized string>'

CONST_NULL = ConstPtr(ConstPtr.value)

# ____________________________________________________________


def make_hashable_int(i):
    from rpython.rtyper.lltypesystem.ll2ctypes import NotCtypesAllocatedStructure
    if not we_are_translated() and isinstance(i, llmemory.AddressAsInt):
        # Warning: such a hash changes at the time of translation
        adr = int2adr(i)
        try:
            return llmemory.cast_adr_to_int(adr, "emulated")
        except NotCtypesAllocatedStructure:
            return 12345 # use an arbitrary number for the hash
    return i

def get_const_ptr_for_string(s):
    from rpython.rtyper.annlowlevel import llstr
    if not we_are_translated():
        try:
            return _const_ptr_for_string[s]
        except KeyError:
            pass
    result = ConstPtr(lltype.cast_opaque_ptr(llmemory.GCREF, llstr(s)))
    if not we_are_translated():
        _const_ptr_for_string[s] = result
    return result
_const_ptr_for_string = {}

def get_const_ptr_for_unicode(s):
    from rpython.rtyper.annlowlevel import llunicode
    if not we_are_translated():
        try:
            return _const_ptr_for_unicode[s]
        except KeyError:
            pass
    if isinstance(s, str):
        s = unicode(s)
    result = ConstPtr(lltype.cast_opaque_ptr(llmemory.GCREF, llunicode(s)))
    if not we_are_translated():
        _const_ptr_for_unicode[s] = result
    return result
_const_ptr_for_unicode = {}

# A dict whose keys are refs (like the .value of ConstPtr).
# It is an r_dict. Note that NULL is not allowed as a key.
@specialize.call_location()
def new_ref_dict():
    return r_dict(rd_eq, rd_hash, simple_hash_eq=True)

def rd_eq(ref1, ref2):
    return ref1 == ref2

def rd_hash(ref):
    assert ref
    return lltype.identityhash(ref)


# ____________________________________________________________

# The JitCellToken class is the root of a tree of traces.  Each branch ends
# in a jump which goes to a LABEL operation; or it ends in a FINISH.

class JitCellToken(AbstractDescr):
    """Used for rop.JUMP, giving the target of the jump.
    This is different from TreeLoop: the TreeLoop class contains the
    whole loop, including 'operations', and goes away after the loop
    was compiled; but the LoopDescr remains alive and points to the
    generated assembler.
    """
    FORCE_BRIDGE_SEGMENTING = 1 # stored in retraced_count

    target_tokens = None
    failed_states = None
    retraced_count = 0
    invalidated = False
    outermost_jitdriver_sd = None
    # and more data specified by the backend when the loop is compiled
    number = -1
    generation = r_int64(0)
    # one purpose of LoopToken is to keep alive the CompiledLoopToken
    # returned by the backend.  When the LoopToken goes away, the
    # CompiledLoopToken has its __del__ called, which frees the assembler
    # memory and the ResumeGuards.
    compiled_loop_token = None

    def __init__(self):
        # For memory management of assembled loops
        self._keepalive_jitcell_tokens = {}      # set of other JitCellToken

    def record_jump_to(self, jitcell_token):
        assert isinstance(jitcell_token, JitCellToken)
        self._keepalive_jitcell_tokens[jitcell_token] = None

    def __repr__(self):
        return '<Loop %d, gen=%d>' % (self.number, self.generation)

    def repr_of_descr(self):
        return '<Loop%d>' % self.number

    def dump(self):
        self.compiled_loop_token.cpu.dump_loop_token(self)

    def get_retraced_count(self):
        return self.retraced_count >> 1

    def set_retraced_count(self, value):
        self.retraced_count = (value << 1) | (self.retraced_count & 1)

class TargetToken(AbstractDescr):
    _ll_loop_code = 0     # for the backend.  If 0, we know that it is
                          # a LABEL that was not compiled yet.

    def __init__(self, targeting_jitcell_token=None,
                 original_jitcell_token=None):
        # Warning, two different jitcell_tokens here!
        #
        # * 'targeting_jitcell_token' is only useful for the front-end,
        #   and it means: consider the LABEL that uses this TargetToken.
        #   At this position, the state is logically the one given
        #   by targeting_jitcell_token.  So e.g. if we want to enter the
        #   JIT with some given green args, if the jitcell matches, then
        #   we can jump to this LABEL.
        #
        # * 'original_jitcell_token' is information from the backend's
        #   point of view: it means that this TargetToken is used in
        #   a LABEL that belongs to either:
        #   - a loop; then 'original_jitcell_token' is this loop
        #   - or a bridge; then 'original_jitcell_token' is the loop
        #     out of which we made this bridge
        #
        self.targeting_jitcell_token = targeting_jitcell_token
        self.original_jitcell_token = original_jitcell_token

        self.virtual_state = None
        self.short_preamble = None

    def repr_of_descr(self):
        return 'TargetToken(%d)' % compute_unique_id(self)

class TreeLoop(object):
    inputargs = None
    operations = None
    call_pure_results = None
    logops = None
    quasi_immutable_deps = None

    def _token(*args):
        raise Exception("TreeLoop.token is killed")
    token = property(_token, _token)

    # This is the jitcell where the trace starts.  Labels within the
    # trace might belong to some other jitcells, i.e. they might have
    # TargetTokens with a different value for 'targeting_jitcell_token'.
    # But these TargetTokens also have a 'original_jitcell_token' field,
    # which must be equal to this one.
    original_jitcell_token = None

    def __init__(self, name):
        self.name = name
        # self.operations = list of ResOperations
        #   ops of the kind 'guard_xxx' contain a further list of operations,
        #   which may itself contain 'guard_xxx' and so on, making a tree.

    def _all_operations(self, omit_finish=False):
        "NOT_RPYTHON"
        result = []
        _list_all_operations(result, self.operations, omit_finish)
        return result

    def summary(self, adding_insns={}, omit_finish=True):    # for debugging
        "NOT_RPYTHON"
        insns = adding_insns.copy()
        for op in self._all_operations(omit_finish=omit_finish):
            opname = op.getopname()
            insns[opname] = insns.get(opname, 0) + 1
        return insns

    def get_operations(self):
        return self.operations

    def get_display_text(self, memo):    # for graphpage.py
        return '%s\n[%s]' % (
            self.name,
            ', '.join([box.repr(memo) for box in self.inputargs]))

    def show(self, errmsg=None):
        "NOT_RPYTHON"
        from rpython.jit.metainterp.graphpage import display_procedures
        display_procedures([self], errmsg)

    def check_consistency(self, check_descr=True):     # for testing
        "NOT_RPYTHON"
        self.check_consistency_of(self.inputargs, self.operations,
                                  check_descr=check_descr)
        for op in self.operations:
            descr = op.getdescr()
            if check_descr and op.getopnum() == rop.LABEL and isinstance(descr, TargetToken):
                assert descr.original_jitcell_token is self.original_jitcell_token

    @staticmethod
    def check_consistency_of(inputargs, operations, check_descr=True):
        "NOT_RPYTHON"
        for box in inputargs:
            assert not isinstance(box, Const), "Loop.inputargs contains %r" % (box,)
        seen = dict.fromkeys(inputargs)
        assert len(seen) == len(inputargs), (
               "duplicate Box in the Loop.inputargs")
        TreeLoop.check_consistency_of_branch(operations, seen,
                                             check_descr=check_descr)

    @staticmethod
    def check_consistency_of_branch(operations, seen, check_descr=True):
        "NOT_RPYTHON"
        for num, op in enumerate(operations):
            if op.is_ovf():
                assert operations[num + 1].getopnum() in (rop.GUARD_NO_OVERFLOW,
                                                          rop.GUARD_OVERFLOW)
            for i in range(op.numargs()):
                box = op.getarg(i)
                if not isinstance(box, Const):
                    assert box in seen
            if op.is_guard() and check_descr:
                assert op.getdescr() is not None
                if hasattr(op.getdescr(), '_debug_suboperations'):
                    ops = op.getdescr()._debug_suboperations
                    TreeLoop.check_consistency_of_branch(ops, seen.copy())
                for box in op.getfailargs() or []:
                    if box is not None:
                        assert not isinstance(box, Const)
                        assert box in seen
            elif check_descr:
                assert op.getfailargs() is None
            if op.type != 'v':
                seen[op] = True
            if op.getopnum() == rop.LABEL:
                inputargs = op.getarglist()
                for box in inputargs:
                    assert not isinstance(box, Const), "LABEL contains %r" % (box,)
                seen = dict.fromkeys(inputargs)
                assert len(seen) == len(inputargs), (
                    "duplicate Box in the LABEL arguments")

        #assert operations[-1].is_final()
        if operations[-1].getopnum() == rop.JUMP:
            target = operations[-1].getdescr()
            if target is not None:
                assert isinstance(target, TargetToken)

    def dump(self):
        # RPython-friendly
        print '%r: inputargs =' % self, self._dump_args(self.inputargs)
        for op in self.operations:
            args = op.getarglist()
            print '\t', op.getopname(), self._dump_args(args), \
                  self._dump_box(op.result)

    def _dump_args(self, boxes):
        return '[' + ', '.join([self._dump_box(box) for box in boxes]) + ']'

    def _dump_box(self, box):
        if box is None:
            return 'None'
        else:
            return box.repr_rpython()

    def __repr__(self):
        return '<%s>' % (self.name,)

def _list_all_operations(result, operations, omit_finish=True):
    if omit_finish and operations[-1].getopnum() == rop.FINISH:
        # xxx obscure
        return
    result.extend(operations)
    for op in operations:
        if op.is_guard() and op.getdescr():
            if hasattr(op.getdescr(), '_debug_suboperations'):
                ops = op.getdescr()._debug_suboperations
                _list_all_operations(result, ops, omit_finish)

# ____________________________________________________________


FO_REPLACED_WITH_CONST = r_uint(1)
FO_POSITION_SHIFT      = 1
FO_POSITION_MASK       = r_uint(0xFFFFFFFE)


class FrontendOp(AbstractResOp):
    type = 'v'
    _attrs_ = ('position_and_flags',)

    def __init__(self, pos):
        # p is the 32-bit position shifted left by one (might be negative,
        # but casted to the 32-bit UINT type)
        p = rffi.cast(rffi.UINT, pos << FO_POSITION_SHIFT)
        self.position_and_flags = r_uint(p)    # zero-extended to a full word

    def get_position(self):
        # p is the signed 32-bit position, from self.position_and_flags
        p = rffi.cast(rffi.INT, self.position_and_flags)
        return intmask(p) >> FO_POSITION_SHIFT

    def set_position(self, new_pos):
        assert new_pos >= 0
        self.position_and_flags &= ~FO_POSITION_MASK
        self.position_and_flags |= r_uint(new_pos << FO_POSITION_SHIFT)

    def is_replaced_with_const(self):
        return bool(self.position_and_flags & FO_REPLACED_WITH_CONST)

    def set_replaced_with_const(self):
        self.position_and_flags |= FO_REPLACED_WITH_CONST

    def __repr__(self):
        return '%s(0x%x)' % (self.__class__.__name__, self.position_and_flags)

class IntFrontendOp(IntOp, FrontendOp):
    _attrs_ = ('position_and_flags', '_resint')

    def copy_value_from(self, other):
        self._resint = other.getint()

class FloatFrontendOp(FloatOp, FrontendOp):
    _attrs_ = ('position_and_flags', '_resfloat')

    def copy_value_from(self, other):
        self._resfloat = other.getfloatstorage()

class RefFrontendOp(RefOp, FrontendOp):
    _attrs_ = ('position_and_flags', '_resref', '_heapc_deps')
    if LONG_BIT == 32:
        _attrs_ += ('_heapc_flags',)   # on 64 bit, this gets stored into the
        _heapc_flags = r_uint(0)       # high 32 bits of 'position_and_flags'
    _heapc_deps = None

    def copy_value_from(self, other):
        self._resref = other.getref_base()

    if LONG_BIT == 32:
        def _get_heapc_flags(self):
            return self._heapc_flags
        def _set_heapc_flags(self, value):
            self._heapc_flags = value
    else:
        def _get_heapc_flags(self):
            return self.position_and_flags >> 32
        def _set_heapc_flags(self, value):
            self.position_and_flags = (
                (self.position_and_flags & 0xFFFFFFFF) |
                (value << 32))


class History(object):
    trace = None

    def __init__(self):
        self.descr_cache = {}
        self.descrs = {}
        self.consts = []
        self._cache = []

    def set_inputargs(self, inpargs, metainterp_sd):
        from rpython.jit.metainterp.opencoder import Trace

        self.trace = Trace(inpargs, metainterp_sd)
        self.inputargs = inpargs
        if self._cache is not None:
            # hack to record the ops *after* we know our inputargs
            for (opnum, argboxes, op, descr) in self._cache:
                pos = self.trace.record_op(opnum, argboxes, descr)
                op.set_position(pos)
            self._cache = None

    def length(self):
        return self.trace._count - len(self.trace.inputargs)

    def trace_tag_overflow(self):
        return self.trace.tag_overflow

    def trace_tag_overflow_imminent(self):
        return self.trace.tag_overflow_imminent()

    def get_trace_position(self):
        return self.trace.cut_point()

    def cut(self, cut_at):
        self.trace.cut_at(cut_at)

    def any_operation(self):
        return self.trace._count > self.trace._start

    @specialize.argtype(2)
    def set_op_value(self, op, value):
        if value is None:
            return
        elif isinstance(value, bool):
            op.setint(int(value))
        elif lltype.typeOf(value) == lltype.Signed:
            op.setint(value)
        elif lltype.typeOf(value) is longlong.FLOATSTORAGE:
            op.setfloatstorage(value)
        else:
            assert lltype.typeOf(value) == llmemory.GCREF
            op.setref_base(value)

    def _record_op(self, opnum, argboxes, descr=None):
        return self.trace.record_op(opnum, argboxes, descr)

    @specialize.argtype(3)
    def record(self, opnum, argboxes, value, descr=None):
        if self.trace is None:
            pos = 2**14 - 1
        else:
            pos = self._record_op(opnum, argboxes, descr)
        if value is None:
            op = FrontendOp(pos)
        elif isinstance(value, bool):
            op = IntFrontendOp(pos)
        elif lltype.typeOf(value) == lltype.Signed:
            op = IntFrontendOp(pos)
        elif lltype.typeOf(value) is longlong.FLOATSTORAGE:
            op = FloatFrontendOp(pos)
        else:
            op = RefFrontendOp(pos)
        if self.trace is None:
            self._cache.append((opnum, argboxes, op, descr))
        self.set_op_value(op, value)
        return op

    def record_nospec(self, opnum, argboxes, descr=None):
        tp = opclasses[opnum].type
        pos = self._record_op(opnum, argboxes, descr)
        if tp == 'v':
            return FrontendOp(pos)
        elif tp == 'i':
            return IntFrontendOp(pos)
        elif tp == 'f':
            return FloatFrontendOp(pos)
        assert tp == 'r'
        return RefFrontendOp(pos)

    def record_default_val(self, opnum, argboxes, descr=None):
        assert rop.is_same_as(opnum)
        op = self.record_nospec(opnum, argboxes, descr)
        op.copy_value_from(argboxes[0])
        return op


# ____________________________________________________________


class NoStats(object):

    def set_history(self, history):
        pass

    def aborted(self):
        pass

    def entered(self):
        pass

    def compiled(self):
        pass

    def add_merge_point_location(self, loc):
        pass

    def name_for_new_loop(self):
        return 'Loop'

    def add_new_loop(self, loop):
        pass

    def record_aborted(self, greenkey):
        pass

    def view(self, **kwds):
        pass

    def clear(self):
        pass

    def add_jitcell_token(self, token):
        pass

class Stats(object):
    """For tests."""

    compiled_count = 0
    enter_count = 0
    aborted_count = 0

    def __init__(self, metainterp_sd):
        self.loops = []
        self.locations = []
        self.aborted_keys = []
        self.invalidated_token_numbers = set()    # <- not RPython
        self.jitcell_token_wrefs = []
        self.jitcell_dicts = []                   # <- not RPython
        self.metainterp_sd = metainterp_sd

    def clear(self):
        del self.loops[:]
        del self.locations[:]
        del self.aborted_keys[:]
        del self.jitcell_token_wrefs[:]
        self.invalidated_token_numbers.clear()
        self.compiled_count = 0
        self.enter_count = 0
        self.aborted_count = 0
        for dict in self.jitcell_dicts:
            dict.clear()

    def add_jitcell_token(self, token):
        assert isinstance(token, JitCellToken)
        self.jitcell_token_wrefs.append(weakref.ref(token))

    def set_history(self, history):
        self.history = history

    def aborted(self):
        self.aborted_count += 1

    def entered(self):
        self.enter_count += 1

    def compiled(self):
        self.compiled_count += 1

    def add_merge_point_location(self, loc):
        self.locations.append(loc)

    def name_for_new_loop(self):
        return 'Loop #%d' % len(self.loops)

    def add_new_loop(self, loop):
        self.loops.append(loop)

    def record_aborted(self, greenkey):
        self.aborted_keys.append(greenkey)

    # test read interface

    def get_all_loops(self):
        return self.loops

    def get_all_jitcell_tokens(self):
        tokens = [t() for t in self.jitcell_token_wrefs]
        if None in tokens:
            assert False, ("get_all_jitcell_tokens will not work as "
                           "loops have been freed")
        return tokens

    def check_history(self, expected=None, **check):
        insns = {}
        t = self.history.trace.get_iter()
        while not t.done():
            op = t.next()
            opname = op.getopname()
            insns[opname] = insns.get(opname, 0) + 1
        if expected is not None:
            insns.pop('debug_merge_point', None)
            insns.pop('enter_portal_frame', None)
            insns.pop('leave_portal_frame', None)
            assert insns == expected
        for insn, expected_count in check.items():
            getattr(rop, insn.upper())  # fails if 'rop.INSN' does not exist
            found = insns.get(insn, 0)
            assert found == expected_count, (
                "found %d %r, expected %d" % (found, insn, expected_count))
        return insns

    def check_resops(self, expected=None, omit_finish=True, **check):
        insns = {}
        if 'call' in check:
            assert check.pop('call') == 0
            check['call_i'] = check['call_r'] = check['call_f'] = check['call_n'] = 0
        if 'call_pure' in check:
            assert check.pop('call_pure') == 0
            check['call_pure_i'] = check['call_pure_r'] = check['call_pure_f'] = 0
        if 'call_may_force' in check:
            assert check.pop('call_may_force') == 0
            check['call_may_force_i'] = check['call_may_force_r'] = check['call_may_force_f'] = check['call_may_force_n'] = 0
        if 'call_assembler' in check:
            assert check.pop('call_assembler') == 0
            check['call_assembler_i'] = check['call_assembler_r'] = check['call_assembler_f'] = check['call_assembler_n'] = 0
        if 'getfield_gc' in check:
            assert check.pop('getfield_gc') == 0
            check['getfield_gc_i'] = check['getfield_gc_r'] = check['getfield_gc_f'] = 0
        if 'getarrayitem_gc_pure' in check:
            assert check.pop('getarrayitem_gc_pure') == 0
            check['getarrayitem_gc_pure_i'] = check['getarrayitem_gc_pure_r'] = check['getarrayitem_gc_pure_f'] = 0
        if 'getarrayitem_gc' in check:
            assert check.pop('getarrayitem_gc') == 0
            check['getarrayitem_gc_i'] = check['getarrayitem_gc_r'] = check['getarrayitem_gc_f'] = 0
        for loop in self.get_all_loops():
            insns = loop.summary(adding_insns=insns, omit_finish=omit_finish)
        return self._check_insns(insns, expected, check)

    def _check_insns(self, insns, expected, check):
        if expected is not None:
            insns.pop('debug_merge_point', None)
            insns.pop('enter_portal_frame', None)
            insns.pop('leave_portal_frame', None)
            insns.pop('label', None)
            assert insns == expected
        for insn, expected_count in check.items():
            getattr(rop, insn.upper())  # fails if 'rop.INSN' does not exist
            found = insns.get(insn, 0)
            assert found == expected_count, (
                "found %d %r, expected %d" % (found, insn, expected_count))
        return insns

    def check_simple_loop(self, expected=None, **check):
        """ Useful in the simplest case when we have only one trace ending with
        a jump back to itself and possibly a few bridges.
        Only the operations within the loop formed by that single jump will
        be counted.
        """
        loops = self.get_all_loops()
        assert len(loops) == 1
        loop = loops[0]
        jumpop = loop.operations[-1]
        assert jumpop.getopnum() == rop.JUMP
        labels = [op for op in loop.operations if op.getopnum() == rop.LABEL]
        targets = [op._descr_wref() for op in labels]
        assert None not in targets # TargetToken was freed, give up
        target = jumpop._descr_wref()
        assert target
        assert targets.count(target) == 1
        i = loop.operations.index(labels[targets.index(target)])
        insns = {}
        for op in loop.operations[i:]:
            opname = op.getopname()
            insns[opname] = insns.get(opname, 0) + 1
        return self._check_insns(insns, expected, check)

    def check_loops(self, expected=None, everywhere=False, **check):
        insns = {}
        for loop in self.get_all_loops():
            #if not everywhere:
            #    if getattr(loop, '_ignore_during_counting', False):
            #        continue
            insns = loop.summary(adding_insns=insns)
        if expected is not None:
            insns.pop('debug_merge_point', None)
            print
            print
            print "        self.check_resops(%s)" % str(insns)
            print
            import pdb; pdb.set_trace()
        else:
            chk = ['%s=%d' % (i, insns.get(i, 0)) for i in check]
            print
            print
            print "        self.check_resops(%s)" % ', '.join(chk)
            print
            import pdb; pdb.set_trace()
        return

        for insn, expected_count in check.items():
            getattr(rop, insn.upper())  # fails if 'rop.INSN' does not exist
            found = insns.get(insn, 0)
            assert found == expected_count, (
                "found %d %r, expected %d" % (found, insn, expected_count))
        return insns

    def check_consistency(self):
        "NOT_RPYTHON"
        for loop in self.get_all_loops():
            loop.check_consistency()

    def maybe_view(self):
        if option.view:
            self.view()

    def view(self, errmsg=None, extraprocedures=[], metainterp_sd=None):
        from rpython.jit.metainterp.graphpage import display_procedures
        procedures = self.get_all_loops()[:]
        for procedure in extraprocedures:
            if procedure in procedures:
                procedures.remove(procedure)
            procedures.append(procedure)
        highlight_procedures = dict.fromkeys(extraprocedures, 1)
        for procedure in procedures:
            if hasattr(procedure, '_looptoken_number') and (
               procedure._looptoken_number in self.invalidated_token_numbers):
                highlight_procedures.setdefault(procedure, 2)
        display_procedures(procedures, errmsg, highlight_procedures, metainterp_sd)

# ----------------------------------------------------------------

class Options:
    def __init__(self, listops=False, failargs_limit=FAILARGS_LIMIT):
        self.listops = listops
        self.failargs_limit = failargs_limit
    def _freeze_(self):
        return True

# ----------------------------------------------------------------

def check_descr(x):
    """Check that 'x' is None or an instance of AbstractDescr.
    Explodes if the annotator only thinks it is an instance of AbstractValue.
    """
    if x is not None:
        assert isinstance(x, AbstractDescr)

class Entry(ExtRegistryEntry):
    _about_ = check_descr

    def compute_result_annotation(self, s_x):
        # Failures here mean that 'descr' is not correctly an AbstractDescr.
        # Please don't check in disabling of this test!
        from rpython.annotator import model as annmodel
        if not annmodel.s_None.contains(s_x):
            assert isinstance(s_x, annmodel.SomeInstance)
            # the following assert fails if we somehow did not manage
            # to ensure that the 'descr' field of ResOperation is really
            # an instance of AbstractDescr, a subclass of AbstractValue.
            assert issubclass(s_x.classdef.classdesc.pyobj, AbstractDescr)

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
