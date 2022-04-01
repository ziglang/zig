from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.typedef import TypeDef, GetSetProperty, interp_attrproperty
from pypy.interpreter.argument import Arguments
from rpython.rlib import jit, rgc
from rpython.rlib.rarithmetic import LONG_BIT, maxint, _get_bitsize
from rpython.tool.sourcetools import func_with_new_name
from rpython.rlib.rawstorage import (
    raw_storage_setitem, free_raw_storage, alloc_raw_storage)
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.objectmodel import keepalive_until_here, specialize

from pypy.module.micronumpy import loop, constants as NPY
from pypy.module.micronumpy.descriptor import (
    get_dtype_cache, decode_w_dtype, num2dtype)
from pypy.module.micronumpy.base import convert_to_array, W_NDimArray
from pypy.module.micronumpy.ctors import numpify
from pypy.module.micronumpy.nditer import W_NDIter, coalesce_iter
from pypy.module.micronumpy.strides import shape_agreement
from pypy.module.micronumpy.support import (_parse_signature, product,
        get_storage_as_int, is_rhs_priority_higher)
from .converters import out_converter
from .casting import (
    can_cast_type, can_cast_array, can_cast_to,
    find_result_type, promote_types)
from .boxes import W_GenericBox, W_ObjectBox

REDUCE, ACCUMULATE, REDUCEAT = range(3)
_reduce_type = ["reduce", "acccumulate", "reduceat"]

def done_if_true(dtype, val):
    return dtype.itemtype.bool(val)


def done_if_false(dtype, val):
    return not dtype.itemtype.bool(val)


def _find_array_wrap(*args, **kwds):
    '''determine an appropriate __array_wrap__ function to call for the outputs.
      If an output argument is provided, then it is wrapped
      with its own __array_wrap__ not with the one determined by
      the input arguments.

      if the provided output argument is already an array,
      the wrapping function is None (which means no wrapping will
      be done --- not even PyArray_Return).

      A NULL is placed in output_wrap for outputs that
      should just have PyArray_Return called.
    '''
    raise NotImplementedError()


def array_priority(space, w_lhs, w_rhs):
    # handle array_priority
    # w_lhs and w_rhs could be of different ndarray subtypes. Numpy does:
    # 1. if __array_priorities__ are equal and one is an ndarray and the
    #        other is a subtype,  return a subtype
    # 2. elif rhs.__array_priority__ is higher, return the type of rhs

    w_ndarray = space.gettypefor(W_NDimArray)
    lhs_type = space.type(w_lhs)
    rhs_type = space.type(w_rhs)
    lhs_for_subtype = w_lhs
    rhs_for_subtype = w_rhs
    #it may be something like a FlatIter, which is not an ndarray
    if not space.issubtype_w(lhs_type, w_ndarray):
        lhs_type = space.type(w_lhs.base)
        lhs_for_subtype = w_lhs.base
    if not space.issubtype_w(rhs_type, w_ndarray):
        rhs_type = space.type(w_rhs.base)
        rhs_for_subtype = w_rhs.base

    w_highpriority = w_lhs
    highpriority_subtype = lhs_for_subtype
    if space.is_w(lhs_type, w_ndarray) and not space.is_w(rhs_type, w_ndarray):
        highpriority_subtype = rhs_for_subtype
        w_highpriority = w_rhs
    if is_rhs_priority_higher(space, w_lhs, w_rhs):
        highpriority_subtype = rhs_for_subtype
        w_highpriority = w_rhs
    return w_highpriority, highpriority_subtype


