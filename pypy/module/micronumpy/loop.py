""" This file is the main run loop as well as evaluation loops for various
operations. This is the place to look for all the computations that iterate
over all the array elements.
"""
import py
from pypy.interpreter.error import oefmt
from rpython.rlib import jit
from rpython.rlib.rstring import StringBuilder
from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.module.micronumpy import support, constants as NPY
from pypy.module.micronumpy.base import W_NDimArray, convert_to_array
from pypy.module.micronumpy.iterators import PureShapeIter, AxisIter, \
    AllButAxisIter, ArrayIter
from pypy.interpreter.argument import Arguments


def call2(space, shape, func, calc_dtype, w_lhs, w_rhs, out):
    if w_lhs.get_size() == 1:
        w_left = w_lhs.get_scalar_value().convert_to(space, calc_dtype)
        left_iter = left_state = None
    else:
        w_left = None
        left_iter, left_state = w_lhs.create_iter(shape)
        left_iter.track_index = False

    if w_rhs.get_size() == 1:
        w_right = w_rhs.get_scalar_value().convert_to(space, calc_dtype)
        right_iter = right_state = None
    else:
        w_right = None
        right_iter, right_state = w_rhs.create_iter(shape)
        right_iter.track_index = False

    out_iter, out_state = out.create_iter(shape)
    shapelen = len(shape)
    res_dtype = out.get_dtype()
    call2_func = try_to_share_iterators_call2(left_iter, right_iter,
            left_state, right_state, out_state)
    params = (space, shapelen, func, calc_dtype, res_dtype, out,
              w_left, w_right, left_iter, right_iter, out_iter,
              left_state, right_state, out_state)
    return call2_func(*params)

def try_to_share_iterators_call2(left_iter, right_iter, left_state, right_state, out_state):
    # these are all possible iterator sharing combinations
    # left == right == out
    # left == right
    # left == out
    # right == out
    right_out_equal = False
    if right_iter:
        # rhs is not a scalar
        if out_state.same(right_state):
            right_out_equal = True
    #
    if not left_iter:
        # lhs is a scalar
        if right_out_equal:
            return call2_advance_out_left
        else:
            # worst case, nothing can be shared and lhs is a scalar
            return call2_advance_out_left_right
    else:
        # lhs is NOT a scalar
        if out_state.same(left_state):
            # (2) out and left are the same -> remove left
            if right_out_equal:
                # the best case
                return call2_advance_out
            else:
                return call2_advance_out_right
        else:
            if right_out_equal:
                # right and out are equal, only advance left and out
                return call2_advance_out_left
            else:
                if right_iter and right_state.same(left_state):
                    # left and right are equal, but still need to advance out
                    return call2_advance_out_left_eq_right
                else:
                    # worst case, nothing can be shared
                    return call2_advance_out_left_right

    assert 0, "logical problem with the selection of the call2 case"

def generate_call2_cases(name, left_state, right_state):
    call2_driver = jit.JitDriver(name='numpy_call2_' + name,
        greens=['shapelen', 'func', 'calc_dtype', 'res_dtype'],
        reds='auto', vectorize=True)
    #
    advance_left_state = left_state == "left_state"
    advance_right_state = right_state == "right_state"
    code = """
    def method(space, shapelen, func, calc_dtype, res_dtype, out,
               w_left, w_right, left_iter, right_iter, out_iter,
               left_state, right_state, out_state):
        while not out_iter.done(out_state):
            call2_driver.jit_merge_point(shapelen=shapelen, func=func,
                    calc_dtype=calc_dtype, res_dtype=res_dtype)
            if left_iter:
                w_left = left_iter.getitem({left_state}).convert_to(space, calc_dtype)
            if right_iter:
                w_right = right_iter.getitem({right_state}).convert_to(space, calc_dtype)
            w_out = func(calc_dtype, w_left, w_right)
            out_iter.setitem(out_state, w_out.convert_to(space, res_dtype))
            out_state = out_iter.next(out_state)
            if advance_left_state and left_iter:
                left_state = left_iter.next(left_state)
            if advance_right_state and right_iter:
                right_state = right_iter.next(right_state)
            #
            # if not set to None, the values will be loop carried
            # (for the var,var case), forcing the vectorization to unpack
            # the vector registers at the end of the loop
            if left_iter:
                w_left = None
            if right_iter:
                w_right = None
        return out
    """
    exec(py.code.Source(code.format(left_state=left_state,right_state=right_state)).compile(), locals())
    method.__name__ = "call2_" + name
    return method

call2_advance_out = generate_call2_cases("inc_out", "out_state", "out_state")
call2_advance_out_left = generate_call2_cases("inc_out_left", "left_state", "out_state")
call2_advance_out_right = generate_call2_cases("inc_out_right", "out_state", "right_state")
call2_advance_out_left_eq_right = generate_call2_cases("inc_out_left_eq_right", "left_state", "left_state")
call2_advance_out_left_right = generate_call2_cases("inc_out_left_right", "left_state", "right_state")

call1_driver = jit.JitDriver(
    name='numpy_call1',
    greens=['shapelen', 'share_iterator', 'func', 'calc_dtype', 'res_dtype'],
    reds='auto', vectorize=True)

