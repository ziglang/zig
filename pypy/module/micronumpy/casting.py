"""Functions and helpers for converting between dtypes"""

from rpython.rlib import jit
from rpython.rlib.signature import signature, types as ann
from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.error import OperationError, oefmt

from pypy.module.micronumpy.base import W_NDimArray, convert_to_array
from pypy.module.micronumpy import constants as NPY
from .types import (
    BaseType, Bool, ULong, Long, Float64, Complex64,
    StringType, UnicodeType, VoidType, ObjectType,
    int_types, float_types, complex_types, number_types, all_types)
from .descriptor import (
    W_Dtype, get_dtype_cache, as_dtype, is_scalar_w, variable_dtype,
    new_string_dtype, new_unicode_dtype, num2dtype)

@jit.unroll_safe
def result_type(space, __args__):
    args_w, kw_w = __args__.unpack()
    if kw_w:
        raise oefmt(space.w_TypeError,
            "result_type() takes no keyword arguments")
    if not args_w:
        raise oefmt(space.w_ValueError,
            "at least one array or dtype is required")
    arrays_w = []
    dtypes_w = []
    for w_arg in args_w:
        if isinstance(w_arg, W_NDimArray):
            arrays_w.append(w_arg)
        elif is_scalar_w(space, w_arg):
            w_scalar = as_scalar(space, w_arg)
            w_arr = W_NDimArray.from_scalar(space, w_scalar)
            arrays_w.append(w_arr)
        else:
            dtype = as_dtype(space, w_arg)
            dtypes_w.append(dtype)
    return find_result_type(space, arrays_w, dtypes_w)

@jit.look_inside_iff(lambda space, arrays_w, dtypes_w:
    jit.loop_unrolling_heuristic(arrays_w, len(arrays_w)) and
    jit.loop_unrolling_heuristic(dtypes_w, len(dtypes_w)))
def find_result_type(space, arrays_w, dtypes_w):
    # equivalent to PyArray_ResultType
    if len(arrays_w) == 1 and not dtypes_w:
        return arrays_w[0].get_dtype()
    elif not arrays_w and len(dtypes_w) == 1:
        return dtypes_w[0]
    result = None
    if not _use_min_scalar(arrays_w, dtypes_w):
        for w_array in arrays_w:
            if result is None:
                result = w_array.get_dtype()
            else:
                result = promote_types(space, result, w_array.get_dtype())
        for dtype in dtypes_w:
            if result is None:
                result = dtype
            else:
                result = promote_types(space, result, dtype)
    else:
        small_unsigned = False
        for w_array in arrays_w:
            dtype = w_array.get_dtype()
            small_unsigned_scalar = False
            if w_array.is_scalar() and dtype.is_number():
                num, alt_num = w_array.get_scalar_value().min_dtype()
                small_unsigned_scalar = (num != alt_num)
                dtype = num2dtype(space, num)
            if result is None:
                result = dtype
                small_unsigned = small_unsigned_scalar
            else:
                result, small_unsigned = _promote_types_su(
                    space, result, dtype,
                    small_unsigned, small_unsigned_scalar)
        for dtype in dtypes_w:
            if result is None:
                result = dtype
                small_unsigned = False
            else:
                result, small_unsigned = _promote_types_su(
                    space, result, dtype,
                    small_unsigned, False)
    return result

simple_kind_ordering = {
    Bool.kind: 0, ULong.kind: 1, Long.kind: 1,
    Float64.kind: 2, Complex64.kind: 2,
    NPY.STRINGLTR: 3, NPY.STRINGLTR2: 3,
    UnicodeType.kind: 3, VoidType.kind: 3, ObjectType.kind: 3}

# this is safe to unroll since it'll only be seen if we look inside
# the find_result_type
@jit.unroll_safe
def _use_min_scalar(arrays_w, dtypes_w):
    """Helper for find_result_type()"""
    if not arrays_w:
        return False
    all_scalars = True
    max_scalar_kind = 0
    max_array_kind = 0
    for w_array in arrays_w:
        if w_array.is_scalar():
            kind = simple_kind_ordering[w_array.get_dtype().kind]
            if kind > max_scalar_kind:
                max_scalar_kind = kind
        else:
            all_scalars = False
            kind = simple_kind_ordering[w_array.get_dtype().kind]
            if kind > max_array_kind:
                max_array_kind = kind
    for dtype in dtypes_w:
        all_scalars = False
        kind = simple_kind_ordering[dtype.kind]
        if kind > max_array_kind:
            max_array_kind = kind
    return not all_scalars and max_array_kind >= max_scalar_kind


