from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec
from pypy.module.micronumpy import loop, descriptor, support
from pypy.module.micronumpy import constants as NPY
from pypy.module.micronumpy.base import convert_to_array, W_NDimArray
from pypy.module.micronumpy.converters import clipmode_converter
from pypy.module.micronumpy.strides import (
    Chunk, new_view, shape_agreement, shape_agreement_multiple)
from .casting import find_binop_result_dtype, find_result_type


def where(space, w_arr, w_x=None, w_y=None):
    """where(condition, [x, y])

    Return elements, either from `x` or `y`, depending on `condition`.

    If only `condition` is given, return ``condition.nonzero()``.

    Parameters
    ----------
    condition : array_like, bool
        When True, yield `x`, otherwise yield `y`.
    x, y : array_like, optional
        Values from which to choose. `x` and `y` need to have the same
        shape as `condition`.

    Returns
    -------
    out : ndarray or tuple of ndarrays
        If both `x` and `y` are specified, the output array contains
        elements of `x` where `condition` is True, and elements from
        `y` elsewhere.

        If only `condition` is given, return the tuple
        ``condition.nonzero()``, the indices where `condition` is True.

    See Also
    --------
    nonzero, choose

    Notes
    -----
    If `x` and `y` are given and input arrays are 1-D, `where` is
    equivalent to::

        [xv if c else yv for (c,xv,yv) in zip(condition,x,y)]

    Examples
    --------
    >>> np.where([[True, False], [True, True]],
    ...          [[1, 2], [3, 4]],
    ...          [[9, 8], [7, 6]])
    array([[1, 8],
           [3, 4]])

    >>> np.where([[0, 1], [1, 0]])
    (array([0, 1]), array([1, 0]))

    >>> x = np.arange(9.).reshape(3, 3)
    >>> np.where( x > 5 )
    (array([2, 2, 2]), array([0, 1, 2]))
    >>> x[np.where( x > 3.0 )]               # Note: result is 1D.
    array([ 4.,  5.,  6.,  7.,  8.])
    >>> np.where(x < 5, x, -1)               # Note: broadcasting.
    array([[ 0.,  1.,  2.],
           [ 3.,  4., -1.],
           [-1., -1., -1.]])


    NOTE: support for not passing x and y is unsupported
    """
    if space.is_none(w_y):
        if space.is_none(w_x):
            arr = convert_to_array(space, w_arr)
            return arr.descr_nonzero(space)
        raise oefmt(space.w_ValueError,
                    "Where should be called with either 1 or 3 arguments")
    if space.is_none(w_x):
        raise oefmt(space.w_ValueError,
                    "Where should be called with either 1 or 3 arguments")
    arr = convert_to_array(space, w_arr)
    x = convert_to_array(space, w_x)
    y = convert_to_array(space, w_y)
    if x.is_scalar() and y.is_scalar() and arr.is_scalar():
        if arr.get_dtype().itemtype.bool(arr.get_scalar_value()):
            return x
        return y
    dtype = find_result_type(space, [x, y], [])
    shape = shape_agreement(space, arr.get_shape(), x)
    shape = shape_agreement(space, shape, y)
    out = W_NDimArray.from_shape(space, shape, dtype)
    return loop.where(space, out, shape, arr, x, y, dtype)


def dot(space, w_obj1, w_obj2, w_out=None):
    w_arr = convert_to_array(space, w_obj1)
    if w_arr.is_scalar():
        return convert_to_array(space, w_obj2).descr_dot(space, w_arr, w_out)
    return w_arr.descr_dot(space, w_obj2, w_out)


def concatenate(space, w_args, w_axis=None):
    args_w = space.listview(w_args)
    if len(args_w) == 0:
        raise oefmt(space.w_ValueError, "need at least one array to concatenate")
    args_w = [convert_to_array(space, w_arg) for w_arg in args_w]
    if w_axis is None:
        w_axis = space.newint(0)
    if space.is_none(w_axis):
        args_w = [w_arg.reshape(space,
                                space.newlist([w_arg.descr_get_size(space)]),
                                w_arg.get_order())
                  for w_arg in args_w]
        w_axis = space.newint(0)
    dtype = args_w[0].get_dtype()
    shape = args_w[0].get_shape()[:]
    ndim = len(shape)
    if ndim == 0:
        raise oefmt(space.w_ValueError,
                    "zero-dimensional arrays cannot be concatenated")
    axis = space.int_w(w_axis)
    orig_axis = axis
    if axis < 0:
        axis = ndim + axis
    if ndim == 1 and axis != 0:
        axis = 0
    if axis < 0 or axis >= ndim:
        raise oefmt(space.w_IndexError, "axis %d out of bounds [0, %d)",
                    orig_axis, ndim)
    for arr in args_w[1:]:
        if len(arr.get_shape()) != ndim:
            raise oefmt(space.w_ValueError,
                        "all the input arrays must have same number of "
                        "dimensions")
        for i, axis_size in enumerate(arr.get_shape()):
            if i == axis:
                shape[i] += axis_size
            elif axis_size != shape[i]:
                raise oefmt(space.w_ValueError,
                            "all the input array dimensions except for the "
                            "concatenation axis must match exactly")

    dtype = find_result_type(space, args_w, [])
    # concatenate does not handle ndarray subtypes, it always returns a ndarray
    res = W_NDimArray.from_shape(space, shape, dtype, NPY.CORDER)
    chunks = [Chunk(0, i, 1, i) for i in shape]
    axis_start = 0
    for arr in args_w:
        if arr.get_shape()[axis] == 0:
            continue
        chunks[axis] = Chunk(axis_start, axis_start + arr.get_shape()[axis], 1,
                             arr.get_shape()[axis])
        view = new_view(space, res, chunks)
        view.implementation.setslice(space, arr)
        axis_start += arr.get_shape()[axis]
    return res