def call1(space, shape, func, calc_dtype, w_obj, w_ret):
    obj_iter, obj_state = w_obj.create_iter(shape)
    obj_iter.track_index = False
    out_iter, out_state = w_ret.create_iter(shape)
    shapelen = len(shape)
    res_dtype = w_ret.get_dtype()
    share_iterator = out_state.same(obj_state)
    while not out_iter.done(out_state):
        call1_driver.jit_merge_point(shapelen=shapelen, func=func,
                                     share_iterator=share_iterator,
                                     calc_dtype=calc_dtype, res_dtype=res_dtype)
        if share_iterator:
            # use out state as param to getitem
            elem = obj_iter.getitem(out_state).convert_to(space, calc_dtype)
        else:
            elem = obj_iter.getitem(obj_state).convert_to(space, calc_dtype)
        out_iter.setitem(out_state, func(calc_dtype, elem).convert_to(space, res_dtype))
        if share_iterator:
            # only advance out, they share the same iteration space
            out_state = out_iter.next(out_state)
        else:
            out_state = out_iter.next(out_state)
            obj_state = obj_iter.next(obj_state)
        elem = None
    return w_ret

call_many_to_one_driver = jit.JitDriver(
    name='numpy_call_many_to_one',
    greens=['shapelen', 'nin', 'func', 'in_dtypes', 'res_dtype'],
    reds='auto')

def call_many_to_one(space, shape, func, in_dtypes, res_dtype, in_args, out):
    # out must hav been built. func needs no calc_type, is usually an
    # external ufunc
    nin = len(in_args)
    in_iters = [None] * nin
    in_states = [None] * nin
    for i in range(nin):
        in_i = in_args[i]
        assert isinstance(in_i, W_NDimArray)
        in_iter, in_state = in_i.create_iter(shape)
        in_iters[i] = in_iter
        in_states[i] = in_state
    shapelen = len(shape)
    assert isinstance(out, W_NDimArray)
    out_iter, out_state = out.create_iter(shape)
    vals = [None] * nin
    while not out_iter.done(out_state):
        call_many_to_one_driver.jit_merge_point(shapelen=shapelen, func=func,
                        in_dtypes=in_dtypes, res_dtype=res_dtype, nin=nin)
        for i in range(nin):
            vals[i] = in_dtypes[i].coerce(space, in_iters[i].getitem(in_states[i]))
        w_arglist = space.newlist(vals)
        w_out_val = space.call_args(func, Arguments.frompacked(space, w_arglist))
        out_iter.setitem(out_state, res_dtype.coerce(space, w_out_val))
        for i in range(nin):
            in_states[i] = in_iters[i].next(in_states[i])
        out_state = out_iter.next(out_state)
    return out

call_many_to_many_driver = jit.JitDriver(
    name='numpy_call_many_to_many',
    greens=['shapelen', 'nin', 'nout', 'func', 'in_dtypes', 'out_dtypes'],
    reds='auto')

def call_many_to_many(space, shape, func, in_dtypes, out_dtypes, in_args, out_args):
    # out must have been built. func needs no calc_type, is usually an
    # external ufunc
    nin = len(in_args)
    in_iters = [None] * nin
    in_states = [None] * nin
    nout = len(out_args)
    out_iters = [None] * nout
    out_states = [None] * nout
    for i in range(nin):
        in_i = in_args[i]
        assert isinstance(in_i, W_NDimArray)
        in_iter, in_state = in_i.create_iter(shape)
        in_iters[i] = in_iter
        in_states[i] = in_state
    for i in range(nout):
        out_i = out_args[i]
        assert isinstance(out_i, W_NDimArray)
        out_iter, out_state = out_i.create_iter(shape)
        out_iters[i] = out_iter
        out_states[i] = out_state
    shapelen = len(shape)
    vals = [None] * nin
    test_iter, test_state = in_iters[-1], in_states[-1]
    if nout > 0:
        test_iter, test_state = out_iters[0], out_states[0]
    while not test_iter.done(test_state):
        call_many_to_many_driver.jit_merge_point(shapelen=shapelen, func=func,
                             in_dtypes=in_dtypes, out_dtypes=out_dtypes,
                             nin=nin, nout=nout)
        for i in range(nin):
            vals[i] = in_dtypes[i].coerce(space, in_iters[i].getitem(in_states[i]))
        w_arglist = space.newlist(vals)
        w_outvals = space.call_args(func, Arguments.frompacked(space, w_arglist))
        # w_outvals should be a tuple, but func can return a single value as well 
        if space.isinstance_w(w_outvals, space.w_tuple):
            batch = space.listview(w_outvals)
            for i in range(len(batch)):
                out_iters[i].setitem(out_states[i], out_dtypes[i].coerce(space, batch[i]))
                out_states[i] = out_iters[i].next(out_states[i])
        elif nout > 0:
            out_iters[0].setitem(out_states[0], out_dtypes[0].coerce(space, w_outvals))
            out_states[0] = out_iters[0].next(out_states[0])
        for i in range(nin):
            in_states[i] = in_iters[i].next(in_states[i])
        test_state = test_iter.next(test_state)
    return space.newtuple([convert_to_array(space, o) for o in out_args])

setslice_driver = jit.JitDriver(name='numpy_setslice',
                                greens = ['shapelen', 'dtype'],
                                reds = 'auto', vectorize=True)

