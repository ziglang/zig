from pypy.interpreter.error import oefmt
from rpython.rlib import jit
from pypy.module.micronumpy import constants as NPY
from pypy.module.micronumpy.base import W_NDimArray


# structures to describe slicing

class BaseChunk(object):
    _attrs_ = ['step', 'out_dim']


class Chunk(BaseChunk):
    input_dim = 1

    def __init__(self, start, stop, step, lgt):
        self.start = start
        self.stop = stop
        self.step = step
        self.lgt = lgt
        if self.step == 0:
            self.out_dim = 0
        else:
            self.out_dim = 1

    def compute(self, space, base_length, base_stride):
        stride = base_stride * self.step
        backstride = base_stride * max(0, self.lgt - 1) * self.step
        return self.start, self.lgt, stride, backstride

    def __repr__(self):
        return 'Chunk(%d, %d, %d, %d)' % (self.start, self.stop, self.step,
                                          self.lgt)

class IntegerChunk(BaseChunk):
    input_dim = 1
    out_dim = 0

    def __init__(self, w_idx):
        self.w_idx = w_idx

    def compute(self, space, base_length, base_stride):
        start, _, _, _ = space.decode_index4(self.w_idx, base_length)
        return start, 0, 0, 0


class SliceChunk(BaseChunk):
    input_dim = 1
    out_dim = 1

    def __init__(self, w_slice):
        self.w_slice = w_slice

    def compute(self, space, base_length, base_stride):
        start, stop, step, length = space.decode_index4(self.w_slice, base_length)
        stride = base_stride * step
        backstride = base_stride * max(0, length - 1) * step
        return start, length, stride, backstride

class NewAxisChunk(Chunk):
    input_dim = 0
    out_dim = 1

    def __init__(self):
        pass

    def compute(self, space, base_length, base_stride):
        return 0, 1, 0, 0

class EllipsisChunk(BaseChunk):
    input_dim = 0
    out_dim = 0

    def __init__(self):
        pass

    def compute(self, space, base_length, base_stride):
        backstride = base_stride * max(0, base_length - 1)
        return 0, base_length, base_stride, backstride

class BooleanChunk(BaseChunk):
    input_dim = 1
    out_dim = 1

    def __init__(self, w_idx):
        self.w_idx = w_idx

    def compute(self, space, base_length, base_stride):
        raise oefmt(space.w_NotImplementedError, 'cannot reach')

def new_view(space, w_arr, chunks):
    arr = w_arr.implementation
    dim = -1
    for i, c in enumerate(chunks):
        if isinstance(c, BooleanChunk):
            dim = i
            break
    if dim >= 0:
        # filter by axis dim
        filtr = chunks[dim]
        assert isinstance(filtr, BooleanChunk)
        # XXX this creates a new array, and fails in setitem
        w_arr = w_arr.getitem_filter(space, filtr.w_idx, axis=dim)
        arr = w_arr.implementation
        chunks[dim] = SliceChunk(space.newslice(space.newint(0),
                                 space.w_None, space.w_None))
        r = calculate_slice_strides(space, arr.shape, arr.start,
                 arr.get_strides(), arr.get_backstrides(), chunks)
    else:
        r = calculate_slice_strides(space, arr.shape, arr.start,
                     arr.get_strides(), arr.get_backstrides(), chunks)
    shape, start, strides, backstrides = r
    return W_NDimArray.new_slice(space, start, strides[:], backstrides[:],
                                 shape[:], arr, w_arr)

@jit.unroll_safe
def _extend_shape(old_shape, chunks):
    shape = []
    i = -1
    for i, c in enumerate_chunks(chunks):
        if c.out_dim > 0:
            shape.append(c.lgt)
    s = i + 1
    assert s >= 0
    return shape[:] + old_shape[s:]


class BaseTransform(object):
    pass


class ViewTransform(BaseTransform):
    def __init__(self, chunks):
        # 4-tuple specifying slicing
        self.chunks = chunks


class BroadcastTransform(BaseTransform):
    def __init__(self, res_shape):
        self.res_shape = res_shape


@jit.look_inside_iff(lambda chunks: jit.isconstant(len(chunks)))
def enumerate_chunks(chunks):
    result = []
    i = -1
    for chunk in chunks:
        i += chunk.input_dim
        result.append((i, chunk))
    return result


@jit.look_inside_iff(lambda space, shape, start, strides, backstrides, chunks:
                     jit.isconstant(len(chunks)))
