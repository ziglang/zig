from pypy.interpreter.error import oefmt
from rpython.rlib.listsort import make_timsort_class
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rarithmetic import widen
from rpython.rlib.rawstorage import raw_storage_getitem, raw_storage_setitem, \
        free_raw_storage, alloc_raw_storage
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.micronumpy import descriptor, types, constants as NPY
from pypy.module.micronumpy.base import W_NDimArray
from pypy.module.micronumpy.iterators import AllButAxisIter

INT_SIZE = rffi.sizeof(lltype.Signed)

all_types = (types.all_float_types + types.all_complex_types +
             types.all_int_types)
all_types = [i for i in all_types if not issubclass(i[0], types.Float16)]
all_types = unrolling_iterable(all_types)


def make_argsort_function(space, itemtype, comp_type, count=1):
    TP = itemtype.T
    step = rffi.sizeof(TP)

    class Repr(object):
        def __init__(self, index_stride_size, stride_size, size, values,
                     indexes, index_start, start):
            self.index_stride_size = index_stride_size
            self.stride_size = stride_size
            self.index_start = index_start
            self.start = start
            self.size = size
            self.values = values
            self.indexes = indexes

        def getitem(self, idx):
            if count < 2:
                v = raw_storage_getitem(TP, self.values, idx * self.stride_size
                                    + self.start)
            else:
                v = []
                for i in range(count):
                    _v = raw_storage_getitem(TP, self.values, idx * self.stride_size
                                    + self.start + step * i)
                    v.append(_v)
            if comp_type == 'int':
                v = widen(v)
            elif comp_type == 'float':
                v = float(v)
            elif comp_type == 'complex':
                v = [float(v[0]),float(v[1])]
            else:
                raise NotImplementedError('cannot reach')
            return (v, raw_storage_getitem(lltype.Signed, self.indexes,
                                           idx * self.index_stride_size +
                                           self.index_start))

        def setitem(self, idx, item):
            if count < 2:
                raw_storage_setitem(self.values, idx * self.stride_size +
                                self.start, rffi.cast(TP, item[0]))
            else:
                i = 0
                for val in item[0]:
                    raw_storage_setitem(self.values, idx * self.stride_size +
                                self.start + i*step, rffi.cast(TP, val))
                    i += 1
            raw_storage_setitem(self.indexes, idx * self.index_stride_size +
                                self.index_start, item[1])

    class ArgArrayRepWithStorage(Repr):
        def __init__(self, index_stride_size, stride_size, size):
            start = 0
            dtype = descriptor.get_dtype_cache(space).w_longdtype
            indexes = dtype.itemtype.malloc(size * dtype.elsize)
            values = alloc_raw_storage(size * stride_size,
                                            track_allocation=False)
            Repr.__init__(self, dtype.elsize, stride_size,
                          size, values, indexes, start, start)

        def __del__(self):
            free_raw_storage(self.indexes, track_allocation=False)
            free_raw_storage(self.values, track_allocation=False)

    def arg_getitem(lst, item):
        return lst.getitem(item)

    def arg_setitem(lst, item, value):
        lst.setitem(item, value)

    def arg_length(lst):
        return lst.size

    def arg_getitem_slice(lst, start, stop):
        retval = ArgArrayRepWithStorage(lst.index_stride_size, lst.stride_size,
                stop-start)
        for i in range(stop-start):
            retval.setitem(i, lst.getitem(i+start))
        return retval

    if count < 2:
        def arg_lt(a, b):
            # Does numpy do <= ?
            return a[0] < b[0] or b[0] != b[0] and a[0] == a[0]
    else:
        def arg_lt(a, b):
            for i in range(count):
                if b[0][i] != b[0][i] and a[0][i] == a[0][i]:
                    return True
                elif b[0][i] == b[0][i] and a[0][i] != a[0][i]:
                    return False
            for i in range(count):
                if a[0][i] < b[0][i]:
                    return True
                elif a[0][i] > b[0][i]:
                    return False
            # Does numpy do True?
            return False

    ArgSort = make_timsort_class(arg_getitem, arg_setitem, arg_length,
                                 arg_getitem_slice, arg_lt)

    def argsort(arr, space, w_axis):
        if w_axis is space.w_None:
            # note that it's fine ot pass None here as we're not going
            # to pass the result around (None is the link to base in slices)
            if arr.get_size() > 0:
                arr = arr.reshape(None, [arr.get_size()])
            axis = 0
        elif w_axis is None:
            axis = -1
        else:
            axis = space.int_w(w_axis)
        # create array of indexes
        dtype = descriptor.get_dtype_cache(space).w_longdtype
        index_arr = W_NDimArray.from_shape(space, arr.get_shape(), dtype)
        with index_arr.implementation as storage, arr as arr_storage:
            if len(arr.get_shape()) == 1:
                for i in range(arr.get_size()):
                    raw_storage_setitem(storage, i * INT_SIZE, i)
                r = Repr(INT_SIZE, arr.strides[0], arr.get_size(), arr_storage,
                         storage, 0, arr.start)
                ArgSort(r).sort()
            else:
                shape = arr.get_shape()
                if axis < 0:
                    axis = len(shape) + axis
                if axis < 0 or axis >= len(shape):
                    raise oefmt(space.w_IndexError, "Wrong axis %d", axis)
                arr_iter = AllButAxisIter(arr, axis)
                arr_state = arr_iter.reset()
                index_impl = index_arr.implementation
                index_iter = AllButAxisIter(index_impl, axis)
                index_state = index_iter.reset()
                stride_size = arr.strides[axis]
                index_stride_size = index_impl.strides[axis]
                axis_size = arr.shape[axis]
                while not arr_iter.done(arr_state):
                    for i in range(axis_size):
                        raw_storage_setitem(storage, i * index_stride_size +
                                            index_state.offset, i)
                    r = Repr(index_stride_size, stride_size, axis_size,
                         arr_storage, storage, index_state.offset, arr_state.offset)
                    ArgSort(r).sort()
                    arr_state = arr_iter.next(arr_state)
                    index_state = index_iter.next(index_state)
            return index_arr

    return argsort


