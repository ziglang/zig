from pypy.interpreter.buffer import BufferView
from pypy.interpreter.error import oefmt
from rpython.rlib import jit, rgc
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rlib.listsort import make_timsort_class
from rpython.rlib.buffer import RawBuffer
from rpython.rlib.debug import make_sure_not_resized
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.rawstorage import alloc_raw_storage, free_raw_storage, \
    raw_storage_getitem, raw_storage_setitem, RAW_STORAGE
from rpython.rtyper.lltypesystem import rffi, lltype, llmemory
from pypy.module.micronumpy import support, loop, constants as NPY
from pypy.module.micronumpy.base import convert_to_array, W_NDimArray, \
    ArrayArgumentException, W_NumpyObject
from pypy.module.micronumpy.iterators import ArrayIter
from pypy.module.micronumpy.strides import (
    IntegerChunk, SliceChunk, NewAxisChunk, EllipsisChunk, BooleanChunk,
    new_view, calc_strides, calc_new_strides, shape_agreement,
    calculate_broadcast_strides, calc_backstrides, calc_start, is_c_contiguous,
    is_f_contiguous)
from rpython.rlib.objectmodel import keepalive_until_here

TimSort = make_timsort_class()
class StrideSort(TimSort):
    '''
    argsort (return the indices to sort) a list of strides
    '''
    def __init__(self, rangelist, strides, order):
        self.strides = strides
        self.order = order
        TimSort.__init__(self, rangelist)

    def lt(self, a, b):
        if self.order == NPY.CORDER:
            return self.strides[a] <= self.strides[b]
        return self.strides[a] < self.strides[b]