def calculate_slice_strides(space, shape, start, strides, backstrides, chunks):
    """
    Note: `chunks` can contain at most one EllipsisChunk object.
    """
    size = 0
    used_dims = 0
    for chunk in chunks:
        used_dims += chunk.input_dim
        size += chunk.out_dim
    if used_dims > len(shape):
        raise oefmt(space.w_IndexError, "too many indices for array")
    else:
        extra_dims = len(shape) - used_dims
    rstrides = [0] * (size + extra_dims)
    rbackstrides = [0] * (size + extra_dims)
    rshape = [0] * (size + extra_dims)
    rstart = start
    i = 0  # index of the current dimension in the input array
    j = 0  # index of the current dimension in the result view
    for chunk in chunks:
        if isinstance(chunk, NewAxisChunk):
            rshape[j] = 1
            j += 1
            continue
        elif isinstance(chunk, EllipsisChunk):
            for k in range(extra_dims):
                start, length, stride, backstride = chunk.compute(
                        space, shape[i], strides[i])
                rshape[j] = length
                rstrides[j] = stride
                rbackstrides[j] = backstride
                j += 1
                i += 1
            continue
        start, length, stride, backstride = chunk.compute(space, shape[i], strides[i])
        if chunk.out_dim == 1:
            rshape[j] = length
            rstrides[j] = stride
            rbackstrides[j] = backstride
            j += chunk.out_dim
        rstart += strides[i] * start
        i += chunk.input_dim
    return rshape, rstart, rstrides, rbackstrides


def calculate_broadcast_strides(strides, backstrides, orig_shape, res_shape, backwards=False):
    rstrides = []
    rbackstrides = []
    for i in range(len(orig_shape)):
        if orig_shape[i] == 1:
            rstrides.append(0)
            rbackstrides.append(0)
        else:
            rstrides.append(strides[i])
            rbackstrides.append(backstrides[i])
    if backwards:
        rstrides = rstrides + [0] * (len(res_shape) - len(orig_shape))
        rbackstrides = rbackstrides + [0] * (len(res_shape) - len(orig_shape))
    else:
        rstrides = [0] * (len(res_shape) - len(orig_shape)) + rstrides
        rbackstrides = [0] * (len(res_shape) - len(orig_shape)) + rbackstrides
    return rstrides, rbackstrides


@jit.unroll_safe
def shape_agreement(space, shape1, w_arr2, broadcast_down=True):
    if w_arr2 is None:
        return shape1
    assert isinstance(w_arr2, W_NDimArray)
    shape2 = w_arr2.get_shape()
    ret = _shape_agreement(shape1, shape2)
    if len(ret) < max(len(shape1), len(shape2)):
        def format_shape(shape):
            if len(shape) > 1:
                return ",".join([str(x) for x in shape])
            else:
                return '%d,' % shape[0]
        raise oefmt(space.w_ValueError,
                    "operands could not be broadcast together with shapes "
                    "(%s) (%s)", format_shape(shape1), format_shape(shape2))
    if not broadcast_down and len([x for x in ret if x != 1]) > len([x for x in shape2 if x != 1]):
        raise oefmt(space.w_ValueError,
                    "unbroadcastable shape (%s) cannot be broadcasted to (%s)",
                    ",".join([str(x) for x in shape1]),
                    ",".join([str(x) for x in shape2])
        )
    return ret


@jit.unroll_safe
def shape_agreement_multiple(space, array_list, shape=None):
    """ call shape_agreement recursively, allow elements from array_list to
    be None (like w_out)
    """
    for arr in array_list:
        if not space.is_none(arr):
            if shape is None:
                shape = arr.get_shape()
            else:
                shape = shape_agreement(space, shape, arr)
    return shape

@jit.unroll_safe
def _shape_agreement(shape1, shape2):
    """ Checks agreement about two shapes with respect to broadcasting. Returns
    the resulting shape.
    """
    lshift = 0
    rshift = 0
    if len(shape1) > len(shape2):
        m = len(shape1)
        n = len(shape2)
        rshift = len(shape2) - len(shape1)
        remainder = shape1
    else:
        m = len(shape2)
        n = len(shape1)
        lshift = len(shape1) - len(shape2)
        remainder = shape2
    endshape = [0] * m
    indices1 = [True] * m
    indices2 = [True] * m
    for i in range(m - 1, m - n - 1, -1):
        left = shape1[i + lshift]
        right = shape2[i + rshift]
        if left == right:
            endshape[i] = left
        elif left == 1:
            endshape[i] = right
            indices1[i + lshift] = False
        elif right == 1:
            endshape[i] = left
            indices2[i + rshift] = False
        else:
            return []
            #raise oefmt(space.w_ValueError,
            #    "frames are not aligned")
    for i in range(m - n):
        endshape[i] = remainder[i]
    return endshape