def argsort_array(arr, space, w_axis):
    cache = space.fromcache(ArgSortCache) # that populates ArgSortClasses
    itemtype = arr.dtype.itemtype
    for tp in all_types:
        if isinstance(itemtype, tp[0]):
            return cache._lookup(tp)(arr, space, w_axis)
    # XXX this should probably be changed
    raise oefmt(space.w_NotImplementedError,
                "sorting of non-numeric types '%s' is not implemented",
                arr.dtype.get_name())


def make_sort_function(space, itemtype, comp_type, count=1):
    TP = itemtype.T
    step = rffi.sizeof(TP)

    class Repr(object):
        def __init__(self, stride_size, size, values, start):
            self.stride_size = stride_size
            self.start = start
            self.size = size
            self.values = values

        def getitem(self, item):
            if count < 2:
                v = raw_storage_getitem(TP, self.values, item * self.stride_size
                                    + self.start)
            else:
                v = []
                for i in range(count):
                    _v = raw_storage_getitem(TP, self.values, item * self.stride_size
                                    + self.start + step * i)
                    v.append(_v)
            if comp_type == 'int':
                v = widen(v)
            elif comp_type == 'float':
                v = float(v)
            elif comp_type == 'complex':
                v = [float(v[0]),float(v[1])]
            else:
                raise NotImplementedError('cannot reach')
            return (v)

        def setitem(self, idx, item):
            if count < 2:
                raw_storage_setitem(self.values, idx * self.stride_size +
                                self.start, rffi.cast(TP, item))
            else:
                i = 0
                for val in item:
                    raw_storage_setitem(self.values, idx * self.stride_size +
                                self.start + i*step, rffi.cast(TP, val))
                    i += 1

    class ArgArrayRepWithStorage(Repr):
        def __init__(self, stride_size, size):
            start = 0
            values = alloc_raw_storage(size * stride_size,
                                            track_allocation=False)
            Repr.__init__(self, stride_size,
                          size, values, start)

        def __del__(self):
            free_raw_storage(self.values, track_allocation=False)

    def arg_getitem(lst, item):
        return lst.getitem(item)

    def arg_setitem(lst, item, value):
        lst.setitem(item, value)

    def arg_length(lst):
        return lst.size

    def arg_getitem_slice(lst, start, stop):
        retval = ArgArrayRepWithStorage(lst.stride_size, stop-start)
        for i in range(stop-start):
            retval.setitem(i, lst.getitem(i+start))
        return retval

    if count < 2:
        def arg_lt(a, b):
            # handles NAN and INF
            return a < b or b != b and a == a
    else:
        def arg_lt(a, b):
            for i in range(count):
                if b[i] != b[i] and a[i] == a[i]:
                    return True
                elif b[i] == b[i] and a[i] != a[i]:
                    return False
            for i in range(count):
                if a[i] < b[i]:
                    return True
                elif a[i] > b[i]:
                    return False
            # Does numpy do True?
            return False

    ArgSort = make_timsort_class(arg_getitem, arg_setitem, arg_length,
                                 arg_getitem_slice, arg_lt)

    def sort(arr, space, w_axis):
        if w_axis is space.w_None:
            # note that it's fine to pass None here as we're not going
            # to pass the result around (None is the link to base in slices)
            arr = arr.reshape(None, [arr.get_size()])
            axis = 0
        elif w_axis is None:
            axis = -1
        else:
            axis = space.int_w(w_axis)
        with arr as storage:
            if len(arr.get_shape()) == 1:
                r = Repr(arr.strides[0], arr.get_size(), storage,
                         arr.start)
                ArgSort(r).sort()
            else:
                shape = arr.get_shape()
                if axis < 0:
                    axis = len(shape) + axis
                if axis < 0 or axis >= len(shape):
                    raise oefmt(space.w_IndexError, "Wrong axis %d", axis)
                arr_iter = AllButAxisIter(arr, axis)
                arr_state = arr_iter.reset()
                stride_size = arr.strides[axis]
                axis_size = arr.shape[axis]
                while not arr_iter.done(arr_state):
                    r = Repr(stride_size, axis_size, storage, arr_state.offset)
                    ArgSort(r).sort()
                    arr_state = arr_iter.next(arr_state)

    return sort