class W_Ufunc(W_Root):
    _immutable_fields_ = [
        "name", "promote_to_largest", "promote_to_float", "promote_bools", "nin",
        "identity", "int_only", "allow_bool", "allow_complex",
        "complex_to_float", "nargs", "nout", "signature"
    ]
    w_doc = None

    def __init__(self, name, promote_to_largest, promote_to_float, promote_bools,
                 identity, int_only, allow_bool, allow_complex, complex_to_float):
        self.name = name
        self.promote_to_largest = promote_to_largest
        self.promote_to_float = promote_to_float
        self.promote_bools = promote_bools
        self.identity = identity
        self.int_only = int_only
        self.allow_bool = allow_bool
        self.allow_complex = allow_complex
        self.complex_to_float = complex_to_float

    def descr_get_name(self, space):
        return space.newtext(self.name)

    def descr_repr(self, space):
        return space.newtext("<ufunc '%s'>" % self.name)

    def get_doc(self, space):
        # Note: allows any object to be set as docstring, because why not?
        if self.w_doc is None:
            return space.w_None
        return self.w_doc

    def set_doc(self, space, w_doc):
        self.w_doc = w_doc

    def descr_get_identity(self, space):
        if self.identity is None:
            return space.w_None
        return self.identity

    def descr_call(self, space, __args__):
        args_w, kwds_w = __args__.unpack()
        # sig, extobj are used in generic ufuncs
        w_subok, w_out, sig, w_casting, extobj = self.parse_kwargs(space, kwds_w)
        out = out_converter(space, w_out)
        if (w_subok is not None and space.is_true(w_subok)):
            raise oefmt(space.w_NotImplementedError, "parameter subok unsupported")
        if kwds_w:
            # numpy compatible, raise with only the first of maybe many keys
            kw  = kwds_w.keys()[0]
            raise oefmt(space.w_TypeError,
                "'%s' is an invalid keyword to ufunc '%s'", kw, self.name)
        if len(args_w) < self.nin:
            raise oefmt(space.w_ValueError, "invalid number of arguments"
                ", expected %d got %d", len(args_w), self.nin)
        elif (len(args_w) > self.nin and out is not None) or \
             (len(args_w) > self.nin + 1):
            raise oefmt(space.w_TypeError, "invalid number of arguments")
        # Override the default out value, if it has been provided in w_wargs
        if len(args_w) > self.nin:
            if out:
                raise oefmt(space.w_ValueError, "cannot specify 'out' as both "
                    "a positional and keyword argument")
            out = args_w[-1]
        else:
            args_w = args_w + [out]
        if w_casting is None:
            casting = 'unsafe'
        else:
            casting = space.text_w(w_casting)
        retval = self.call(space, args_w, sig, casting, extobj)
        keepalive_until_here(args_w)
        return retval

    def descr_accumulate(self, space, w_obj, w_axis=None, w_dtype=None, w_out=None):
        if w_axis is None:
            w_axis = space.newint(0)
        out = out_converter(space, w_out)
        return self.reduce(space, w_obj, w_axis, True, #keepdims must be true
                           out, w_dtype, variant=ACCUMULATE)

    @unwrap_spec(keepdims=bool)
    def descr_reduce(self, space, w_obj, w_axis=None, w_dtype=None,
                     w_out=None, keepdims=False):
        from pypy.module.micronumpy.ndarray import W_NDimArray
        if w_axis is None:
            w_axis = space.newint(0)
        out = out_converter(space, w_out)
        return self.reduce(space, w_obj, w_axis, keepdims, out, w_dtype)

    @specialize.arg(7)
    def reduce(self, space, w_obj, w_axis, keepdims=False, out=None, dtype=None,
               variant=REDUCE):
        if self.nin != 2:
            raise oefmt(space.w_ValueError,
                        "%s only supported for binary functions",
                        _reduce_type[variant])
        assert isinstance(self, W_Ufunc2)
        obj = convert_to_array(space, w_obj)
        if obj.get_dtype().is_flexible():
            raise oefmt(space.w_TypeError,
                        "cannot perform %s with flexible type",
                        _reduce_type[variant])
        obj_shape = obj.get_shape()
        if obj.is_scalar():
            return obj.get_scalar_value()
        shapelen = len(obj_shape)

        if space.is_none(w_axis):
            axes = range(shapelen)
            axis = maxint
        elif space.isinstance_w(w_axis, space.w_tuple):
            axes_w = space.listview(w_axis)
            axes = [0] * len(axes_w)
            for i in range(len(axes_w)):
                x = space.int_w(axes_w[i])
                if x < 0:
                    x += shapelen
                if x < 0 or x >= shapelen:
                    raise oefmt(space.w_ValueError, "'axis' entry is out of bounds")
                axes[i] = x
        else:
            if space.isinstance_w(w_axis, space.w_tuple) and space.len_w(w_axis) == 1:
                w_axis = space.getitem(w_axis, space.newint(0))
            axis = space.int_w(w_axis)
            if axis < -shapelen or axis >= shapelen:
                raise oefmt(space.w_ValueError, "'axis' entry is out of bounds")
            if axis < 0:
                axis += shapelen
            axes = [axis]
        dtype = decode_w_dtype(space, dtype)

        if dtype is None and out is not None:
            dtype = out.get_dtype()

        if dtype is None:
            obj_dtype = obj.get_dtype()
            num = obj_dtype.num
            if ((obj_dtype.is_bool() or obj_dtype.is_int()) and
                    self.promote_to_largest):
                if obj_dtype.is_bool():
                    num = NPY.LONG
                elif obj_dtype.elsize * 8 < LONG_BIT:
                    if obj_dtype.is_unsigned():
                        num = NPY.ULONG
                    else:
                        num = NPY.LONG
            dtype = num2dtype(space, num)

        if self.identity is None:
            for i in axes:
                if obj_shape[i] == 0:
                    raise oefmt(space.w_ValueError,
                        "zero-size array to reduction operation %s "
                        "which has no identity", self.name)

        if variant == ACCUMULATE:
            if len(axes) != 1:
                raise oefmt(space.w_ValueError,
                    "accumulate does not allow multiple axes")
            axis = axes[0]
            assert axis >= 0
            dtype = self.find_binop_type(space, dtype)
            shape = obj_shape[:]
            if out:
                # There appears to be a lot of accidental complexity in what
                # shapes cnumpy allows for out.
                # We simply require out.shape == obj.shape
                if out.get_shape() != obj_shape:
                    raise oefmt(space.w_ValueError,
                                "output parameter shape mismatch, expecting "
                                "[%s], got [%s]",
                                ",".join([str(x) for x in shape]),
                                ",".join([str(x) for x in out.get_shape()]),
                                )
                dtype = out.get_dtype()
                call__array_wrap__ = False
            else:
                out = W_NDimArray.from_shape(space, shape, dtype,
                                            w_instance=obj)
                call__array_wrap__ = True
            if shapelen > 1:
                if obj.get_size() == 0:
                    if self.identity is not None:
                        out.fill(space, self.identity.convert_to(space, dtype))
                    return out
                loop.accumulate(
                    space, self.func, obj, axis, dtype, out, self.identity)
            else:
                loop.accumulate_flat(
                    space, self.func, obj, dtype, out, self.identity)
            if call__array_wrap__:
                out = space.call_method(obj, '__array_wrap__', out, space.w_None)
            return out

        axis_flags = [False] * shapelen
        for i in axes:
            if axis_flags[i]:
                raise oefmt(space.w_ValueError, "duplicate value in 'axis'")
            axis_flags[i] = True


        _, dtype, _ = self.find_specialization(space, dtype, dtype, out,
                                                   casting='unsafe')
        if shapelen == len(axes):
            if out:
                if out.ndims() > 0:
                    raise oefmt(space.w_ValueError,
                                "output parameter for reduction operation %s has "
                                "too many dimensions", self.name)
                dtype = out.get_dtype()
            res = loop.reduce_flat(
                space, self.func, obj, dtype, self.done_func, self.identity)
            if out:
                out.set_scalar_value(res)
                return out
            w_NDimArray = space.gettypefor(W_NDimArray)
            call__array_wrap__ = False
            if keepdims:
                shape = [1] * len(obj_shape)
                out = W_NDimArray.from_shape(space, shape, dtype, w_instance=obj)
                out.implementation.setitem(0, res)
                call__array_wrap__ = True
                res = out
            elif (space.issubtype_w(space.type(w_obj), w_NDimArray) and 
                  not space.is_w(space.type(w_obj), w_NDimArray)):
                # subtypes return a ndarray subtype, not a scalar
                out = W_NDimArray.from_shape(space, [1], dtype, w_instance=obj)
                out.implementation.setitem(0, res)
                call__array_wrap__ = True
                res = out
            if call__array_wrap__:
                res = space.call_method(obj, '__array_wrap__', res, space.w_None)
            return res

        else:
            temp = None
            if keepdims:
                shape = obj_shape[:]
                for axis in axes:
                    shape[axis] = 1
            else:
                shape = [0] * (shapelen - len(axes))
                j = 0
                for i in range(shapelen):
                    if not axis_flags[i]:
                        shape[j] = obj_shape[i]
                        j += 1
            if out:
                # Test for shape agreement
                # XXX maybe we need to do broadcasting here, although I must
                #     say I don't understand the details for axis reduce
                if out.ndims() > len(shape):
                    raise oefmt(space.w_ValueError,
                                "output parameter for reduction operation %s "
                                "has too many dimensions", self.name)
                elif out.ndims() < len(shape):
                    raise oefmt(space.w_ValueError,
                                "output parameter for reduction operation %s "
                                "does not have enough dimensions", self.name)
                elif out.get_shape() != shape:
                    raise oefmt(space.w_ValueError,
                                "output parameter shape mismatch, expecting "
                                "[%s], got [%s]",
                                ",".join([str(x) for x in shape]),
                                ",".join([str(x) for x in out.get_shape()]),
                                )
                call__array_wrap__ = False
                dtype = out.get_dtype()
            else:
                out = W_NDimArray.from_shape(space, shape, dtype,
                                             w_instance=obj)
            if obj.get_size() == 0:
                if self.identity is not None:
                    out.fill(space, self.identity.convert_to(space, dtype))
                return out
            loop.reduce(
                space, self.func, obj, axis_flags, dtype, out, self.identity)
            out = space.call_method(obj, '__array_wrap__', out, space.w_None)
            return out

    def descr_outer(self, space, args_w):
        if self.nin != 2:
            raise oefmt(space.w_ValueError,
                    "outer product only supported for binary functions")
        if len(args_w) != 2:
            raise oefmt(space.w_ValueError,
                    "exactly two arguments expected")
        args = [convert_to_array(space, w_obj) for w_obj in args_w]
        w_outshape = [space.newint(i) for i in args[0].get_shape() + [1]*args[1].ndims()]
        args0 = args[0].reshape(space, space.newtuple(w_outshape))
        return self.descr_call(space, Arguments.frompacked(space, 
                                                        space.newlist([args0, args[1]])))

    def parse_kwargs(self, space, kwds_w):
        w_casting = kwds_w.pop('casting', None)
        w_subok = kwds_w.pop('subok', None)
        w_out = kwds_w.pop('out', space.w_None)
        sig = None
        # TODO handle triple of extobj,
        # see _extract_pyvals in ufunc_object.c
        extobj_w = kwds_w.pop('extobj', get_extobj(space))
        if not space.isinstance_w(extobj_w, space.w_list) or space.len_w(extobj_w) != 3:
            raise oefmt(space.w_TypeError, "'extobj' must be a list of 3 values")
        return w_subok, w_out, sig, w_casting, extobj_w

def get_extobj(space):
        extobj_w = space.newlist([space.newint(8192), space.newint(0), space.w_None])
        return extobj_w


_reflected_ops = {
        'add': 'radd',
        'subtract': 'rsub',
        'multiply': 'rmul',
        'divide': 'rdiv',
        'true_divide': 'rtruediv',
        'floor_divide': 'rfloordiv',
        'remainder': 'rmod',
        'power': 'rpow',
        'left_shift': 'rlshift',
        'right_shift': 'rrshift',
        'bitwise_and': 'rand',
        'bitwise_xor': 'rxor',
        'bitwise_or': 'ror',
        #/* Comparisons */
        'equal': 'eq',
        'not_equal': 'ne',
        'greater': 'lt',
        'less': 'gt',
        'greater_equal': 'le',
        'less_equal': 'ge',
}

for key, value in _reflected_ops.items():
    _reflected_ops[key] = "__" + value + "__"
del key
del value

def _has_reflected_op(space, w_obj, op):
    if op not in _reflected_ops:
        return False
    return space.getattr(w_obj, space.newtext(_reflected_ops[op])) is not None

def safe_casting_mode(casting):
    assert casting is not None
    if casting in ('unsafe', 'same_kind'):
        return 'safe'
    else:
        return casting

