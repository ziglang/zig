import weakref, os
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.objectmodel import compute_identity_hash
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.jit.codewriter import longlong
from rpython.jit.backend.llsupport.symbolic import (WORD as INT_WORD,
        SIZEOF_FLOAT as FLOAT_WORD)

class SettingForwardedOnAbstractValue(Exception):
    pass

class CountingDict(object):
    def __init__(self):
        self._d = weakref.WeakKeyDictionary()
        self.counter = 0

    def __getitem__(self, item):
        try:
            return self._d[item]
        except KeyError:
            c = self.counter
            self.counter += 1
            self._d[item] = c
            return c

class AbstractValue(object):
    _repr_memo = CountingDict()
    is_info_class = False
    namespace = None
    _attrs_ = ()

    def _get_hash_(self):
        return compute_identity_hash(self)

    def same_box(self, other):
        return self is other

    def same_shape(self, other):
        return True

    def repr_short(self, memo):
        return self.repr(memo)

    def is_constant(self):
        return False

    def get_forwarded(self):
        return None

    def set_forwarded(self, forwarded_to):
        llop.debug_print(lltype.Void, "setting forwarded on:", self.__class__.__name__)
        raise SettingForwardedOnAbstractValue()

    @specialize.arg(1)
    def get_box_replacement(op, not_const=False):
        # Read the chain "op, op._forwarded, op._forwarded._forwarded..."
        # until we reach None or an Info instance, and return the last
        # item before that.
        while isinstance(op, AbstractResOpOrInputArg):  # else, _forwarded is None
            next_op = op._forwarded
            if (next_op is None or next_op.is_info_class or
                (not_const and next_op.is_constant())):
                return op
            op = next_op
        return op

    def reset_value(self):
        pass

    def is_inputarg(self):
        return False

    def returns_vector(self):
        return False

    def is_vector(self):
        return False

    def returns_void(self):
        return False


def ResOperation(opnum, args, descr=None):
    cls = opclasses[opnum]
    op = cls()
    op.initarglist(args)
    if descr is not None:
        assert isinstance(op, ResOpWithDescr)
        if opnum == rop.FINISH:
            assert descr.final_descr
        elif OpHelpers.is_guard(opnum):
            assert not descr.final_descr
        op.setdescr(descr)
    return op

def VecOperation(opnum, args, baseop, count, descr=None):
    vecinfo = baseop.get_forwarded()
    assert isinstance(vecinfo, VectorizationInfo)
    datatype = vecinfo.datatype
    bytesize = vecinfo.bytesize
    signed = vecinfo.signed
    if baseop.is_typecast():
        ft,tt = baseop.cast_types()
        datatype = tt
        bytesize = baseop.cast_to_bytesize()
    return VecOperationNew(opnum, args, datatype, bytesize, signed, count, descr)

def VecOperationNew(opnum, args, datatype, bytesize, signed, count, descr=None):
    op = ResOperation(opnum, args, descr=descr)
    vecinfo = VectorizationInfo(None)
    vecinfo.setinfo(datatype, bytesize, signed)
    vecinfo.count = count
    op.set_forwarded(vecinfo)
    if isinstance(op,VectorOp):
        op.datatype = datatype
        op.bytesize = bytesize
        op.signed = signed
        op.count = count
    else:
        assert isinstance(op, VectorGuardOp)
        op.datatype = datatype
        op.bytesize = bytesize
        op.signed = signed
        op.count = count
    assert op.count > 0

    if not we_are_translated():
        # for the test suite
        op._vec_debug_info = vecinfo
    return op

def vector_repr(self, num):
    if we_are_translated():
        # the set_forwarded solution is volatile, we CANNOT acquire
        # the information (e.g. count, bytesize) here easily
        return 'v' + str(num)
    if hasattr(self, '_vec_debug_info'):
        vecinfo = self._vec_debug_info
        count = vecinfo.count 
        datatype = vecinfo.datatype
        bytesize = vecinfo.bytesize
    elif self.vector == -2:
        count = self.count
        datatype = self.datatype
        bytesize = self.bytesize
    else:
        assert 0, "cannot debug print variable"
    if self.opnum in (rop.VEC_UNPACK_I, rop.VEC_UNPACK_F):
        return self.type + str(num)
    return 'v%d[%dx%s%d]' % (num, count, datatype,
                             bytesize * 8)

class VectorizationInfo(AbstractValue):
    _attrs_ = ('datatype', 'bytesize', 'signed', 'count')
    datatype = '\x00'
    bytesize = -1 # -1 means the biggest size known to the machine
    signed = True
    count = -1

    def __init__(self, op):
        if op is None:
            return
        from rpython.jit.metainterp.history import Const
        if isinstance(op, Const) or isinstance(op, AbstractInputArg):
            self.setinfo(op.type, -1, op.type == 'i')
            return
        if op.is_primitive_array_access():
            from rpython.jit.backend.llsupport.descr import ArrayDescr
            descr = op.getdescr()
            if not we_are_translated():
                from rpython.jit.backend.llgraph.runner import _getdescr
                descr = _getdescr(op)
            type = op.type
            bytesize = descr.get_item_size_in_bytes()
            signed = descr.is_item_signed()
            datatype = type
            self.setinfo(datatype, bytesize, signed)
        elif op.opnum == rop.INT_SIGNEXT:
            from rpython.jit.metainterp import history
            arg0 = op.getarg(0)
            arg1 = op.getarg(1)
            assert isinstance(arg1, history.ConstInt)
            self.setinfo('i', arg1.value, True)
        elif op.is_typecast():
            ft,tt = op.cast_types()
            bytesize = op.cast_to_bytesize()
            self.setinfo(tt, bytesize, True)
        else:
            # pass through the type of the first input argument
            type = op.type
            signed = type == 'i'
            bytesize = -1
            if op.numargs() > 0:
                i = 0
                arg = op.getarg(i)
                while arg.is_constant() and i+1 < op.numargs():
                    i += 1
                    arg = op.getarg(i)
                if not arg.is_constant():
                    vecinfo = arg.get_forwarded()
                    if vecinfo is not None and isinstance(vecinfo, VectorizationInfo):
                        if vecinfo.datatype != '\x00' and \
                           vecinfo.bytesize != -1:
                            type = vecinfo.datatype
                            signed = vecinfo.signed
                            bytesize = vecinfo.bytesize
            if rop.returns_bool_result(op.opnum):
                type = 'i'
            self.setinfo(type, bytesize, signed)

    def setinfo(self, datatype, bytesize, signed):
        self.datatype = datatype
        if bytesize == -1:
            if datatype == 'i':
                bytesize = INT_WORD
            elif datatype == 'f':
                bytesize = FLOAT_WORD
            elif datatype == 'r':
                bytesize = INT_WORD
            elif datatype == 'v':
                bytesize = 0
            elif datatype == 'V': # input arg vector
                bytesize = INT_WORD
            else:
                assert 0, "unknown datasize"
        self.bytesize = bytesize
        self.signed = signed


class AbstractResOpOrInputArg(AbstractValue):
    _attrs_ = ('_forwarded',)
    _forwarded = None # either another resop or OptInfo

    def get_forwarded(self):
        return self._forwarded

    def set_forwarded(self, forwarded_to):
        assert forwarded_to is not self
        self._forwarded = forwarded_to

    def getdescr(self):
        return None

    def forget_value(self):
        pass

