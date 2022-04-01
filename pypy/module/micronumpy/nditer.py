from rpython.rlib import jit
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.error import OperationError, oefmt
from pypy.module.micronumpy import support, concrete
from pypy.module.micronumpy.base import W_NDimArray, convert_to_array, W_NumpyObject
from pypy.module.micronumpy.descriptor import decode_w_dtype
from pypy.module.micronumpy.iterators import ArrayIter
from pypy.module.micronumpy.strides import (calculate_broadcast_strides,
                                            shape_agreement, shape_agreement_multiple)
from pypy.module.micronumpy.casting import (find_binop_result_dtype, 
                    can_cast_array, can_cast_type)
import pypy.module.micronumpy.constants as NPY
from pypy.module.micronumpy.converters import order_converter


def parse_op_arg(space, name, w_op_flags, n, parse_one_arg):
    if space.is_w(w_op_flags, space.w_None):
        w_op_flags = space.newtuple([space.newtext('readonly')])
    if not space.isinstance_w(w_op_flags, space.w_tuple) and not \
            space.isinstance_w(w_op_flags, space.w_list):
        raise oefmt(space.w_ValueError,
                    '%s must be a tuple or array of per-op flag-tuples',
                    name)
    ret = []
    w_lst = space.listview(w_op_flags)
    if space.isinstance_w(w_lst[0], space.w_tuple) or \
       space.isinstance_w(w_lst[0], space.w_list):
        if len(w_lst) != n:
            raise oefmt(space.w_ValueError,
                        '%s must be a tuple or array of per-op flag-tuples',
                        name)
        for item in w_lst:
            ret.append(parse_one_arg(space, space.listview(item)))
    else:
        op_flag = parse_one_arg(space, w_lst)
        for i in range(n):
            ret.append(op_flag)
    return ret


class OpFlag(object):
    def __init__(self):
        self.rw = ''
        self.broadcast = True
        self.force_contig = False
        self.force_align = False
        self.native_byte_order = False
        self.tmp_copy = ''
        self.allocate = False

def parse_op_flag(space, lst):
    op_flag = OpFlag()
    for w_item in lst:
        item = space.text_w(w_item)
        if item == 'readonly':
            op_flag.rw = 'r'
        elif item == 'readwrite':
            op_flag.rw = 'rw'
        elif item == 'writeonly':
            op_flag.rw = 'w'
        elif item == 'no_broadcast':
            op_flag.broadcast = False
        elif item == 'contig':
            op_flag.force_contig = True
        elif item == 'aligned':
            op_flag.force_align = True
        elif item == 'nbo':
            op_flag.native_byte_order = True
        elif item == 'copy':
            op_flag.tmp_copy = 'r'
        elif item == 'updateifcopy':
            op_flag.tmp_copy = 'rw'
        elif item == 'allocate':
            op_flag.allocate = True
        elif item == 'no_subtype':
            raise oefmt(space.w_NotImplementedError,
                '"no_subtype" op_flag not implemented yet')
        elif item == 'arraymask':
            raise oefmt(space.w_NotImplementedError,
                '"arraymask" op_flag not implemented yet')
        elif item == 'writemask':
            raise oefmt(space.w_NotImplementedError,
                '"writemask" op_flag not implemented yet')
        else:
            raise oefmt(space.w_ValueError,
                'op_flags must be a tuple or array of per-op flag-tuples')
    if op_flag.rw == '':
        raise oefmt(space.w_ValueError,
                    "None of the iterator flags READWRITE, READONLY, or "
                    "WRITEONLY were specified for an operand")
    return op_flag