class W_Ufunc1(W_Ufunc):
    _immutable_fields_ = ["func", "bool_result", "dtypes[*]"]
    nin = 1
    nout = 1
    nargs = 2
    signature = None

    def __init__(self, func, name, promote_to_largest=False, promote_to_float=False,
            promote_bools=False, identity=None, bool_result=False, int_only=False,
            allow_bool=True, allow_complex=True, complex_to_float=False):
        W_Ufunc.__init__(self, name, promote_to_largest, promote_to_float, promote_bools,
                         identity, int_only, allow_bool, allow_complex, complex_to_float)
        self.func = func
        self.bool_result = bool_result

    def call(self, space, args_w, sig, casting, extobj):
        w_obj = args_w[0]
        out = None
        if len(args_w) > 1:
            out = out_converter(space, args_w[1])
        w_obj = numpify(space, w_obj)
        dtype = w_obj.get_dtype(space)
        calc_dtype, dt_out, func = self.find_specialization(space, dtype, out, casting)
        if isinstance(w_obj, W_GenericBox):
            if out is None:
                return self.call_scalar(space, w_obj, calc_dtype)
            else:
                w_obj = W_NDimArray.from_scalar(space, w_obj)
        assert isinstance(w_obj, W_NDimArray)
        shape = shape_agreement(space, w_obj.get_shape(), out,
                                broadcast_down=False)
        if out is None:
            w_res = W_NDimArray.from_shape(
                space, shape, dt_out, w_instance=w_obj)
        else:
            w_res = out
        w_res = loop.call1(space, shape, func, calc_dtype, w_obj, w_res)
        if out is None:
            if w_res.is_scalar():
                return w_res.get_scalar_value()
            ctxt = space.newtuple([self, space.newtuple([w_obj]), space.newint(0)])
            w_res = space.call_method(w_obj, '__array_wrap__', w_res, ctxt)
        return w_res

    def call_scalar(self, space, w_arg, in_dtype):
        w_val = self.func(in_dtype, w_arg.convert_to(space, in_dtype))
        if isinstance(w_val, W_ObjectBox):
            return w_val.w_obj
        return w_val

    def find_specialization(self, space, dtype, out, casting):
        if dtype.is_flexible():
            raise oefmt(space.w_TypeError, "ufunc '%s' did not contain a loop",
                        self.name)
        if (not self.allow_bool and dtype.is_bool() or
                not self.allow_complex and dtype.is_complex()):
            raise oefmt(space.w_TypeError,
                "ufunc %s not supported for the input type", self.name)
        dt_in, dt_out = self._calc_dtype(space, dtype, out, casting)
        return dt_in, dt_out, self.func

    @jit.unroll_safe
    def _calc_dtype(self, space, arg_dtype, out=None, casting='unsafe'):
        if arg_dtype.is_object():
            return arg_dtype, arg_dtype
        in_casting = safe_casting_mode(casting)
        for dt_in, dt_out in self.dtypes:
            if not can_cast_type(space, arg_dtype, dt_in, in_casting):
                continue
            if out is not None:
                res_dtype = out.get_dtype()
                if not can_cast_type(space, dt_out, res_dtype, casting):
                    continue
            return dt_in, dt_out

        else:
            raise oefmt(space.w_TypeError,
                "ufunc '%s' not supported for the input types", self.name)


class W_Ufunc2(W_Ufunc):
    _immutable_fields_ = ["func", "bool_result", "done_func", "dtypes[*]",
                          "simple_binary"]
    nin = 2
    nout = 1
    nargs = 3
    signature = None

    def __init__(self, func, name, promote_to_largest=False, promote_to_float=False,
            promote_bools=False, identity=None, bool_result=False, int_only=False,
            allow_bool=True, allow_complex=True, complex_to_float=False):
        W_Ufunc.__init__(self, name, promote_to_largest, promote_to_float, promote_bools,
                         identity, int_only, allow_bool, allow_complex, complex_to_float)
        self.func = func
        if name == 'logical_and':
            self.done_func = done_if_false
        elif name == 'logical_or':
            self.done_func = done_if_true
        else:
            self.done_func = None
        self.bool_result = bool_result or (self.done_func is not None)
        self.simple_binary = (
            allow_complex and allow_bool and not self.bool_result and not int_only
            and not complex_to_float and not promote_to_float
            and not promote_bools)

    def are_common_types(self, dtype1, dtype2):
        if dtype1.is_bool() or dtype2.is_bool():
            return False
        if (dtype1.is_int() and dtype2.is_int() or
                dtype1.is_float() and dtype2.is_float() or
                dtype1.is_complex() and dtype2.is_complex()):
            return True
        return False

    @jit.unroll_safe
    def call(self, space, args_w, sig, casting, extobj):
        if len(args_w) > 2:
            [w_lhs, w_rhs, out] = args_w
            out = out_converter(space, out)
        else:
            [w_lhs, w_rhs] = args_w
            out = None
        if not isinstance(w_rhs, W_NDimArray):
            # numpy implementation detail, useful for things like numpy.Polynomial
            # FAIL with NotImplemented if the other object has
            # the __r<op>__ method and has __array_priority__ as
            # an attribute (signalling it can handle ndarray's)
            # and is not already an ndarray or a subtype of the same type.
            r_greater = is_rhs_priority_higher(space, w_lhs, w_rhs)
            if r_greater and _has_reflected_op(space, w_rhs, self.name):
                return space.w_NotImplemented
        w_lhs = numpify(space, w_lhs)
        w_rhs = numpify(space, w_rhs)
        w_ldtype = w_lhs.get_dtype(space)
        w_rdtype = w_rhs.get_dtype(space)
        if w_ldtype.is_object() or w_rdtype.is_object():
            if ((w_ldtype.is_object() and w_ldtype.is_record()) and
                (w_rdtype.is_object() and w_rdtype.is_record())):
                pass
            elif ((w_ldtype.is_object() and w_ldtype.is_record()) or
                (w_rdtype.is_object() and w_rdtype.is_record())):
                if self.name == 'not_equal':
                    return space.w_True
                elif self.name == 'equal':
                    return space.w_False
                else:
                    msg = ("ufunc '%s' not supported for the input types, "
                           "and the inputs could not be safely coerced to "
                           "any supported types according to the casting "
                           "rule '%s'")
                    raise oefmt(space.w_TypeError, msg, self.name, casting)
            else:
                pass
        elif w_ldtype.is_str() and w_rdtype.is_str() and \
                self.bool_result:
            pass
        elif (w_ldtype.is_str()) and \
                self.bool_result and out is None:
            if self.name in ('equal', 'less_equal', 'less'):
               return space.w_False
            return space.w_True
        elif (w_rdtype.is_str()) and \
                self.bool_result and out is None:
            if self.name in ('not_equal','less', 'less_equal'):
               return space.w_True
            return space.w_False
        elif w_ldtype.is_flexible() or w_rdtype.is_flexible():
            if self.bool_result:
                if self.name == 'equal' or self.name == 'not_equal':
                    res = w_ldtype.eq(space, w_rdtype)
                    if not res:
                        return space.newbool(self.name == 'not_equal')
                else:
                    return space.w_NotImplemented
            else:
                raise oefmt(space.w_TypeError,
                            'unsupported operand dtypes %s and %s for "%s"',
                            w_rdtype.get_name(), w_ldtype.get_name(),
                            self.name)

        if (isinstance(w_lhs, W_GenericBox) and
                isinstance(w_rhs, W_GenericBox) and out is None):
            return self.call_scalar(space, w_lhs, w_rhs, casting)
        if isinstance(w_lhs, W_GenericBox):
            w_lhs = W_NDimArray.from_scalar(space, w_lhs)
        assert isinstance(w_lhs, W_NDimArray)
        if isinstance(w_rhs, W_GenericBox):
            w_rhs = W_NDimArray.from_scalar(space, w_rhs)
        assert isinstance(w_rhs, W_NDimArray)
        calc_dtype, dt_out, func = self.find_specialization(
            space, w_ldtype, w_rdtype, out, casting, w_lhs, w_rhs)

        new_shape = shape_agreement(space, w_lhs.get_shape(), w_rhs)
        new_shape = shape_agreement(space, new_shape, out, broadcast_down=False)
        w_highpriority, out_subtype = array_priority(space, w_lhs, w_rhs)
        if out is None:
            w_res = W_NDimArray.from_shape(space, new_shape, dt_out,
                                           w_instance=out_subtype)
        else:
            w_res = out
        w_res = loop.call2(space, new_shape, self.func, calc_dtype,
                           w_lhs, w_rhs, w_res)
        if out is None:
            if w_res.is_scalar():
                return w_res.get_scalar_value()
            ctxt = space.newtuple([self, space.newtuple([w_lhs, w_rhs]), space.newint(0)])
            w_res = space.call_method(w_highpriority, '__array_wrap__', w_res, ctxt)
        return w_res

    def call_scalar(self, space, w_lhs, w_rhs, casting):
        in_dtype, out_dtype, func = self.find_specialization(
            space, w_lhs.get_dtype(space), w_rhs.get_dtype(space),
            out=None, casting=casting)
        w_val = self.func(in_dtype,
                          w_lhs.convert_to(space, in_dtype),
                          w_rhs.convert_to(space, in_dtype))
        if isinstance(w_val, W_ObjectBox):
            return w_val.w_obj
        return w_val

    def _find_specialization(self, space, l_dtype, r_dtype, out, casting,
                             w_arg1, w_arg2):
        if (not self.allow_bool and (l_dtype.is_bool() or
                                         r_dtype.is_bool()) or
                not self.allow_complex and (l_dtype.is_complex() or
                                            r_dtype.is_complex())):
            raise oefmt(space.w_TypeError,
                "ufunc '%s' not supported for the input types", self.name)
        if self.bool_result and not self.done_func:
            # XXX: should actually pass the arrays
            dtype = find_result_type(space, [], [l_dtype, r_dtype])
            bool_dtype = get_dtype_cache(space).w_booldtype
            return dtype, bool_dtype, self.func
        dt_in, dt_out = self._calc_dtype(
            space, l_dtype, r_dtype, out, casting, w_arg1, w_arg2)
        return dt_in, dt_out, self.func

    def find_specialization(self, space, l_dtype, r_dtype, out, casting,
                            w_arg1=None, w_arg2=None):
        if self.simple_binary:
            if out is None and not (l_dtype.is_object() or r_dtype.is_object()):
                if w_arg1 is not None and w_arg2 is not None:
                    w_arg1 = convert_to_array(space, w_arg1)
                    w_arg2 = convert_to_array(space, w_arg2)
                    dtype = find_result_type(space, [w_arg1, w_arg2], [])
                else:
                    dtype = promote_types(space, l_dtype, r_dtype)
                return dtype, dtype, self.func
        return self._find_specialization(
            space, l_dtype, r_dtype, out, casting, w_arg1, w_arg2)

    def find_binop_type(self, space, dtype):
        """Find a valid dtype signature of the form xx->x"""
        if dtype.is_object():
            return dtype
        for dt_in, dt_out in self.dtypes:
            if can_cast_to(dtype, dt_in):
                if dt_out == dt_in:
                    return dt_in
                else:
                    dtype = dt_out
                    break
        for dt_in, dt_out in self.dtypes:
            if can_cast_to(dtype, dt_in) and dt_out == dt_in:
                return dt_in
        raise oefmt(space.w_ValueError,
            "could not find a matching type for %s.accumulate, "
            "requested type has type code '%s'", self.name, dtype.char)


    @jit.unroll_safe
    def _calc_dtype(self, space, l_dtype, r_dtype, out, casting,
                    w_arg1, w_arg2):
        if l_dtype.is_object() or r_dtype.is_object():
            dtype = get_dtype_cache(space).w_objectdtype
            return dtype, dtype
        use_min_scalar = (w_arg1 is not None and w_arg2 is not None and
                          ((w_arg1.is_scalar() and not w_arg2.is_scalar()) or
                           (not w_arg1.is_scalar() and w_arg2.is_scalar())))
        in_casting = safe_casting_mode(casting)
        if use_min_scalar:
            w_arg1 = convert_to_array(space, w_arg1)
            w_arg2 = convert_to_array(space, w_arg2)
        elif (in_casting == 'safe' and l_dtype.num == 7 and r_dtype.num == 7 and
              out is None and not self.promote_to_float):
            # while long (7) can be cast to int32 (5) on 32 bit, don't do it
            return l_dtype, l_dtype
        for dt_in, dt_out in self.dtypes:
            if use_min_scalar:
                if not (can_cast_array(space, w_arg1, dt_in, in_casting) and
                        can_cast_array(space, w_arg2, dt_in, in_casting)):
                    continue
            else:
                if not (can_cast_type(space, l_dtype, dt_in, in_casting) and
                        can_cast_type(space, r_dtype, dt_in, in_casting)):
                    continue
            if out is not None:
                res_dtype = out.get_dtype()
                if not can_cast_type(space, dt_out, res_dtype, casting):
                    continue
            return dt_in, dt_out

        else:
            raise oefmt(space.w_TypeError,
                "ufunc '%s' not supported for the input types", self.name)