class AbstractResOp(AbstractResOpOrInputArg):
    """The central ResOperation class, representing one operation."""

    _attrs_ = ()

    # debug
    name = ""
    pc = 0
    opnum = 0
    _cls_has_bool_result = False
    type = 'v'
    boolreflex = -1
    boolinverse = -1
    vector = -1 # -1 means, no vector equivalent, -2 it is a vector statement
    cls_casts = ('\x00', -1, '\x00', -1, -1)

    def getopnum(self):
        return self.opnum

    #def same_box(self, other):
    #    if self.is_same_as():
    #        return self is other or self.getarg(0).same_box(other)
    #    return self is other

    # methods implemented by the arity mixins
    # ---------------------------------------

    def initarglist(self, args):
        "This is supposed to be called only just after the ResOp has been created"
        raise NotImplementedError

    def getarglist(self):
        raise NotImplementedError

    def getarglist_copy(self):
        return self.getarglist()

    def getarg(self, i):
        raise NotImplementedError

    def setarg(self, i, box):
        raise NotImplementedError

    def numargs(self):
        raise NotImplementedError

    # methods implemented by GuardResOp
    # ---------------------------------

    def getfailargs(self):
        return None

    def setfailargs(self, fail_args):
        raise NotImplementedError

    # methods implemented by ResOpWithDescr
    # -------------------------------------

    #def getdescr(self): -- in the base class, AbstractResOpOrInputArg
    #    return None

    def setdescr(self, descr):
        raise NotImplementedError

    def cleardescr(self):
        pass

    # common methods
    # --------------

    def copy(self):
        return self.copy_and_change(self.opnum)

    def copy_and_change(self, opnum, args=None, descr=None):
        "shallow copy: the returned operation is meant to be used in place of self"
        # XXX specialize
        from rpython.jit.metainterp.history import DONT_CHANGE
        
        if args is None:
            args = self.getarglist_copy()
        if descr is None:
            descr = self.getdescr()
        if descr is DONT_CHANGE:
            descr = None
        return ResOperation(opnum, args, descr)

    def repr(self, memo, graytext=False):
        # RPython-friendly version
        if self.type != 'v':
            try:
                num = memo[self]
            except KeyError:
                num = len(memo)
                memo[self] = num
            if self.is_vector():
                sres = vector_repr(self, num) + ' = '
            else:
                sres = self.type + str(num) + ' = '
        #if self.result is not None:
        #    sres = '%s = ' % (self.result,)
        else:
            sres = ''
        if self.name:
            prefix = "%s:%s   " % (self.name, self.pc)
            if graytext:
                prefix = "\f%s\f" % prefix
        else:
            prefix = ""
        args = self.getarglist()
        descr = self.getdescr()
        if descr is None or we_are_translated():
            s = '%s%s%s(%s)' % (prefix, sres, self.getopname(),
                                ', '.join([a.repr_short(memo) for a in args]))
        else:
            s = '%s%s%s(%s)' % (prefix, sres, self.getopname(),
                                ', '.join([a.repr_short(memo) for a in args] +
                                          ['descr=%r' % descr]))
        # --- enable to display the failargs too:
        #if isinstance(self, GuardResOp):
        #    s += ' [%s]' % (', '.join([a.repr_short(memo) for a in
        #                                self.getfailargs()]),)
        return s

    def repr_short(self, memo):
        try:
            num = memo[self]
        except KeyError:
            num = len(memo)
            memo[self] = num
        if self.is_vector():
            return vector_repr(self, num)
        return self.type + str(num)

    def __repr__(self):
        r = self.repr(self._repr_memo)
        if self.namespace is not None:
            return "<" + self.namespace + ">" + r
        return r

    def getopname(self):
        try:
            return opname[self.getopnum()].lower()
        except KeyError:
            return '<%d>' % self.getopnum()

    def is_guard(self):
        return rop.is_guard(self.getopnum())

    def is_ovf(self):
        return rop.is_ovf(self.getopnum())

    def can_raise(self):
        return rop.can_raise(self.getopnum())

    def is_foldable_guard(self):
        return rop.is_foldable_guard(self.getopnum())

    def is_primitive_array_access(self):
        """ Indicates that this operations loads/stores a
        primitive type (int,float) """
        if rop.is_primitive_load(self.opnum) or rop.is_primitive_store(self.opnum):
            descr = self.getdescr()
            if not we_are_translated():
                from rpython.jit.backend.llgraph.runner import _getdescr
                descr = _getdescr(self)
            if descr and descr.is_array_of_primitives():
                return True
        return False

    def is_vector(self):
        return False

    def returns_void(self):
        return self.type == 'v'

    def returns_vector(self):
        return self.type != 'v' and self.vector == -2

    def is_typecast(self):
        return False

    def cast_count(self, vec_reg_size):
        return self.cls_casts[4]

    def cast_types(self):
        return self.cls_casts[0], self.cls_casts[2]

    def cast_to_bytesize(self):
        return self.cls_casts[3]

    def cast_from_bytesize(self):
        return self.cls_casts[1]

    def casts_up(self):
        return self.cast_to_bytesize() > self.cast_from_bytesize()

    def casts_down(self):
        # includes the cast as noop
        return self.cast_to_bytesize() <= self.cast_from_bytesize()

# ===================
# Top of the hierachy
# ===================

class PlainResOp(AbstractResOp):
    pass


class ResOpWithDescr(AbstractResOp):

    _descr = None

    def getdescr(self):
        return self._descr

    def setdescr(self, descr):
        # for 'call', 'new', 'getfield_gc'...: the descr is a prebuilt
        # instance provided by the backend holding details about the type
        # of the operation.  It must inherit from AbstractDescr.  The
        # backend provides it with cpu.fielddescrof(), cpu.arraydescrof(),
        # cpu.calldescrof(), and cpu.typedescrof().
        self._check_descr(descr)
        self._descr = descr

    def cleardescr(self):
        self._descr = None

    def _check_descr(self, descr):
        if not we_are_translated() and getattr(descr, 'I_am_a_descr', False):
            return # needed for the mock case in oparser_model
        from rpython.jit.metainterp.history import check_descr
        check_descr(descr)


class GuardResOp(ResOpWithDescr):

    _fail_args = None
    rd_resume_position = -1

    def getfailargs(self):
        return self._fail_args

    def getfailargs_copy(self):
        return self._fail_args[:]

    def setfailargs(self, fail_args):
        self._fail_args = fail_args

    def copy_and_change(self, opnum, args=None, descr=None):
        newop = AbstractResOp.copy_and_change(self, opnum, args, descr)
        assert isinstance(newop, GuardResOp)
        newop.setfailargs(self.getfailargs())
        newop.rd_resume_position = self.rd_resume_position
        return newop

class VectorGuardOp(GuardResOp):
    bytesize = 0
    datatype = '\x00'
    signed = True
    count = 0

    def copy_and_change(self, opnum, args=None, descr=None):
        newop = GuardResOp.copy_and_change(self, opnum, args, descr)
        assert isinstance(newop, VectorGuardOp)
        newop.datatype = self.datatype
        newop.bytesize = self.bytesize
        newop.signed = self.signed
        newop.count = self.count
        return newop

class VectorOp(ResOpWithDescr):
    bytesize = 0
    datatype = '\x00'
    signed = True
    count = 0

    def is_vector(self):
        if self.getopnum() in (rop.VEC_UNPACK_I, rop.VEC_UNPACK_F):
            arg = self.getarg(2)
            from rpython.jit.metainterp.history import ConstInt
            assert isinstance(arg, ConstInt)
            return arg.value > 1
        return True

    def copy_and_change(self, opnum, args=None, descr=None):
        newop = ResOpWithDescr.copy_and_change(self, opnum, args, descr)
        assert isinstance(newop, VectorOp)
        newop.datatype = self.datatype
        newop.bytesize = self.bytesize
        newop.signed = self.signed
        newop.count = self.count
        return newop

    def same_shape(self, other):
        """ NOT_RPYTHON """
        myvecinfo = self.get_forwarded()
        othervecinfo = other.get_forwarded()
        if other.is_vector() != self.is_vector():
            return False
        if myvecinfo.datatype != othervecinfo.datatype:
            return False
        if myvecinfo.bytesize != othervecinfo.bytesize:
            return False
        if myvecinfo.signed != othervecinfo.signed:
            return False
        if myvecinfo.count != othervecinfo.count:
            return False
        return True


