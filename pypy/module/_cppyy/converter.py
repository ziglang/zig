import sys

from pypy.interpreter.error import OperationError, oefmt
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import r_singlefloat, r_longfloat
from rpython.rlib import rfloat, rawrefcount
from pypy.module._rawffi.interp_rawffi import letter2tp
from pypy.module._rawffi.interp_array import W_ArrayInstance
from pypy.module._cppyy import helper, capi, ffitypes, lowlevelviews

# Converter objects are used to translate between RPython and C++. They are
# defined by the type name for which they provide conversion. Uses are for
# function arguments, as well as for read and write access to data members.
# All type conversions are fully checked.
#
# Converter instances are greated by get_converter(<type name>), see below.
# The name given should be qualified in case there is a specialised, exact
# match for the qualified type.


def get_rawobject(space, w_obj, can_be_None=True):
    from pypy.module._cppyy.interp_cppyy import W_CPPInstance
    cppinstance = space.interp_w(W_CPPInstance, w_obj, can_be_None=can_be_None)
    if cppinstance:
        rawobject = cppinstance.get_rawobject()
        assert lltype.typeOf(rawobject) == capi.C_OBJECT
        return rawobject
    return capi.C_NULL_OBJECT

def set_rawobject(space, w_obj, address):
    from pypy.module._cppyy.interp_cppyy import W_CPPInstance
    cppinstance = space.interp_w(W_CPPInstance, w_obj, can_be_None=True)
    if cppinstance:
        assert lltype.typeOf(cppinstance._rawobject) == capi.C_OBJECT
        cppinstance._rawobject = rffi.cast(capi.C_OBJECT, address)

def get_rawobject_nonnull(space, w_obj):
    from pypy.module._cppyy.interp_cppyy import W_CPPInstance
    cppinstance = space.interp_w(W_CPPInstance, w_obj, can_be_None=True)
    if cppinstance:
        cppinstance._nullcheck()
        rawobject = cppinstance.get_rawobject()
        assert lltype.typeOf(rawobject) == capi.C_OBJECT
        return rawobject
    return capi.C_NULL_OBJECT

def is_nullpointer_specialcase(space, w_obj):
    # 0 and nullptr may serve as "NULL"

    # integer 0
    try:
        return space.int_w(w_obj) == 0
    except Exception:
        pass
    # C++-style nullptr
    from pypy.module._cppyy import interp_cppyy
    return space.is_true(space.is_(w_obj, interp_cppyy.get_nullptr(space)))

def get_rawbuffer(space, w_obj):
    # raw buffer
    try:
        buf = space.getarg_w('s*', w_obj)
        return rffi.cast(rffi.VOIDP, buf.get_raw_address())
    except Exception:
        pass
    # array type
    try:
        if hasattr(space, "fake"):
            raise NotImplementedError
        arr = space.interp_w(W_ArrayInstance, w_obj, can_be_None=True)
        if arr:
            return rffi.cast(rffi.VOIDP, space.uint_w(arr.getbuffer(space)))
    except Exception:
        pass
    # pre-defined nullptr
    if is_nullpointer_specialcase(space, w_obj):
        return rffi.cast(rffi.VOIDP, 0)
    raise TypeError("not an addressable buffer")


class TypeConverter(object):
    _immutable_fields_ = ['cffi_name', 'name']

    cffi_name  = None
    name       = ""

    def __init__(self, space, extra):
        pass

    def _get_raw_address(self, space, w_obj, offset):
        rawobject = get_rawobject_nonnull(space, w_obj)
        assert lltype.typeOf(rawobject) == capi.C_OBJECT
        if rawobject:
            fieldptr = capi.direct_ptradd(rawobject, offset)
        else:
            fieldptr = rffi.cast(capi.C_OBJECT, offset)
        return fieldptr

    def _is_abstract(self, space):
        raise oefmt(space.w_TypeError,
                    "no converter available for '%s'", self.name)

    def cffi_type(self, space):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible

    def convert_argument(self, space, w_obj, address):
        self._is_abstract(space)

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible

    def default_argument_libffi(self, space, address):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible

    def from_memory(self, space, w_obj, offset):
        self._is_abstract(space)

    def to_memory(self, space, w_obj, w_value, offset):
        self._is_abstract(space)

    def finalize_call(self, space, w_obj):
        pass

    def free_argument(self, space, arg):
        pass


class ArrayTypeConverterMixin(object):
    _mixin_ = True
    _immutable_fields_ = ['size']

    def __init__(self, space, array_size):
        if array_size <= 0:
            self.size = sys.maxint
        else:
            self.size = array_size

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp

    def from_memory(self, space, w_obj, offset):
        # read access, so no copy needed
        address = self._get_raw_address(space, w_obj, offset)
        ipv = rffi.cast(rffi.UINTPTR_T, address)
        return lowlevelviews.W_LowLevelView(
            space, letter2tp(space, self.typecode), self.size, ipv)

    def to_memory(self, space, w_obj, w_value, offset):
        # copy the full array (uses byte copy for now)
        address = rffi.cast(rffi.CCHARP, self._get_raw_address(space, w_obj, offset))
        buf = space.getarg_w('s*', w_value)
        # TODO: report if too many items given?
        for i in range(min(self.size*self.typesize, buf.getlength())):
            address[i] = buf.getitem(i)