def sort_array(arr, space, w_axis, w_order):
    cache = space.fromcache(SortCache)  # that populates SortClasses
    itemtype = arr.dtype.itemtype
    if arr.dtype.byteorder == NPY.OPPBYTE:
        raise oefmt(space.w_NotImplementedError,
                    "sorting of non-native byteorder not supported yet")
    for tp in all_types:
        if isinstance(itemtype, tp[0]):
            return cache._lookup(tp)(arr, space, w_axis)
    # XXX this should probably be changed
    raise oefmt(space.w_NotImplementedError,
                "sorting of non-numeric types '%s' is not implemented",
                arr.dtype.get_name())


class ArgSortCache(object):
    built = False

    def __init__(self, space):
        if self.built:
            return
        self.built = True
        cache = {}
        for cls, it in all_types._items:
            if it == 'complex':
                cache[cls] = make_argsort_function(space, cls, it, 2)
            else:
                cache[cls] = make_argsort_function(space, cls, it)
        self.cache = cache
        self._lookup = specialize.memo()(lambda tp: cache[tp[0]])


class SortCache(object):
    built = False

    def __init__(self, space):
        if self.built:
            return
        self.built = True
        cache = {}
        for cls, it in all_types._items:
            if it == 'complex':
                cache[cls] = make_sort_function(space, cls, it, 2)
            else:
                cache[cls] = make_sort_function(space, cls, it)
        self.cache = cache
        self._lookup = specialize.memo()(lambda tp: cache[tp[0]])