# ===========
# type mixins
# ===========

class IntOp(object):
    _mixin_ = True

    type = 'i'

    _resint = 0

    def getint(self):
        return self._resint

    getvalue = getint

    def setint(self, intval):
        self._resint = intval

    def copy_value_from(self, other):
        self.setint(other.getint())

    def constbox(self):
        from rpython.jit.metainterp import history
        return history.ConstInt(self.getint())

    def nonnull(self):
        return self._resint != 0

class FloatOp(object):
    _mixin_ = True

    type = 'f'

    _resfloat = longlong.ZEROF

    def getfloatstorage(self):
        return self._resfloat

    getvalue = getfloatstorage

    def getfloat(self):
        return longlong.getrealfloat(self.getfloatstorage())

    def setfloatstorage(self, floatval):
        assert lltype.typeOf(floatval) is longlong.FLOATSTORAGE
        self._resfloat = floatval

    def copy_value_from(self, other):
        self.setfloatstorage(other.getfloatstorage())

    def constbox(self):
        from rpython.jit.metainterp import history
        return history.ConstFloat(self.getfloatstorage())

    def nonnull(self):
        return bool(longlong.extract_bits(self._resfloat))

class RefOp(object):
    _mixin_ = True

    type = 'r'

    _resref = lltype.nullptr(llmemory.GCREF.TO)

    def getref_base(self):
        return self._resref

    def reset_value(self):
        self.setref_base(lltype.nullptr(llmemory.GCREF.TO))

    getvalue = getref_base

    def forget_value(self):
        self._resref = lltype.nullptr(llmemory.GCREF.TO)

    def setref_base(self, refval):
        self._resref = refval

    def getref(self, PTR):
        return lltype.cast_opaque_ptr(PTR, self.getref_base())
    getref._annspecialcase_ = 'specialize:arg(1)'

    def copy_value_from(self, other):
        self.setref_base(other.getref_base())

    def nonnull(self):
        return bool(self._resref)

    def constbox(self):
        from rpython.jit.metainterp import history
        return history.ConstPtr(self.getref_base())

class CastOp(object):
    _mixin_ = True

    def is_typecast(self):
        return True

    def cast_to(self):
        to_type, size = self.cls_casts[2], self.cls_casts[3]
        if self.cls_casts[3] == 0:
            if self.getopnum() == rop.INT_SIGNEXT:
                from rpython.jit.metainterp.history import ConstInt
                arg = self.getarg(1)
                assert isinstance(arg, ConstInt)
                return (to_type,arg.value)
            else:
                raise NotImplementedError
        return (to_type,size)

    def cast_from(self):
        type, size, a, b = self.cls_casts
        if size == -1:
            return self.bytesize
        return (type, size)

    def cast_input_bytesize(self, vec_reg_size):
        count = vec_reg_size // self.cast_to_bytesize()
        size = self.cast_from_bytesize() * self.cast_count(vec_reg_size)
        return size

class SignExtOp(object):
    _mixin_ = True

    def is_typecast(self):
        return True

    def cast_types(self):
        return self.cls_casts[0], self.cls_casts[2]

    def cast_to_bytesize(self):
        from rpython.jit.metainterp.history import ConstInt
        arg = self.getarg(1)
        assert isinstance(arg, ConstInt)
        return arg.value

    def cast_from_bytesize(self):
        arg = self.getarg(0)
        vecinfo = arg.get_forwarded()
        if vecinfo is None or not isinstance(vecinfo, VectorizationInfo):
            vecinfo = VectorizationInfo(arg)
        return vecinfo.bytesize

    def cast_input_bytesize(self, vec_reg_size):
        return vec_reg_size # self.cast_from_bytesize() * self.cast_count(vec_reg_size)


class AbstractInputArg(AbstractResOpOrInputArg):
    _attrs_ = ('_forwarded', 'position')

    def repr(self, memo):
        try:
            num = memo[self]
        except KeyError:
            num = len(memo)
            memo[self] = num
        return self.type + str(num)

    def get_position(self):
        return self.position

    def __repr__(self):
        return self.repr(self._repr_memo)

    def is_inputarg(self):
        return True

class InputArgInt(IntOp, AbstractInputArg):
    datatype = 'i'
    bytesize = INT_WORD
    signed = True

    def __init__(self, intval=0):
        self.setint(intval)

class InputArgFloat(FloatOp, AbstractInputArg):
    datatype = 'f'
    bytesize = FLOAT_WORD
    signed = True

    def __init__(self, f=longlong.ZEROF):
        self.setfloatstorage(f)

    @staticmethod
    def fromfloat(x):
        return InputArgFloat(longlong.getfloatstorage(x))

class InputArgRef(RefOp, AbstractInputArg):
    datatype = 'r'

    def __init__(self, r=lltype.nullptr(llmemory.GCREF.TO)):
        self.setref_base(r)

    def reset_value(self):
        self.setref_base(lltype.nullptr(llmemory.GCREF.TO))

class InputArgVector(AbstractInputArg):
    type = 'V'
    def __init__(self):
        pass

    def returns_vector(self):
        return True

# ============
# arity mixins
# ============

class NullaryOp(object):
    _mixin_ = True

    def initarglist(self, args):
        assert len(args) == 0

    def getarglist(self):
        return []

    def numargs(self):
        return 0

    def getarg(self, i):
        raise IndexError

    def setarg(self, i, box):
        raise IndexError


class UnaryOp(object):
    _mixin_ = True
    _arg0 = None

    def initarglist(self, args):
        assert len(args) == 1
        self._arg0, = args

    def getarglist(self):
        return [self._arg0]

    def numargs(self):
        return 1

    def getarg(self, i):
        if i == 0:
            return self._arg0
        else:
            raise IndexError

    def setarg(self, i, box):
        if i == 0:
            self._arg0 = box
        else:
            raise IndexError

class BinaryOp(object):
    _mixin_ = True
    _arg0 = None
    _arg1 = None

    def initarglist(self, args):
        assert len(args) == 2
        self._arg0, self._arg1 = args

    def numargs(self):
        return 2

    def getarg(self, i):
        if i == 0:
            return self._arg0
        elif i == 1:
            return self._arg1
        else:
            raise IndexError

    def setarg(self, i, box):
        if i == 0:
            self._arg0 = box
        elif i == 1:
            self._arg1 = box
        else:
            raise IndexError

    def getarglist(self):
        return [self._arg0, self._arg1]


class TernaryOp(object):
    _mixin_ = True
    _arg0 = None
    _arg1 = None
    _arg2 = None

    def initarglist(self, args):
        assert len(args) == 3
        self._arg0, self._arg1, self._arg2 = args

    def getarglist(self):
        return [self._arg0, self._arg1, self._arg2]

    def numargs(self):
        return 3

    def getarg(self, i):
        if i == 0:
            return self._arg0
        elif i == 1:
            return self._arg1
        elif i == 2:
            return self._arg2
        else:
            raise IndexError

    def setarg(self, i, box):
        if i == 0:
            self._arg0 = box
        elif i == 1:
            self._arg1 = box
        elif i == 2:
            self._arg2 = box
        else:
            raise IndexError


class N_aryOp(object):
    _mixin_ = True
    _args = None

    def initarglist(self, args):
        self._args = args
        if not we_are_translated() and \
               self.__class__.__name__.startswith('FINISH'):   # XXX remove me
            assert len(args) <= 1      # FINISH operations take 0 or 1 arg now

    def getarglist(self):
        return self._args

    def getarglist_copy(self):
        return self._args[:]

    def numargs(self):
        return len(self._args)

    def getarg(self, i):
        return self._args[i]

    def setarg(self, i, box):
        self._args[i] = box


# ____________________________________________________________

""" All the operations are desribed like this:

NAME/no-of-args-or-*[b][d]/types-of-result

if b is present it means the operation produces a boolean
if d is present it means there is a descr
type of result can be one or more of r i f n
"""