def setslice(space, shape, target, source):
    if not shape:
        dtype = target.dtype
        val = source.getitem(source.start)
        if dtype.is_str_or_unicode():
            val = dtype.coerce(space, val)
        else:
            val = val.convert_to(space, dtype)
        target.setitem(target.start, val)
        return target
    return _setslice(space, shape, target, source)

def _setslice(space, shape, target, source):
    # note that unlike everything else, target and source here are
    # array implementations, not arrays
    target_iter, target_state = target.create_iter(shape)
    source_iter, source_state = source.create_iter(shape)
    source_iter.track_index = False
    dtype = target.dtype
    shapelen = len(shape)
    while not target_iter.done(target_state):
        setslice_driver.jit_merge_point(shapelen=shapelen, dtype=dtype)
        val = source_iter.getitem(source_state)
        if dtype.is_str_or_unicode() or dtype.is_record():
            val = dtype.coerce(space, val)
        else:
            val = val.convert_to(space, dtype)
        target_iter.setitem(target_state, val)
        target_state = target_iter.next(target_state)
        source_state = source_iter.next(source_state)
    return target


def split_iter(arr, axis_flags):
    """Prepare 2 iterators for nested iteration over `arr`.

    Arguments:
        arr: instance of BaseConcreteArray
        axis_flags: list of bools, one for each dimension of `arr`.The inner
        iterator operates over the dimensions for which the flag is True
    """
    shape = arr.get_shape()
    strides = arr.get_strides()
    backstrides = arr.get_backstrides()
    shapelen = len(shape)
    assert len(axis_flags) == shapelen
    inner_shape = [-1] * shapelen
    inner_strides = [-1] * shapelen
    inner_backstrides = [-1] * shapelen
    outer_shape = [-1] * shapelen
    outer_strides = [-1] * shapelen
    outer_backstrides = [-1] * shapelen
    for i in range(len(shape)):
        if axis_flags[i]:
            inner_shape[i] = shape[i]
            inner_strides[i] = strides[i]
            inner_backstrides[i] = backstrides[i]
            outer_shape[i] = 1
            outer_strides[i] = 0
            outer_backstrides[i] = 0
        else:
            outer_shape[i] = shape[i]
            outer_strides[i] = strides[i]
            outer_backstrides[i] = backstrides[i]
            inner_shape[i] = 1
            inner_strides[i] = 0
            inner_backstrides[i] = 0
    inner_iter = ArrayIter(arr, support.product(inner_shape),
                           inner_shape, inner_strides, inner_backstrides)
    outer_iter = ArrayIter(arr, support.product(outer_shape),
                           outer_shape, outer_strides, outer_backstrides)
    return inner_iter, outer_iter


reduce_flat_driver = jit.JitDriver(
    name='numpy_reduce_flat',
    greens = ['shapelen', 'func', 'done_func', 'calc_dtype'], reds = 'auto',
    vectorize = True)

def reduce_flat(space, func, w_arr, calc_dtype, done_func, identity):
    obj_iter, obj_state = w_arr.create_iter()
    if identity is None:
        cur_value = obj_iter.getitem(obj_state).convert_to(space, calc_dtype)
        obj_state = obj_iter.next(obj_state)
    else:
        cur_value = identity.convert_to(space, calc_dtype)
    shapelen = len(w_arr.get_shape())
    while not obj_iter.done(obj_state):
        reduce_flat_driver.jit_merge_point(
            shapelen=shapelen, func=func,
            done_func=done_func, calc_dtype=calc_dtype)
        rval = obj_iter.getitem(obj_state).convert_to(space, calc_dtype)
        if done_func is not None and done_func(calc_dtype, rval):
            return rval
        cur_value = func(calc_dtype, cur_value, rval)
        obj_state = obj_iter.next(obj_state)
    return cur_value

reduce_driver = jit.JitDriver(
    name='numpy_reduce',
    greens=['shapelen', 'func', 'dtype'], reds='auto',
    vectorize=True)

def reduce(space, func, w_arr, axis_flags, dtype, out, identity):
    out_iter, out_state = out.create_iter()
    out_iter.track_index = False
    shape = w_arr.get_shape()
    shapelen = len(shape)
    inner_iter, outer_iter = split_iter(w_arr.implementation, axis_flags)
    assert outer_iter.size == out_iter.size

    if identity is not None:
        identity = identity.convert_to(space, dtype)
    outer_state = outer_iter.reset()
    while not outer_iter.done(outer_state):
        inner_state = inner_iter.reset()
        inner_state.offset = outer_state.offset
        if identity is not None:
            w_val = identity
        else:
            w_val = inner_iter.getitem(inner_state).convert_to(space, dtype)
            inner_state = inner_iter.next(inner_state)
        while not inner_iter.done(inner_state):
            reduce_driver.jit_merge_point(
                shapelen=shapelen, func=func, dtype=dtype)
            w_item = inner_iter.getitem(inner_state).convert_to(space, dtype)
            w_val = func(dtype, w_item, w_val)
            inner_state = inner_iter.next(inner_state)
        out_iter.setitem(out_state, w_val)
        out_state = out_iter.next(out_state)
        outer_state = outer_iter.next(outer_state)
    return out

accumulate_flat_driver = jit.JitDriver(
    name='numpy_accumulate_flat',
    greens=['shapelen', 'func', 'dtype', 'out_dtype'],
    reds='auto', vectorize=True)