@unwrap_spec(repeats=int)
def repeat(space, w_arr, repeats, w_axis):
    arr = convert_to_array(space, w_arr)
    if space.is_none(w_axis):
        arr = arr.descr_flatten(space)
        orig_size = arr.get_shape()[0]
        shape = [arr.get_shape()[0] * repeats]
        w_res = W_NDimArray.from_shape(space, shape, arr.get_dtype(), w_instance=arr)
        for i in range(repeats):
            chunks = [Chunk(i, shape[0] - repeats + i, repeats, orig_size)]
            view = new_view(space, w_res, chunks)
            view.implementation.setslice(space, arr)
    else:
        axis = space.int_w(w_axis)
        shape = arr.get_shape()[:]
        chunks = [Chunk(0, i, 1, i) for i in shape]
        orig_size = shape[axis]
        shape[axis] *= repeats
        w_res = W_NDimArray.from_shape(space, shape, arr.get_dtype(), w_instance=arr)
        for i in range(repeats):
            chunks[axis] = Chunk(i, shape[axis] - repeats + i, repeats,
                                 orig_size)
            view = new_view(space, w_res, chunks)
            view.implementation.setslice(space, arr)
    return w_res


def count_nonzero(space, w_obj):
    return space.newint(loop.count_all_true(convert_to_array(space, w_obj)))


def choose(space, w_arr, w_choices, w_out, w_mode):
    arr = convert_to_array(space, w_arr)
    choices = [convert_to_array(space, w_item) for w_item
               in space.listview(w_choices)]
    if not choices:
        raise oefmt(space.w_ValueError, "choices list cannot be empty")
    if space.is_none(w_out):
        w_out = None
    elif not isinstance(w_out, W_NDimArray):
        raise oefmt(space.w_TypeError, "return arrays must be of ArrayType")
    shape = shape_agreement_multiple(space, choices + [w_out])
    out = descriptor.dtype_agreement(space, choices, shape, w_out)
    dtype = out.get_dtype()
    mode = clipmode_converter(space, w_mode)
    loop.choose(space, arr, choices, shape, dtype, out, mode)
    return out


def put(space, w_arr, w_indices, w_values, w_mode):
    arr = convert_to_array(space, w_arr)
    mode = clipmode_converter(space, w_mode)

    if not w_indices:
        raise oefmt(space.w_ValueError, "indices list cannot be empty")
    if not w_values:
        raise oefmt(space.w_ValueError, "value list cannot be empty")

    dtype = arr.get_dtype()

    if space.isinstance_w(w_indices, space.w_list):
        indices = space.listview(w_indices)
    else:
        indices = [w_indices]

    if space.isinstance_w(w_values, space.w_list):
        values = space.listview(w_values)
    else:
        values = [w_values]

    v_idx = 0
    for idx in indices:
        index = support.index_w(space, idx)

        if index < 0 or index >= arr.get_size():
            if mode == NPY.RAISE:
                raise oefmt(space.w_IndexError,
                    "index %d is out of bounds for axis 0 with size %d",
                    index, arr.get_size())
            elif mode == NPY.WRAP:
                index = index % arr.get_size()
            elif mode == NPY.CLIP:
                if index < 0:
                    index = 0
                else:
                    index = arr.get_size() - 1
            else:
                assert False

        value = values[v_idx]

        if v_idx + 1 < len(values):
            v_idx += 1

        arr.setitem(space, [index], dtype.coerce(space, value))


def diagonal(space, arr, offset, axis1, axis2):
    shape = arr.get_shape()
    shapelen = len(shape)
    if offset < 0:
        offset = -offset
        axis1, axis2 = axis2, axis1
    size = min(shape[axis1], shape[axis2] - offset)
    dtype = arr.dtype
    if axis1 < axis2:
        shape = (shape[:axis1] + shape[axis1 + 1:axis2] +
                 shape[axis2 + 1:] + [size])
    else:
        shape = (shape[:axis2] + shape[axis2 + 1:axis1] +
                 shape[axis1 + 1:] + [size])
    out = W_NDimArray.from_shape(space, shape, dtype)
    if size == 0:
        return out
    if shapelen == 2:
        # simple case
        loop.diagonal_simple(space, arr, out, offset, axis1, axis2, size)
    else:
        loop.diagonal_array(space, arr, out, offset, axis1, axis2, shape)
    return out