_oplist = [
    '_FINAL_FIRST',
    'JUMP/*d/n',
    'FINISH/*d/n',
    '_FINAL_LAST',

    'LABEL/*d/n',

    '_GUARD_FIRST',
    '_GUARD_FOLDABLE_FIRST',
    'GUARD_TRUE/1d/n',
    'GUARD_FALSE/1d/n',
    'VEC_GUARD_TRUE/1d/n',
    'VEC_GUARD_FALSE/1d/n',
    'GUARD_VALUE/2d/n',
    'GUARD_CLASS/2d/n',
    'GUARD_NONNULL/1d/n',
    'GUARD_ISNULL/1d/n',
    'GUARD_NONNULL_CLASS/2d/n',
    'GUARD_GC_TYPE/2d/n',       # only if supports_guard_gc_type
    'GUARD_IS_OBJECT/1d/n',     # only if supports_guard_gc_type
    'GUARD_SUBCLASS/2d/n',      # only if supports_guard_gc_type
    '_GUARD_FOLDABLE_LAST',
    'GUARD_NO_EXCEPTION/0d/n',   # may be called with an exception currently set
    'GUARD_EXCEPTION/1d/r',     # XXX kill me, use only SAVE_EXCEPTION
    'GUARD_NO_OVERFLOW/0d/n',
    'GUARD_OVERFLOW/0d/n',
    'GUARD_NOT_FORCED/0d/n',      # may be called with an exception currently set
    'GUARD_NOT_FORCED_2/0d/n',    # same as GUARD_NOT_FORCED, but for finish()
    'GUARD_NOT_INVALIDATED/0d/n',
    'GUARD_FUTURE_CONDITION/0d/n',
    'GUARD_ALWAYS_FAILS/0d/n',    # to end really long traces
    # is removable, may be patched by an optimization
    '_GUARD_LAST', # ----- end of guard operations -----

    '_NOSIDEEFFECT_FIRST', # ----- start of no_side_effect operations -----
    '_ALWAYS_PURE_FIRST', # ----- start of always_pure operations -----
    'INT_ADD/2/i',
    'INT_SUB/2/i',
    'INT_MUL/2/i',
    'UINT_MUL_HIGH/2/i',       # a * b as a double-word, keep the high word
    'INT_AND/2/i',
    'INT_OR/2/i',
    'INT_XOR/2/i',
    'INT_RSHIFT/2/i',
    'INT_LSHIFT/2/i',
    'UINT_RSHIFT/2/i',
    'INT_SIGNEXT/2/i',
    'FLOAT_ADD/2/f',
    'FLOAT_SUB/2/f',
    'FLOAT_MUL/2/f',
    'FLOAT_TRUEDIV/2/f',
    'FLOAT_NEG/1/f',
    'FLOAT_ABS/1/f',
    'CAST_FLOAT_TO_INT/1/i',          # don't use for unsigned ints; we would
    'CAST_INT_TO_FLOAT/1/f',          # need some messy code in the backend
    'CAST_FLOAT_TO_SINGLEFLOAT/1/i',
    'CAST_SINGLEFLOAT_TO_FLOAT/1/f',
    'CONVERT_FLOAT_BYTES_TO_LONGLONG/1/' + ('i' if longlong.is_64_bit else 'f'),
    'CONVERT_LONGLONG_BYTES_TO_FLOAT/1/f',
    #
    # vector operations
    '_VEC_PURE_FIRST',
    '_VEC_ARITHMETIC_FIRST',
    'VEC_INT_ADD/2/i',
    'VEC_INT_SUB/2/i',
    'VEC_INT_MUL/2/i',
    'VEC_INT_AND/2/i',
    'VEC_INT_OR/2/i',
    'VEC_INT_XOR/2/i',
    'VEC_FLOAT_ADD/2/f',
    'VEC_FLOAT_SUB/2/f',
    'VEC_FLOAT_MUL/2/f',
    'VEC_FLOAT_TRUEDIV/2/f',
    'VEC_FLOAT_NEG/1/f',
    'VEC_FLOAT_ABS/1/f',
    '_VEC_ARITHMETIC_LAST',
    'VEC_FLOAT_EQ/2b/i',
    'VEC_FLOAT_NE/2b/i',
    'VEC_FLOAT_XOR/2/f',
    'VEC_INT_IS_TRUE/1b/i',
    'VEC_INT_NE/2b/i',
    'VEC_INT_EQ/2b/i',

    '_VEC_CAST_FIRST',
    'VEC_INT_SIGNEXT/2/i',
    # double -> float: v2 = cast(v1, 2) equal to v2 = (v1[0], v1[1], X, X)
    'VEC_CAST_FLOAT_TO_SINGLEFLOAT/1/i',
    # v4 = cast(v3, 0, 2), v4 = (v3[0], v3[1])
    'VEC_CAST_SINGLEFLOAT_TO_FLOAT/1/f',
    'VEC_CAST_FLOAT_TO_INT/1/i',
    'VEC_CAST_INT_TO_FLOAT/1/f',
    '_VEC_CAST_LAST',

    'VEC/0/if',
    'VEC_UNPACK/3/if',          # iX|fX = VEC_INT_UNPACK(vX, index, count)
    'VEC_PACK/4/if',            # VEC_INT_PACK(vX, var/const, index, count)
    'VEC_EXPAND/1/if',          # vX = VEC_INT_EXPAND(var/const)
    '_VEC_PURE_LAST',
    #
    'INT_LT/2b/i',
    'INT_LE/2b/i',
    'INT_EQ/2b/i',
    'INT_NE/2b/i',
    'INT_GT/2b/i',
    'INT_GE/2b/i',
    'UINT_LT/2b/i',
    'UINT_LE/2b/i',
    'UINT_GT/2b/i',
    'UINT_GE/2b/i',
    'FLOAT_LT/2b/i',
    'FLOAT_LE/2b/i',
    'FLOAT_EQ/2b/i',
    'FLOAT_NE/2b/i',
    'FLOAT_GT/2b/i',
    'FLOAT_GE/2b/i',
    #
    'INT_IS_ZERO/1b/i',
    'INT_IS_TRUE/1b/i',
    'INT_NEG/1/i',
    'INT_INVERT/1/i',
    'INT_FORCE_GE_ZERO/1/i',
    #
    'SAME_AS/1/ifr',      # gets a Const or a Box, turns it into another Box
    'CAST_PTR_TO_INT/1/i',
    'CAST_INT_TO_PTR/1/r',
    #
    'PTR_EQ/2b/i',
    'PTR_NE/2b/i',
    'INSTANCE_PTR_EQ/2b/i',
    'INSTANCE_PTR_NE/2b/i',
    'NURSERY_PTR_INCREMENT/2/r',
    #
    'ARRAYLEN_GC/1d/i',
    'STRLEN/1/i',
    'STRGETITEM/2/i',
    'GETARRAYITEM_GC_PURE/2d/rfi',
    'UNICODELEN/1/i',
    'UNICODEGETITEM/2/i',
    #
    'LOAD_FROM_GC_TABLE/1/r',    # only emitted by rewrite.py
    'LOAD_EFFECTIVE_ADDRESS/4/i', # only emitted by rewrite.py, only if
    # cpu.supports_load_effective_address. [v_gcptr,v_index,c_baseofs,c_shift]
    # res = arg0 + (arg1 << arg3) + arg2
    #
    '_ALWAYS_PURE_LAST',  # ----- end of always_pure operations -----

    # parameters GC_LOAD
    # 1: pointer to complex object
    # 2: integer describing the offset
    # 3: constant integer. byte size of datatype to load (negative if it is signed)
    'GC_LOAD/3/rfi',
    # parameters GC_LOAD_INDEXED
    # 1: pointer to complex object
    # 2: integer describing the index
    # 3: constant integer scale factor
    # 4: constant integer base offset   (final offset is 'base + scale * index')
    # 5: constant integer. byte size of datatype to load (negative if it is signed)
    # (GC_LOAD is equivalent to GC_LOAD_INDEXED with arg3==1, arg4==0)
    'GC_LOAD_INDEXED/5/rfi',

    '_RAW_LOAD_FIRST',
    'GETARRAYITEM_GC/2d/rfi',
    'GETARRAYITEM_RAW/2d/fi',
    'RAW_LOAD/2d/fi',
    'VEC_LOAD/4d/fi',
    '_RAW_LOAD_LAST',

    'GETINTERIORFIELD_GC/2d/rfi',
    'GETFIELD_GC/1d/rfi',
    'GETFIELD_RAW/1d/rfi',
    '_MALLOC_FIRST',
    'NEW/0d/r',           #-> GcStruct, gcptrs inside are zeroed (not the rest)
    'NEW_WITH_VTABLE/0d/r',#-> GcStruct with vtable, gcptrs inside are zeroed
    'NEW_ARRAY/1d/r',     #-> GcArray, not zeroed. only for arrays of primitives
    'NEW_ARRAY_CLEAR/1d/r',#-> GcArray, fully zeroed
    'NEWSTR/1/r',         #-> STR, the hash field is zeroed
    'NEWUNICODE/1/r',     #-> UNICODE, the hash field is zeroed
    '_MALLOC_LAST',
    'FORCE_TOKEN/0/r',    # historical name; nowadays, returns the jitframe
    'VIRTUAL_REF/2/r',    # removed before it's passed to the backend
    'STRHASH/1/i',        # only reading the .hash field, might be zero so far
    'UNICODEHASH/1/i',    #     (unless applied on consts, where .hash is forced)
    # this one has no *visible* side effect, since the virtualizable
    # must be forced, however we need to execute it anyway
    '_NOSIDEEFFECT_LAST', # ----- end of no_side_effect operations -----

    # same paramters as GC_LOAD, but one additional for the value to store
    # note that the itemsize is not signed (always > 0)
    # (gcptr, index, value, [scale, base_offset,] itemsize)
    # invariants for GC_STORE: index is constant, but can be large
    # invariants for GC_STORE_INDEXED: index is a non-constant box;
    #                                  scale is a constant;
    #                                  base_offset is a small constant
    'GC_STORE/4d/n',
    'GC_STORE_INDEXED/6d/n',

    'INCREMENT_DEBUG_COUNTER/1/n',
    '_RAW_STORE_FIRST',
    'SETARRAYITEM_GC/3d/n',
    'SETARRAYITEM_RAW/3d/n',
    'RAW_STORE/3d/n',
    'VEC_STORE/5d/n',
    '_RAW_STORE_LAST',
    'SETINTERIORFIELD_GC/3d/n',
    'SETINTERIORFIELD_RAW/3d/n',    # right now, only used by tests
    'SETFIELD_GC/2d/n',
    'ZERO_ARRAY/5d/n',  # only emitted by the rewrite, clears (part of) an array
                        # [arraygcptr, firstindex, length, scale_firstindex,
                        #  scale_length], descr=ArrayDescr
    'SETFIELD_RAW/2d/n',
    'STRSETITEM/3/n',
    'UNICODESETITEM/3/n',
    'COND_CALL_GC_WB/1d/n',       # [objptr] (for the write barrier)
    'COND_CALL_GC_WB_ARRAY/2d/n', # [objptr, arrayindex] (write barr. for array)
    '_JIT_DEBUG_FIRST',
    'DEBUG_MERGE_POINT/*/n',      # debugging only
    'ENTER_PORTAL_FRAME/2/n',     # debugging only
    'LEAVE_PORTAL_FRAME/1/n',     # debugging only
    'JIT_DEBUG/*/n',              # debugging only
    '_JIT_DEBUG_LAST',
    'ESCAPE/*/rfin',              # tests only
    'FORCE_SPILL/1/n',            # tests only
    'VIRTUAL_REF_FINISH/2/n',   # removed before it's passed to the backend
    'COPYSTRCONTENT/5/n',       # src, dst, srcstart, dststart, length
    'COPYUNICODECONTENT/5/n',
    'QUASIIMMUT_FIELD/1d/n',    # [objptr], descr=SlowMutateDescr
    'ASSERT_NOT_NONE/1/n',      # [objptr]
    'RECORD_EXACT_CLASS/2/n',   # [objptr, clsptr]
    'KEEPALIVE/1/n',
    'SAVE_EXCEPTION/0/r',
    'SAVE_EXC_CLASS/0/i',       # XXX kill me
    'RESTORE_EXCEPTION/2/n',    # XXX kill me

    '_CANRAISE_FIRST', # ----- start of can_raise operations -----
    '_CALL_FIRST',
    'CALL/*d/rfin',
    'COND_CALL/*d/n',   # a conditional call, with first argument as a condition
    'COND_CALL_VALUE/*d/ri',  # "return a0 or a1(a2, ..)", a1 elidable
    'CALL_ASSEMBLER/*d/rfin',  # call already compiled assembler
    'CALL_MAY_FORCE/*d/rfin',
    'CALL_LOOPINVARIANT/*d/rfin',
    'CALL_RELEASE_GIL/*d/fin',  # release the GIL around the call
    'CALL_PURE/*d/rfin',             # removed before it's passed to the backend
    'CHECK_MEMORY_ERROR/1/n',   # after a CALL: NULL => propagate MemoryError
    'CALL_MALLOC_NURSERY/1/r',  # nursery malloc, const number of bytes, zeroed
    'CALL_MALLOC_NURSERY_VARSIZE/3d/r',
    'CALL_MALLOC_NURSERY_VARSIZE_FRAME/1/r',
    # nursery malloc, non-const number of bytes, zeroed
    # note that the number of bytes must be well known to be small enough
    # to fulfill allocating in the nursery rules (and no card markings)
    '_CALL_LAST',
    '_CANRAISE_LAST', # ----- end of can_raise operations -----

    '_OVF_FIRST', # ----- start of is_ovf operations -----
    'INT_ADD_OVF/2/i', # note that the orded has to match INT_ADD order
    'INT_SUB_OVF/2/i',
    'INT_MUL_OVF/2/i',
    '_OVF_LAST', # ----- end of is_ovf operations -----
    '_LAST',     # for the backend to add more internal operations
]