class BaseConcreteArray(object):
    _immutable_fields_ = ['dtype?', 'storage', 'start', 'size', 'shape[*]',
                          'strides[*]', 'backstrides[*]', 'order', 'gcstruct',
                          'flags']
    start = 0
    parent = None
    flags = 0

    # JIT hints that length of all those arrays is a constant

    def get_shape(self):
        shape = self.shape
        jit.hint(len(shape), promote=True)
        return shape

    def get_strides(self):
        strides = self.strides
        jit.hint(len(strides), promote=True)
        return strides

    def get_backstrides(self):
        backstrides = self.backstrides
        jit.hint(len(backstrides), promote=True)
        return backstrides

    def get_flags(self):
        return self.flags

    def getitem(self, index):
        return self.dtype.read(self, index, 0)

    def getitem_bool(self, index):
        return self.dtype.read_bool(self, index, 0)

    def setitem(self, index, value):
        self.dtype.store(self, index, 0, value)

    @jit.unroll_safe
    def setslice(self, space, arr):
        if arr.get_size() == 1:
            # we can always set self[:] = scalar
            pass
        elif len(arr.get_shape()) >  len(self.get_shape()):
            # record arrays get one extra dimension
            if not self.dtype.is_record() or \
                    len(arr.get_shape()) > len(self.get_shape()) + 1:
                raise oefmt(space.w_ValueError,
                    "could not broadcast input array from shape "
                    "(%s) into shape (%s)",
                    ','.join([str(x) for x in arr.get_shape()]),
                    ','.join([str(x) for x in self.get_shape()]),
                    )
        shape = shape_agreement(space, self.get_shape(), arr)
        impl = arr.implementation
        if impl.storage == self.storage:
            impl = impl.copy(space)
        loop.setslice(space, shape, self, impl)

    def get_size(self):
        return self.size // self.dtype.elsize

    def get_storage_size(self):
        return self.size

    def reshape(self, orig_array, new_shape, order=NPY.ANYORDER):
        # Since we got to here, prod(new_shape) == self.size
        order = support.get_order_as_CF(self.order, order)
        new_strides = None
        if self.size == 0:
            new_strides, _ = calc_strides(new_shape, self.dtype, order)
        else:
            if len(self.get_shape()) == 0:
                new_strides = [self.dtype.elsize] * len(new_shape)
            else:
                new_strides = calc_new_strides(new_shape, self.get_shape(),
                                               self.get_strides(), order)
                if new_strides is None or len(new_strides) != len(new_shape):
                    return None
        if new_strides is not None:
            # We can create a view, strides somehow match up.
            new_backstrides = calc_backstrides(new_strides, new_shape)
            assert isinstance(orig_array, W_NDimArray) or orig_array is None
            return SliceArray(self.start, new_strides, new_backstrides,
                              new_shape, self, orig_array)
        return None

    def get_view(self, space, orig_array, dtype, new_shape, strides=None, backstrides=None):
        if not strides:
            strides, backstrides = calc_strides(new_shape, dtype,
                                                    self.order)
        return SliceArray(self.start, strides, backstrides, new_shape,
                          self, orig_array, dtype=dtype)

    def get_real(self, space, orig_array):
        strides = self.get_strides()
        backstrides = self.get_backstrides()
        if self.dtype.is_complex():
            dtype = self.dtype.get_float_dtype(space)
            return SliceArray(self.start, strides, backstrides,
                              self.get_shape(), self, orig_array, dtype=dtype)
        return SliceArray(self.start, strides, backstrides,
                          self.get_shape(), self, orig_array)

    def set_real(self, space, orig_array, w_value):
        tmp = self.get_real(space, orig_array)
        tmp.setslice(space, convert_to_array(space, w_value))

    def get_imag(self, space, orig_array):
        strides = self.get_strides()
        backstrides = self.get_backstrides()
        if self.dtype.is_complex():
            dtype = self.dtype.get_float_dtype(space)
            return SliceArray(self.start + dtype.elsize, strides, backstrides,
                              self.get_shape(), self, orig_array, dtype=dtype)
        impl = NonWritableArray(self.get_shape(), self.dtype, self.order,
                                strides, backstrides)
        if not self.dtype.is_flexible():
            impl.fill(space, self.dtype.box(0))
        return impl

    def set_imag(self, space, orig_array, w_value):
        tmp = self.get_imag(space, orig_array)
        tmp.setslice(space, convert_to_array(space, w_value))

    # -------------------- applevel get/setitem -----------------------

    @jit.unroll_safe
    def _lookup_by_index(self, space, view_w):
        item = self.start
        strides = self.get_strides()
        for i, w_index in enumerate(view_w):
            if space.isinstance_w(w_index, space.w_slice):
                raise IndexError
            idx = support.index_w(space, w_index)
            if idx < 0:
                idx = self.get_shape()[i] + idx
            if idx < 0 or idx >= self.get_shape()[i]:
                raise oefmt(space.w_IndexError,
                            "index %d is out of bounds for axis %d with size "
                            "%d", idx, i, self.get_shape()[i])
            item += idx * strides[i]
        return item

    @jit.unroll_safe
    def _lookup_by_unwrapped_index(self, space, lst):
        item = self.start
        shape = self.get_shape()
        strides = self.get_strides()
        assert len(lst) == len(shape)
        for i, idx in enumerate(lst):
            if idx < 0:
                idx = shape[i] + idx
            if idx < 0 or idx >= shape[i]:
                raise oefmt(space.w_IndexError,
                            "index %d is out of bounds for axis %d with size "
                            "%d", idx, i, self.get_shape()[i])
            item += idx * strides[i]
        return item

    def getitem_index(self, space, index):
        return self.getitem(self._lookup_by_unwrapped_index(space, index))

    def setitem_index(self, space, index, value):
        self.setitem(self._lookup_by_unwrapped_index(space, index), value)

    @jit.unroll_safe
    def _single_item_index(self, space, w_idx):
        """ Return an index of single item if possible, otherwise raises
        IndexError
        """
        if (space.isinstance_w(w_idx, space.w_text) or
            space.isinstance_w(w_idx, space.w_slice) or
            space.is_w(w_idx, space.w_None)):
            raise IndexError
        if isinstance(w_idx, W_NDimArray) and not w_idx.is_scalar():
            raise ArrayArgumentException
        shape = self.get_shape()
        shape_len = len(shape)
        view_w = None
        if space.isinstance_w(w_idx, space.w_list):
            raise ArrayArgumentException
        if space.isinstance_w(w_idx, space.w_tuple):
            view_w = space.fixedview(w_idx)
            if len(view_w) != shape_len:
                raise IndexError
            # check for arrays
            for w_item in view_w:
                if (isinstance(w_item, W_NDimArray) or
                    space.isinstance_w(w_item, space.w_list)):
                    raise ArrayArgumentException
                elif space.is_w(w_item, space.w_Ellipsis):
                    raise IndexError
            return self._lookup_by_index(space, view_w)
        if shape_len == 0:
            raise oefmt(space.w_IndexError, "too many indices for array")
        elif shape_len > 1:
            raise IndexError
        idx = support.index_w(space, w_idx)
        return self._lookup_by_index(space, [space.newint(idx)])

    @jit.unroll_safe
    def _prepare_slice_args(self, space, w_idx):
        from pypy.module.micronumpy import boxes
        if space.isinstance_w(w_idx, space.w_text):
            raise oefmt(space.w_IndexError, "only integers, slices (`:`), "
                "ellipsis (`...`), numpy.newaxis (`None`) and integer or "
                "boolean arrays are valid indices")
        if space.isinstance_w(w_idx, space.w_slice):
            if len(self.get_shape()) == 0:
                raise oefmt(space.w_ValueError, "cannot slice a 0-d array")
            return [SliceChunk(w_idx), EllipsisChunk()]
        elif space.isinstance_w(w_idx, space.w_int):
            return [IntegerChunk(w_idx), EllipsisChunk()]
        elif isinstance(w_idx, W_NDimArray) and w_idx.is_scalar():
            w_idx = w_idx.get_scalar_value().item(space)
            if not space.isinstance_w(w_idx, space.w_int) and \
                    not space.isinstance_w(w_idx, space.w_bool):
                raise oefmt(space.w_IndexError,
                            "arrays used as indices must be of integer (or "
                            "boolean) type")
            return [IntegerChunk(w_idx), EllipsisChunk()]
        elif space.is_w(w_idx, space.w_None):
            return [NewAxisChunk(), EllipsisChunk()]
        result = []
        has_ellipsis = False
        has_filter = False
        for w_item in space.fixedview(w_idx):
            if space.is_w(w_item, space.w_Ellipsis):
                if has_ellipsis:
                    # in CNumPy, this is only a deprecation warning
                    raise oefmt(space.w_ValueError,
                        "an index can only have a single Ellipsis (`...`); "
                        "replace all but one with slices (`:`).")
                result.append(EllipsisChunk())
                has_ellipsis = True
            elif space.is_w(w_item, space.w_None):
                result.append(NewAxisChunk())
            elif space.isinstance_w(w_item, space.w_slice):
                result.append(SliceChunk(w_item))
            elif isinstance(w_item, W_NDimArray) and w_item.get_dtype().is_bool():
                if has_filter:
                    # in CNumPy, the support for this is incomplete
                    raise oefmt(space.w_ValueError,
                        "an index can only have a single boolean mask; "
                        "use np.take or create a sinlge mask array")
                has_filter = True
                result.append(BooleanChunk(w_item))
            elif isinstance(w_item, boxes.W_GenericBox):
                result.append(IntegerChunk(w_item.descr_int(space)))
            else:
                result.append(IntegerChunk(w_item))
        if not has_ellipsis:
            result.append(EllipsisChunk())
        return result

    def descr_getitem(self, space, orig_arr, w_index):
        try:
            item = self._single_item_index(space, w_index)
            return self.getitem(item)
        except IndexError:
            # not a single result
            chunks = self._prepare_slice_args(space, w_index)
            copy = False
            if isinstance(chunks[0], BooleanChunk):
                # numpy compatibility
                copy = True
            w_ret = new_view(space, orig_arr, chunks)
            if copy:
                w_ret = w_ret.descr_copy(space, space.newint(w_ret.get_order()))
            return w_ret

    def descr_setitem(self, space, orig_arr, w_index, w_value):
        try:
            item = self._single_item_index(space, w_index)
            self.setitem(item, self.dtype.coerce(space, w_value))
        except IndexError:
            w_value = convert_to_array(space, w_value)
            chunks = self._prepare_slice_args(space, w_index)
            view = new_view(space, orig_arr, chunks)
            view.implementation.setslice(space, w_value)

    def transpose(self, orig_array, axes=None):
        if len(self.get_shape()) < 2:
            return self
        strides = []
        backstrides = []
        shape = []
        if axes is None:
            axes = range(len(self.get_shape()) - 1, -1, -1)
        for i in axes:
            strides.append(self.get_strides()[i])
            backstrides.append(self.get_backstrides()[i])
            shape.append(self.get_shape()[i])
        return SliceArray(self.start, strides,
                          backstrides, shape, self, orig_array)

    def copy(self, space, order=NPY.ANYORDER):
        if order == NPY.ANYORDER:
            order = NPY.KEEPORDER
        return self.astype(space, self.dtype, order, copy=True)

    def create_iter(self, shape=None, backward_broadcast=False):
        if shape is not None and \
                support.product(shape) > support.product(self.get_shape()):
            r = calculate_broadcast_strides(self.get_strides(),
                                            self.get_backstrides(),
                                            self.get_shape(), shape,
                                            backward_broadcast)
            i = ArrayIter(self, support.product(shape), shape, r[0], r[1])
        else:
            i = ArrayIter(self, self.get_size(), self.shape,
                          self.strides, self.backstrides)
        return i, i.reset()

    def swapaxes(self, space, orig_arr, axis1, axis2):
        shape = self.get_shape()[:]
        strides = self.get_strides()[:]
        backstrides = self.get_backstrides()[:]
        shape[axis1], shape[axis2] = shape[axis2], shape[axis1]
        strides[axis1], strides[axis2] = strides[axis2], strides[axis1]
        backstrides[axis1], backstrides[axis2] = backstrides[axis2], backstrides[axis1]
        return W_NDimArray.new_slice(space, self.start, strides,
                                     backstrides, shape, self, orig_arr)

    def nonzero(self, space, index_type):
        s = loop.count_all_true_concrete(self)
        box = index_type.itemtype.box
        nd = len(self.get_shape()) or 1
        w_res = W_NDimArray.from_shape(space, [s, nd], index_type)
        loop.nonzero(w_res, self, box)
        w_res = w_res.implementation.swapaxes(space, w_res, 0, 1)
        l_w = [w_res.descr_getitem(space, space.newint(d)) for d in range(nd)]
        return space.newtuple(l_w)

    ##def get_storage(self):
    ##    return self.storage
    ## use a safer context manager
    def __enter__(self):
        return self.storage

    def __exit__(self, typ, value, traceback):
        keepalive_until_here(self)

    def get_buffer(self, space, flags):
        errtype = space.w_ValueError # should be BufferError, numpy does this instead
        if ((flags & space.BUF_C_CONTIGUOUS) == space.BUF_C_CONTIGUOUS and
                not self.flags & NPY.ARRAY_C_CONTIGUOUS):
           raise oefmt(errtype, "ndarray is not C-contiguous")
        if ((flags & space.BUF_F_CONTIGUOUS) == space.BUF_F_CONTIGUOUS and
                not self.flags & NPY.ARRAY_F_CONTIGUOUS):
           raise oefmt(errtype, "ndarray is not Fortran contiguous")
        if ((flags & space.BUF_ANY_CONTIGUOUS) == space.BUF_ANY_CONTIGUOUS and
                not (self.flags & NPY.ARRAY_F_CONTIGUOUS or
                     self.flags & NPY.ARRAY_C_CONTIGUOUS)):
           raise oefmt(errtype, "ndarray is not contiguous")
        if ((flags & space.BUF_STRIDES) != space.BUF_STRIDES and
                not self.flags & NPY.ARRAY_C_CONTIGUOUS):
           raise oefmt(errtype, "ndarray is not C-contiguous")
        if ((flags & space.BUF_WRITABLE) == space.BUF_WRITABLE and
            not self.flags & NPY.ARRAY_WRITEABLE):
           raise oefmt(errtype, "buffer source array is read-only")
        readonly = not (flags & space.BUF_WRITABLE) == space.BUF_WRITABLE
        return ArrayView(self, readonly)

    def astype(self, space, dtype, order, copy=True):
        # copy the general pattern of the strides
        # but make the array storage contiguous in memory
        shape = self.get_shape()
        strides = self.get_strides()
        if order not in (NPY.KEEPORDER, NPY.FORTRANORDER, NPY.CORDER):
            raise oefmt(space.w_ValueError, "Unknown order %d in astype", order)
        if len(strides) == 0:
            t_strides = []
            backstrides = []
        elif order in (NPY.FORTRANORDER, NPY.CORDER):
            t_strides, backstrides = calc_strides(shape, dtype, order)
        else:
            indx_array = range(len(strides))
            list_sorter = StrideSort(indx_array, strides, self.order)
            list_sorter.sort()
            t_elsize = dtype.elsize
            t_strides = strides[:]
            base = dtype.elsize
            for i in indx_array:
                t_strides[i] = base
                base *= shape[i]
            backstrides = calc_backstrides(t_strides, shape)
        order = support.get_order_as_CF(self.order, order)
        impl = ConcreteArray(shape, dtype, order, t_strides, backstrides)
        if copy:
            loop.setslice(space, impl.get_shape(), impl, self)
        return impl

