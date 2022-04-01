from rpython.jit.backend.llsupport.rewrite import cpu_simplify_scale
from rpython.jit.backend.llsupport.descr import (unpack_arraydescr,
        unpack_fielddescr, unpack_interiorfielddescr, ArrayDescr)
from rpython.rlib.objectmodel import specialize, always_inline
from rpython.jit.metainterp.history import (VECTOR, FLOAT, INT, ConstInt)
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.metainterp.optimizeopt.schedule import (forwarded_vecinfo,
        failnbail_transformation)
from rpython.jit.metainterp.jitexc import NotAVectorizeableLoop
from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem import lltype
from rpython.rlib.debug import debug_print

class TypeRestrict(object):
    ANY_TYPE = '\x00'
    ANY_SIZE = -1
    ANY_SIGN = -1
    ANY_COUNT = -1
    SIGNED = 1
    UNSIGNED = 0

    def __init__(self,
                 type=ANY_TYPE,
                 bytesize=ANY_SIZE,
                 count=ANY_SIGN,
                 sign=ANY_COUNT):
        self.type = type
        self.bytesize = bytesize
        self.sign = sign
        self.count = count

    @always_inline
    def any_size(self):
        return self.bytesize == TypeRestrict.ANY_SIZE

    @always_inline
    def any_count(self):
        return self.count == TypeRestrict.ANY_COUNT

    def check(self, value):
        vecinfo = forwarded_vecinfo(value)
        assert vecinfo.datatype != '\x00'
        if self.type != TypeRestrict.ANY_TYPE:
            if self.type != vecinfo.datatype:
                msg = "type mismatch %s != %s" % \
                        (self.type, vecinfo.datatype)
                failnbail_transformation(msg)
        assert vecinfo.bytesize > 0
        if not self.any_size():
            if self.bytesize != vecinfo.bytesize:
                msg = "bytesize mismatch %s != %s" % \
                        (self.bytesize, vecinfo.bytesize)
                failnbail_transformation(msg)
        assert vecinfo.count > 0
        if self.count != TypeRestrict.ANY_COUNT:
            if vecinfo.count < self.count:
                msg = "count mismatch %s < %s" % \
                        (self.count, vecinfo.count)
                failnbail_transformation(msg)
        if self.sign != TypeRestrict.ANY_SIGN:
            if bool(self.sign) == vecinfo.sign:
                msg = "sign mismatch %s < %s" % \
                        (self.sign, vecinfo.sign)
                failnbail_transformation(msg)

    def max_input_count(self, count):
        """ How many """
        if self.count != TypeRestrict.ANY_COUNT:
            return self.count
        return count

class OpRestrict(object):
    def __init__(self, argument_restris):
        self.argument_restrictions = argument_restris

    def check_operation(self, state, pack, op):
        return None

    def crop_vector(self, op, newsize, size):
        return newsize, size

    def must_crop_vector(self, op, index):
        restrict = self.argument_restrictions[index]
        vecinfo = forwarded_vecinfo(op.getarg(index))
        size = vecinfo.bytesize
        newsize = self.crop_to_size(op, index)
        return not restrict.any_size() and newsize != size

    @always_inline
    def crop_to_size(self, op, index):
        restrict = self.argument_restrictions[index]
        return restrict.bytesize

    def opcount_filling_vector_register(self, op, vec_reg_size):
        """ How many operations of that kind can one execute
            with a machine instruction of register size X?
        """
        if op.is_typecast():
            if op.casts_down():
                size = op.cast_input_bytesize(vec_reg_size)
                return size // op.cast_from_bytesize()
            else:
                return vec_reg_size // op.cast_to_bytesize()
        vecinfo = forwarded_vecinfo(op)
        return  vec_reg_size // vecinfo.bytesize

class GuardRestrict(OpRestrict):
    def opcount_filling_vector_register(self, op, vec_reg_size):
        arg = op.getarg(0)
        vecinfo = forwarded_vecinfo(arg)
        return vec_reg_size // vecinfo.bytesize