_cast_ops = {
    'CAST_FLOAT_TO_INT': ('f', 8, 'i', 4, 2),
    'VEC_CAST_FLOAT_TO_INT': ('f', 8, 'i', 4, 2),
    'CAST_INT_TO_FLOAT': ('i', 4, 'f', 8, 2),
    'VEC_CAST_INT_TO_FLOAT': ('i', 4, 'f', 8, 2),
    'CAST_FLOAT_TO_SINGLEFLOAT': ('f', 8, 'i', 4, 2),
    'VEC_CAST_FLOAT_TO_SINGLEFLOAT': ('f', 8, 'i', 4, 2),
    'CAST_SINGLEFLOAT_TO_FLOAT': ('i', 4, 'f', 8, 2),
    'VEC_CAST_SINGLEFLOAT_TO_FLOAT': ('i', 4, 'f', 8, 2),
    'INT_SIGNEXT': ('i', 0, 'i', 0, 0),
    'VEC_INT_SIGNEXT': ('i', 0, 'i', 0, 0),
}

import platform
if not platform.machine().startswith('x86'):
    # Uh, that should be moved to vector_ext really!
    _cast_ops['CAST_FLOAT_TO_INT'] = ('f', 8, 'i', 8, 2)
    _cast_ops['VEC_CAST_FLOAT_TO_INT'] = ('f', 8, 'i', 8, 2)
    _cast_ops['CAST_INT_TO_FLOAT'] = ('i', 8, 'f', 8, 2)
    _cast_ops['VEC_CAST_INT_TO_FLOAT'] = ('i', 8, 'f', 8, 2)