OBJECTSTORE = lltype.GcStruct('ObjectStore',
                              ('length', lltype.Signed),
                              ('step', lltype.Signed),
                              ('storage', llmemory.Address),
                              rtti=True)
offset_of_storage = llmemory.offsetof(OBJECTSTORE, 'storage')
offset_of_length = llmemory.offsetof(OBJECTSTORE, 'length')
offset_of_step = llmemory.offsetof(OBJECTSTORE, 'step')

V_OBJECTSTORE = lltype.nullptr(OBJECTSTORE)

def customtrace(gc, obj, callback, arg):
    #debug_print('in customtrace w/obj', obj)
    length = (obj + offset_of_length).signed[0]
    step = (obj + offset_of_step).signed[0]
    storage = (obj + offset_of_storage).address[0]
    #debug_print('tracing', length, 'objects in ndarray.storage')
    i = 0
    while i < length:
        gc._trace_callback(callback, arg, storage)
        storage += step
        i += 1

lambda_customtrace = lambda: customtrace

def _setup():
    rgc.register_custom_trace_hook(OBJECTSTORE, lambda_customtrace)

@jit.dont_look_inside
def _create_objectstore(storage, length, elsize):
    gcstruct = lltype.malloc(OBJECTSTORE)
    # JIT does not support cast_ptr_to_adr
    gcstruct.storage = llmemory.cast_ptr_to_adr(storage)
    #print 'create gcstruct',gcstruct,'with storage',storage,'as',gcstruct.storage
    gcstruct.length = length
    gcstruct.step = elsize
    return gcstruct