def _match_dtypes(space, indtypes, targetdtypes, i_target, casting):
    allok = True
    for i in range(len(indtypes)):
        origin = indtypes[i]
        target = targetdtypes[i + i_target]
        if origin is None:
            continue
        if target is None:
            continue
        if not can_cast_type(space, origin, target, casting):
            allok = False
            break
    return allok

def _raise_err_msg(self, space, dtypes0, dtypes1):
    dtypesstr = ''
    for d in dtypes0:
        if d is None:
            dtypesstr += 'None,'
        else:
            dtypesstr += '%s%s%s,' % (d.byteorder, d.kind, d.elsize)
    _dtypesstr = ','.join(['%s%s%s' % (d.byteorder, d.kind, d.elsize) \
                    for d in dtypes1])
    raise oefmt(space.w_TypeError,
         "input dtype [%s] did not match any known dtypes [%s] ",
         dtypesstr,_dtypesstr)


class W_UfuncGeneric(W_Ufunc):
    '''
    Handle a number of python functions, each with a signature and dtypes.
    The signature can specify how to create the inner loop, i.e.
    (i,j),(j,k)->(i,k) for a dot-like matrix multiplication, and the dtypes
    can specify the input, output args for the function. When called, the actual
    function used will be resolved by examining the input arg's dtypes.

    If dtypes == 'match', only one argument is provided and the output dtypes
    will match the input dtype (not cpython numpy compatible)

    This is the parallel to PyUFuncOjbect, see include/numpy/ufuncobject.h
    '''
    _immutable_fields_ = ["funcs", "dtypes", "data", "match_dtypes"]

    def __init__(self, space, funcs, name, identity, nin, nout, dtypes,
                 signature, match_dtypes=False, stack_inputs=False,
                 external_loop=False):
        # XXX make sure funcs, signature, dtypes, nin, nout are consistent

        # These don't matter, we use the signature and dtypes for determining
        # output dtype
        promote_to_largest = promote_to_float = promote_bools = False
        allow_bool = allow_complex = True
        int_only = complex_to_float = False
        W_Ufunc.__init__(self, name, promote_to_largest, promote_to_float, promote_bools,
                         identity, int_only, allow_bool, allow_complex, complex_to_float)
        self.funcs = funcs
        self.dtypes = dtypes
        self.nin = nin
        self.nout = nout
        self.match_dtypes = match_dtypes
        self.nargs = nin + max(nout, 1) # ufuncs can always be called with an out=<> kwarg
        if not match_dtypes and (len(dtypes) % len(funcs) != 0 or
                                  len(dtypes) / len(funcs) != self.nargs):
            raise oefmt(space.w_ValueError,
                "generic ufunc with %d functions, %d arguments, but %d dtypes",
                len(funcs), self.nargs, len(dtypes))
        self.signature = signature
        #These will be filled in by _parse_signature
        self.core_enabled = True    # False for scalar ufunc, True for generalized ufunc
        self.stack_inputs = stack_inputs
        self.core_num_dim_ix = 0 # number of distinct dimension names in signature
        self.core_num_dims = [0] * self.nargs  # number of core dimensions of each nargs
        self.core_offsets = [0] * self.nargs
        self.core_dim_ixs = [] # indices into unique shapes for each arg
        self.external_loop = external_loop

    def reduce(self, space, w_obj, w_axis, keepdims=False, out=None, dtype=None,
               variant=REDUCE):
        raise oefmt(space.w_NotImplementedError, 'not implemented yet')

    def call(self, space, args_w, sig, casting, extobj):
        if len(args_w) < self.nin:
            raise oefmt(space.w_ValueError,
                 '%s called with too few input args, expected at least %d got %d',
                 self.name, self.nin, len(args_w))
        inargs = [convert_to_array(space, args_w[i]) for i in range(self.nin)]
        outargs = [None] * self.nout
        for i in range(len(args_w)-self.nin):
            out = args_w[i+self.nin]
            if space.is_w(out, space.w_None) or out is None:
                continue
            else:
                if not isinstance(out, W_NDimArray):
                    raise oefmt(space.w_TypeError,
                         'output arg %d must be an array, not %s', i+self.nin, str(args_w[i+self.nin]))
                outargs[i] = out
        _dtypes = self.dtypes
        if self.match_dtypes:
            _dtypes = [i.get_dtype() for i in inargs if isinstance(i, W_NDimArray)]
            for i in outargs:
                if isinstance(i, W_NDimArray):
                    _dtypes.append(i.get_dtype())
                else:
                    _dtypes.append(_dtypes[0])
        index, dtypes = self.type_resolver(space, inargs, outargs, sig, _dtypes)
        func = self.funcs[index]
        iter_shape, arg_shapes, matched_dims = self.verify_args(space, inargs, outargs)
        inargs, outargs, need_to_cast = self.alloc_args(space, inargs, outargs, dtypes,
                                          arg_shapes)
        if not self.external_loop:
            inargs0 = inargs[0]
            outargs0 = outargs[0]
            assert isinstance(inargs0, W_NDimArray)
            assert isinstance(outargs0, W_NDimArray)
            nin = self.nin
            assert nin >= 0
            res_dtype = outargs0.get_dtype()
            new_shape = inargs0.get_shape()
            # XXX use _find_array_wrap and wrap outargs using __array_wrap__
            if self.stack_inputs:
                loop.call_many_to_many(space, new_shape, func,
                                         dtypes, [], inargs + outargs, [])
                if len(outargs) < 2:
                    return outargs[0]
                return space.newtuple(outargs)
            if len(outargs) < 2:
                return loop.call_many_to_one(space, new_shape, func,
                         dtypes[:nin], dtypes[-1], inargs, outargs[0])
            return loop.call_many_to_many(space, new_shape, func,
                         dtypes[:nin], dtypes[nin:], inargs, outargs)
        w_casting = space.w_None
        w_op_dtypes = space.w_None
        for tf in need_to_cast:
            if tf:
                w_casting = space.newtext('safe')
                w_op_dtypes = space.newtuple([d for d in dtypes])

        w_flags = space.w_None # NOT 'external_loop', we do coalescing by core_num_dims
        w_ro = space.newtuple([space.newtext('readonly'), space.newtext('copy')])
        w_rw = space.newtuple([space.newtext('readwrite'), space.newtext('updateifcopy')])

        w_op_flags = space.newtuple([w_ro] * len(inargs) + [w_rw] * len(outargs))
        w_op_axes = space.w_None

        if isinstance(func, W_GenericUFuncCaller):
            # Use GeneralizeUfunc interface with signature
            # Unlike numpy, we will not broadcast dims before
            # the core_ndims rather we use nditer iteration
            # so dims[0] == 1
            dims = [1] + matched_dims
            steps = []
            allargs = inargs + outargs
            for i in range(len(allargs)):
                steps.append(0)
            for i in range(len(allargs)):
                _arg = allargs[i]
                assert isinstance(_arg, W_NDimArray)
                start_dim = len(iter_shape)
                steps += _arg.implementation.strides[start_dim:]
            func.set_dims_and_steps(space, dims, steps)
        else:
            # it is a function, ready to be called by the iterator,
            # from frompyfunc
            pass
        # mimic NpyIter_AdvancedNew with a nditer
        w_itershape = space.newlist([space.newint(i) for i in iter_shape])
        nd_it = W_NDIter(space, space.newlist(inargs + outargs), w_flags,
                      w_op_flags, w_op_dtypes, w_casting, w_op_axes,
                      w_itershape, allow_backward=False)
        # coalesce each iterators, according to inner_dimensions
        for i in range(len(inargs) + len(outargs)):
            for j in range(self.core_num_dims[i]):
                new_iter = coalesce_iter(nd_it.iters[i][0], nd_it.op_flags[i],
                                nd_it, nd_it.order, flat=False)
                nd_it.iters[i] = (new_iter, new_iter.reset())
            # do the iteration
        if self.stack_inputs:
            while not nd_it.done:
                # XXX jit me
                for it, st in nd_it.iters:
                    if not it.done(st):
                        break
                else:
                    nd_it.done = True
                    break
                args = []
                for i, (it, st) in enumerate(nd_it.iters):
                    args.append(nd_it.getitem(it, st))
                    nd_it.iters[i] = (it, it.next(st))
                space.call_args(func, Arguments.frompacked(space, space.newlist(args)))
        else:
            # do the iteration
            while not nd_it.done:
                # XXX jit me
                for it, st in nd_it.iters:
                    if not it.done(st):
                        break
                else:
                    nd_it.done = True
                    break
                initers = []
                outiters = []
                nin = len(inargs)
                for i, (it, st) in enumerate(nd_it.iters[:nin]):
                    initers.append(nd_it.getitem(it, st))
                    nd_it.iters[i] = (it, it.next(st))
                for i, (it, st) in enumerate(nd_it.iters[nin:]):
                    outiters.append(nd_it.getitem(it, st))
                    nd_it.iters[i + nin] = (it, it.next(st))
                outs = space.call_args(func, Arguments.frompacked(space, space.newlist(initers)))
                if len(outiters) < 2:
                    outiters[0].descr_setitem(space, space.w_Ellipsis, outs)
                else:
                    for i in range(self.nout):
                        w_val = space.getitem(outs, space.newint(i))
                        outiters[i].descr_setitem(space, space.w_Ellipsis, w_val)
        # XXX use _find_array_wrap and wrap outargs using __array_wrap__
        if len(outargs) > 1:
            return space.newtuple([convert_to_array(space, o) for o in outargs])
        return outargs[0]

    def parse_kwargs(self, space, kwargs_w):
        w_subok, w_out, sig, w_casting, extobj = \
                    W_Ufunc.parse_kwargs(self, space, kwargs_w)
        # do equivalent of get_ufunc_arguments in numpy's ufunc_object.c
        dtype_w = kwargs_w.pop('dtype', None)
        if not space.is_w(dtype_w, space.w_None) and not dtype_w is None:
            if sig:
                raise oefmt(space.w_RuntimeError,
                        "cannot specify both 'sig' and 'dtype'")
            dtype = decode_w_dtype(space, dtype_w)
            sig = dtype.char
        order = kwargs_w.pop('order', None)
        if not space.is_w(order, space.w_None) and not order is None:
            raise oefmt(space.w_NotImplementedError, '"order" keyword not implemented')
        parsed_kw = []
        for kw in kwargs_w:
            if kw.startswith('sig'):
                if sig:
                    raise oefmt(space.w_RuntimeError,
                            "cannot specify both 'sig' and 'dtype'")
                sig = space.text_w(kwargs_w[kw])
                parsed_kw.append(kw)
            elif kw.startswith('where'):
                raise oefmt(space.w_NotImplementedError,
                            '"where" keyword not implemented')
                parsed_kw.append(kw)
        for kw in parsed_kw:
            kwargs_w.pop(kw)
        return w_subok, w_out, sig, w_casting, extobj

    def type_resolver(self, space, inargs, outargs, type_tup, _dtypes):
        # Find a match for the inargs.dtype in _dtypes, like
        # linear_search_type_resolver in numpy ufunc_type_resolutions.c
        # type_tup can be '', a tuple of dtypes, or a string
        # of the form 'dt->D' where the letters are dtype specs

        # XXX why does the next line not pass translation?
        # dtypes = [i.get_dtype() for i in inargs]
        dtypes = []
        for i in inargs:
            if isinstance(i, W_NDimArray):
                dtypes.append(i.get_dtype())
            else:
                dtypes.append(None)
        for i in outargs:
            if isinstance(i, W_NDimArray):
                dtypes.append(i.get_dtype())
            else:
                dtypes.append(None)
        if isinstance(type_tup, str) and len(type_tup) > 0:
            try:
                if len(type_tup) == 1:
                    s_dtypes = [get_dtype_cache(space).dtypes_by_name[type_tup]] * self.nargs
                elif len(type_tup) == self.nargs + 2:
                    s_dtypes = []
                    for i in range(self.nin):
                        s_dtypes.append(get_dtype_cache(space).dtypes_by_name[type_tup[i]])
                    #skip the '->' in the signature
                    for i in range(self.nout):
                        j = i + self.nin + 2
                        s_dtypes.append(get_dtype_cache(space).dtypes_by_name[type_tup[j]])
                else:
                    raise oefmt(space.w_TypeError, "a type-string for %s " \
                        "requires 1 typecode or %d typecode(s) before and %d" \
                        " after the -> sign, not '%s'", self.name, self.nin,
                        self.nout, type_tup)
            except KeyError:
                raise oefmt(space.w_ValueError, "unknown typecode in" \
                        " call to %s with type-string '%s'", self.name, type_tup)
            # Make sure args can be cast to dtypes
            if not _match_dtypes(space, dtypes, s_dtypes, 0, "safe"):
                _raise_err_msg(self, space, dtypes, s_dtypes)
            dtypes = s_dtypes    
        #Find the first matchup of dtypes with _dtypes
        for i in range(0, len(_dtypes), self.nargs):
            allok = _match_dtypes(space, dtypes, _dtypes, i, "no")
            if allok:
                break
        else:
            # No exact matches, can we cast?
            for i in range(0, len(_dtypes), self.nargs):
                allok = _match_dtypes(space, dtypes, _dtypes, i, "safe")
                if allok:
                    end = i + self.nargs
                    assert i >= 0
                    assert end >=0
                    dtypes = _dtypes[i:end]
                    break
            else:
                if len(self.funcs) > 1:
                    _raise_err_msg(self, space, dtypes, _dtypes)
                i = 0
        # Fill in empty dtypes
        for j in range(self.nargs):
            if dtypes[j] is None:
                dtypes[j] = _dtypes[i+j]
        return i / self.nargs, dtypes

    def alloc_args(self, space, inargs, outargs, dtypes, arg_shapes):
        # Any None outarg are allocated, and inargs, outargs may need casting
        inargs0 = inargs[0]
        assert isinstance(inargs0, W_NDimArray)
        order = inargs0.get_order()
        need_to_cast = []
        for i in range(self.nin):
            curarg = inargs[i]
            assert isinstance(curarg, W_NDimArray)
            if len(arg_shapes[i]) != curarg.ndims():
                # reshape
                sz = product(curarg.get_shape()) * curarg.get_dtype().elsize
                with curarg.implementation as storage:
                    inargs[i] = W_NDimArray.from_shape_and_storage(
                        space, arg_shapes[i], storage,
                        curarg.get_dtype(), storage_bytes=sz, w_base=curarg)
            need_to_cast.append(curarg.get_dtype() != dtypes[i])
        for i in range(len(outargs)):
            j = self.nin + i
            curarg = outargs[i]
            if not isinstance(curarg, W_NDimArray):
                outargs[i] = W_NDimArray.from_shape(space, arg_shapes[j], dtypes[j], order)
                curarg = outargs[i]
            elif len(arg_shapes[i]) != curarg.ndims():
                # reshape
                sz = product(curarg.get_shape()) * curarg.get_dtype().elsize
                with curarg.implementation as storage:
                    outargs[i] = W_NDimArray.from_shape_and_storage(
                        space, arg_shapes[i], storage,
                        curarg.get_dtype(), storage_bytes=sz, w_base=curarg)
                curarg = outargs[i]
            assert isinstance(curarg, W_NDimArray)
            need_to_cast.append(curarg.get_dtype() != dtypes[j])
        return inargs, outargs, need_to_cast

    def verify_args(self, space, inargs, outargs):
        # Figure out the number of iteration dimensions, which
        # is the broadcast result of all the input non-core
        # dimensions
        iter_shape = []
        arg_shapes = []
        max_matched_dims = 0
        for i in self.core_dim_ixs:
            if i > max_matched_dims:
                max_matched_dims = i
        matched_dims = [-1] * (1 + max_matched_dims)
        for i in range(len(inargs) + len(outargs)):
            if i < len(inargs):
                _i = i
                name = 'Input'
                curarg = inargs[i]
            else:
                _i = i - self.nin
                name = 'Output'
                curarg = outargs[_i]
            dim_offset = self.core_offsets[i]
            num_dims = self.core_num_dims[i]
            if not isinstance(curarg, W_NDimArray):
                target_dims = []
                for j in range(num_dims):
                    core_dim_index = self.core_dim_ixs[dim_offset + j]
                    v = matched_dims[core_dim_index]
                    if v < 0:
                        raise oefmt(space.w_ValueError, "%s: %s operand %d "
                            "is empty but unique core dimension %d in signature "
                            "%s of gufunc was not specified",
                             self.name, name, _i, core_dim_index, self.signature)
                    target_dims.append(v)
                arg_shapes.append(iter_shape + target_dims)
                continue
            n = len(curarg.get_shape()) - num_dims
            if n < 0:
                raise oefmt(space.w_ValueError, "%s: %s operand %d does "
                    "not have enough dimensions (has %d, gufunc with "
                    "signature %s requires %d)", self.name, name, _i,
                    num_dims+n, self.signature, num_dims)
            dims_to_match = curarg.get_shape()[n:]
            dims_to_broadcast = curarg.get_shape()[:n]
            offset = n - len(iter_shape)
            if offset > 0:
                # Prepend extra dimensions to iter_shape, matched_dims
                iter_shape = dims_to_broadcast[:offset] + iter_shape
                arg_shapes = [dims_to_broadcast[:offset] + asp for asp in arg_shapes]
                offset = 0
            # Make sure iter_shape[offset:] matches dims_to_broadcast
            offset = abs(offset) # for translation
            for j in range(offset, len(iter_shape)):
                x = iter_shape[j + offset]
                y = dims_to_broadcast[j]
                if y > 1 and x != 0 and ((x > y and x % y) or y %x):
                    raise oefmt(space.w_ValueError, "%s: %s operand %d has a "
                        "mismatch in its broadcast dimension %d "
                        "(size %d is different from %d)",
                         self.name, name, _i, j, x, y)
                iter_shape[offset + j] = max(x, y)
            #print 'Find or verify signature ixs',self.core_dim_ixs,
            #print 'starting',dim_offset,'n',n,'num_dims',num_dims,'matching',dims_to_match
            for j in range(num_dims):
                core_dim_index = self.core_dim_ixs[dim_offset + j]
                if core_dim_index > len(dims_to_match):
                    raise oefmt(space.w_ValueError, "%s: %s operand %d has a "
                        "mismatch in its core dimension %d, with gufunc "
                        "signature %s (index is larger than input shape)",
                         self.name, name, _i, j, self.signature, core_dim_index)
                if matched_dims[core_dim_index] < 0:
                    matched_dims[core_dim_index] = dims_to_match[j]
                elif matched_dims[core_dim_index] != dims_to_match[j]:
                    raise oefmt(space.w_ValueError, "%s: %s operand %d has a "
                        "mismatch in its core dimension %d, with gufunc "
                        "signature %s (expected %d, got %d)",
                         self.name, name, _i, j,
                         self.signature, matched_dims[core_dim_index],
                         dims_to_match[core_dim_index])
            #print 'adding',iter_shape,'+',dims_to_match,'to arg_shapes'
            if n < len(iter_shape):
                #Broadcast over the len(iter_shape) - n dims of iter_shape
                broadcast_dims = len(iter_shape) - n
                arg_shapes.append(iter_shape[:n] + [1] * broadcast_dims + dims_to_match)
            else:
                arg_shapes.append(iter_shape + dims_to_match)
        # TODO once we support obejct dtypes,
        # FAIL with NotImplementedError if the other object has
        # the __r<op>__ method and has a higher priority than
        # the current op (signalling it can handle ndarray's).

        # TODO parse and handle subok
        # TODO handle more flags, op_flags
        #print 'iter_shape',iter_shape,'arg_shapes',arg_shapes,'matched_dims',matched_dims
        return iter_shape, arg_shapes, matched_dims