def accumulate_flat(space, func, w_arr, calc_dtype, w_out, identity):
    arr_iter, arr_state = w_arr.create_iter()
    out_iter, out_state = w_out.create_iter()
    out_iter.track_index = False
    if identity is None:
        cur_value = arr_iter.getitem(arr_state).convert_to(space, calc_dtype)
        out_iter.setitem(out_state, cur_value)
        out_state = out_iter.next(out_state)
        arr_state = arr_iter.next(arr_state)
    else:
        cur_value = identity.convert_to(space, calc_dtype)
    shapelen = len(w_arr.get_shape())
    out_dtype = w_out.get_dtype()
    while not arr_iter.done(arr_state):
        accumulate_flat_driver.jit_merge_point(
            shapelen=shapelen, func=func, dtype=calc_dtype,
            out_dtype=out_dtype)
        w_item = arr_iter.getitem(arr_state).convert_to(space, calc_dtype)
        cur_value = func(calc_dtype, cur_value, w_item)
        out_iter.setitem(out_state, out_dtype.coerce(space, cur_value))
        out_state = out_iter.next(out_state)
        arr_state = arr_iter.next(arr_state)

accumulate_driver = jit.JitDriver(
    name='numpy_accumulate',
    greens=['shapelen', 'func', 'calc_dtype'],
    reds='auto',
    vectorize=True)


def accumulate(space, func, w_arr, axis, calc_dtype, w_out, identity):
    out_iter, out_state = w_out.create_iter()
    arr_shape = w_arr.get_shape()
    temp_shape = arr_shape[:axis] + arr_shape[axis + 1:]
    temp = W_NDimArray.from_shape(space, temp_shape, calc_dtype, w_instance=w_arr)
    temp_iter = AxisIter(temp.implementation, w_arr.get_shape(), axis)
    temp_state = temp_iter.reset()
    arr_iter, arr_state = w_arr.create_iter()
    arr_iter.track_index = False
    if identity is not None:
        identity = identity.convert_to(space, calc_dtype)
    shapelen = len(arr_shape)
    while not out_iter.done(out_state):
        accumulate_driver.jit_merge_point(shapelen=shapelen, func=func,
                                          calc_dtype=calc_dtype)
        w_item = arr_iter.getitem(arr_state).convert_to(space, calc_dtype)
        arr_state = arr_iter.next(arr_state)

        out_indices = out_iter.indices(out_state)
        if out_indices[axis] == 0:
            if identity is not None:
                w_item = func(calc_dtype, identity, w_item)
        else:
            cur_value = temp_iter.getitem(temp_state)
            w_item = func(calc_dtype, cur_value, w_item)

        out_iter.setitem(out_state, w_item)
        out_state = out_iter.next(out_state)
        temp_iter.setitem(temp_state, w_item)
        temp_state = temp_iter.next(temp_state)
    return w_out

def fill(arr, box):
    arr_iter, arr_state = arr.create_iter()
    while not arr_iter.done(arr_state):
        arr_iter.setitem(arr_state, box)
        arr_state = arr_iter.next(arr_state)

def assign(space, arr, seq):
    arr_iter, arr_state = arr.create_iter()
    arr_dtype = arr.get_dtype()
    for item in seq:
        arr_iter.setitem(arr_state, arr_dtype.coerce(space, item))
        arr_state = arr_iter.next(arr_state)

where_driver = jit.JitDriver(name='numpy_where',
                             greens = ['shapelen', 'dtype', 'arr_dtype'],
                             reds = 'auto',
                             vectorize=True)

def where(space, out, shape, arr, x, y, dtype):
    out_iter, out_state = out.create_iter(shape)
    arr_iter, arr_state = arr.create_iter(shape)
    arr_dtype = arr.get_dtype()
    x_iter, x_state = x.create_iter(shape)
    y_iter, y_state = y.create_iter(shape)
    if x.is_scalar():
        if y.is_scalar():
            iter, state = arr_iter, arr_state
        else:
            iter, state = y_iter, y_state
    else:
        iter, state = x_iter, x_state
    out_iter.track_index = x_iter.track_index = False
    arr_iter.track_index = y_iter.track_index = False
    iter.track_index = True
    shapelen = len(shape)
    while not iter.done(state):
        where_driver.jit_merge_point(shapelen=shapelen, dtype=dtype,
                                        arr_dtype=arr_dtype)
        w_cond = arr_iter.getitem(arr_state)
        if arr_dtype.itemtype.bool(w_cond):
            w_val = x_iter.getitem(x_state).convert_to(space, dtype)
        else:
            w_val = y_iter.getitem(y_state).convert_to(space, dtype)
        out_iter.setitem(out_state, w_val)
        out_state = out_iter.next(out_state)
        arr_state = arr_iter.next(arr_state)
        x_state = x_iter.next(x_state)
        y_state = y_iter.next(y_state)
        if x.is_scalar():
            if y.is_scalar():
                state = arr_state
            else:
                state = y_state
        else:
            state = x_state
    return out