# ____________________________________________________________

class rop(object):
    @staticmethod
    def call_for_descr(descr):
        tp = descr.get_normalized_result_type()
        if tp == 'i':
            return rop.CALL_I
        elif tp == 'r':
            return rop.CALL_R
        elif tp == 'f':
            return rop.CALL_F
        assert tp == 'v'
        return rop.CALL_N

    @staticmethod
    def call_pure_for_descr(descr):
        tp = descr.get_normalized_result_type()
        if tp == 'i':
            return rop.CALL_PURE_I
        elif tp == 'r':
            return rop.CALL_PURE_R
        elif tp == 'f':
            return rop.CALL_PURE_F
        assert tp == 'v'
        return rop.CALL_PURE_N

    @staticmethod
    def call_may_force_for_descr(descr):
        tp = descr.get_normalized_result_type()
        if tp == 'i':
            return rop.CALL_MAY_FORCE_I
        elif tp == 'r':
            return rop.CALL_MAY_FORCE_R
        elif tp == 'f':
            return rop.CALL_MAY_FORCE_F
        assert tp == 'v'
        return rop.CALL_MAY_FORCE_N

    @staticmethod
    def call_release_gil_for_descr(descr):
        tp = descr.get_normalized_result_type()
        if tp == 'i':
            return rop.CALL_RELEASE_GIL_I
        # no such thing
        #elif tp == 'r':
        #    return rop.CALL_RELEASE_GIL_R
        elif tp == 'f':
            return rop.CALL_RELEASE_GIL_F
        assert tp == 'v'
        return rop.CALL_RELEASE_GIL_N

    @staticmethod
    def call_assembler_for_descr(descr):
        tp = descr.get_normalized_result_type()
        if tp == 'i':
            return rop.CALL_ASSEMBLER_I
        elif tp == 'r':
            return rop.CALL_ASSEMBLER_R
        elif tp == 'f':
            return rop.CALL_ASSEMBLER_F
        assert tp == 'v'
        return rop.CALL_ASSEMBLER_N

    @staticmethod
    def call_loopinvariant_for_descr(descr):
        tp = descr.get_normalized_result_type()
        if tp == 'i':
            return rop.CALL_LOOPINVARIANT_I
        elif tp == 'r':
            return rop.CALL_LOOPINVARIANT_R
        elif tp == 'f':
            return rop.CALL_LOOPINVARIANT_F
        assert tp == 'v'
        return rop.CALL_LOOPINVARIANT_N

    @staticmethod
    def cond_call_value_for_descr(descr):
        tp = descr.get_normalized_result_type()
        if tp == 'i':
            return rop.COND_CALL_VALUE_I
        elif tp == 'r':
            return rop.COND_CALL_VALUE_R
        assert False, tp

    @staticmethod
    def getfield_pure_for_descr(descr):
        if descr.is_pointer_field():
            return rop.GETFIELD_GC_PURE_R
        elif descr.is_float_field():
            return rop.GETFIELD_GC_PURE_F
        return rop.GETFIELD_GC_PURE_I

    @staticmethod
    def getfield_for_descr(descr):
        if descr.is_pointer_field():
            return rop.GETFIELD_GC_R
        elif descr.is_float_field():
            return rop.GETFIELD_GC_F
        return rop.GETFIELD_GC_I

    @staticmethod
    def getarrayitem_pure_for_descr(descr):
        if descr.is_array_of_pointers():
            return rop.GETARRAYITEM_GC_PURE_R
        elif descr.is_array_of_floats():
            return rop.GETARRAYITEM_GC_PURE_F
        return rop.GETARRAYITEM_GC_PURE_I

    @staticmethod
    def getarrayitem_for_descr(descr):
        if descr.is_array_of_pointers():
            return rop.GETARRAYITEM_GC_R
        elif descr.is_array_of_floats():
            return rop.GETARRAYITEM_GC_F
        return rop.GETARRAYITEM_GC_I

    @staticmethod
    def same_as_for_type(tp):
        if tp == 'i':
            return rop.SAME_AS_I
        elif tp == 'r':
            return rop.SAME_AS_R
        else:
            assert tp == 'f'
            return rop.SAME_AS_F

    @staticmethod
    def call_for_type(tp):
        if tp == 'i':
            return rop.CALL_I
        elif tp == 'r':
            return rop.CALL_R
        elif tp == 'f':
            return rop.CALL_F
        return rop.CALL_N

    @staticmethod
    def call_pure_for_type(tp):
        if tp == 'i':
            return rop.CALL_PURE_I
        elif tp == 'r':
            return rop.CALL_PURE_R
        elif tp == 'f':
            return rop.CALL_PURE_F
        return rop.CALL_PURE_N

    @staticmethod
    def is_guard(opnum):
        return rop._GUARD_FIRST <= opnum <= rop._GUARD_LAST

    @staticmethod
    def is_comparison(opnum):
        return rop.is_always_pure(opnum) and rop.returns_bool_result(opnum)

    @staticmethod
    def is_foldable_guard(opnum):
        return rop._GUARD_FOLDABLE_FIRST <= opnum <= rop._GUARD_FOLDABLE_LAST

    @staticmethod
    def is_guard_exception(opnum):
        return (opnum == rop.GUARD_EXCEPTION or
                opnum == rop.GUARD_NO_EXCEPTION)

    @staticmethod
    def is_guard_overflow(opnum):
        return (opnum == rop.GUARD_OVERFLOW or
                opnum == rop.GUARD_NO_OVERFLOW)

    @staticmethod
    def is_jit_debug(opnum):
        return rop._JIT_DEBUG_FIRST <= opnum <= rop._JIT_DEBUG_LAST

    @staticmethod
    def is_always_pure(opnum):
        return rop._ALWAYS_PURE_FIRST <= opnum <= rop._ALWAYS_PURE_LAST

    @staticmethod
    def is_pure_with_descr(opnum, descr):
        if rop.is_always_pure(opnum):
            return True
        if (opnum == rop.GETFIELD_RAW_I or
            opnum == rop.GETFIELD_RAW_R or
            opnum == rop.GETFIELD_RAW_F or
            opnum == rop.GETFIELD_GC_I or
            opnum == rop.GETFIELD_GC_R or
            opnum == rop.GETFIELD_GC_F or
            opnum == rop.GETARRAYITEM_RAW_I or
            opnum == rop.GETARRAYITEM_RAW_F):
            return descr.is_always_pure()
        return False

    @staticmethod
    def is_pure_getfield(opnum, descr):
        if (opnum == rop.GETFIELD_GC_I or
            opnum == rop.GETFIELD_GC_F or
            opnum == rop.GETFIELD_GC_R):
            return descr is not None and descr.is_always_pure()
        return False

    @staticmethod
    def has_no_side_effect(opnum):
        return rop._NOSIDEEFFECT_FIRST <= opnum <= rop._NOSIDEEFFECT_LAST

    @staticmethod
    def can_raise(opnum):
        return rop._CANRAISE_FIRST <= opnum <= rop._CANRAISE_LAST

    @staticmethod
    def is_malloc(opnum):
        # a slightly different meaning from can_malloc
        return rop._MALLOC_FIRST <= opnum <= rop._MALLOC_LAST

    @staticmethod
    def can_malloc(opnum):
        return rop.is_call(opnum) or rop.is_malloc(opnum)

    @staticmethod
    def is_same_as(opnum):
        return opnum in (rop.SAME_AS_I, rop.SAME_AS_F, rop.SAME_AS_R)

    @staticmethod
    def is_getfield(opnum):
        return opnum in (rop.GETFIELD_GC_I, rop.GETFIELD_GC_F,
                              rop.GETFIELD_GC_R)

    @staticmethod
    def is_getarrayitem(opnum):
        return opnum in (rop.GETARRAYITEM_GC_I, rop.GETARRAYITEM_GC_F,
                         rop.GETARRAYITEM_GC_R, rop.GETARRAYITEM_GC_PURE_I,
                         rop.GETARRAYITEM_GC_PURE_F,
                         rop.GETARRAYITEM_GC_PURE_R)

    @staticmethod
    def is_real_call(opnum):
        return (opnum == rop.CALL_I or
                opnum == rop.CALL_R or
                opnum == rop.CALL_F or
                opnum == rop.CALL_N)

    @staticmethod
    def is_call_assembler(opnum):
        return (opnum == rop.CALL_ASSEMBLER_I or
                opnum == rop.CALL_ASSEMBLER_R or
                opnum == rop.CALL_ASSEMBLER_N or
                opnum == rop.CALL_ASSEMBLER_F)

    @staticmethod
    def is_call_may_force(opnum):
        return (opnum == rop.CALL_MAY_FORCE_I or
                opnum == rop.CALL_MAY_FORCE_R or
                opnum == rop.CALL_MAY_FORCE_N or
                opnum == rop.CALL_MAY_FORCE_F)

    @staticmethod
    def is_call_pure(opnum):
        return (opnum == rop.CALL_PURE_I or
                opnum == rop.CALL_PURE_R or
                opnum == rop.CALL_PURE_N or
                opnum == rop.CALL_PURE_F)

    @staticmethod
    def is_call_release_gil(opnum):
        # no R returning call_release_gil
        return (opnum == rop.CALL_RELEASE_GIL_I or
                opnum == rop.CALL_RELEASE_GIL_F or
                opnum == rop.CALL_RELEASE_GIL_N)

    @staticmethod
    def is_cond_call_value(opnum):
        return (opnum == rop.COND_CALL_VALUE_I or
                opnum == rop.COND_CALL_VALUE_R)

    @staticmethod
    def is_ovf(opnum):
        return rop._OVF_FIRST <= opnum <= rop._OVF_LAST

    @staticmethod
    def is_vector_arithmetic(opnum):
        return rop._VEC_ARITHMETIC_FIRST <= opnum <= rop._VEC_ARITHMETIC_LAST

    @staticmethod
    def is_raw_array_access(opnum):
        return rop.is_raw_load(opnum) or rop.is_raw_store(opnum)

    @staticmethod
    def is_primitive_load(opnum):
        return rop._RAW_LOAD_FIRST < opnum < rop._RAW_LOAD_LAST

    @staticmethod
    def is_primitive_store(opnum):
        return rop._RAW_STORE_FIRST < opnum < rop._RAW_STORE_LAST

    @staticmethod
    def is_final(opnum):
        return rop._FINAL_FIRST <= opnum <= rop._FINAL_LAST

    @staticmethod
    def returns_bool_result(opnum):
        return opclasses[opnum]._cls_has_bool_result

    @staticmethod
    def is_label(opnum):
        return opnum == rop.LABEL

    @staticmethod
    def is_call(opnum):
        return rop._CALL_FIRST <= opnum <= rop._CALL_LAST

    @staticmethod
    def is_plain_call(opnum):
        return (opnum == rop.CALL_I or
                opnum == rop.CALL_R or
                opnum == rop.CALL_F or
                opnum == rop.CALL_N)

    @staticmethod
    def is_call_loopinvariant(opnum):
        return (opnum == rop.CALL_LOOPINVARIANT_I or
                opnum == rop.CALL_LOOPINVARIANT_R or
                opnum == rop.CALL_LOOPINVARIANT_F or
                opnum == rop.CALL_LOOPINVARIANT_N)

    @staticmethod
    def get_gc_load(tp):
        if tp == 'i':
            return rop.GC_LOAD_I
        elif tp == 'f':
            return rop.GC_LOAD_F
        else:
            assert tp == 'r'
        return rop.GC_LOAD_R

    @staticmethod
    def get_gc_load_indexed(tp):
        if tp == 'i':
            return rop.GC_LOAD_INDEXED_I
        elif tp == 'f':
            return rop.GC_LOAD_INDEXED_F
        else:
            assert tp == 'r'
            return rop.GC_LOAD_INDEXED_R

    @staticmethod
    def inputarg_from_tp(tp):
        if tp == 'i':
            return InputArgInt()
        elif tp == 'r' or tp == 'p':
            return InputArgRef()
        elif tp == 'v':
            return InputArgVector()
        else:
            assert tp == 'f'
            return InputArgFloat()

    @staticmethod
    def create_vec_expand(arg, bytesize, signed, count):
        if arg.type == 'i':
            opnum = rop.VEC_EXPAND_I
        else:
            assert arg.type == 'f'
            opnum = rop.VEC_EXPAND_F
        return VecOperationNew(opnum, [arg], arg.type, bytesize, signed, count)

    @staticmethod
    def create_vec(datatype, bytesize, signed, count):
        if datatype == 'i':
            opnum = rop.VEC_I
        else:
            assert datatype == 'f'
            opnum = rop.VEC_F
        return VecOperationNew(opnum, [], datatype, bytesize, signed, count)

    @staticmethod
    def create_vec_pack(datatype, args, bytesize, signed, count):
        if datatype == 'i':
            opnum = rop.VEC_PACK_I
        else:
            assert datatype == 'f'
            opnum = rop.VEC_PACK_F
        return VecOperationNew(opnum, args, datatype, bytesize, signed, count)

    @staticmethod
    def create_vec_unpack(datatype, args, bytesize, signed, count):
        if datatype == 'i':
            opnum = rop.VEC_UNPACK_I
        else:
            assert datatype == 'f'
            opnum = rop.VEC_UNPACK_F
        return VecOperationNew(opnum, args, datatype, bytesize, signed, count)