class PtrTypeConverterMixin(object):
    _mixin_ = True
    _immutable_fields_ = ['size']

    def __init__(self, space, array_size):
        self.size = sys.maxint

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp

    def convert_argument(self, space, w_obj, address):
        w_tc = space.findattr(w_obj, space.newtext('typecode'))
        if w_tc is not None and space.text_w(w_tc) != self.typecode:
            raise oefmt(space.w_TypeError,
                        "expected %s pointer type, but received %s",
                        self.typecode, space.text_w(w_tc))
        x = rffi.cast(rffi.VOIDPP, address)
        try:
            x[0] = rffi.cast(rffi.VOIDP, get_rawbuffer(space, w_obj))
        except TypeError:
            raise oefmt(space.w_TypeError,
                        "raw buffer interface not supported")
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = 'o'

    def from_memory(self, space, w_obj, offset):
        # read access, so no copy needed
        address = self._get_raw_address(space, w_obj, offset)
        ipv = rffi.cast(rffi.UINTPTR_T, rffi.cast(rffi.VOIDPP, address)[0])
        return lowlevelviews.W_LowLevelView(
            space, letter2tp(space, self.typecode), self.size, ipv)

    def to_memory(self, space, w_obj, w_value, offset):
        # copy only the pointer value
        rawobject = get_rawobject_nonnull(space, w_obj)
        byteptr = rffi.cast(rffi.VOIDPP, capi.direct_ptradd(rawobject, offset))
        buf = space.getarg_w('s*', w_value)
        try:
            byteptr[0] = rffi.cast(rffi.VOIDP, buf.get_raw_address())
        except ValueError:
            raise oefmt(space.w_TypeError,
                        "raw buffer interface not supported")

class ArrayPtrTypeConverterMixin(PtrTypeConverterMixin):
    _mixin_ = True

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidpp


class NumericTypeConverterMixin(object):
    _mixin_ = True

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        x = rffi.cast(self.c_ptrtype, address)
        x[0] = self._unwrap_object(space, w_obj)

    def default_argument_libffi(self, space, address):
        if not self.valid_default:
            from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
            raise FastCallNotPossible
        x = rffi.cast(self.c_ptrtype, address)
        x[0] = self.default

    def from_memory(self, space, w_obj, offset):
        address = self._get_raw_address(space, w_obj, offset)
        rffiptr = rffi.cast(self.c_ptrtype, address)
        return self._wrap_object(space, rffiptr[0])

    def to_memory(self, space, w_obj, w_value, offset):
        address = self._get_raw_address(space, w_obj, offset)
        rffiptr = rffi.cast(self.c_ptrtype, address)
        rffiptr[0] = self._unwrap_object(space, w_value)

class ConstRefNumericTypeConverterMixin(object):
    _mixin_ = True

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        obj = self._unwrap_object(space, w_obj)
        typed_buf = rffi.cast(self.c_ptrtype, scratch)
        typed_buf[0] = obj
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = scratch


class IntTypeConverterMixin(NumericTypeConverterMixin):
    _mixin_ = True

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(self.c_ptrtype, address)
        x[0] = self._unwrap_object(space, w_obj)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = self.typecode

class FloatTypeConverterMixin(NumericTypeConverterMixin):
    _mixin_ = True

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(self.c_ptrtype, address)
        x[0] = self._unwrap_object(space, w_obj)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = self.typecode


class VoidConverter(TypeConverter):
    _immutable_fields_ = ['name']

    def __init__(self, space, name):
        self.name = name

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_void

    def convert_argument(self, space, w_obj, address):
        self._is_abstract(space)


class BoolConverter(ffitypes.typeid(bool), TypeConverter):
    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(rffi.LONGP, address)
        x[0] = self._unwrap_object(space, w_obj)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = 'b'

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        x = rffi.cast(rffi.LONGP, address)
        x[0] = self._unwrap_object(space, w_obj)

    def from_memory(self, space, w_obj, offset):
        address = rffi.cast(rffi.CCHARP, self._get_raw_address(space, w_obj, offset))
        if address[0] == '\x01':
            return space.w_True
        return space.w_False

    def to_memory(self, space, w_obj, w_value, offset):
        address = rffi.cast(rffi.CCHARP, self._get_raw_address(space, w_obj, offset))
        arg = self._unwrap_object(space, w_value)
        if arg:
            address[0] = '\x01'
        else:
            address[0] = '\x00'


class CharTypeConverterMixin(object):
    _mixin_ = True

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(self.c_ptrtype, address)
        x[0] = self._unwrap_object(space, w_obj)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = 'b'

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        x = rffi.cast(self.c_ptrtype, address)
        x[0] = self._unwrap_object(space, w_obj)

    def from_memory(self, space, w_obj, offset):
        address = rffi.cast(self.c_ptrtype, self._get_raw_address(space, w_obj, offset))
        return self._wrap_object(space, address[0])

    def to_memory(self, space, w_obj, w_value, offset):
        address = rffi.cast(self.c_ptrtype, self._get_raw_address(space, w_obj, offset))
        address[0] = self._unwrap_object(space, w_value)


class FloatConverter(ffitypes.typeid(rffi.FLOAT), FloatTypeConverterMixin, TypeConverter):
    _immutable_fields_ = ['default', 'valid_default']

    def __init__(self, space, default):
        self.valid_default = False
        try:
            fval = float(rfloat.rstring_to_float(default))
            self.valid_default = True
        except Exception:
            fval = float(0.)
        self.default = rffi.cast(rffi.FLOAT, r_singlefloat(fval))

    def from_memory(self, space, w_obj, offset):
        address = self._get_raw_address(space, w_obj, offset)
        rffiptr = rffi.cast(self.c_ptrtype, address)
        return self._wrap_object(space, rffiptr[0])