W_Ufunc.typedef = TypeDef("numpy.ufunc",
    __call__ = interp2app(W_Ufunc.descr_call),
    __repr__ = interp2app(W_Ufunc.descr_repr),
    __name__ = GetSetProperty(W_Ufunc.descr_get_name),
    __doc__ = GetSetProperty(W_Ufunc.get_doc, W_Ufunc.set_doc),

    identity = GetSetProperty(W_Ufunc.descr_get_identity),
    accumulate = interp2app(W_Ufunc.descr_accumulate),
    nin = interp_attrproperty("nin", cls=W_Ufunc,
        wrapfn="newint"),
    nout = interp_attrproperty("nout", cls=W_Ufunc,
        wrapfn="newint"),
    nargs = interp_attrproperty("nargs", cls=W_Ufunc,
        wrapfn="newint"),
    signature = interp_attrproperty("signature", cls=W_Ufunc,
        wrapfn="newtext_or_none"),

    reduce = interp2app(W_Ufunc.descr_reduce),
    outer = interp2app(W_Ufunc.descr_outer),
)


def ufunc_dtype_caller(space, ufunc_name, op_name, nin, bool_result):
    def get_op(dtype):
        try:
            return getattr(dtype.itemtype, op_name)
        except AttributeError:
            raise oefmt(space.w_NotImplementedError,
                        "%s not implemented for %s",
                        ufunc_name, dtype.get_name())
    dtype_cache = get_dtype_cache(space)
    if nin == 1:
        def impl(res_dtype, value):
            res = get_op(res_dtype)(value)
            if bool_result:
                return dtype_cache.w_booldtype.box(res)
            return res
    elif nin == 2:
        def impl(res_dtype, lvalue, rvalue):
            res = get_op(res_dtype)(lvalue, rvalue)
            if bool_result:
                return dtype_cache.w_booldtype.box(res)
            return res
    return func_with_new_name(impl, ufunc_name)