opclasses = []   # mapping numbers to the concrete ResOp class
opname = {}      # mapping numbers to the original names, for debugging
oparity = []     # mapping numbers to the arity of the operation or -1
opwithdescr = [] # mapping numbers to a flag "takes a descr"
optypes = []     # mapping numbers to type of return

def setup(debug_print=False):
    i = 0
    for name in _oplist:
        if '/' in name:
            name, arity, result = name.split('/')
            withdescr = 'd' in arity
            boolresult = 'b' in arity
            arity = arity.rstrip('db')
            if arity == '*':
                arity = -1
            else:
                arity = int(arity)
        else:
            arity, withdescr, boolresult, result = -1, True, False, None       # default
        if not name.startswith('_'):
            for r in result:
                if len(result) == 1:
                    cls_name = name
                else:
                    cls_name = name + '_' + r.upper()
                setattr(rop, cls_name, i)
                opname[i] = cls_name
                cls = create_class_for_op(cls_name, i, arity, withdescr, r)
                cls._cls_has_bool_result = boolresult
                opclasses.append(cls)
                oparity.append(arity)
                opwithdescr.append(withdescr)
                optypes.append(r)
                if debug_print:
                    print '%30s = %d' % (cls_name, i)
                i += 1
        else:
            setattr(rop, name, i)
            opclasses.append(None)
            oparity.append(-1)
            opwithdescr.append(False)
            optypes.append(' ')
            if debug_print:
                print '%30s = %d' % (name, i)
            i += 1
    # for optimizeopt/pure.py's getrecentops()
    assert (rop.INT_ADD_OVF - rop._OVF_FIRST ==
            rop.INT_ADD - rop._ALWAYS_PURE_FIRST)
    assert (rop.INT_SUB_OVF - rop._OVF_FIRST ==
            rop.INT_SUB - rop._ALWAYS_PURE_FIRST)
    assert (rop.INT_MUL_OVF - rop._OVF_FIRST ==
            rop.INT_MUL - rop._ALWAYS_PURE_FIRST)