class ConstFloatRefConverter(ConstRefNumericTypeConverterMixin, FloatConverter):
    _immutable_fields_ = ['typecode']
    typecode = 'f'

class DoubleConverter(ffitypes.typeid(rffi.DOUBLE), FloatTypeConverterMixin, TypeConverter):
    _immutable_fields_ = ['default', 'valid_default']

    def __init__(self, space, default):
        self.valid_default = False
        try:
            self.default = rffi.cast(self.c_type, rfloat.rstring_to_float(default))
            self.valid_default = True
        except Exception:
            self.default = rffi.cast(self.c_type, 0.)

class ConstDoubleRefConverter(ConstRefNumericTypeConverterMixin, DoubleConverter):
    _immutable_fields_ = ['typecode']
    typecode = 'd'

class LongDoubleConverter(TypeConverter):
    _immutable_fields_ = ['default', 'valid_default']
    typecode = 'g'

    def __init__(self, space, default):
        self.valid_default = False
        try:
            # use float() instead of cast with r_longfloat
            fval = rffi.cast(rffi.DOUBLE, rfloat.rstring_to_float(default))
            self.valid_default = True
        except Exception:
            fval = rffi.cast(rffi.DOUBLE, 0.)
        #self.default = r_longfloat(fval)
        self.default = fval

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(rffi.VOIDP, address)
        capi.c_double2longdouble(space, space.float_w(w_obj), x)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = self.typecode

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        x = rffi.cast(rffi.VOIDP, address)
        capi.c_double2longdouble(space, space.float_w(w_obj), x)

    def default_argument_libffi(self, space, address):
        if not self.valid_default:
            from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
            raise FastCallNotPossible
        x = rffi.cast(rffi.VOIDP, address)
        capi.c_double2longdouble(space, self.default, x)

    def from_memory(self, space, w_obj, offset):
        address = self._get_raw_address(space, w_obj, offset)
        rffiptr = rffi.cast(rffi.VOIDP, address)
        return space.newfloat(capi.c_longdouble2double(space, rffiptr))

    def to_memory(self, space, w_obj, w_value, offset):
        address = self._get_raw_address(space, w_obj, offset)
        rffiptr = rffi.cast(rffi.VOIDP, address)
        capi.c_double2longdouble(space, space.float_w(w_value), rffiptr)

class ConstLongDoubleRefConverter(ConstRefNumericTypeConverterMixin, LongDoubleConverter):
    _immutable_fields_ = ['typecode']
    typecode = 'g'

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        capi.c_double2longdouble(space, space.float_w(w_obj), rffi.cast(rffi.VOIDP, scratch))
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = scratch


class CStringConverter(TypeConverter):
    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(rffi.VOIDPP, address)
        arg = space.text_w(w_obj)
        x[0] = rffi.cast(rffi.VOIDP, rffi.str2charp(arg))
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = 'p'

    def from_memory(self, space, w_obj, offset):
        address = self._get_raw_address(space, w_obj, offset)
        charpptr = rffi.cast(rffi.CCHARPP, address)
        return space.newtext(rffi.charp2str(charpptr[0]))

    def free_argument(self, space, arg):
        lltype.free(rffi.cast(rffi.CCHARPP, arg)[0], flavor='raw')

class CStringConverterWithSize(CStringConverter):
    _immutable_fields_ = ['size']

    def __init__(self, space, extra):
        self.size = extra

    def from_memory(self, space, w_obj, offset):
        address = self._get_raw_address(space, w_obj, offset)
        charpptr = rffi.cast(rffi.CCHARP, address)
        if 0 <= self.size and self.size != 2**31-1:   # cling's code for "unknown" (?)
            strsize = self.size
            if charpptr[self.size-1] == '\0':
                strsize = self.size-1  # rffi will add \0 back
            return space.newtext(rffi.charpsize2str(charpptr, strsize))
        return space.newtext(rffi.charp2str(charpptr))


class VoidPtrConverter(TypeConverter):
    def _unwrap_object(self, space, w_obj):
        try:
            obj = get_rawbuffer(space, w_obj)
        except TypeError:
            obj = rffi.cast(rffi.VOIDP, get_rawobject(space, w_obj, False))
        return obj

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = self._unwrap_object(space, w_obj)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = 'o'

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = self._unwrap_object(space, w_obj)

    def from_memory(self, space, w_obj, offset):
        # returned as a long value for the address (INTPTR_T is not proper
        # per se, but rffi does not come with a PTRDIFF_T)
        address = self._get_raw_address(space, w_obj, offset)
        ipv = rffi.cast(rffi.UINTPTR_T, rffi.cast(rffi.VOIDPP, address)[0])
        if ipv == rffi.cast(rffi.UINTPTR_T, 0):
            from pypy.module._cppyy import interp_cppyy
            return interp_cppyy.get_nullptr(space)
        shape = letter2tp(space, 'P')
        return lowlevelviews.W_LowLevelView(space, shape, sys.maxint/shape.size, ipv)

    def to_memory(self, space, w_obj, w_value, offset):
        address = rffi.cast(rffi.VOIDPP, self._get_raw_address(space, w_obj, offset))
        if is_nullpointer_specialcase(space, w_value):
            address[0] = rffi.cast(rffi.VOIDP, 0)
        else:
            address[0] = rffi.cast(rffi.VOIDP, self._unwrap_object(space, w_value))