def _new_argmin_argmax(op_name):
    arg_driver = jit.JitDriver(name='numpy_' + op_name,
                               greens = ['shapelen', 'dtype'],
                               reds = 'auto')
    arg_flat_driver = jit.JitDriver(name='numpy_flat_' + op_name,
                                    greens = ['shapelen', 'dtype'],
                                    reds = 'auto')

    def argmin_argmax(space, w_arr, w_out, axis):
        from pypy.module.micronumpy.descriptor import get_dtype_cache
        dtype = w_arr.get_dtype()
        shapelen = len(w_arr.get_shape())
        axis_flags = [False] * shapelen
        axis_flags[axis] = True
        inner_iter, outer_iter = split_iter(w_arr.implementation, axis_flags)
        outer_state = outer_iter.reset()
        out_iter, out_state = w_out.create_iter()
        while not outer_iter.done(outer_state):
            inner_state = inner_iter.reset()
            inner_state.offset = outer_state.offset
            cur_best = inner_iter.getitem(inner_state)
            inner_state = inner_iter.next(inner_state)
            result = 0
            idx = 1
            while not inner_iter.done(inner_state):
                arg_driver.jit_merge_point(shapelen=shapelen, dtype=dtype)
                w_val = inner_iter.getitem(inner_state)
                old_best = getattr(dtype.itemtype, op_name)(cur_best, w_val)
                if not old_best:
                    result = idx
                    cur_best = w_val
                inner_state = inner_iter.next(inner_state)
                idx += 1
            result = get_dtype_cache(space).w_longdtype.box(result)
            out_iter.setitem(out_state, result)
            out_state = out_iter.next(out_state)
            outer_state = outer_iter.next(outer_state)
        return w_out

    def argmin_argmax_flat(w_arr):
        result = 0
        idx = 1
        dtype = w_arr.get_dtype()
        iter, state = w_arr.create_iter()
        cur_best = iter.getitem(state)
        state = iter.next(state)
        shapelen = len(w_arr.get_shape())
        while not iter.done(state):
            arg_flat_driver.jit_merge_point(shapelen=shapelen, dtype=dtype)
            w_val = iter.getitem(state)
            old_best = getattr(dtype.itemtype, op_name)(cur_best, w_val)
            if not old_best:
                result = idx
                cur_best = w_val
            state = iter.next(state)
            idx += 1
        return result

    return argmin_argmax, argmin_argmax_flat
argmin, argmin_flat = _new_argmin_argmax('argmin')
argmax, argmax_flat = _new_argmin_argmax('argmax')

dot_driver = jit.JitDriver(name = 'numpy_dot',
                           greens = ['dtype'],
                           reds = 'auto',
                           vectorize=True)

def multidim_dot(space, left, right, result, dtype, right_critical_dim):
    ''' assumes left, right are concrete arrays
    given left.shape == [3, 5, 7],
          right.shape == [2, 7, 4]
    then
     result.shape == [3, 5, 2, 4]
     broadcast shape should be [3, 5, 2, 7, 4]
     result should skip dims 3 which is len(result_shape) - 1
        (note that if right is 1d, result should
                  skip len(result_shape))
     left should skip 2, 4 which is a.ndims-1 + range(right.ndims)
          except where it==(right.ndims-2)
     right should skip 0, 1
    '''
    left_shape = left.get_shape()
    right_shape = right.get_shape()
    left_impl = left.implementation
    right_impl = right.implementation
    assert left_shape[-1] == right_shape[right_critical_dim]
    assert result.get_dtype() == dtype
    outi, outs = result.create_iter()
    outi.track_index = False
    lefti = AllButAxisIter(left_impl, len(left_shape) - 1)
    righti = AllButAxisIter(right_impl, right_critical_dim)
    lefts = lefti.reset()
    rights = righti.reset()
    n = left_impl.shape[-1]
    s1 = left_impl.strides[-1]
    s2 = right_impl.strides[right_critical_dim]
    while not lefti.done(lefts):
        while not righti.done(rights):
            oval = outi.getitem(outs)
            i1 = lefts.offset
            i2 = rights.offset
            i = 0
            while i < n:
                i += 1
                dot_driver.jit_merge_point(dtype=dtype)
                lval = left_impl.getitem(i1).convert_to(space, dtype)
                rval = right_impl.getitem(i2).convert_to(space, dtype)
                oval = dtype.itemtype.add(oval, dtype.itemtype.mul(lval, rval))
                i1 += jit.promote(s1)
                i2 += jit.promote(s2)
            outi.setitem(outs, oval)
            outs = outi.next(outs)
            rights = righti.next(rights)
        rights = righti.reset(rights)
        lefts = lefti.next(lefts)
    return result

count_all_true_driver = jit.JitDriver(name = 'numpy_count',
                                      greens = ['shapelen', 'dtype'],
                                      reds = 'auto',
                                      vectorize=True)

def count_all_true_concrete(impl):
    s = 0
    iter, state = impl.create_iter()
    shapelen = len(impl.shape)
    dtype = impl.dtype
    while not iter.done(state):
        count_all_true_driver.jit_merge_point(shapelen=shapelen, dtype=dtype)
        s += iter.getitem_bool(state)
        state = iter.next(state)
    return s

def count_all_true(arr):
    if arr.is_scalar():
        return arr.get_dtype().itemtype.bool(arr.get_scalar_value())
    else:
        return count_all_true_concrete(arr.implementation)

nonzero_driver = jit.JitDriver(name = 'numpy_nonzero',
                               greens = ['shapelen', 'dims', 'dtype'],
                               reds = 'auto',
                               vectorize=True)