class UfuncState(object):
    def __init__(self, space):
        "NOT_RPYTHON"
        for ufunc_def in [
            ("add", "add", 2, {"identity": 0, "promote_to_largest": True}),
            ("subtract", "sub", 2),
            ("multiply", "mul", 2, {"identity": 1, "promote_to_largest": True}),
            ("bitwise_and", "bitwise_and", 2, {"identity": 1,
                                               "int_only": True}),
            ("bitwise_or", "bitwise_or", 2, {"identity": 0,
                                             "int_only": True}),
            ("bitwise_xor", "bitwise_xor", 2, {"int_only": True}),
            ("invert", "invert", 1, {"int_only": True}),
            ("floor_divide", "floordiv", 2, {"promote_bools": True}),
            ("divide", "div", 2, {"promote_bools": True}),
            ("true_divide", "div", 2, {"promote_to_float": True}),
            ("mod", "mod", 2, {"promote_bools": True, 'allow_complex': False}),
            ("power", "pow", 2, {"promote_bools": True}),
            ("left_shift", "lshift", 2, {"int_only": True}),
            ("right_shift", "rshift", 2, {"int_only": True}),

            ("equal", "eq", 2, {"bool_result": True}),
            ("not_equal", "ne", 2, {"bool_result": True}),
            ("less", "lt", 2, {"bool_result": True}),
            ("less_equal", "le", 2, {"bool_result": True}),
            ("greater", "gt", 2, {"bool_result": True}),
            ("greater_equal", "ge", 2, {"bool_result": True}),
            ("isnan", "isnan", 1, {"bool_result": True}),
            ("isinf", "isinf", 1, {"bool_result": True}),
            ("isfinite", "isfinite", 1, {"bool_result": True}),

            ('logical_and', 'logical_and', 2, {'identity': 1}),
            ('logical_or', 'logical_or', 2, {'identity': 0}),
            ('logical_xor', 'logical_xor', 2, {'bool_result': True}),
            ('logical_not', 'logical_not', 1, {'bool_result': True}),

            ("maximum", "max", 2),
            ("minimum", "min", 2),

            ("copysign", "copysign", 2, {"promote_to_float": True,
                                         "allow_complex": False}),

            ("positive", "pos", 1),
            ("negative", "neg", 1),
            ("absolute", "abs", 1, {"complex_to_float": True}),
            ("rint", "rint", 1),
            ("sign", "sign", 1, {"allow_bool": False}),
            ("signbit", "signbit", 1, {"bool_result": True,
                                       "allow_complex": False}),
            ("reciprocal", "reciprocal", 1),
            ("conjugate", "conj", 1),
            ("real", "real", 1, {"complex_to_float": True}),
            ("imag", "imag", 1, {"complex_to_float": True}),

            ("fabs", "fabs", 1, {"promote_to_float": True,
                                 "allow_complex": False}),
            ("fmax", "fmax", 2, {"promote_to_float": True}),
            ("fmin", "fmin", 2, {"promote_to_float": True}),
            ("fmod", "fmod", 2, {"promote_to_float": True,
                                 'allow_complex': False}),
            ("floor", "floor", 1, {"promote_to_float": True,
                                   "allow_complex": False}),
            ("ceil", "ceil", 1, {"promote_to_float": True,
                                   "allow_complex": False}),
            ("trunc", "trunc", 1, {"promote_to_float": True,
                                   "allow_complex": False}),
            ("exp", "exp", 1, {"promote_to_float": True}),
            ("exp2", "exp2", 1, {"promote_to_float": True}),
            ("expm1", "expm1", 1, {"promote_to_float": True}),

            ('sqrt', 'sqrt', 1, {'promote_to_float': True}),
            ('square', 'square', 1, {'promote_to_float': True}),

            ("sin", "sin", 1, {"promote_to_float": True}),
            ("cos", "cos", 1, {"promote_to_float": True}),
            ("tan", "tan", 1, {"promote_to_float": True}),
            ("arcsin", "arcsin", 1, {"promote_to_float": True}),
            ("arccos", "arccos", 1, {"promote_to_float": True}),
            ("arctan", "arctan", 1, {"promote_to_float": True}),
            ("arctan2", "arctan2", 2, {"promote_to_float": True,
                                       "allow_complex": False}),
            ("sinh", "sinh", 1, {"promote_to_float": True}),
            ("cosh", "cosh", 1, {"promote_to_float": True}),
            ("tanh", "tanh", 1, {"promote_to_float": True}),
            ("arcsinh", "arcsinh", 1, {"promote_to_float": True}),
            ("arccosh", "arccosh", 1, {"promote_to_float": True}),
            ("arctanh", "arctanh", 1, {"promote_to_float": True}),

            ("radians", "radians", 1, {"promote_to_float": True,
                                       "allow_complex": False}),
            ("degrees", "degrees", 1, {"promote_to_float": True,
                                       "allow_complex": False}),

            ("log", "log", 1, {"promote_to_float": True}),
            ("log2", "log2", 1, {"promote_to_float": True}),
            ("log10", "log10", 1, {"promote_to_float": True}),
            ("log1p", "log1p", 1, {"promote_to_float": True}),
            ("logaddexp", "logaddexp", 2, {"promote_to_float": True,
                                       "allow_complex": False}),
            ("logaddexp2", "logaddexp2", 2, {"promote_to_float": True,
                                       "allow_complex": False}),
        ]:
            self.add_ufunc(space, *ufunc_def)

    def add_ufunc(self, space, ufunc_name, op_name, nin, extra_kwargs=None):
        if extra_kwargs is None:
            extra_kwargs = {}

        identity = extra_kwargs.get("identity")
        if identity is not None:
            identity = \
                get_dtype_cache(space).w_longdtype.box(identity)
        extra_kwargs["identity"] = identity

        func = ufunc_dtype_caller(space, ufunc_name, op_name, nin,
            bool_result=extra_kwargs.get("bool_result", False),
        )
        if nin == 1:
            ufunc = unary_ufunc(space, func, ufunc_name, **extra_kwargs)
        elif nin == 2:
            ufunc = binary_ufunc(space, func, ufunc_name, **extra_kwargs)
        setattr(self, ufunc_name, ufunc)