def get_base_class(mixins, base):
    try:
        return get_base_class.cache[(base,) + mixins]
    except KeyError:
        arity_name = mixins[0].__name__[:-2]  # remove the trailing "Op"
        name = arity_name + base.__name__ # something like BinaryPlainResOp
        bases = mixins + (base,)
        cls = type(name, bases, {})
        get_base_class.cache[(base,) + mixins] = cls
        return cls
get_base_class.cache = {}

def create_class_for_op(name, opnum, arity, withdescr, result_type):
    arity2mixin = {
        0: NullaryOp,
        1: UnaryOp,
        2: BinaryOp,
        3: TernaryOp
    }

    is_guard = name.startswith('GUARD')
    if name.startswith('VEC'):
        if name.startswith('VEC_GUARD'):
            baseclass = VectorGuardOp
        else:
            baseclass = VectorOp
    elif is_guard:
        assert withdescr
        baseclass = GuardResOp
    elif withdescr:
        baseclass = ResOpWithDescr
    else:
        baseclass = PlainResOp

    mixins = [arity2mixin.get(arity, N_aryOp)]
    if name in _cast_ops:
        if "INT_SIGNEXT" in name:
            mixins.append(SignExtOp)
        mixins.append(CastOp)

    cls_name = '%s_OP' % name
    bases = (get_base_class(tuple(mixins), baseclass),)
    dic = {'opnum': opnum}
    res = type(cls_name, bases, dic)
    if result_type == 'n':
        result_type = 'v' # why?
    res.type = result_type
    return res

setup(__name__ == '__main__')   # print out the table when run directly
del _oplist

_opboolinverse = {
    rop.INT_EQ: rop.INT_NE,
    rop.INT_NE: rop.INT_EQ,
    rop.INT_LT: rop.INT_GE,
    rop.INT_GE: rop.INT_LT,
    rop.INT_GT: rop.INT_LE,
    rop.INT_LE: rop.INT_GT,

    rop.UINT_LT: rop.UINT_GE,
    rop.UINT_GE: rop.UINT_LT,
    rop.UINT_GT: rop.UINT_LE,
    rop.UINT_LE: rop.UINT_GT,

    rop.FLOAT_EQ: rop.FLOAT_NE,
    rop.FLOAT_NE: rop.FLOAT_EQ,
    rop.FLOAT_LT: rop.FLOAT_GE,
    rop.FLOAT_GE: rop.FLOAT_LT,
    rop.FLOAT_GT: rop.FLOAT_LE,
    rop.FLOAT_LE: rop.FLOAT_GT,

    rop.PTR_EQ: rop.PTR_NE,
    rop.PTR_NE: rop.PTR_EQ,
}

_opboolreflex = {
    rop.INT_EQ: rop.INT_EQ,
    rop.INT_NE: rop.INT_NE,
    rop.INT_LT: rop.INT_GT,
    rop.INT_GE: rop.INT_LE,
    rop.INT_GT: rop.INT_LT,
    rop.INT_LE: rop.INT_GE,

    rop.UINT_LT: rop.UINT_GT,
    rop.UINT_GE: rop.UINT_LE,
    rop.UINT_GT: rop.UINT_LT,
    rop.UINT_LE: rop.UINT_GE,

    rop.FLOAT_EQ: rop.FLOAT_EQ,
    rop.FLOAT_NE: rop.FLOAT_NE,
    rop.FLOAT_LT: rop.FLOAT_GT,
    rop.FLOAT_GE: rop.FLOAT_LE,
    rop.FLOAT_GT: rop.FLOAT_LT,
    rop.FLOAT_LE: rop.FLOAT_GE,

    rop.PTR_EQ: rop.PTR_EQ,
    rop.PTR_NE: rop.PTR_NE,
}
_opvector = {
    rop.RAW_LOAD_I:         rop.VEC_LOAD_I,
    rop.RAW_LOAD_F:         rop.VEC_LOAD_F,
    rop.GETARRAYITEM_RAW_I: rop.VEC_LOAD_I,
    rop.GETARRAYITEM_RAW_F: rop.VEC_LOAD_F,
    rop.GETARRAYITEM_GC_I: rop.VEC_LOAD_I,
    rop.GETARRAYITEM_GC_F: rop.VEC_LOAD_F,
    # note that there is no _PURE operation for vector operations.
    # reason: currently we do not care if it is pure or not!
    rop.GETARRAYITEM_GC_PURE_I: rop.VEC_LOAD_I,
    rop.GETARRAYITEM_GC_PURE_F: rop.VEC_LOAD_F,
    rop.RAW_STORE:        rop.VEC_STORE,
    rop.SETARRAYITEM_RAW: rop.VEC_STORE,
    rop.SETARRAYITEM_GC: rop.VEC_STORE,

    rop.INT_ADD:   rop.VEC_INT_ADD,
    rop.INT_SUB:   rop.VEC_INT_SUB,
    rop.INT_MUL:   rop.VEC_INT_MUL,
    rop.INT_AND:   rop.VEC_INT_AND,
    rop.INT_OR:   rop.VEC_INT_OR,
    rop.INT_XOR:   rop.VEC_INT_XOR,
    rop.FLOAT_ADD: rop.VEC_FLOAT_ADD,
    rop.FLOAT_SUB: rop.VEC_FLOAT_SUB,
    rop.FLOAT_MUL: rop.VEC_FLOAT_MUL,
    rop.FLOAT_TRUEDIV: rop.VEC_FLOAT_TRUEDIV,
    rop.FLOAT_ABS: rop.VEC_FLOAT_ABS,
    rop.FLOAT_NEG: rop.VEC_FLOAT_NEG,
    rop.FLOAT_EQ:  rop.VEC_FLOAT_EQ,
    rop.FLOAT_NE:  rop.VEC_FLOAT_NE,
    rop.INT_IS_TRUE: rop.VEC_INT_IS_TRUE,
    rop.INT_EQ:  rop.VEC_INT_EQ,
    rop.INT_NE:  rop.VEC_INT_NE,

    # casts
    rop.INT_SIGNEXT: rop.VEC_INT_SIGNEXT,
    rop.CAST_FLOAT_TO_SINGLEFLOAT: rop.VEC_CAST_FLOAT_TO_SINGLEFLOAT,
    rop.CAST_SINGLEFLOAT_TO_FLOAT: rop.VEC_CAST_SINGLEFLOAT_TO_FLOAT,
    rop.CAST_INT_TO_FLOAT: rop.VEC_CAST_INT_TO_FLOAT,
    rop.CAST_FLOAT_TO_INT: rop.VEC_CAST_FLOAT_TO_INT,

    # guard
    rop.GUARD_TRUE: rop.VEC_GUARD_TRUE,
    rop.GUARD_FALSE: rop.VEC_GUARD_FALSE,
}

def setup2():
    for cls in opclasses:
        if cls is None:
            continue
        opnum = cls.opnum
        name = opname[opnum]
        if opnum in _opboolreflex:
            cls.boolreflex = _opboolreflex[opnum]
        if opnum in _opboolinverse:
            cls.boolinverse = _opboolinverse[opnum]
        if opnum in _opvector:
            cls.vector = _opvector[opnum]
        if name in _cast_ops:
            cls.cls_casts = _cast_ops[name]
        if name.startswith('VEC'):
            cls.vector = -2
setup2()
del _opboolinverse
del _opboolreflex
del _opvector
del _cast_ops

def get_deep_immutable_oplist(operations):
    """
    When not we_are_translated(), turns ``operations`` into a frozenlist and
    monkey-patch its items to make sure they are not mutated.

    When we_are_translated(), do nothing and just return the old list.
    """
    from rpython.tool.frozenlist import frozenlist
    if we_are_translated():
        return operations
    #
    def setarg(*args):
        assert False, "operations cannot change at this point"
    def setdescr(*args):
        assert False, "operations cannot change at this point"
    newops = frozenlist(operations)
    for op in newops:
        op.setarg = setarg
        op.setdescr = setdescr
    return newops

OpHelpers = rop