def parse_func_flags(space, nditer, w_flags):
    if space.is_w(w_flags, space.w_None):
        return
    elif not space.isinstance_w(w_flags, space.w_tuple) and not \
            space.isinstance_w(w_flags, space.w_list):
        raise oefmt(space.w_ValueError,
            'Iter global flags must be a list or tuple of strings')
    lst = space.listview(w_flags)
    for w_item in lst:
        if not space.isinstance_w(w_item, space.w_bytes) and not \
                space.isinstance_w(w_item, space.w_unicode):
            raise oefmt(space.w_TypeError,
                        "expected string or Unicode object, %T found",
                        w_item)
        item = space.text_w(w_item)
        if item == 'external_loop':
            nditer.external_loop = True
        elif item == 'buffered':
            # Each iterator should be 1d
            nditer.buffered = True
        elif item == 'c_index':
            nditer.tracked_index = 'C'
        elif item == 'f_index':
            nditer.tracked_index = 'F'
        elif item == 'multi_index':
            nditer.tracked_index = 'multi'
        elif item == 'common_dtype':
            nditer.common_dtype = True
        elif item == 'delay_bufalloc':
            nditer.delay_bufalloc = True
        elif item == 'grow_inner':
            nditer.grow_inner = True
        elif item == 'ranged':
            nditer.ranged = True
        elif item == 'refs_ok':
            nditer.refs_ok = True
        elif item == 'reduce_ok':
            raise oefmt(space.w_NotImplementedError,
                'nditer reduce_ok not implemented yet')
            nditer.reduce_ok = True
        elif item == 'zerosize_ok':
            nditer.zerosize_ok = True
        else:
            raise oefmt(space.w_ValueError,
                        'Unexpected iterator global flag "%s"',
                        item)
    if nditer.tracked_index and nditer.external_loop:
        raise oefmt(space.w_ValueError,
            'Iterator flag EXTERNAL_LOOP cannot be used if an index or '
            'multi-index is being tracked')

def is_backward(imp_order, order):
    if imp_order == order:
        return False
    if order == NPY.KEEPORDER:
        return False
    else:
        return True


class OperandIter(ArrayIter):
    _immutable_fields_ = ['slice_shape', 'slice_stride', 'slice_backstride',
                          'operand_type', 'base']

    def getitem(self, state):
        # cannot be called - must return a boxed value
        assert False

    def getitem_bool(self, state):
        # cannot be called - must return a boxed value
        assert False

    def setitem(self, state, elem):
        # cannot be called - must return a boxed value
        assert False


class ConcreteIter(OperandIter):
    def __init__(self, array, size, shape, strides, backstrides,
                 op_flags, base):
        OperandIter.__init__(self, array, size, shape, strides, backstrides)
        self.slice_shape =[]
        self.slice_stride = []
        self.slice_backstride = []
        if op_flags.rw == 'r':
            self.operand_type = concrete.ConcreteNonWritableArrayWithBase
        else:
            self.operand_type = concrete.ConcreteArrayWithBase
        self.base = base

    def getoperand(self, state):
        assert state.iterator is self
        impl = self.operand_type
        res = impl([], self.array.dtype, self.array.order, [], [],
                   self.array.storage, self.base)
        res.start = state.offset
        return res


class SliceIter(OperandIter):
    def __init__(self, array, size, shape, strides, backstrides, slice_shape,
                 slice_stride, slice_backstride, op_flags, base):
        OperandIter.__init__(self, array, size, shape, strides, backstrides)
        self.slice_shape = slice_shape
        self.slice_stride = slice_stride
        self.slice_backstride = slice_backstride
        if op_flags.rw == 'r':
            self.operand_type = concrete.NonWritableSliceArray
        else:
            self.operand_type = concrete.SliceArray
        self.base = base

    def getoperand(self, state):
        assert state.iterator is self
        impl = self.operand_type
        arr = impl(state.offset, self.slice_stride, self.slice_backstride,
                   self.slice_shape, self.array, self.base)
        return arr


def calculate_ndim(op_in, oa_ndim):
    if oa_ndim >=0:
        return oa_ndim
    else:
        ndim = 0
        for op in op_in:
            if op is None:
                continue
            assert isinstance(op, W_NDimArray)
            ndim = max(ndim, op.ndims())
    return ndim