class VoidPtrPtrConverter(TypeConverter):
    typecode = 'p'

    def __init__(self, space, extra):
        self.ref_buffer = lltype.nullptr(rffi.VOIDPP.TO)

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(rffi.VOIDPP, address)
        try:
            x[0] = get_rawbuffer(space, w_obj)
        except TypeError:
            ptr = rffi.cast(rffi.VOIDP, get_rawobject(space, w_obj))
            self.ref_buffer = lltype.malloc(rffi.VOIDPP.TO, 1, flavor='raw')
            self.ref_buffer[0] = ptr
            x[0] = self.ref_buffer
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = self.typecode

    def finalize_call(self, space, w_obj):
        if self.ref_buffer:
            set_rawobject(space, w_obj, self.ref_buffer[0])

    def free_argument(self, space, arg):
        if self.ref_buffer:
            lltype.free(self.ref_buffer, flavor='raw')
            self.ref_buffer = lltype.nullptr(rffi.VOIDPP.TO)

class VoidPtrRefConverter(VoidPtrPtrConverter):
    _immutable_fields_ = ['typecode']
    typecode   = 'V'

class InstanceRefConverter(TypeConverter):
    _immutable_fields_ = ['typecode', 'clsdecl']
    typecode = 'V'

    def __init__(self, space, clsdecl):
        from pypy.module._cppyy.interp_cppyy import W_CPPClassDecl
        assert isinstance(clsdecl, W_CPPClassDecl)
        self.clsdecl = clsdecl

    def _unwrap_object(self, space, w_obj):
        from pypy.module._cppyy.interp_cppyy import W_CPPInstance
        if isinstance(w_obj, W_CPPInstance):
            from pypy.module._cppyy.interp_cppyy import INSTANCE_FLAGS_IS_RVALUE
            if w_obj.rt_flags & INSTANCE_FLAGS_IS_RVALUE:
                # reject moves as all are explicit
                raise ValueError("lvalue expected")
            if capi.c_is_subtype(space, w_obj.clsdecl, self.clsdecl):
                rawobject = w_obj.get_rawobject()
                offset = capi.c_base_offset(space, w_obj.clsdecl, self.clsdecl, rawobject, 1)
                obj_address = capi.direct_ptradd(rawobject, offset)
                return rffi.cast(capi.C_OBJECT, obj_address)
        raise oefmt(space.w_TypeError,
                    "cannot pass %T instance as %s", w_obj, self.clsdecl.name)

    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = rffi.cast(rffi.VOIDP, self._unwrap_object(space, w_obj))
        address = rffi.cast(capi.C_OBJECT, address)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = self.typecode

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = rffi.cast(rffi.VOIDP, self._unwrap_object(space, w_obj))

class InstanceMoveConverter(InstanceRefConverter):
    def _unwrap_object(self, space, w_obj):
        # moving is same as by-ref, but have to check that move is allowed
        from pypy.module._cppyy.interp_cppyy import W_CPPInstance, INSTANCE_FLAGS_IS_RVALUE
        obj = space.interp_w(W_CPPInstance, w_obj)
        if obj:
            if obj.rt_flags & INSTANCE_FLAGS_IS_RVALUE:
                obj.rt_flags &= ~INSTANCE_FLAGS_IS_RVALUE
                try:
                    return InstanceRefConverter._unwrap_object(self, space, w_obj)
                except Exception:
                    # TODO: if the method fails on some other converter, then the next
                    # overload can not be an rvalue anymore
                    obj.rt_flags |= INSTANCE_FLAGS_IS_RVALUE
                    raise
        raise oefmt(space.w_ValueError, "object is not an rvalue")


class InstanceConverter(InstanceRefConverter):

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible       # TODO: by-value is a jit_libffi special case

    def from_memory(self, space, w_obj, offset):
        address = rffi.cast(capi.C_OBJECT, self._get_raw_address(space, w_obj, offset))
        from pypy.module._cppyy import interp_cppyy
        return interp_cppyy.wrap_cppinstance(space, address, self.clsdecl, do_cast=False)

    def to_memory(self, space, w_obj, w_value, offset):
        address = rffi.cast(capi.C_OBJECT, self._get_raw_address(space, w_obj, offset))
        assign = self.clsdecl.get_overload("__assign__")
        from pypy.module._cppyy import interp_cppyy
        assign.call_impl(address, [w_value])

class InstancePtrConverter(InstanceRefConverter):
    typecode = 'o'

    def _unwrap_object(self, space, w_obj):
        try:
            return InstanceRefConverter._unwrap_object(self, space, w_obj)
        except OperationError as e:
            # if not instance, allow certain special cases
            if is_nullpointer_specialcase(space, w_obj):
                return capi.C_NULL_OBJECT
            raise e

    def from_memory(self, space, w_obj, offset):
        address = rffi.cast(capi.C_OBJECT, self._get_raw_address(space, w_obj, offset))
        from pypy.module._cppyy import interp_cppyy
        return interp_cppyy.wrap_cppinstance(
            space, address, self.clsdecl, do_cast=False, is_ref=True)

    def to_memory(self, space, w_obj, w_value, offset):
        from pypy.module._cppyy.interp_cppyy import W_CPPInstance
        cppinstance = space.interp_w(W_CPPInstance, w_value, can_be_None=True)
        if cppinstance:
            # get the object address from value, correct for hierarchy offset
            rawobject = cppinstance.get_rawobject()
            base_offset = capi.c_base_offset(space, cppinstance.clsdecl, self.clsdecl, rawobject, 1)
            rawptr = capi.direct_ptradd(rawobject, base_offset)

            # get the data member address and write the pointer in
            address = rffi.cast(rffi.VOIDPP, self._get_raw_address(space, w_obj, offset))
            address[0] = rffi.cast(rffi.VOIDP, rawptr)

            # register the value object for potential recycling
            from pypy.module._cppyy.interp_cppyy import memory_regulator
            memory_regulator.register(cppinstance)
        else:
            raise oefmt(space.w_TypeError,
                        "cannot pass %T instance as %s", w_value, self.clsdecl.name)