def unary_ufunc(space, func, ufunc_name, **kwargs):
    ufunc = W_Ufunc1(func, ufunc_name, **kwargs)
    ufunc.dtypes = _ufunc1_dtypes(ufunc, space)
    return ufunc

def _ufunc1_dtypes(ufunc, space):
    dtypes = []
    cache = get_dtype_cache(space)
    if not ufunc.promote_bools and not ufunc.promote_to_float:
        dtypes.append((cache.w_booldtype, cache.w_booldtype))
    if not ufunc.promote_to_float:
        for dt in cache.integer_dtypes:
            dtypes.append((dt, dt))
    if not ufunc.int_only:
        for dt in cache.float_dtypes:
            dtypes.append((dt, dt))
        for dt in cache.complex_dtypes:
            if ufunc.complex_to_float:
                if dt.num == NPY.CFLOAT:
                    dt_out = get_dtype_cache(space).w_float32dtype
                else:
                    dt_out = get_dtype_cache(space).w_float64dtype
                dtypes.append((dt, dt_out))
            else:
                dtypes.append((dt, dt))
    if ufunc.bool_result:
        dtypes = [(dt_in, cache.w_booldtype) for dt_in, _ in dtypes]
    return dtypes

def binary_ufunc(space, func, ufunc_name, **kwargs):
    ufunc = W_Ufunc2(func, ufunc_name, **kwargs)
    ufunc.dtypes = _ufunc2_dtypes(ufunc, space)
    return ufunc

def _ufunc2_dtypes(ufunc, space):
    dtypes = []
    cache = get_dtype_cache(space)
    if not ufunc.promote_bools and not ufunc.promote_to_float:
        dtypes.append((cache.w_booldtype, cache.w_booldtype))
    if not ufunc.promote_to_float:
        for dt in cache.integer_dtypes:
            dtypes.append((dt, dt))
    if not ufunc.int_only:
        for dt in cache.float_dtypes:
            dtypes.append((dt, dt))
        for dt in cache.complex_dtypes:
            if ufunc.complex_to_float:
                if dt.num == NPY.CFLOAT:
                    dt_out = get_dtype_cache(space).w_float32dtype
                else:
                    dt_out = get_dtype_cache(space).w_float64dtype
                dtypes.append((dt, dt_out))
            else:
                dtypes.append((dt, dt))
    if ufunc.bool_result:
        dtypes = [(dt_in, cache.w_booldtype) for dt_in, _ in dtypes]
    return dtypes


def get(space):
    return space.fromcache(UfuncState)

@unwrap_spec(nin=int, nout=int, signature='text', w_identity=WrappedDefault(None),
             name='text', doc='text', stack_inputs=bool)