def coalesce_axes(it, space):
    # Copy logic from npyiter_coalesce_axes, used in ufunc iterators
    # and in nditer's with 'external_loop' flag
    can_coalesce = True
    for idim in range(it.ndim - 1):
        for op_it, _ in it.iters:
            if op_it is None:
                continue
            assert isinstance(op_it, ArrayIter)
            indx = len(op_it.strides)
            if it.order == NPY.FORTRANORDER:
                indx = len(op_it.array.strides) - indx
                assert indx >=0
                astrides = op_it.array.strides[indx:]
            else:
                astrides = op_it.array.strides[:indx]
            # does op_it iters over array "naturally"
            if astrides != op_it.strides:
                can_coalesce = False
                break
        if can_coalesce:
            for i in range(len(it.iters)):
                new_iter = coalesce_iter(it.iters[i][0], it.op_flags[i], it,
                                         it.order)
                it.iters[i] = (new_iter, new_iter.reset())
            if len(it.shape) > 1:
                if it.order == NPY.FORTRANORDER:
                    it.shape = it.shape[1:]
                else:
                    it.shape = it.shape[:-1]
            else:
                it.shape = [1]

        else:
            break
    # Always coalesce at least one
    for i in range(len(it.iters)):
        new_iter = coalesce_iter(it.iters[i][0], it.op_flags[i], it, NPY.CORDER)
        it.iters[i] = (new_iter, new_iter.reset())
    if len(it.shape) > 1:
        if it.order == NPY.FORTRANORDER:
            it.shape = it.shape[1:]
        else:
            it.shape = it.shape[:-1]
    else:
        it.shape = [1]


def coalesce_iter(old_iter, op_flags, it, order, flat=True):
    '''
    We usually iterate through an array one value at a time.
    But after coalesce(), getoperand() will return a slice by removing
    the fastest varying dimension(s) from the beginning or end of the shape.
    If flat is true, then the slice will be 1d, otherwise stack up the shape of
    the fastest varying dimension in the slice, so an iterator of a  'C' array
    of shape (2,4,3) after two calls to coalesce will iterate 2 times over a slice
    of shape (4,3) by setting the offset to the beginning of the data at each iteration
    '''
    shape = [s+1 for s in old_iter.shape_m1]
    if len(shape) < 1:
        return old_iter
    strides = old_iter.strides
    backstrides = old_iter.backstrides
    if order == NPY.FORTRANORDER:
        new_shape = shape[1:]
        new_strides = strides[1:]
        new_backstrides = backstrides[1:]
        _stride = old_iter.slice_stride + [strides[0]]
        _shape =  old_iter.slice_shape + [shape[0]]
        _backstride = old_iter.slice_backstride + [strides[0] * (shape[0] - 1)]
        fastest = shape[0]
    else:
        new_shape = shape[:-1]
        new_strides = strides[:-1]
        new_backstrides = backstrides[:-1]
        # use the operand's iterator's rightmost stride,
        # even if it is not the fastest (for 'F' or swapped axis)
        _stride = [strides[-1]] + old_iter.slice_stride
        _shape = [shape[-1]]  + old_iter.slice_shape
        _backstride = [(shape[-1] - 1) * strides[-1]] + old_iter.slice_backstride
        fastest = shape[-1]
    if fastest == 0:
        return old_iter
    if flat:
        _shape = [support.product(_shape)]
        if len(_stride) > 1:
            _stride = [min(_stride[0], _stride[1])]
        _backstride = [(shape[0] - 1) * _stride[0]]
    return SliceIter(old_iter.array, old_iter.size / fastest,
                new_shape, new_strides, new_backstrides,
                _shape, _stride, _backstride, op_flags, it)

class IndexIterator(object):
    def __init__(self, shape, backward=False):
        self.shape = shape
        self.index = [0] * len(shape)
        self.backward = backward

    @jit.unroll_safe
    def next(self):
        for i in range(len(self.shape) - 1, -1, -1):
            if self.index[i] < self.shape[i] - 1:
                self.index[i] += 1
                break
            else:
                self.index[i] = 0

    def getvalue(self):
        if not self.backward:
            ret = self.index[-1]
            for i in range(len(self.shape) - 2, -1, -1):
                ret += self.index[i] * self.shape[i - 1]
        else:
            ret = self.index[0]
            for i in range(1, len(self.shape)):
                ret += self.index[i] * self.shape[i - 1]
        return ret