class InstancePtrPtrConverter(InstancePtrConverter):
    typecode = 'o'

    def __init__(self, space, extra):
        InstancePtrConverter.__init__(self, space, extra)
        self.ref_buffer = lltype.nullptr(rffi.VOIDPP.TO)

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(rffi.VOIDPP, address)
        ptr = rffi.cast(rffi.VOIDP, self._unwrap_object(space, w_obj))
        self.ref_buffer = lltype.malloc(rffi.VOIDPP.TO, 1, flavor='raw')
        self.ref_buffer[0] = ptr
        x[0] = self.ref_buffer
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = self.typecode

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        # TODO: finalize_call not yet called for fast call (see interp_cppyy.py)
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible

    def from_memory(self, space, w_obj, offset):
        self._is_abstract(space)

    def to_memory(self, space, w_obj, w_value, offset):
        self._is_abstract(space)

    def finalize_call(self, space, w_obj):
        if self.ref_buffer:
            set_rawobject(space, w_obj, self.ref_buffer[0])

    def free_argument(self, space, arg):
        if self.ref_buffer:
            lltype.free(self.ref_buffer, flavor='raw')
            self.ref_buffer = lltype.nullptr(rffi.VOIDPP.TO)

class InstanceArrayConverter(InstancePtrConverter):
    _immutable_fields_ = ['size']

    def __init__(self, space, clsdecl, array_size, dimensions):
        InstancePtrConverter.__init__(self, space, clsdecl)
        if array_size <= 0 or array_size == 2**31-1:   # cling's code for "unknown" (?)
            self.size = sys.maxint
        else:
            self.size = array_size
        # peel one off as that should be the same as the array size
        self.dimensions = dimensions[1:]

    def from_memory(self, space, w_obj, offset):
        address = rffi.cast(capi.C_OBJECT, self._get_raw_address(space, w_obj, offset))
        return lowlevelviews.W_ArrayOfInstances(space, self.clsdecl, address, self.size, self.dimensions)

    def to_memory(self, space, w_obj, w_value, offset):
        self._is_abstract(space)


class STLStringConverter(InstanceConverter):
    def __init__(self, space, extra):
        from pypy.module._cppyy import interp_cppyy
        cppclass = interp_cppyy.scope_byname(space, capi.std_string_name)
        InstanceConverter.__init__(self, space, cppclass)

    def _unwrap_object(self, space, w_obj):
        from pypy.module._cppyy.interp_cppyy import W_CPPInstance
        if isinstance(w_obj, W_CPPInstance):
            arg = InstanceConverter._unwrap_object(self, space, w_obj)
            return capi.c_stdstring2stdstring(space, arg)
        return capi.c_charp2stdstring(space, space.text_w(w_obj), space.len_w(w_obj))

    def free_argument(self, space, arg):
        capi.c_destruct(space, self.clsdecl, rffi.cast(capi.C_OBJECT, rffi.cast(rffi.VOIDPP, arg)[0]))

class STLStringMoveConverter(STLStringConverter):
    def _unwrap_object(self, space, w_obj):
        # moving is same as by-ref, but have to check that move is allowed
        moveit_reason = 3
        from pypy.module._cppyy.interp_cppyy import W_CPPInstance, INSTANCE_FLAGS_IS_RVALUE
        try:
            obj = space.interp_w(W_CPPInstance, w_obj)
            if obj and obj.rt_flags & INSTANCE_FLAGS_IS_RVALUE:
                obj.rt_flags &= ~INSTANCE_FLAGS_IS_RVALUE
                moveit_reason = 1
            else:
                moveit_reason = 0
        except:
            pass

        if moveit_reason:
            try:
                return STLStringConverter._unwrap_object(self, space, w_obj)
            except Exception:
                 if moveit_reason == 1:
                    # TODO: if the method fails on some other converter, then the next
                    # overload can not be an rvalue anymore
                    obj = space.interp_w(W_CPPInstance, w_obj)
                    obj.rt_flags |= INSTANCE_FLAGS_IS_RVALUE
                    raise

        raise oefmt(space.w_ValueError, "object is not an rvalue")

class STLStringRefConverter(InstancePtrConverter):
    _immutable_fields_ = ['cppclass', 'typecode']
    typecode    = 'V'

    def __init__(self, space, extra):
        from pypy.module._cppyy import interp_cppyy
        cppclass = interp_cppyy.scope_byname(space, capi.std_string_name)
        InstancePtrConverter.__init__(self, space, cppclass)