class ConcreteArrayNotOwning(BaseConcreteArray):
    def __init__(self, shape, dtype, order, strides, backstrides, storage, start=0):
        make_sure_not_resized(shape)
        make_sure_not_resized(strides)
        make_sure_not_resized(backstrides)
        self.shape = shape
        # already tested for overflow in from_shape_and_storage
        self.size = support.product(shape) * dtype.elsize
        if order not in (NPY.CORDER, NPY.FORTRANORDER):
            raise oefmt(dtype.itemtype.space.w_ValueError, "ConcreteArrayNotOwning but order is not 0,1 rather %d", order)
        self.order = order
        self.dtype = dtype
        self.strides = strides
        self.backstrides = backstrides
        self.storage = storage
        self.start = start
        self.gcstruct = V_OBJECTSTORE

    def fill(self, space, box):
        self.dtype.itemtype.fill(
            self.storage, self.dtype.elsize, self.dtype.is_native(),
            box, 0, self.size, 0, self.gcstruct)

    def set_shape(self, space, orig_array, new_shape):
        if len(new_shape) > NPY.MAXDIMS:
            raise oefmt(space.w_ValueError,
                "sequence too large; cannot be greater than %d", NPY.MAXDIMS)
        try:
            ovfcheck(support.product_check(new_shape) * self.dtype.elsize)
        except OverflowError as e:
            raise oefmt(space.w_ValueError, "array is too big.")
        strides, backstrides = calc_strides(new_shape, self.dtype,
                                                    self.order)
        return SliceArray(self.start, strides, backstrides, new_shape, self,
                          orig_array)

    def set_dtype(self, space, dtype):
        # size/shape/strides shouldn't change
        assert dtype.elsize == self.dtype.elsize
        self.dtype = dtype

    def argsort(self, space, w_axis):
        from .selection import argsort_array
        return argsort_array(self, space, w_axis)

    def sort(self, space, w_axis, w_order):
        from .selection import sort_array
        return sort_array(self, space, w_axis, w_order)

    def base(self):
        return None