class LoadRestrict(OpRestrict):
    def check_operation(self, state, pack, op):
        opnum = op.getopnum()
        descr = op.getdescr()
        if not we_are_translated() and not isinstance(descr, ArrayDescr):
            itemsize = descr.get_item_size_in_bytes()
            ofs = 0
        else:
            itemsize, ofs, _ = unpack_arraydescr(op.getdescr())
        args = [op.getarg(0), op.getarg(1), ConstInt(1), ConstInt(ofs)]
        if rop.is_getarrayitem(opnum) or \
             opnum in (rop.GETARRAYITEM_RAW_I, rop.GETARRAYITEM_RAW_F):
            index_box = op.getarg(1)
            scale, offset, changed, emit = cpu_simplify_scale(state.cpu, index_box, itemsize, ofs)
            args[2] = ConstInt(scale)
            args[3] = ConstInt(offset)
            if emit:
                state.oplist.append(changed)
                args[1] = changed

        return args


    def opcount_filling_vector_register(self, op, vec_reg_size):
        assert rop.is_primitive_load(op.opnum)
        descr = op.getdescr()
        return vec_reg_size // descr.get_item_size_in_bytes()

class StoreRestrict(OpRestrict):
    def __init__(self, argument_restris):
        self.argument_restrictions = argument_restris

    def check_operation(self, state, pack, op):
        opnum = op.getopnum()
        descr = op.getdescr()
        if not we_are_translated() and not isinstance(descr, ArrayDescr):
            itemsize = descr.get_item_size_in_bytes()
            ofs = 0
        else:
            itemsize, ofs, _ = unpack_arraydescr(op.getdescr())
        args = [op.getarg(0), op.getarg(1), op.getarg(2), ConstInt(1), ConstInt(ofs)]
        if opnum in (rop.SETARRAYITEM_GC, rop.SETARRAYITEM_RAW):
            index_box = op.getarg(1)
            scale, offset, changed, emit = cpu_simplify_scale(state.cpu, index_box, itemsize, ofs)
            args[3] = ConstInt(scale)
            args[4] = ConstInt(offset)
            if emit:
                state.oplist.append(changed)
                args[1] = changed
        return args

    def must_crop_vector(self, op, index):
        vecinfo = forwarded_vecinfo(op.getarg(index))
        bytesize = vecinfo.bytesize
        return self.crop_to_size(op, index) != bytesize

    @always_inline
    def crop_to_size(self, op, index):
        # there is only one parameter that needs to be transformed!
        descr = op.getdescr()
        return descr.get_item_size_in_bytes()

    def opcount_filling_vector_register(self, op, vec_reg_size):
        assert rop.is_primitive_store(op.opnum)
        descr = op.getdescr()
        return vec_reg_size // descr.get_item_size_in_bytes()

class OpMatchSizeTypeFirst(OpRestrict):
    def check_operation(self, state, pack, op):
        i = 0
        infos = [forwarded_vecinfo(o) for o in op.getarglist()]
        arg0 = op.getarg(i)
        while arg0.is_constant() and i < op.numargs():
            i += 1
            arg0 = op.getarg(i)
        vecinfo = forwarded_vecinfo(arg0)
        bytesize = vecinfo.bytesize
        datatype = vecinfo.datatype

        for arg in op.getarglist():
            if arg.is_constant():
                continue
            curvecinfo = forwarded_vecinfo(arg)
            if curvecinfo.bytesize != bytesize:
                debug_print("op match size first type failed")
                raise NotAVectorizeableLoop
            if curvecinfo.datatype != datatype:
                debug_print("op match size first type failed (datatype)")
                raise NotAVectorizeableLoop
        return None

TR_ANY = TypeRestrict()
TR_ANY_FLOAT = TypeRestrict(FLOAT)
TR_ANY_INTEGER = TypeRestrict(INT)
TR_FLOAT_2 = TypeRestrict(FLOAT, 4, 2)
TR_DOUBLE_2 = TypeRestrict(FLOAT, 8, 2)
TR_INT32_2 = TypeRestrict(INT, 4, 2)
TR_INT64_2 = TypeRestrict(INT, 8, 2)