class PyObjectConverter(TypeConverter):
    def cffi_type(self, space):
        state = space.fromcache(ffitypes.State)
        return state.c_voidp

    def convert_argument(self, space, w_obj, address):
        if hasattr(space, "fake"):
            raise NotImplementedError
        space.getbuiltinmodule("cpyext")
        from pypy.module.cpyext.pyobject import make_ref
        ref = make_ref(space, w_obj)
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = rffi.cast(rffi.VOIDP, ref)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = 'a'

    def convert_argument_libffi(self, space, w_obj, address, scratch):
        # TODO: free_argument not yet called for fast call (see interp_cppyy.py)
        from pypy.module._cppyy.interp_cppyy import FastCallNotPossible
        raise FastCallNotPossible

        # proposed implementation:
        """if hasattr(space, "fake"):
            raise NotImplementedError
        space.getbuiltinmodule("cpyext")
        from pypy.module.cpyext.pyobject import make_ref
        ref = make_ref(space, w_obj)
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = rffi.cast(rffi.VOIDP, ref)"""

    def free_argument(self, space, arg):
        if hasattr(space, "fake"):
            raise NotImplementedError
        space.getbuiltinmodule("cpyext")
        from pypy.module.cpyext.pyobject import decref, PyObject
        decref(space, rffi.cast(PyObject, rffi.cast(rffi.VOIDPP, arg)[0]))


class FunctionPointerConverter(TypeConverter):
    _immutable_fields_ = ['signature']

    def __init__(self, space, signature):
        self.signature = signature

    def convert_argument(self, space, w_obj, address):
        # TODO: atm, does not actually get an overload, but a staticmethod
        from pypy.module._cppyy.interp_cppyy import W_CPPOverload
        cppol = space.interp_w(W_CPPOverload, w_obj)

        # find the function with matching signature
        for i in range(len(cppol.functions)):
            m = cppol.functions[i]
            if m.signature(False) == self.signature:
                x = rffi.cast(rffi.VOIDPP, address)
                x[0] = rffi.cast(rffi.VOIDP, capi.c_function_address(space, m.cppmethod))
                address = rffi.cast(capi.C_OBJECT, address)
                ba = rffi.cast(rffi.CCHARP, address)
                ba[capi.c_function_arg_typeoffset(space)] = 'p'
                return

        # lookup failed
        raise oefmt(space.w_TypeError,
                    "no overload found matching %s", self.signature)


class SmartPtrConverter(TypeConverter):
    _immutable_fields = ['typecode', 'smartdecl', 'rawdecl', 'deref']
    typecode    = 'V'

    def __init__(self, space, smartdecl, raw, deref):
        from pypy.module._cppyy.interp_cppyy import W_CPPClassDecl, get_pythonized_cppclass
        self.smartdecl = smartdecl
        w_raw   = get_pythonized_cppclass(space, raw)
        self.rawdecl   = space.interp_w(W_CPPClassDecl,
            space.findattr(w_raw, space.newtext("__cppdecl__")))
        self.deref     = deref

    def _unwrap_object(self, space, w_obj):
        from pypy.module._cppyy.interp_cppyy import W_CPPInstance
        if isinstance(w_obj, W_CPPInstance):
            # w_obj could carry a 'hidden' smart ptr or be one, cover both cases
            have_match = False
            if w_obj.smartdecl and capi.c_is_subtype(space, w_obj.smartdecl, self.smartdecl):
                # hidden case, do not derefence when getting obj address
                have_match = True
                rawobject = w_obj._rawobject      # TODO: this direct access if fugly
                offset = capi.c_base_offset(space, w_obj.smartdecl, self.smartdecl, rawobject, 1)
            elif capi.c_is_subtype(space, w_obj.clsdecl, self.smartdecl):
                # exposed smart pointer
                have_match = True
                rawobject = w_obj.get_rawobject()
                offset = capi.c_base_offset(space, w_obj.clsdecl, self.smartdecl, rawobject, 1)
            if have_match:
                obj_address = capi.direct_ptradd(rawobject, offset)
                return rffi.cast(capi.C_OBJECT, obj_address)

        raise oefmt(space.w_TypeError,
                    "cannot pass %T instance as %s", w_obj, self.rawdecl.name)

    def convert_argument(self, space, w_obj, address):
        x = rffi.cast(rffi.VOIDPP, address)
        x[0] = rffi.cast(rffi.VOIDP, self._unwrap_object(space, w_obj))
        address = rffi.cast(capi.C_OBJECT, address)
        ba = rffi.cast(rffi.CCHARP, address)
        ba[capi.c_function_arg_typeoffset(space)] = self.typecode

    def from_memory(self, space, w_obj, offset):
        address = rffi.cast(capi.C_OBJECT, self._get_raw_address(space, w_obj, offset))
        from pypy.module._cppyy import interp_cppyy
        return interp_cppyy.wrap_cppinstance(space, address,
            self.rawdecl, smartdecl=self.smartdecl, deref=self.deref, do_cast=False)

class SmartPtrPtrConverter(SmartPtrConverter):
    typecode    = 'o'

    def from_memory(self, space, w_obj, offset):
        self._is_abstract(space)

    def to_memory(self, space, w_obj, w_value, offset):
        self._is_abstract(space)


class SmartPtrRefConverter(SmartPtrPtrConverter):
    typecode    = 'V'


class MacroConverter(TypeConverter):
    def from_memory(self, space, w_obj, offset):
        # TODO: get the actual type info from somewhere ...
        address = self._get_raw_address(space, w_obj, offset)
        longptr = rffi.cast(rffi.LONGP, address)
        return space.newlong(longptr[0])