def frompyfunc(space, w_func, nin, nout, w_dtypes=None, signature='',
     w_identity=None, name='', doc='', stack_inputs=False):
    ''' frompyfunc(func, nin, nout) #cpython numpy compatible
        frompyfunc(func, nin, nout, dtypes=None, signature='',
                   identity=None, name='', doc='',
                   stack_inputs=False)

    Takes an arbitrary Python function and returns a ufunc.

    Can be used, for example, to add broadcasting to a built-in Python
    function (see Examples section).

    Parameters
    ----------
    func : Python function object
        An arbitrary Python function or list of functions (if dtypes is specified).
    nin : int
        The number of input arguments.
    nout : int
        The number of arrays returned by `func`.
    dtypes: None or [dtype, ...] of the input, output args for each function,
         or 'match' to force output to exactly match input dtype
         Note that 'match' is a pypy-only extension to allow non-object
         return dtypes
    signature*: str, default=''
         The mapping of input args to output args, defining the
         inner-loop indexing. If it is empty, the func operates on scalars
    identity*: None (default) or int
         For reduce-type ufuncs, the default value
    name: str, default=''
    doc: str, default=''
    stack_inputs*: boolean, whether the function is of the form
            out = func(*in)  False
            or
            func(*[in + out])    True

    only one of out_dtype or signature may be specified

    Returns
    -------
    out : ufunc
        Returns a Numpy universal function (``ufunc``) object.

    Notes
    -----
    If the signature and dtype are both missing, the returned ufunc
        always returns PyObject arrays (cpython numpy compatability).
    Input arguments marked with a * are pypy-only extensions

    Examples
    --------
    Use frompyfunc to add broadcasting to the Python function ``oct``:

    >>> oct_obj_array = np.frompyfunc(oct, 1, 1)
    >>> oct_obj_array(np.array((10, 30, 100)))
    array([012, 036, 0144], dtype=object)
    >>> np.array((oct(10), oct(30), oct(100))) # for comparison
    array(['012', '036', '0144'],
          dtype='|S4')
    >>> oct_array = np.frompyfunc(oct, 1, 1, out_dtype=str)
    >>> oct_obj_array(np.array((10, 30, 100)))
    array([012, 036, 0144], dtype='|S4')
    '''
    if (space.isinstance_w(w_func, space.w_tuple) or
        space.isinstance_w(w_func, space.w_list)):
        func = space.listview(w_func)
        for w_f in func:
            if not space.is_true(space.callable(w_f)):
                raise oefmt(space.w_TypeError, 'func must be callable')
    else:
        if not space.is_true(space.callable(w_func)):
            raise oefmt(space.w_TypeError, 'func must be callable')
        func = [w_func]
    match_dtypes = False
    if space.is_none(w_dtypes) and not signature:
        raise oefmt(space.w_NotImplementedError,
             'object dtype requested but not implemented')
    elif (space.isinstance_w(w_dtypes, space.w_tuple) or
            space.isinstance_w(w_dtypes, space.w_list)):
            _dtypes = space.listview(w_dtypes)
            if space.isinstance_w(_dtypes[0], space.w_text) and space.text_w(_dtypes[0]) == 'match':
                dtypes = []
                match_dtypes = True
            else:
                dtypes = [None]*len(_dtypes)
                for i in range(len(dtypes)):
                    dtypes[i] = decode_w_dtype(space, _dtypes[i])
    else:
        raise oefmt(space.w_ValueError,
            'dtypes must be None or a list of dtypes')

    if space.is_none(w_identity):
        identity =  None
    elif space.isinstance_w(w_identity, space.w_int):
        identity = \
            get_dtype_cache(space).w_longdtype.box(space.int_w(w_identity))
    else:
        raise oefmt(space.w_ValueError,
            'identity must be None or an int')

    if len(signature) == 0:
        external_loop=False
    else:
        external_loop=True

    w_ret = W_UfuncGeneric(space, func, name, identity, nin, nout, dtypes,
                           signature, match_dtypes=match_dtypes,
                           stack_inputs=stack_inputs, external_loop=external_loop)
    if w_ret.external_loop:
        _parse_signature(space, w_ret, w_ret.signature)
    if doc:
        w_ret.set_doc(space, space.newtext(doc))
    return w_ret

# Instantiated in cpyext/ndarrayobject. It is here since ufunc calls
# set_dims_and_steps, otherwise ufunc, ndarrayobject would have circular
# imports
Py_ssize_t = lltype.Typedef(rffi.SSIZE_T, 'Py_ssize_t')
npy_intpp = rffi.CArrayPtr(Py_ssize_t)
LONG_SIZE = LONG_BIT / 8
CCHARP_SIZE = _get_bitsize('P') / 8

class W_GenericUFuncCaller(W_Root):
    _attrs_ = ['func', 'data', 'dims', 'steps', 'dims_steps_set']
    def __init__(self, func, data):
        self.func = func
        self.data = data
        self.dims = alloc_raw_storage(0, track_allocation=False)
        self.steps = alloc_raw_storage(0, track_allocation=False)
        self.dims_steps_set = False

    @rgc.must_be_light_finalizer
    def __del__(self):
        free_raw_storage(self.dims, track_allocation=False)
        free_raw_storage(self.steps, track_allocation=False)

    def descr_call(self, space, __args__):
        args_w, kwds_w = __args__.unpack()
        # Can be called two ways, as a GenericUfunc or a GeneralizedUfunc.
        # The difference is in the meaning of dims and steps,
        # a GenericUfunc is a scalar function that flatiters over the array(s).
        # a GeneralizedUfunc will iterate over dims[0], but will use dims[1...]
        # and steps[1, ...] to call a function on ndarray(s).
        # set up via a call to set_dims_and_steps()
        dataps = alloc_raw_storage(CCHARP_SIZE * len(args_w), track_allocation=False)
        if self.dims_steps_set is False:
            self.dims = alloc_raw_storage(LONG_SIZE * len(args_w), track_allocation=False)
            self.steps = alloc_raw_storage(LONG_SIZE * len(args_w), track_allocation=False)
            for i in range(len(args_w)):
                arg_i = args_w[i]
                if not isinstance(arg_i, W_NDimArray):
                    raise OperationError(space.w_NotImplementedError,
                         space.newtext("cannot mix ndarray and %r (arg %d) in call to ufunc" % (
                                       arg_i, i)))
                with arg_i.implementation as storage:
                    addr = get_storage_as_int(storage, arg_i.get_start())
                    raw_storage_setitem(dataps, CCHARP_SIZE * i, rffi.cast(rffi.CCHARP, addr))
                #This assumes we iterate over the whole array (it should be a view...)
                raw_storage_setitem(self.dims, LONG_SIZE * i, rffi.cast(rffi.LONG, arg_i.get_size()))
                raw_storage_setitem(self.steps, LONG_SIZE * i, rffi.cast(rffi.LONG, arg_i.get_dtype().elsize))
        else:
            for i in range(len(args_w)):
                arg_i = args_w[i]
                assert isinstance(arg_i, W_NDimArray)
                with arg_i.implementation as storage:
                    addr = get_storage_as_int(storage, arg_i.get_start())
                raw_storage_setitem(dataps, CCHARP_SIZE * i, rffi.cast(rffi.CCHARP, addr))
        try:
            arg1 = rffi.cast(rffi.CArrayPtr(rffi.CCHARP), dataps)
            arg2 = rffi.cast(npy_intpp, self.dims)
            arg3 = rffi.cast(npy_intpp, self.steps)
            self.func(arg1, arg2, arg3, self.data)
        finally:
            free_raw_storage(dataps, track_allocation=False)
        keepalive_until_here(args_w)

    def set_dims_and_steps(self, space, dims, steps):
        if not isinstance(dims, list) or not isinstance(steps, list):
            raise oefmt(space.w_RuntimeError,
                 "set_dims_and_steps called inappropriately")
        if self.dims_steps_set:
            free_raw_storage(self.dims, track_allocation=False)
            free_raw_storage(self.steps, track_allocation=False)
        self.dims = alloc_raw_storage(LONG_SIZE * len(dims), track_allocation=False)
        self.steps = alloc_raw_storage(LONG_SIZE * len(steps), track_allocation=False)
        for i in range(len(dims)):
            raw_storage_setitem(self.dims, LONG_SIZE * i, rffi.cast(rffi.LONG, dims[i]))
        for i in range(len(steps)):
            raw_storage_setitem(self.steps, LONG_SIZE * i, rffi.cast(rffi.LONG, steps[i]))
        self.dims_steps_set = True

W_GenericUFuncCaller.typedef = TypeDef("hiddenclass",
    __call__ = interp2app(W_GenericUFuncCaller.descr_call),
)

GenericUfunc = lltype.FuncType([rffi.CArrayPtr(rffi.CCHARP), npy_intpp, npy_intpp,
                                      rffi.VOIDP], lltype.Void)