@unwrap_spec(casting='text')
def can_cast(space, w_from, w_totype, casting='safe'):
    try:
        target = as_dtype(space, w_totype, allow_None=False)
    except TypeError:
        raise oefmt(space.w_TypeError,
            "did not understand one of the types; 'None' not accepted")
    if isinstance(w_from, W_NDimArray):
        return space.newbool(can_cast_array(space, w_from, target, casting))
    elif is_scalar_w(space, w_from):
        w_scalar = as_scalar(space, w_from)
        w_arr = W_NDimArray.from_scalar(space, w_scalar)
        return space.newbool(can_cast_array(space, w_arr, target, casting))

    try:
        origin = as_dtype(space, w_from, allow_None=False)
    except TypeError:
        raise oefmt(space.w_TypeError,
            "did not understand one of the types; 'None' not accepted")
    return space.newbool(can_cast_type(space, origin, target, casting))

kind_ordering = {
    Bool.kind: 0, ULong.kind: 1, Long.kind: 2,
    Float64.kind: 4, Complex64.kind: 5,
    NPY.STRINGLTR: 6, NPY.STRINGLTR2: 6,
    UnicodeType.kind: 7, VoidType.kind: 8, ObjectType.kind: 9}

def can_cast_type(space, origin, target, casting):
    # equivalent to PyArray_CanCastTypeTo
    if origin == target:
        return True
    if casting == 'unsafe':
        return True
    elif casting == 'no':
        return origin.eq(space, target)
    if origin.num == target.num:
        if origin.is_record():
            return (target.is_record() and
                    can_cast_record(space, origin, target, casting))
        else:
            if casting == 'equiv':
                return origin.elsize == target.elsize
            elif casting == 'safe':
                return origin.elsize <= target.elsize
            else:
                return True

    elif casting == 'same_kind':
        if can_cast_to(origin, target):
            return True
        if origin.kind in kind_ordering and target.kind in kind_ordering:
            return kind_ordering[origin.kind] <= kind_ordering[target.kind]
        return False
    elif casting == 'safe':
        return can_cast_to(origin, target)
    else:  # 'equiv'
        return origin.num == target.num and origin.elsize == target.elsize

def can_cast_record(space, origin, target, casting):
    if origin is target:
        return True
    if origin.fields is None or target.fields is None:
        return False
    if len(origin.fields) != len(target.fields):
        return False
    for name, (offset, orig_field) in origin.fields.iteritems():
        if name not in target.fields:
            return False
        target_field = target.fields[name][1]
        if not can_cast_type(space, orig_field, target_field, casting):
            return False
    return True


def can_cast_array(space, w_from, target, casting):
    # equivalent to PyArray_CanCastArrayTo
    origin = w_from.get_dtype()
    if w_from.is_scalar():
        return can_cast_scalar(
            space, origin, w_from.get_scalar_value(), target, casting)
    else:
        return can_cast_type(space, origin, target, casting)

def can_cast_scalar(space, from_type, value, target, casting):
    # equivalent to CNumPy's can_cast_scalar_to
    if from_type == target or casting == 'unsafe':
        return True
    if not from_type.is_number() or casting in ('no', 'equiv'):
        return can_cast_type(space, from_type, target, casting)
    if not from_type.is_native():
        value = value.descr_byteswap(space)
    dtypenum, altnum = value.min_dtype()
    if target.is_unsigned():
        dtypenum = altnum
    dtype = num2dtype(space, dtypenum)
    return can_cast_type(space, dtype, target, casting)

def as_scalar(space, w_obj):
    dtype = scalar2dtype(space, w_obj)
    return dtype.coerce(space, w_obj)

def min_scalar_type(space, w_a):
    w_array = convert_to_array(space, w_a)
    dtype = w_array.get_dtype()
    if w_array.is_scalar() and dtype.is_number():
        num, alt_num = w_array.get_scalar_value().min_dtype()
        return num2dtype(space, num)
    else:
        return dtype