def get_shape_from_iterable(space, old_size, w_iterable):
    new_size = 0
    new_shape = []
    if space.isinstance_w(w_iterable, space.w_int):
        new_size = space.int_w(w_iterable)
        if new_size < 0:
            new_size = old_size
        new_shape = [new_size]
    else:
        neg_dim = -1
        batch = space.listview(w_iterable)
        new_size = 1
        new_shape = []
        i = 0
        for elem in batch:
            s = space.int_w(elem)
            if s < 0:
                if neg_dim >= 0:
                    raise oefmt(space.w_ValueError,
                        "can only specify one unknown dimension")
                s = 1
                neg_dim = i
            new_size *= s
            new_shape.append(s)
            i += 1
        if neg_dim >= 0:
            new_shape[neg_dim] = old_size / new_size
            new_size *= new_shape[neg_dim]
    if new_size != old_size:
        raise oefmt(space.w_ValueError,
                    "total size of new array must be unchanged")
    return new_shape


@jit.unroll_safe
def calc_strides(shape, dtype, order):
    strides = []
    backstrides = []
    s = 1
    shape_rev = shape[:]
    if order in [NPY.CORDER, NPY.ANYORDER]:
        shape_rev.reverse()
    for sh in shape_rev:
        slimit = max(sh, 1)
        strides.append(s * dtype.elsize)
        backstrides.append(s * (slimit - 1) * dtype.elsize)
        s *= slimit
    if order in [NPY.CORDER, NPY.ANYORDER]:
        strides.reverse()
        backstrides.reverse()
    return strides, backstrides

@jit.unroll_safe
def calc_backstrides(strides, shape):
    ndims = len(shape)
    new_backstrides = [0] * ndims
    for nd in range(ndims):
        new_backstrides[nd] = (shape[nd] - 1) * strides[nd]
    return new_backstrides

# Recalculating strides. Find the steps that the iteration does for each
# dimension, given the stride and shape. Then try to create a new stride that
# fits the new shape, using those steps. If there is a shape/step mismatch
# (meaning that the realignment of elements crosses from one step into another)
# return None so that the caller can raise an exception.
def calc_new_strides(new_shape, old_shape, old_strides, order):
    # Return the proper strides for new_shape, or None if the mapping crosses
    # stepping boundaries

    # Assumes that prod(old_shape) == prod(new_shape), len(old_shape) > 1, and
    # len(new_shape) > 0
    steps = []
    last_step = 1
    oldI = 0
    new_strides = []
    if order == NPY.FORTRANORDER:
        for i in range(len(old_shape)):
            steps.append(old_strides[i] / last_step)
            last_step *= old_shape[i]
        cur_step = steps[0]
        n_new_elems_used = 1
        n_old_elems_to_use = old_shape[0]
        for s in new_shape:
            new_strides.append(cur_step * n_new_elems_used)
            n_new_elems_used *= s
            while n_new_elems_used > n_old_elems_to_use:
                oldI += 1
                if steps[oldI] != steps[oldI - 1]:
                    return None
                n_old_elems_to_use *= old_shape[oldI]
            if n_new_elems_used == n_old_elems_to_use:
                oldI += 1
                if oldI < len(old_shape):
                    cur_step = steps[oldI]
                    n_old_elems_to_use *= old_shape[oldI]
    else:
        for i in range(len(old_shape) - 1, -1, -1):
            steps.insert(0, old_strides[i] / last_step)
            last_step *= old_shape[i]
        cur_step = steps[-1]
        n_new_elems_used = 1
        oldI = -1
        n_old_elems_to_use = old_shape[-1]
        for i in range(len(new_shape) - 1, -1, -1):
            s = new_shape[i]
            new_strides.insert(0, cur_step * n_new_elems_used)
            n_new_elems_used *= s
            while n_new_elems_used > n_old_elems_to_use:
                oldI -= 1
                if steps[oldI] != steps[oldI + 1]:
                    return None
                n_old_elems_to_use *= old_shape[oldI]
            if n_new_elems_used == n_old_elems_to_use:
                oldI -= 1
                if oldI >= -len(old_shape):
                    cur_step = steps[oldI]
                    n_old_elems_to_use *= old_shape[oldI]
    return new_strides[:]

def calc_start(shape, strides):
    ''' Strides can be negative for non-contiguous data.
    Calculate the appropriate positive starting position so
    the indexing still works properly
    '''
    start = 0
    for i in range(len(shape)):
        if strides[i] < 0:
            start -= strides[i] * (shape[i] - 1)
    return start

@jit.unroll_safe
def is_c_contiguous(arr):
    shape = arr.get_shape()
    strides = arr.get_strides()
    ret = True
    sd = arr.dtype.elsize
    for i in range(len(shape) - 1, -1, -1):
        dim = shape[i]
        if strides[i] != sd:
            ret = False
            break
        if dim == 0:
            break
        sd *= dim
    return ret

@jit.unroll_safe
def is_f_contiguous(arr):
    shape = arr.get_shape()
    strides = arr.get_strides()
    ret = True
    sd = arr.dtype.elsize
    for i in range(len(shape)):
        dim = shape[i]
        if strides[i] != sd:
            ret = False
            break
        if dim == 0:
            break
        sd *= dim
    return ret