def nonzero(res, arr, box):
    res_iter, res_state = res.create_iter()
    arr_iter, arr_state = arr.create_iter()
    shapelen = len(arr.shape)
    dtype = arr.dtype
    dims = range(shapelen)
    while not arr_iter.done(arr_state):
        nonzero_driver.jit_merge_point(shapelen=shapelen, dims=dims, dtype=dtype)
        if arr_iter.getitem_bool(arr_state):
            arr_indices = arr_iter.indices(arr_state)
            for d in dims:
                res_iter.setitem(res_state, box(arr_indices[d]))
                res_state = res_iter.next(res_state)
        arr_state = arr_iter.next(arr_state)
    return res


getitem_filter_driver = jit.JitDriver(name = 'numpy_getitem_bool',
                                      greens = ['shapelen', 'arr_dtype',
                                                'index_dtype'],
                                      reds = 'auto',
                                      vectorize=True)

def getitem_filter(res, arr, index):
    res_iter, res_state = res.create_iter()
    shapelen = len(arr.get_shape())
    if shapelen > 1 and len(index.get_shape()) < 2:
        index_iter, index_state = index.create_iter(arr.get_shape(), backward_broadcast=True)
    else:
        index_iter, index_state = index.create_iter()
    arr_iter, arr_state = arr.create_iter()
    arr_dtype = arr.get_dtype()
    index_dtype = index.get_dtype()
    # support the deprecated form where arr([True]) will return arr[0, ...]
    # by iterating over res_iter, not index_iter
    while not res_iter.done(res_state):
        getitem_filter_driver.jit_merge_point(shapelen=shapelen,
                                              index_dtype=index_dtype,
                                              arr_dtype=arr_dtype,
                                              )
        if index_iter.getitem_bool(index_state):
            res_iter.setitem(res_state, arr_iter.getitem(arr_state))
            res_state = res_iter.next(res_state)
        index_state = index_iter.next(index_state)
        arr_state = arr_iter.next(arr_state)
    return res

setitem_filter_driver = jit.JitDriver(name = 'numpy_setitem_bool',
                                      greens = ['shapelen', 'arr_dtype',
                                                'index_dtype'],
                                      reds = 'auto',
                                      vectorize=True)

def setitem_filter(space, arr, index, value):
    arr_iter, arr_state = arr.create_iter()
    shapelen = len(arr.get_shape())
    if shapelen > 1 and len(index.get_shape()) < 2:
        index_iter, index_state = index.create_iter(arr.get_shape(), backward_broadcast=True)
    else:
        index_iter, index_state = index.create_iter()
    if value.get_size() == 1:
        value_iter, value_state = value.create_iter(arr.get_shape())
    else:
        value_iter, value_state = value.create_iter()
    index_dtype = index.get_dtype()
    arr_dtype = arr.get_dtype()
    while not index_iter.done(index_state):
        setitem_filter_driver.jit_merge_point(shapelen=shapelen,
                                              index_dtype=index_dtype,
                                              arr_dtype=arr_dtype,
                                             )
        if index_iter.getitem_bool(index_state):
            val = arr_dtype.coerce(space, value_iter.getitem(value_state))
            value_state = value_iter.next(value_state)
            arr_iter.setitem(arr_state, val)
        arr_state = arr_iter.next(arr_state)
        index_state = index_iter.next(index_state)

flatiter_getitem_driver = jit.JitDriver(name = 'numpy_flatiter_getitem',
                                        greens = ['dtype'],
                                        reds = 'auto',
                                        vectorize=True)

def flatiter_getitem(res, base_iter, base_state, step):
    ri, rs = res.create_iter()
    dtype = res.get_dtype()
    while not ri.done(rs):
        flatiter_getitem_driver.jit_merge_point(dtype=dtype)
        ri.setitem(rs, base_iter.getitem(base_state))
        base_state = base_iter.goto(base_state.index + step)
        rs = ri.next(rs)
    return res

flatiter_setitem_driver = jit.JitDriver(name = 'numpy_flatiter_setitem',
                                        greens = ['dtype'],
                                        reds = 'auto',
                                        vectorize=True)

def flatiter_setitem(space, dtype, val, arr_iter, arr_state, step, length):
    val_iter, val_state = val.create_iter()
    while length > 0:
        flatiter_setitem_driver.jit_merge_point(dtype=dtype)
        val = val_iter.getitem(val_state)
        if dtype.is_str_or_unicode():
            val = dtype.coerce(space, val)
        else:
            val = val.convert_to(space, dtype)
        arr_iter.setitem(arr_state, val)
        arr_state = arr_iter.goto(arr_state.index + step)
        val_state = val_iter.next(val_state)
        if val_iter.done(val_state):
            val_state = val_iter.reset(val_state)
        length -= 1

fromstring_driver = jit.JitDriver(name = 'numpy_fromstring',
                                  greens = ['itemsize', 'dtype'],
                                  reds = 'auto')

def fromstring_loop(space, a, dtype, itemsize, s):
    i = 0
    ai, state = a.create_iter()
    while not ai.done(state):
        fromstring_driver.jit_merge_point(dtype=dtype, itemsize=itemsize)
        sub = s[i*itemsize:i*itemsize + itemsize]
        val = dtype.runpack_str(space, sub)
        ai.setitem(state, val)
        state = ai.next(state)
        i += 1