def w_promote_types(space, w_type1, w_type2):
    dt1 = as_dtype(space, w_type1, allow_None=False)
    dt2 = as_dtype(space, w_type2, allow_None=False)
    return promote_types(space, dt1, dt2)

def find_binop_result_dtype(space, dt1, dt2):
    if dt2 is None:
        return dt1
    if dt1 is None:
        return dt2
    return promote_types(space, dt1, dt2)

def promote_types(space, dt1, dt2):
    """Return the smallest dtype to which both input dtypes can be safely cast"""
    # Equivalent to PyArray_PromoteTypes
    num = promotion_table[dt1.num][dt2.num]
    if num != -1:
        return num2dtype(space, num)

    # dt1.num should be <= dt2.num
    if dt1.num > dt2.num:
        dt1, dt2 = dt2, dt1

    if dt2.is_str():
        if dt1.is_str():
            if dt1.elsize > dt2.elsize:
                return dt1
            else:
                return dt2
        else:  # dt1 is numeric
            dt1_size = dt1.itemtype.strlen
            if dt1_size > dt2.elsize:
                return new_string_dtype(space, dt1_size)
            else:
                return dt2
    elif dt2.is_unicode():
        if dt1.is_unicode():
            if dt1.elsize > dt2.elsize:
                return dt1
            else:
                return dt2
        elif dt1.is_str():
            if dt2.elsize >= 4 * dt1.elsize:
                return dt2
            else:
                return new_unicode_dtype(space, dt1.elsize)
        else:  # dt1 is numeric
            dt1_size = dt1.itemtype.strlen
            if 4 * dt1_size > dt2.elsize:
                return new_unicode_dtype(space, dt1_size)
            else:
                return dt2
    else:
        assert dt2.num == NPY.VOID
        if can_cast_type(space, dt1, dt2, casting='equiv'):
            return dt1
    raise oefmt(space.w_TypeError, "invalid type promotion")

def _promote_types_su(space, dt1, dt2, su1, su2):
    """Like promote_types(), but handles the small_unsigned flag as well"""
    if su1:
        if dt2.is_bool() or dt2.is_unsigned():
            dt1 = dt1.as_unsigned(space)
        else:
            dt1 = dt1.as_signed(space)
    elif su2:
        if dt1.is_bool() or dt1.is_unsigned():
            dt2 = dt2.as_unsigned(space)
        else:
            dt2 = dt2.as_signed(space)
    if dt1.elsize < dt2.elsize:
        su = su2 and (su1 or not dt1.is_signed())
    elif dt1.elsize == dt2.elsize:
        su = su1 and su2
    else:
        su = su1 and (su2 or not dt2.is_signed())
    return promote_types(space, dt1, dt2), su

def scalar2dtype(space, w_obj):
    from .boxes import W_GenericBox
    bool_dtype = get_dtype_cache(space).w_booldtype
    long_dtype = get_dtype_cache(space).w_longdtype
    int64_dtype = get_dtype_cache(space).w_int64dtype
    uint64_dtype = get_dtype_cache(space).w_uint64dtype
    complex_dtype = get_dtype_cache(space).w_complex128dtype
    float_dtype = get_dtype_cache(space).w_float64dtype
    object_dtype = get_dtype_cache(space).w_objectdtype
    if isinstance(w_obj, W_GenericBox):
        return w_obj.get_dtype(space)

    if space.isinstance_w(w_obj, space.w_bool):
        return bool_dtype
    elif space.isinstance_w(w_obj, space.w_int):
        try:
            space.int_w(w_obj)
        except OperationError as e:
            if e.match(space, space.w_OverflowError):
                if space.is_true(space.le(w_obj, space.newint(0))):
                    return int64_dtype
                return uint64_dtype
            raise
        return int64_dtype
    elif space.isinstance_w(w_obj, space.w_float):
        return float_dtype
    elif space.isinstance_w(w_obj, space.w_complex):
        return complex_dtype
    elif space.isinstance_w(w_obj, space.w_bytes):
        return variable_dtype(space, 'S%d' % space.len_w(w_obj))
    elif space.isinstance_w(w_obj, space.w_unicode):
        return new_unicode_dtype(space, space.len_w(w_obj))
    return object_dtype