class ConcreteArray(ConcreteArrayNotOwning):
    def __init__(self, shape, dtype, order, strides, backstrides,
                 storage=lltype.nullptr(RAW_STORAGE), zero=True):
        gcstruct = V_OBJECTSTORE
        flags = NPY.ARRAY_ALIGNED | NPY.ARRAY_WRITEABLE
        try:
            length = support.product_check(shape)
            self.size = ovfcheck(length * dtype.elsize)
        except OverflowError:
            raise oefmt(dtype.itemtype.space.w_ValueError, "array is too big.")
        if storage == lltype.nullptr(RAW_STORAGE):
            if dtype.num == NPY.OBJECT:
                storage = dtype.itemtype.malloc(length * dtype.elsize, zero=True)
                gcstruct = _create_objectstore(storage, length, dtype.elsize)
            else:
                storage = dtype.itemtype.malloc(length * dtype.elsize, zero=zero)
            flags |= NPY.ARRAY_OWNDATA
        start = calc_start(shape, strides)
        ConcreteArrayNotOwning.__init__(self, shape, dtype, order, strides, backstrides,
                                        storage, start=start)
        self.gcstruct = gcstruct
        if is_c_contiguous(self):
            flags |= NPY.ARRAY_C_CONTIGUOUS
        if is_f_contiguous(self):
            flags |= NPY.ARRAY_F_CONTIGUOUS
        self.flags = flags

    def __del__(self):
        if self.gcstruct:
            self.gcstruct.length = 0
        free_raw_storage(self.storage, track_allocation=False)