def tostring(space, arr):
    builder = StringBuilder()
    iter, state = arr.create_iter()
    w_res_str = W_NDimArray.from_shape(space, [1], arr.get_dtype())
    itemsize = arr.get_dtype().elsize
    with w_res_str.implementation as storage:
        res_str_casted = rffi.cast(rffi.CArrayPtr(lltype.Char),
                               support.get_storage_as_int(storage))
        while not iter.done(state):
            w_res_str.implementation.setitem(0, iter.getitem(state))
            for i in range(itemsize):
                builder.append(res_str_casted[i])
            state = iter.next(state)
        return builder.build()

getitem_int_driver = jit.JitDriver(name = 'numpy_getitem_int',
                                   greens = ['shapelen', 'indexlen',
                                             'prefixlen', 'dtype'],
                                   reds = 'auto')

def getitem_array_int(space, arr, res, iter_shape, indexes_w, prefix_w):
    shapelen = len(iter_shape)
    prefixlen = len(prefix_w)
    indexlen = len(indexes_w)
    dtype = arr.get_dtype()
    iter = PureShapeIter(iter_shape, indexes_w)
    while not iter.done():
        getitem_int_driver.jit_merge_point(shapelen=shapelen, indexlen=indexlen,
                                           dtype=dtype, prefixlen=prefixlen)
        # prepare the index
        index_w = [None] * indexlen
        for i in range(indexlen):
            if iter.idx_w_i[i] is not None:
                index_w[i] = iter.idx_w_i[i].getitem(iter.idx_w_s[i])
            else:
                index_w[i] = indexes_w[i]
        res.descr_setitem(space, space.newtuple(prefix_w[:prefixlen] +
                                            iter.get_index(space, shapelen)),
                          arr.descr_getitem(space, space.newtuple(index_w)))
        iter.next()
    return res

setitem_int_driver = jit.JitDriver(name = 'numpy_setitem_int',
                                   greens = ['shapelen', 'indexlen',
                                             'prefixlen', 'dtype'],
                                   reds = 'auto')

def setitem_array_int(space, arr, iter_shape, indexes_w, val_arr,
                      prefix_w):
    shapelen = len(iter_shape)
    indexlen = len(indexes_w)
    prefixlen = len(prefix_w)
    dtype = arr.get_dtype()
    iter = PureShapeIter(iter_shape, indexes_w)
    while not iter.done():
        setitem_int_driver.jit_merge_point(shapelen=shapelen, indexlen=indexlen,
                                           dtype=dtype, prefixlen=prefixlen)
        # prepare the index
        index_w = [None] * indexlen
        for i in range(indexlen):
            if iter.idx_w_i[i] is not None:
                index_w[i] = iter.idx_w_i[i].getitem(iter.idx_w_s[i])
            else:
                index_w[i] = indexes_w[i]
        w_idx = space.newtuple(prefix_w[:prefixlen] + iter.get_index(space,
                                                                  shapelen))
        if val_arr.is_scalar():
            w_value = val_arr.get_scalar_value()
        else:
            w_value = val_arr.descr_getitem(space, w_idx)
        arr.descr_setitem(space, space.newtuple(index_w), w_value)
        iter.next()

byteswap_driver = jit.JitDriver(name='numpy_byteswap_driver',
                                greens = ['dtype'],
                                reds = 'auto',
                                vectorize=True)

def byteswap(from_, to):
    dtype = from_.dtype
    from_iter, from_state = from_.create_iter()
    to_iter, to_state = to.create_iter()
    while not from_iter.done(from_state):
        byteswap_driver.jit_merge_point(dtype=dtype)
        val = dtype.itemtype.byteswap(from_iter.getitem(from_state))
        to_iter.setitem(to_state, val)
        to_state = to_iter.next(to_state)
        from_state = from_iter.next(from_state)

choose_driver = jit.JitDriver(name='numpy_choose_driver',
                              greens = ['shapelen', 'mode', 'dtype'],
                              reds = 'auto',
                              vectorize=True)

def choose(space, arr, choices, shape, dtype, out, mode):
    shapelen = len(shape)
    pairs = [a.create_iter(shape) for a in choices]
    iterators = [i[0] for i in pairs]
    states = [i[1] for i in pairs]
    arr_iter, arr_state = arr.create_iter(shape)
    out_iter, out_state = out.create_iter(shape)
    while not arr_iter.done(arr_state):
        choose_driver.jit_merge_point(shapelen=shapelen, dtype=dtype,
                                      mode=mode)
        index = support.index_w(space, arr_iter.getitem(arr_state))
        if index < 0 or index >= len(iterators):
            if mode == NPY.RAISE:
                raise oefmt(space.w_ValueError,
                            "invalid entry in choice array")
            elif mode == NPY.WRAP:
                index = index % (len(iterators))
            else:
                assert mode == NPY.CLIP
                if index < 0:
                    index = 0
                else:
                    index = len(iterators) - 1
        val = iterators[index].getitem(states[index]).convert_to(space, dtype)
        out_iter.setitem(out_state, val)
        for i in range(len(iterators)):
            states[i] = iterators[i].next(states[i])
        out_state = out_iter.next(out_state)
        arr_state = arr_iter.next(arr_state)

clip_driver = jit.JitDriver(name='numpy_clip_driver',
                            greens = ['shapelen', 'dtype'],
                            reds = 'auto',
                            vectorize=True)