OR_MSTF_I = OpMatchSizeTypeFirst([TR_ANY_INTEGER, TR_ANY_INTEGER])
OR_MSTF_F = OpMatchSizeTypeFirst([TR_ANY_FLOAT, TR_ANY_FLOAT])
STORE_RESTRICT = StoreRestrict([None, None, TR_ANY])
LOAD_RESTRICT = LoadRestrict([])
GUARD_RESTRICT = GuardRestrict([TR_ANY_INTEGER])


class VectorExt(object):

    should_align_unroll = True

    def __init__(self):
        self._enabled = False
        self.register_size = 0 # in bytes
        self.accum = False
        self._setup = False

    def is_setup(self):
        return self._setup

    def setup_once(self):
        raise NotImplementedError

    def enable(self, vec_size, accum=False):
        self._enabled = vec_size != 0
        self.register_size = vec_size
        self.accum = accum

    def is_enabled(self):
        return self._enabled

    def vec_size(self):
        return self.register_size

    def supports_accumulation(self):
        return self.accum

    # note that the following definition is x86 arch specific
    TR_MAPPING = {
        rop.VEC_INT_ADD:            OR_MSTF_I,
        rop.VEC_INT_SUB:            OR_MSTF_I,
        rop.VEC_INT_MUL:            OR_MSTF_I,
        rop.VEC_INT_AND:            OR_MSTF_I,
        rop.VEC_INT_OR:             OR_MSTF_I,
        rop.VEC_INT_XOR:            OR_MSTF_I,
        rop.VEC_INT_EQ:             OR_MSTF_I,
        rop.VEC_INT_NE:             OR_MSTF_I,

        rop.VEC_FLOAT_ADD:          OR_MSTF_F,
        rop.VEC_FLOAT_SUB:          OR_MSTF_F,
        rop.VEC_FLOAT_MUL:          OR_MSTF_F,
        rop.VEC_FLOAT_TRUEDIV:      OR_MSTF_F,
        rop.VEC_FLOAT_ABS:          OpRestrict([TR_ANY_FLOAT]),
        rop.VEC_FLOAT_NEG:          OpRestrict([TR_ANY_FLOAT]),

        rop.VEC_STORE:              STORE_RESTRICT,

        rop.VEC_LOAD_I:             LOAD_RESTRICT,
        rop.VEC_LOAD_F:             LOAD_RESTRICT,

        rop.VEC_GUARD_TRUE:             GUARD_RESTRICT,
        rop.VEC_GUARD_FALSE:            GUARD_RESTRICT,

        ## irregular
        rop.VEC_INT_SIGNEXT:        OpRestrict([TR_ANY_INTEGER]),

        rop.VEC_CAST_FLOAT_TO_SINGLEFLOAT:  OpRestrict([TR_DOUBLE_2]),
        # weird but the trace will store single floats in int boxes
        rop.VEC_CAST_SINGLEFLOAT_TO_FLOAT:  OpRestrict([TR_INT32_2]),
        rop.VEC_CAST_FLOAT_TO_INT:          OpRestrict([TR_DOUBLE_2]),
        rop.VEC_CAST_INT_TO_FLOAT:          OpRestrict([TR_INT32_2]),

        rop.VEC_FLOAT_EQ:           OpRestrict([TR_ANY_FLOAT,TR_ANY_FLOAT]),
        rop.VEC_FLOAT_NE:           OpRestrict([TR_ANY_FLOAT,TR_ANY_FLOAT]),
        rop.VEC_INT_IS_TRUE:        OpRestrict([TR_ANY_INTEGER,TR_ANY_INTEGER]),
    }

    def get_operation_restriction(self, op):
        res = self.TR_MAPPING.get(op.vector, None)
        if not res:
            failnbail_transformation("could not get OpRestrict for " + str(op))
        return res