_converters = {}         # builtin and custom types
_a_converters = {}       # array and ptr versions of above
def get_converter(space, _name, default):
    # The matching of the name to a converter should follow:
    #   1) full, exact match
    #       1a) const-removed match
    #   2) match of decorated, unqualified type
    #   3) generalized cases (covers basically all user classes)
    #       3a) smart pointers
    #   4) void* or void converter (which fails on use)

    # original, exact match
    try:
        return _converters[_name](space, default)
    except KeyError:
        pass

    # resolved, exact match
    name = capi.c_resolve_name(space, _name)
    try:
        return _converters[name](space, default)
    except KeyError:
        pass

    # const-removed match
    try:
        return _converters[helper.remove_const(name)](space, default)
    except KeyError:
        pass

    # match of decorated, unqualified type
    cpd = helper.compound(name)
    clean_name = capi.c_resolve_name(space, helper.clean_type(name))
    try:
        return _converters[clean_name+cpd](space, default)
    except KeyError:
        pass

    # arrays (array_size may be negative, meaning: no size or no size found)
    array_size = -1
    if cpd == "[]":
        array_size = helper.array_size(_name)    # uses original arg
    elif cpd == '*' and ':' in default:
        # this happens for multi-dimensional arrays: those are described as pointers
        cpd = "[]"
        splitpos = default.find(':')
        if 0 < splitpos:     # always true, but needed for annotator
            array_size = int(default[:splitpos])

    try:
        # TODO: using clean_name here drops const (e.g. const char[] will
        # never be seen this way)
        return _a_converters[clean_name+cpd](space, array_size)
    except KeyError:
        pass

    # generalized cases (covers basically all user classes)
    from pypy.module._cppyy import interp_cppyy
    scope_decl = interp_cppyy.scope_byname(space, clean_name)
    if scope_decl:
        from pypy.module._cppyy.interp_cppyy import W_CPPClassDecl
        clsdecl = space.interp_w(W_CPPClassDecl, scope_decl, can_be_None=False)

        # check smart pointer type
        check_smart = capi.c_smartptr_info(space, clean_name)
        if check_smart[0]:
            if cpd == '':
                return SmartPtrConverter(space, clsdecl, check_smart[1], check_smart[2])
            elif cpd == '*':
                return SmartPtrPtrConverter(space, clsdecl, check_smart[1], check_smart[2])
            elif cpd == '&':
                return SmartPtrRefConverter(space, clsdecl, check_smart[1], check_smart[2])
            # fall through: can still return smart pointer in non-smart way

        # type check for the benefit of the annotator
        if cpd == "*":
            return InstancePtrConverter(space, clsdecl)
        elif cpd == "&":
            return InstanceRefConverter(space, clsdecl)
        elif cpd == "&&":
            return InstanceMoveConverter(space, clsdecl)
        elif cpd in ["**", "*[]", "&*"]:
            return InstancePtrPtrConverter(space, clsdecl)
        elif cpd == "[]" and array_size > 0:
            # default encodes the dimensions
            dims = default.split(':')
            return InstanceArrayConverter(space, clsdecl, array_size, dims)
        elif cpd == "":
            return InstanceConverter(space, clsdecl)

    if "(anonymous)" in name:
        # special case: enum w/o a type name
        return _converters["internal_enum_type_t"+cpd](space, default)
    elif "(*)" in name or "::*)" in name:
        # function pointer
        pos = name.find("*)")
        if pos > 0:
            return FunctionPointerConverter(space, name[pos+2:])

    # void*|**|*& or void converter (which fails on use)
    if 0 <= cpd.find('*'):
        return VoidPtrConverter(space, default)  # "user knows best"

    # return a void converter here, so that the class can be build even
    # when some types are unknown
    return VoidConverter(space, name)            # fails on use


_converters["bool"]                     = BoolConverter
_converters["float"]                    = FloatConverter
_converters["const float&"]             = ConstFloatRefConverter
_converters["double"]                   = DoubleConverter
_converters["const double&"]            = ConstDoubleRefConverter
_converters["long double"]              = LongDoubleConverter
_converters["const long double&"]       = ConstLongDoubleRefConverter
_converters["const char*"]              = CStringConverter
_converters["void*"]                    = VoidPtrConverter
_converters["void**"]                   = VoidPtrPtrConverter
_converters["void*&"]                   = VoidPtrRefConverter

# special cases (note: 'std::string' aliases added below)
_converters["std::basic_string<char>"]           = STLStringConverter
_converters["const std::basic_string<char>&"]    = STLStringConverter     # TODO: shouldn't copy
_converters["std::basic_string<char>&"]          = STLStringRefConverter
_converters["std::basic_string<char>&&"]         = STLStringMoveConverter

_converters["PyObject*"]                         = PyObjectConverter

_converters["#define"]                           = MacroConverter