def clip(space, arr, shape, min, max, out):
    assert min or max
    arr_iter, arr_state = arr.create_iter(shape)
    if min is not None:
        min_iter, min_state = min.create_iter(shape)
    else:
        min_iter, min_state = None, None
    if max is not None:
        max_iter, max_state = max.create_iter(shape)
    else:
        max_iter, max_state = None, None
    out_iter, out_state = out.create_iter(shape)
    shapelen = len(shape)
    dtype = out.get_dtype()
    while not arr_iter.done(arr_state):
        clip_driver.jit_merge_point(shapelen=shapelen, dtype=dtype)
        w_v = arr_iter.getitem(arr_state).convert_to(space, dtype)
        arr_state = arr_iter.next(arr_state)
        if min_iter is not None:
            w_min = min_iter.getitem(min_state).convert_to(space, dtype)
            if dtype.itemtype.lt(w_v, w_min):
                w_v = w_min
            min_state = min_iter.next(min_state)
        if max_iter is not None:
            w_max = max_iter.getitem(max_state).convert_to(space, dtype)
            if dtype.itemtype.gt(w_v, w_max):
                w_v = w_max
            max_state = max_iter.next(max_state)
        out_iter.setitem(out_state, w_v)
        out_state = out_iter.next(out_state)

round_driver = jit.JitDriver(name='numpy_round_driver',
                             greens = ['shapelen', 'dtype'],
                             reds = 'auto',
                             vectorize=True)

def round(space, arr, dtype, shape, decimals, out):
    arr_iter, arr_state = arr.create_iter(shape)
    out_iter, out_state = out.create_iter(shape)
    shapelen = len(shape)
    while not arr_iter.done(arr_state):
        round_driver.jit_merge_point(shapelen=shapelen, dtype=dtype)
        w_v = arr_iter.getitem(arr_state).convert_to(space, dtype)
        w_v = dtype.itemtype.round(w_v, decimals)
        out_iter.setitem(out_state, w_v)
        arr_state = arr_iter.next(arr_state)
        out_state = out_iter.next(out_state)

diagonal_simple_driver = jit.JitDriver(name='numpy_diagonal_simple_driver',
                                       greens = ['axis1', 'axis2'],
                                       reds = 'auto')

def diagonal_simple(space, arr, out, offset, axis1, axis2, size):
    out_iter, out_state = out.create_iter()
    i = 0
    index = [0] * 2
    while i < size:
        diagonal_simple_driver.jit_merge_point(axis1=axis1, axis2=axis2)
        index[axis1] = i
        index[axis2] = i + offset
        out_iter.setitem(out_state, arr.getitem_index(space, index))
        i += 1
        out_state = out_iter.next(out_state)

def diagonal_array(space, arr, out, offset, axis1, axis2, shape):
    out_iter, out_state = out.create_iter()
    iter = PureShapeIter(shape, [])
    shapelen_minus_1 = len(shape) - 1
    assert shapelen_minus_1 >= 0
    if axis1 < axis2:
        a = axis1
        b = axis2 - 1
    else:
        a = axis2
        b = axis1 - 1
    assert a >= 0
    assert b >= 0
    while not iter.done():
        last_index = iter.indexes[-1]
        if axis1 < axis2:
            indexes = (iter.indexes[:a] + [last_index] +
                       iter.indexes[a:b] + [last_index + offset] +
                       iter.indexes[b:shapelen_minus_1])
        else:
            indexes = (iter.indexes[:a] + [last_index + offset] +
                       iter.indexes[a:b] + [last_index] +
                       iter.indexes[b:shapelen_minus_1])
        out_iter.setitem(out_state, arr.getitem_index(space, indexes))
        iter.next()
        out_state = out_iter.next(out_state)

def _new_binsearch(side, op_name):
    binsearch_driver = jit.JitDriver(name='numpy_binsearch_' + side,
                                     greens=['dtype'],
                                     reds='auto')

    def binsearch(space, arr, key, ret):
        assert len(arr.get_shape()) == 1
        dtype = key.get_dtype()
        op = getattr(dtype.itemtype, op_name)
        key_iter, key_state = key.create_iter()
        ret_iter, ret_state = ret.create_iter()
        ret_iter.track_index = False
        size = arr.get_size()
        min_idx = 0
        max_idx = size
        last_key_val = key_iter.getitem(key_state)
        while not key_iter.done(key_state):
            key_val = key_iter.getitem(key_state)
            if dtype.itemtype.lt(last_key_val, key_val):
                max_idx = size
            else:
                min_idx = 0
                max_idx = max_idx + 1 if max_idx < size else size
            last_key_val = key_val
            while min_idx < max_idx:
                binsearch_driver.jit_merge_point(dtype=dtype)
                mid_idx = min_idx + ((max_idx - min_idx) >> 1)
                mid_val = arr.getitem(space, [mid_idx]).convert_to(space, dtype)
                if op(mid_val, key_val):
                    min_idx = mid_idx + 1
                else:
                    max_idx = mid_idx
            ret_iter.setitem(ret_state, ret.get_dtype().box(min_idx))
            ret_state = ret_iter.next(ret_state)
            key_state = key_iter.next(key_state)
    return binsearch

binsearch_left = _new_binsearch('left', 'lt')
binsearch_right = _new_binsearch('right', 'le')
