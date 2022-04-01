from rpython.rlib import jit
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rtyper.lltypesystem import rffi, lltype

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec, appdef
from pypy.interpreter.typedef import GetSetProperty
from pypy.objspace.std.typeobject import W_TypeObject
from pypy.objspace.std.objspace import StdObjSpace
from pypy.module.micronumpy import constants as NPY
from pypy.module.exceptions.interp_exceptions import _new_exception, W_UserWarning

W_VisibleDeprecationWarning = _new_exception('VisibleDeprecationWarning', W_UserWarning,
    """Visible deprecation warning.

    By default, python will not show deprecation warnings, so this class
    can be used when a very visible warning is helpful, for example because
    the usage is most likely a user bug.

    """)


def issequence_w(space, w_obj):
    from pypy.module.micronumpy.base import W_NDimArray
    return (space.isinstance_w(w_obj, space.w_tuple) or
           space.isinstance_w(w_obj, space.w_list) or
           space.isinstance_w(w_obj, space.w_memoryview) or
           isinstance(w_obj, W_NDimArray))


def index_w(space, w_obj):
    try:
        return space.int_w(space.index(w_obj))
    except OperationError:
        try:
            return space.int_w(space.int(w_obj))
        except OperationError:
            raise oefmt(space.w_IndexError, "only integers, slices (`:`), "
                "ellipsis (`...`), numpy.newaxis (`None`) and integer or "
                "boolean arrays are valid indices")


@jit.unroll_safe
def product(s):
    i = 1
    for x in s:
        i *= x
    return i

@jit.unroll_safe
def product_check(s):
    i = 1
    for x in s:
        try:
            i = ovfcheck(i * x)
        except OverflowError:
            raise
    return i

def check_and_adjust_index(space, index, size, axis):
    if index < -size or index >= size:
        if axis >= 0:
            raise oefmt(space.w_IndexError,
                        "index %d is out of bounds for axis %d with size %d",
                        index, axis, size)
        else:
            raise oefmt(space.w_IndexError,
                        "index %d is out of bounds for size %d",
                        index, size)
    if index < 0:
        index += size
    return index

def _next_non_white_space(s, offset):
    ret = offset
    while ret < len(s) and (s[ret] == ' ' or s[ret] == '\t'):
        ret += 1
        if ret >= len(s):
            break
    return ret

def _is_alpha_underscore(ch):
    return (ch >= 'A' and ch <= 'Z') or (ch >= 'a' and ch <= 'z') or ch == '_'

def _is_alnum_underscore(ch):
    return _is_alpha_underscore(ch) or (ch >= '0' and ch <='9')