# add basic (builtin) converters
def _build_basic_converters():
    "NOT_RPYTHON"
    # basic char types
    type_info = {
        (rffi.CHAR,               "char"),
        (rffi.SIGNEDCHAR,         "signed char"),
        (rffi.UCHAR,              "unsigned char"),
        (lltype.UniChar,          "wchar_t"),
        (ffitypes.CHAR16_T,       "char16_t"),
        (ffitypes.CHAR32_T,       "char32_t"),
    }

    for c_type, name in type_info:
        class BasicConverter(ffitypes.typeid(c_type), CharTypeConverterMixin, TypeConverter):
            _immutable_ = True
            def __init__(self, space, default):
                self.valid_default = False
                try:
                    self.default = rffi.cast(self.c_type, capi.c_strtoull(space, default))
                    self.valid_default = True
                except Exception:
                    self.default = rffi.cast(self.c_type, 0)
        class ConstRefConverter(ConstRefNumericTypeConverterMixin, BasicConverter):
            _immutable_ = True
        _converters[name] = BasicConverter
        _converters["const "+name+"&"] = ConstRefConverter

    # signed types use strtoll in setting of default in __init__, unsigned uses strtoull
    type_info = (
        (ffitypes.INT8_T,    ("int8_t",),                                                     'b', capi.c_strtoll),
        (ffitypes.UINT8_T,   ("uint8_t", "std::byte", "byte"),                                'B', capi.c_strtoull),
        (rffi.SHORT,         ("short", "short int"),                                          'h', capi.c_strtoll),
        (rffi.USHORT,        ("unsigned short", "unsigned short int"),                        'H', capi.c_strtoull),
        (rffi.INT,           ("int", "internal_enum_type_t"),                                 'i', capi.c_strtoll),
        (rffi.UINT,          ("unsigned", "unsigned int"),                                    'I', capi.c_strtoull),
        (rffi.LONG,          ("long", "long int"),                                            'l', capi.c_strtoll),
        (rffi.ULONG,         ("unsigned long", "unsigned long int"),                          'L', capi.c_strtoull),
        (rffi.LONGLONG,      ("long long", "long long int", "Long64_t"),                      'q', capi.c_strtoll),
        (rffi.ULONGLONG,     ("unsigned long long", "unsigned long long int", "ULong64_t"),   'Q', capi.c_strtoull),
    )

    # constref converters exist only b/c the stubs take constref by value, whereas
    # libffi takes them by pointer (hence it needs the fast-path in testing); note
    # that this is list is not complete, as some classes are specialized

    for c_type, names, c_tc, dfc in type_info:
        class BasicConverter(ffitypes.typeid(c_type), IntTypeConverterMixin, TypeConverter):
            _immutable_ = True
            typecode = c_tc
            def __init__(self, space, default):
                self.valid_default = False
                try:
                    self.default = rffi.cast(self.c_type, dfc(space, default))
                    self.valid_default = True
                except Exception:
                    self.default = rffi.cast(self.c_type, 0)
        class ConstRefConverter(ConstRefNumericTypeConverterMixin, BasicConverter):
            _immutable_ = True
        for name in names:
            _converters[name] = BasicConverter
            _converters["const "+name+"&"] = ConstRefConverter

_build_basic_converters()

# create the array and pointer converters; all real work is in the mixins
def _build_array_converters():
    "NOT_RPYTHON"
    array_info = (
        ('b', rffi.sizeof(rffi.SIGNEDCHAR), ("bool",)),    # is debatable, but works ...
        ('b', rffi.sizeof(rffi.SIGNEDCHAR), ("signed char",)),
        ('B', rffi.sizeof(rffi.UCHAR),      ("unsigned char", "std::byte", "byte")),
        ('h', rffi.sizeof(rffi.SHORT),      ("short int", "short")),
        ('H', rffi.sizeof(rffi.USHORT),     ("unsigned short int", "unsigned short")),
        ('i', rffi.sizeof(rffi.INT),        ("int",)),
        ('I', rffi.sizeof(rffi.UINT),       ("unsigned int", "unsigned")),
        ('l', rffi.sizeof(rffi.LONG),       ("long int", "long")),
        ('L', rffi.sizeof(rffi.ULONG),      ("unsigned long int", "unsigned long")),
        ('q', rffi.sizeof(rffi.LONGLONG),   ("long long", "long long int", "Long64_t")),
        ('Q', rffi.sizeof(rffi.ULONGLONG),  ("unsigned long long", "unsigned long long int", "ULong64_t")),
        ('f', rffi.sizeof(rffi.FLOAT),      ("float",)),
        ('d', rffi.sizeof(rffi.DOUBLE),     ("double",)),
#        ('g', rffi.sizeof(rffi.LONGDOUBLE), ("long double",)),
    )

    for tcode, tsize, names in array_info:
        class ArrayConverter(ArrayTypeConverterMixin, TypeConverter):
            _immutable_fields_ = ['typecode', 'typesize']
            typecode = tcode
            typesize = tsize
        class PtrConverter(PtrTypeConverterMixin, TypeConverter):
            _immutable_fields_ = ['typecode', 'typesize']
            typecode = tcode
            typesize = tsize
        class ArrayPtrConverter(ArrayPtrTypeConverterMixin, TypeConverter):
            _immutable_fields_ = ['typecode', 'typesize']
            typecode = tcode
            typesize = tsize
        for name in names:
            _a_converters[name+'[]'] = ArrayConverter
            _a_converters[name+'*']  = PtrConverter
            _a_converters[name+'**'] = ArrayPtrConverter

    # special case, const char* w/ size and w/o '\0'
    _a_converters["const char[]"] = CStringConverterWithSize
    _a_converters["char[]"]       = _a_converters["const char[]"]     # debatable

_build_array_converters()

# add another set of aliased names
def _add_aliased_converters():
    "NOT_RPYTHON"
    aliases = (
        ("const char*",                     "char*"),

        ("std::basic_string<char>",         "std::string"),
        ("const std::basic_string<char>&",  "const std::string&"),
        ("std::basic_string<char>&",        "std::string&"),
        ("std::basic_string<char>&&",       "std::string&&"),

        ("const internal_enum_type_t&",     "internal_enum_type_t&"),

        ("PyObject*",                       "_object*"),
    )

    for c_type, alias in aliases:
        _converters[alias] = _converters[c_type]
_add_aliased_converters()