@signature(ann.instance(W_Dtype), ann.instance(W_Dtype), returns=ann.bool())
def can_cast_to(dt1, dt2):
    """Return whether dtype `dt1` can be cast safely to `dt2`"""
    # equivalent to PyArray_CanCastTo
    from .casting import can_cast_itemtype
    result = can_cast_itemtype(dt1.itemtype, dt2.itemtype)
    if result:
        if dt1.num == NPY.STRING:
            if dt2.num == NPY.STRING:
                return dt1.elsize <= dt2.elsize
            elif dt2.num == NPY.UNICODE:
                return dt1.elsize * 4 <= dt2.elsize
        elif dt1.num == NPY.UNICODE and dt2.num == NPY.UNICODE:
            return dt1.elsize <= dt2.elsize
        elif dt2.num in (NPY.STRING, NPY.UNICODE):
            if dt2.num == NPY.STRING:
                char_size = 1
            else:  # NPY.UNICODE
                char_size = 4
            if dt2.elsize == 0:
                return True
            if dt1.is_int():
                return dt2.elsize >= dt1.itemtype.strlen * char_size
    return result


@signature(ann.instance(BaseType), ann.instance(BaseType), returns=ann.bool())
def can_cast_itemtype(tp1, tp2):
    # equivalent to PyArray_CanCastSafely
    return casting_table[tp1.num][tp2.num]

#_________________________


casting_table = [[False] * NPY.NTYPES for _ in range(NPY.NTYPES)]

def enable_cast(type1, type2):
    casting_table[type1.num][type2.num] = True

def _can_cast(type1, type2):
    """NOT_RPYTHON: operates on BaseType subclasses"""
    return casting_table[type1.num][type2.num]

for tp in all_types:
    enable_cast(tp, tp)
    if tp.num != NPY.DATETIME:
        enable_cast(Bool, tp)
    enable_cast(tp, ObjectType)
    enable_cast(tp, VoidType)
enable_cast(StringType, UnicodeType)
#enable_cast(Bool, TimeDelta)

for tp in number_types:
    enable_cast(tp, StringType)
    enable_cast(tp, UnicodeType)

for tp1 in int_types:
    for tp2 in int_types:
        if tp1.signed:
            if tp2.signed and tp1.basesize() <= tp2.basesize():
                enable_cast(tp1, tp2)
        else:
            if tp2.signed and tp1.basesize() < tp2.basesize():
                enable_cast(tp1, tp2)
            elif not tp2.signed and tp1.basesize() <= tp2.basesize():
                enable_cast(tp1, tp2)
for tp1 in int_types:
    for tp2 in float_types + complex_types:
        size1 = tp1.basesize()
        size2 = tp2.basesize()
        if (size1 < 8 and size2 > size1) or (size1 >= 8 and size2 >= size1):
            enable_cast(tp1, tp2)
for tp1 in float_types:
    for tp2 in float_types + complex_types:
        if tp1.basesize() <= tp2.basesize():
            enable_cast(tp1, tp2)
for tp1 in complex_types:
    for tp2 in complex_types:
        if tp1.basesize() <= tp2.basesize():
            enable_cast(tp1, tp2)

promotion_table = [[-1] * NPY.NTYPES for _ in range(NPY.NTYPES)]
def promotes(tp1, tp2, tp3):
    if tp3 is None:
        num = -1
    else:
        num = tp3.num
    promotion_table[tp1.num][tp2.num] = num


for tp in all_types:
    promotes(tp, ObjectType, ObjectType)
    promotes(ObjectType, tp, ObjectType)

for tp1 in [Bool] + number_types:
    for tp2 in [Bool] + number_types:
        if tp1 is tp2:
            promotes(tp1, tp1, tp1)
        elif _can_cast(tp1, tp2):
            promotes(tp1, tp2, tp2)
        elif _can_cast(tp2, tp1):
            promotes(tp1, tp2, tp1)
        else:
            # Brute-force search for the least upper bound
            result = None
            for tp3 in number_types:
                if _can_cast(tp1, tp3) and _can_cast(tp2, tp3):
                    if result is None:
                        result = tp3
                    elif _can_cast(tp3, result) and not _can_cast(result, tp3):
                        result = tp3
            promotes(tp1, tp2, result)