def _parse_signature(space, ufunc, signature):
    '''
    rewritten from _parse_signature in numpy/core/src/umath/ufunc_object.c
    it takes a signature like '(),()->()' or '(i)->(i)' or '(i,j),(j,k)->(i,k)'
    and sets up the ufunc to handle the actual call appropriately

    cpython numpy chops the dim names i,j,k out of the signature using pointers with
    no copying, while faster than this code it seems like a marginally useful optimization.
    We copy them out into var_names
    '''
    i = _next_non_white_space(signature, 0)
    cur_arg = 0
    cur_core_dim = 0 # index into ufunc.cor_dim_ixs
    nd = 0           # number of dims of the current argument
    var_names = {}
    while i < len(signature):
        # loop over input/output arguments
        if cur_arg == ufunc.nin:
            if signature[i:i+2] != '->':
                raise oefmt(space.w_ValueError, '%s at %d in "%s"',
                    "expect '->'", i, signature)
            i = _next_non_white_space(signature, i+2)
        # parse core dimensions of one argument,
        # e.g. "()", "(i)", or "(i,j)"
        if signature[i] != '(':
            raise oefmt(space.w_ValueError, '%s at %d in "%s"',
                    "expect '('", i, signature)
        i = _next_non_white_space(signature, i+1)
        end_of_arg = signature.find(')', i)
        if end_of_arg < 0:
            raise oefmt(space.w_ValueError, '%s %d in "%s"',
                    "could not find ')' after", i, signature)
        if end_of_arg == i:
            # no named arg, skip the next loop
            next_comma = -1
            i += 1
        else:
            next_comma = signature.find(',', i, end_of_arg)
            if next_comma < 0:
                next_comma = end_of_arg
        while next_comma > 0 and next_comma <= end_of_arg:
            # loop over core dimensions
            name_end = next_comma - 1
            while signature[name_end] == ' ' or signature[name_end] == '\t':
                name_end -= 1
            if name_end < i:
                raise oefmt(space.w_ValueError, '%s at %d in "%s"',
                    "expect dimension name", i, signature)
            var_name = signature[i:name_end + 1]
            for s in var_name:
                if not _is_alnum_underscore(s):
                    raise oefmt(space.w_ValueError, '%s at %d in "%s"',
                        "expect dimension name", i, signature)
            if var_name not in var_names:
                var_names[var_name] = ufunc.core_num_dim_ix
                ufunc.core_num_dim_ix += 1
            ufunc.core_dim_ixs.append(var_names[var_name])
            cur_core_dim += 1
            nd += 1
            i = next_comma
            if signature[i] == ',':
                i = _next_non_white_space(signature, i + 1);
                if signature[i] == ')':
                    raise oefmt(space.w_ValueError, '%s at %d in "%s"',
                        "',' must not be followed by ')'", i, signature)
            if end_of_arg <= i:
                next_comma = -1
                i = end_of_arg + 1
            else:
                next_comma = signature.find(',', i, end_of_arg)
                if next_comma < 0:
                    next_comma = end_of_arg
        ufunc.core_num_dims[cur_arg] = nd
        ufunc.core_offsets[cur_arg] = cur_core_dim - nd
        cur_arg += 1
        nd = 0
        if i < len(signature):
            i = _next_non_white_space(signature, i)
        if cur_arg != ufunc.nin and cur_arg != ufunc.nargs:
            # The list of input arguments (or output arguments) was
            # only read partially
            if signature[i] != ',':
                raise oefmt(space.w_ValueError, '%s at %d in "%s"',
                    "expect ','", i, signature)
            i = _next_non_white_space(signature, i + 1);
    if cur_arg != ufunc.nargs:
        raise oefmt(space.w_ValueError, '%s at %d in "%s"',
            "incomplete signature: not all arguments found", i, signature)
    if cur_core_dim == 0:
        ufunc.core_enabled = False
    return 0 # for historical reasons, any failures will raise

def get_storage_as_int(storage, start=0):
        return rffi.cast(lltype.Signed, storage) + start

def is_rhs_priority_higher(space, w_lhs, w_rhs):
    w_zero = space.newfloat(0.0)
    w_priority_l = space.findattr(w_lhs, space.newtext('__array_priority__')) or w_zero
    w_priority_r = space.findattr(w_rhs, space.newtext('__array_priority__')) or w_zero
    # XXX what is better, unwrapping values or space.gt?
    return space.is_true(space.gt(w_priority_r, w_priority_l))

def get_order_as_CF(proto_order, req_order):
    if req_order == NPY.CORDER:
        return NPY.CORDER
    elif req_order == NPY.FORTRANORDER:
        return NPY.FORTRANORDER
    return proto_order

def descr_set_docstring(space, w_obj, w_docstring):
    if not isinstance(space, StdObjSpace):
        raise oefmt(space.w_NotImplementedError,
                    "This only works with the real object space")
    if isinstance(w_obj, W_TypeObject):
        w_obj.w_doc = w_docstring
        return
    elif isinstance(w_obj, GetSetProperty):
        if space.is_none(w_docstring):
            doc = None
        else:
            doc = space.text_w(w_docstring)
        w_obj.doc = doc
        return
    app_set_docstring(space, w_obj, w_docstring)

app_set_docstring = appdef("""app_set_docstring_(obj, docstring):
    import types
    if isinstance(obj, types.MethodType):
        obj.im_func.__doc__ = docstring
    else:
        obj.__doc__ = docstring
""")