class ConcreteArrayWithBase(ConcreteArrayNotOwning):
    def __init__(self, shape, dtype, order, strides, backstrides, storage,
                 orig_base, start=0):
        ConcreteArrayNotOwning.__init__(self, shape, dtype, order,
                                        strides, backstrides, storage, start)
        self.orig_base = orig_base
        if isinstance(orig_base, W_NumpyObject):
            flags = orig_base.get_flags() & NPY.ARRAY_ALIGNED
            flags |=  orig_base.get_flags() & NPY.ARRAY_WRITEABLE
        else:
            flags = 0
        if is_c_contiguous(self):
            flags |= NPY.ARRAY_C_CONTIGUOUS
        if is_f_contiguous(self):
            flags |= NPY.ARRAY_F_CONTIGUOUS
        self.flags = flags

    def base(self):
        return self.orig_base


class ConcreteNonWritableArrayWithBase(ConcreteArrayWithBase):
    def __init__(self, shape, dtype, order, strides, backstrides, storage,
                 orig_base, start=0):
        ConcreteArrayWithBase.__init__(self, shape, dtype, order, strides,
                backstrides, storage, orig_base, start)
        self.flags &= ~ NPY.ARRAY_WRITEABLE

    def descr_setitem(self, space, orig_array, w_index, w_value):
        raise oefmt(space.w_ValueError, "assignment destination is read-only")


class NonWritableArray(ConcreteArray):
    def __init__(self, shape, dtype, order, strides, backstrides,
                 storage=lltype.nullptr(RAW_STORAGE), zero=True):
        ConcreteArray.__init__(self, shape, dtype, order, strides, backstrides,
                    storage, zero)
        self.flags &= ~ NPY.ARRAY_WRITEABLE

    def descr_setitem(self, space, orig_array, w_index, w_value):
        raise oefmt(space.w_ValueError, "assignment destination is read-only")