class W_NDIter(W_NumpyObject):
    _immutable_fields_ = ['ndim', ]
    def __init__(self, space, w_seq, w_flags, w_op_flags, w_op_dtypes,
                 w_casting, w_op_axes, w_itershape, buffersize=0,
                 order=NPY.KEEPORDER, allow_backward=True):
        self.external_loop = False
        self.buffered = False
        self.tracked_index = ''
        self.common_dtype = False
        self.delay_bufalloc = False
        self.grow_inner = False
        self.ranged = False
        self.refs_ok = False
        self.reduce_ok = False
        self.zerosize_ok = False
        self.index_iter = None
        self.done = False
        self.first_next = True
        self.op_axes = []
        self.allow_backward = allow_backward
        if not space.is_w(w_casting, space.w_None):
            self.casting = space.text_w(w_casting)
        else:
            self.casting = 'safe'
        # convert w_seq operands to a list of W_NDimArray
        if space.isinstance_w(w_seq, space.w_tuple) or \
           space.isinstance_w(w_seq, space.w_list):
            w_seq_as_list = space.listview(w_seq)
            self.seq = [convert_to_array(space, w_elem)
                        if not space.is_none(w_elem) else None
                        for w_elem in w_seq_as_list]
        else:
            self.seq = [convert_to_array(space, w_seq)]
        if order == NPY.ANYORDER:
            # 'A' means "'F' order if all the arrays are Fortran contiguous,
            #            'C' order otherwise"
            order = NPY.CORDER
            for s in self.seq:
                if s and not(s.get_flags() & NPY.ARRAY_F_CONTIGUOUS):
                     break
                else:
                    order = NPY.FORTRANORDER
        elif order == NPY.KEEPORDER:
            # 'K' means "as close to the order the array elements appear in
            #     memory as possible", so match self.order to seq.order
            order = NPY.CORDER
            for s in self.seq:
                if s and not(s.get_order() == NPY.FORTRANORDER):
                     break
                else:
                    order = NPY.FORTRANORDER
        self.order = order
        parse_func_flags(space, self, w_flags)
        self.op_flags = parse_op_arg(space, 'op_flags', w_op_flags,
                                     len(self.seq), parse_op_flag)
        # handle w_op_axes
        oa_ndim = -1
        if not space.is_none(w_op_axes):
            oa_ndim = self.set_op_axes(space, w_op_axes)
        self.ndim = calculate_ndim(self.seq, oa_ndim)

        # handle w_op_dtypes part 1: creating self.dtypes list from input
        if not space.is_none(w_op_dtypes):
            w_seq_as_list = space.listview(w_op_dtypes)
            self.dtypes = [decode_w_dtype(space, w_elem) for w_elem in w_seq_as_list]
            if len(self.dtypes) != len(self.seq):
                raise oefmt(space.w_ValueError,
                    "op_dtypes must be a tuple/list matching the number of ops")
        else:
            self.dtypes = []

        # handle None or writable operands, calculate my shape
        outargs = [i for i in range(len(self.seq))
                   if self.seq[i] is None or self.op_flags[i].rw == 'w']
        if len(outargs) > 0:
            out_shape = shape_agreement_multiple(space, [self.seq[i] for i in outargs])
        else:
            out_shape = None
        if space.isinstance_w(w_itershape, space.w_tuple) or \
           space.isinstance_w(w_itershape, space.w_list):
            self.shape = [space.int_w(i) for i in space.listview(w_itershape)]
        else:
            self.shape = shape_agreement_multiple(space, self.seq,
                                                           shape=out_shape)
        if len(outargs) > 0:
            # Make None operands writeonly and flagged for allocation
            if len(self.dtypes) > 0:
                out_dtype = self.dtypes[outargs[0]]
            else:
                out_dtype = None
                for i in range(len(self.seq)):
                    if self.seq[i] is None:
                        self.op_flags[i].allocate = True
                        continue
                    if self.op_flags[i].rw == 'w':
                        continue
                    out_dtype = find_binop_result_dtype(
                        space, self.seq[i].get_dtype(), out_dtype)
            for i in outargs:
                if self.seq[i] is None:
                    # XXX can we postpone allocation to later?
                    self.seq[i] = W_NDimArray.from_shape(space, self.shape, out_dtype)
                else:
                    if not self.op_flags[i].broadcast:
                        # Raises if output cannot be broadcast
                        try:
                            shape_agreement(space, self.shape, self.seq[i], False)
                        except OperationError as e:
                            raise oefmt(space.w_ValueError, "non-broadcastable"
                                " output operand with shape %s doesn't match "
                                "the broadcast shape %s", 
                                str(self.seq[i].get_shape()),
                                str(self.shape)) 

        if self.tracked_index != "":
            order = self.order
            if order == NPY.KEEPORDER:
                order = self.seq[0].implementation.order
            if self.tracked_index == "multi":
                backward = False
            else:
                backward = ((
                    order == NPY.CORDER and self.tracked_index != 'C') or (
                    order == NPY.FORTRANORDER and self.tracked_index != 'F'))
            self.index_iter = IndexIterator(self.shape, backward=backward)

        # handle w_op_dtypes part 2: copy where needed if possible
        if len(self.dtypes) > 0:
            for i in range(len(self.seq)):
                self_d = self.dtypes[i]
                seq_d = self.seq[i].get_dtype()
                if not self_d:
                    self.dtypes[i] = seq_d
                elif self_d != seq_d:
                        impl = self.seq[i].implementation
                        if self.buffered or 'r' in self.op_flags[i].tmp_copy:
                            if not can_cast_array(
                                    space, self.seq[i], self_d, self.casting):
                                raise oefmt(space.w_TypeError, "Iterator operand %d"
                                    " dtype could not be cast from %R to %R"
                                    " according to the rule '%s'",
                                    i, seq_d, self_d, self.casting)
                            order = support.get_order_as_CF(impl.order, self.order)
                            new_impl = impl.astype(space, self_d, order).copy(space)
                            self.seq[i] = W_NDimArray(new_impl)
                        else:
                            raise oefmt(space.w_TypeError, "Iterator "
                                "operand required copying or buffering, "
                                "but neither copying nor buffering was "
                                "enabled")
                        if 'w' in self.op_flags[i].rw:
                            if not can_cast_type(
                                    space, self_d, seq_d, self.casting):
                                raise oefmt(space.w_TypeError, "Iterator"
                                    " requested dtype could not be cast from "
                                    " %R to %R, the operand %d dtype, accord"
                                    "ing to the rule '%s'",
                                    self_d, seq_d, i, self.casting)
        elif self.buffered and not (self.external_loop and len(self.seq)<2):
            for i in range(len(self.seq)):
                if i not in outargs:
                    self.seq[i] = self.seq[i].descr_copy(space,
                                     w_order=space.newint(self.order))
            self.dtypes = [s.get_dtype() for s in self.seq]
        else:
            #copy them from seq
            self.dtypes = [s.get_dtype() for s in self.seq]

        # create an iterator for each operand
        self.iters = []
        for i in range(len(self.seq)):
            it = self.get_iter(space, i)
            it.contiguous = False
            self.iters.append((it, it.reset()))

        if self.external_loop:
            coalesce_axes(self, space)

    def get_iter(self, space, i):
        arr = self.seq[i]
        imp = arr.implementation
        if arr.is_scalar():
            return ConcreteIter(imp, 1, [], [], [], self.op_flags[i], self)
        shape = self.shape
        if (self.external_loop and len(self.seq)<2 and self.buffered):
            # Special case, always return a memory-ordered iterator
            stride = imp.dtype.elsize
            backstride = imp.size * stride - stride
            return ConcreteIter(imp, imp.get_size(), 
                [support.product(shape)], [stride], [backstride],
                            self.op_flags[i], self)
        backward = imp.order != self.order
        # XXX cleanup needed
        strides = imp.strides
        backstrides = imp.backstrides
        if self.allow_backward:
            if  ((abs(imp.strides[0]) < abs(imp.strides[-1]) and not backward) or \
                 (abs(imp.strides[0]) > abs(imp.strides[-1]) and backward)):
                # flip the strides. Is this always true for multidimension?
                strides = imp.strides[:]
                backstrides = imp.backstrides[:]
                shape = imp.shape[:]
                strides.reverse()
                backstrides.reverse()
                shape.reverse()
        r = calculate_broadcast_strides(strides, backstrides, imp.shape,
                                        shape, backward)
        iter_shape = shape
        if len(shape) != len(r[0]):
            # shape can be shorter when using an external loop, just return a view
            iter_shape = imp.shape
        return ConcreteIter(imp, imp.get_size(), iter_shape, r[0], r[1],
                            self.op_flags[i], self)


    def set_op_axes(self, space, w_op_axes):
        if space.len_w(w_op_axes) != len(self.seq):
            raise oefmt(space.w_ValueError,
                        "op_axes must be a tuple/list matching the number of ops")
        op_axes = space.listview(w_op_axes)
        oa_ndim = -1
        for w_axis in op_axes:
            if not space.is_none(w_axis):
                axis_len = space.len_w(w_axis)
                if oa_ndim == -1:
                    oa_ndim = axis_len
                elif axis_len != oa_ndim:
                    raise oefmt(space.w_ValueError,
                                "Each entry of op_axes must have the same size")
                self.op_axes.append([space.int_w(x) if not space.is_none(x) else -1
                                     for x in space.listview(w_axis)])
        if oa_ndim == -1:
            raise oefmt(space.w_ValueError,
                        "If op_axes is provided, at least one list of axes "
                        "must be contained within it")
        raise oefmt(space.w_NotImplementedError, "op_axis not finished yet")
        # Check that values make sense:
        # - in bounds for each operand
        # ValueError: Iterator input op_axes[0][3] (==3) is not a valid axis of op[0], which has 2 dimensions
        # - no repeat axis
        # ValueError: The 'op_axes' provided to the iterator constructor for operand 1 contained duplicate value 0
        return oa_ndim

    def descr_iter(self, space):
        return self

    def getitem(self, it, st):
        w_res = W_NDimArray(it.getoperand(st))
        return w_res

    def descr_getitem(self, space, w_idx):
        idx = space.int_w(w_idx)
        try:
            it, st = self.iters[idx]
        except IndexError:
            raise oefmt(space.w_IndexError,
                        "Iterator operand index %d is out of bounds", idx)
        return self.getitem(it, st)

    def descr_setitem(self, space, w_idx, w_value):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_len(self, space):
        space.newint(len(self.iters))

    @jit.unroll_safe
    def descr_next(self, space):
        for it, st in self.iters:
            if not it.done(st):
                break
        else:
            self.done = True
            raise OperationError(space.w_StopIteration, space.w_None)
        res = []
        if self.index_iter:
            if not self.first_next:
                self.index_iter.next()
            else:
                self.first_next = False
        for i, (it, st) in enumerate(self.iters):
            res.append(self.getitem(it, st))
            self.iters[i] = (it, it.next(st))
        if len(res) < 2:
            return res[0]
        return space.newtuple(res)

    def iternext(self):
        if self.index_iter:
            self.index_iter.next()
        for i, (it, st) in enumerate(self.iters):
            self.iters[i] = (it, it.next(st))
        for it, st in self.iters:
            if not it.done(st):
                break
        else:
            self.done = True
            return self.done
        return self.done

    def descr_iternext(self, space):
        return space.newbool(self.iternext())

    def descr_copy(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_debug_print(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_enable_external_loop(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    @unwrap_spec(axis=int)
    def descr_remove_axis(self, space, axis):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_remove_multi_index(self, space, w_multi_index):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_reset(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_get_operands(self, space):
        l_w = []
        for op in self.seq:
            l_w.append(op.descr_view(space))
        return space.newlist(l_w)

    def descr_get_dtypes(self, space):
        res = [None] * len(self.seq)
        for i in range(len(self.seq)):
            res[i] = self.seq[i].descr_get_dtype(space)
        return space.newtuple(res)

    def descr_get_finished(self, space):
        return space.newbool(self.done)

    def descr_get_has_delayed_bufalloc(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_get_has_index(self, space):
        return space.newbool(self.tracked_index in ["C", "F"])

    def descr_get_index(self, space):
        if not self.tracked_index in ["C", "F"]:
            raise oefmt(space.w_ValueError, "Iterator does not have an index")
        if self.done:
            raise oefmt(space.w_ValueError, "Iterator is past the end")
        return space.newint(self.index_iter.getvalue())

    def descr_get_has_multi_index(self, space):
        return space.newbool(self.tracked_index == "multi")

    def descr_get_multi_index(self, space):
        if not self.tracked_index == "multi":
            raise oefmt(space.w_ValueError, "Iterator is not tracking a multi-index")
        if self.done:
            raise oefmt(space.w_ValueError, "Iterator is past the end")
        return space.newtuple([space.newint(x) for x in self.index_iter.index])

    def descr_get_iterationneedsapi(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_get_iterindex(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_get_itersize(self, space):
        return space.newint(support.product(self.shape))

    def descr_get_itviews(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_get_ndim(self, space):
        return space.newint(self.ndim)

    def descr_get_nop(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_get_shape(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")

    def descr_get_value(self, space):
        raise oefmt(space.w_NotImplementedError, "not implemented yet")


@unwrap_spec(w_flags=WrappedDefault(None), w_op_flags=WrappedDefault(None),
             w_op_dtypes=WrappedDefault(None), w_order=WrappedDefault(None),
             w_casting=WrappedDefault(None), w_op_axes=WrappedDefault(None),
             w_itershape=WrappedDefault(None), w_buffersize=WrappedDefault(0))
def descr_new_nditer(space, w_subtype, w_seq, w_flags, w_op_flags, w_op_dtypes,
                 w_casting, w_op_axes, w_itershape, w_buffersize, w_order):
    npy_order = order_converter(space, w_order, NPY.KEEPORDER)
    buffersize = space.int_w(w_buffersize) 
    return W_NDIter(space, w_seq, w_flags, w_op_flags, w_op_dtypes, w_casting, w_op_axes,
                    w_itershape, buffersize, npy_order)

W_NDIter.typedef = TypeDef('numpy.nditer',
    __new__ = interp2app(descr_new_nditer),

    __iter__ = interp2app(W_NDIter.descr_iter),
    __getitem__ = interp2app(W_NDIter.descr_getitem),
    __setitem__ = interp2app(W_NDIter.descr_setitem),
    __len__ = interp2app(W_NDIter.descr_len),

    next = interp2app(W_NDIter.descr_next),
    iternext = interp2app(W_NDIter.descr_iternext),
    copy = interp2app(W_NDIter.descr_copy),
    debug_print = interp2app(W_NDIter.descr_debug_print),
    enable_external_loop = interp2app(W_NDIter.descr_enable_external_loop),
    remove_axis = interp2app(W_NDIter.descr_remove_axis),
    remove_multi_index = interp2app(W_NDIter.descr_remove_multi_index),
    reset = interp2app(W_NDIter.descr_reset),

    operands = GetSetProperty(W_NDIter.descr_get_operands),
    dtypes = GetSetProperty(W_NDIter.descr_get_dtypes),
    finished = GetSetProperty(W_NDIter.descr_get_finished),
    has_delayed_bufalloc = GetSetProperty(W_NDIter.descr_get_has_delayed_bufalloc),
    has_index = GetSetProperty(W_NDIter.descr_get_has_index),
    index = GetSetProperty(W_NDIter.descr_get_index),
    has_multi_index = GetSetProperty(W_NDIter.descr_get_has_multi_index),
    multi_index = GetSetProperty(W_NDIter.descr_get_multi_index),
    iterationneedsapi = GetSetProperty(W_NDIter.descr_get_iterationneedsapi),
    iterindex = GetSetProperty(W_NDIter.descr_get_iterindex),
    itersize = GetSetProperty(W_NDIter.descr_get_itersize),
    itviews = GetSetProperty(W_NDIter.descr_get_itviews),
    ndim = GetSetProperty(W_NDIter.descr_get_ndim),
    nop = GetSetProperty(W_NDIter.descr_get_nop),
    shape = GetSetProperty(W_NDIter.descr_get_shape),
    value = GetSetProperty(W_NDIter.descr_get_value),
)
W_NDIter.typedef.acceptable_as_base_class = False