class SliceArray(BaseConcreteArray):
    def __init__(self, start, strides, backstrides, shape, parent, orig_arr,
                 dtype=None):
        self.strides = strides
        self.backstrides = backstrides
        self.shape = shape
        if dtype is None:
            dtype = parent.dtype
        if isinstance(parent, SliceArray):
            parent = parent.parent # one level only
        self.parent = parent
        self.storage = parent.storage
        self.gcstruct = parent.gcstruct
        if parent.order not in (NPY.CORDER, NPY.FORTRANORDER):
            raise oefmt(dtype.itemtype.space.w_ValueError, "SliceArray but parent order is not 0,1 rather %d", parent.order)
        self.order = parent.order
        self.dtype = dtype
        try:
            self.size = ovfcheck(support.product_check(shape) * self.dtype.elsize)
        except OverflowError:
            raise oefmt(dtype.itemtype.space.w_ValueError, "array is too big.")
        self.start = start
        self.orig_arr = orig_arr
        flags = parent.flags & NPY.ARRAY_ALIGNED
        flags |= parent.flags & NPY.ARRAY_WRITEABLE
        if is_c_contiguous(self):
            flags |= NPY.ARRAY_C_CONTIGUOUS
        if is_f_contiguous(self):
            flags |= NPY.ARRAY_F_CONTIGUOUS
        self.flags = flags

    def base(self):
        return self.orig_arr

    def fill(self, space, box):
        loop.fill(self, box.convert_to(space, self.dtype))

    def set_shape(self, space, orig_array, new_shape):
        if len(new_shape) > NPY.MAXDIMS:
            raise oefmt(space.w_ValueError,
                "sequence too large; cannot be greater than %d", NPY.MAXDIMS)
        try:
            ovfcheck(support.product_check(new_shape) * self.dtype.elsize)
        except OverflowError as e:
            raise oefmt(space.w_ValueError, "array is too big.")
        if len(self.get_shape()) < 2 or self.size == 0:
            # TODO: this code could be refactored into calc_strides
            # but then calc_strides would have to accept a stepping factor
            strides = []
            backstrides = []
            dtype = self.dtype
            try:
                s = self.get_strides()[0] // dtype.elsize
            except IndexError:
                s = 1
            if self.order != NPY.FORTRANORDER:
                new_shape.reverse()
            for sh in new_shape:
                strides.append(s * dtype.elsize)
                backstrides.append(s * (sh - 1) * dtype.elsize)
                s *= max(1, sh)
            if self.order != NPY.FORTRANORDER:
                strides.reverse()
                backstrides.reverse()
                new_shape.reverse()
            return self.__class__(self.start, strides, backstrides, new_shape,
                              self, orig_array)
        new_strides = calc_new_strides(new_shape, self.get_shape(),
                                       self.get_strides(),
                                       self.order)
        if new_strides is None or len(new_strides) != len(new_shape):
            raise oefmt(space.w_AttributeError,
                "incompatible shape for a non-contiguous array")
        new_backstrides = [0] * len(new_shape)
        for nd in range(len(new_shape)):
            new_backstrides[nd] = (new_shape[nd] - 1) * new_strides[nd]
        return self.__class__(self.start, new_strides, new_backstrides, new_shape,
                          self, orig_array)

    def sort(self, space, w_axis, w_order):
        from .selection import sort_array
        return sort_array(self, space, w_axis, w_order)

class NonWritableSliceArray(SliceArray):
    def __init__(self, start, strides, backstrides, shape, parent, orig_arr,
                 dtype=None):
        SliceArray.__init__(self, start, strides, backstrides, shape, parent,
                        orig_arr, dtype)
        self.flags &= ~NPY.ARRAY_WRITEABLE

    def descr_setitem(self, space, orig_array, w_index, w_value):
        raise oefmt(space.w_ValueError, "assignment destination is read-only")


class VoidBoxStorage(BaseConcreteArray):
    def __init__(self, size, dtype):
        self.storage = alloc_raw_storage(size)
        self.gcstruct = V_OBJECTSTORE
        self.dtype = dtype
        self.size = size
        self.flags = (NPY.ARRAY_C_CONTIGUOUS | NPY.ARRAY_F_CONTIGUOUS |
                     NPY.ARRAY_WRITEABLE | NPY.ARRAY_ALIGNED)

    def __del__(self):
        free_raw_storage(self.storage)


class ArrayData(RawBuffer):
    _immutable_ = True
    def __init__(self, impl, readonly):
        self.impl = impl
        self.readonly = readonly

    def getitem(self, index):
        return raw_storage_getitem(lltype.Char, self.impl.storage,
                 index + self.impl.start)

    def setitem(self, index, v):
        # XXX what if self.readonly?
        raw_storage_setitem(self.impl.storage, index + self.impl.start,
                            rffi.cast(lltype.Char, v))

    def getlength(self):
        return self.impl.size - self.impl.start

    def get_raw_address(self):
        from rpython.rtyper.lltypesystem import rffi
        return rffi.ptradd(self.impl.storage, self.impl.start)


class ArrayView(BufferView):
    _immutable_ = True

    def __init__(self, impl, readonly):
        self.impl = impl
        self.readonly = readonly
        self.data = ArrayData(impl, readonly)

    def getlength(self):
        return self.data.getlength()

    def getbytes(self, start, size):
        return self.data[start:start + size]

    def as_readbuf(self):
        return ArrayData(self.impl, readonly=True)

    def as_writebuf(self):
        assert not self.readonly
        return ArrayData(self.impl, readonly=False)

    def getformat(self):
        sb = StringBuilder()
        self.impl.dtype.getformat(sb)
        return sb.build()

    def getitemsize(self):
        return self.impl.dtype.elsize

    def getndim(self):
        return len(self.impl.shape)

    def getshape(self):
        return self.impl.shape

    def getstrides(self):
        return self.impl.strides

    def get_raw_address(self):
        return self.data.get_raw_address()
