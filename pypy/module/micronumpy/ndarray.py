from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app, unwrap_spec, applevel, \
    WrappedDefault
from pypy.interpreter.typedef import TypeDef, GetSetProperty, \
    make_weakref_descr
from pypy.interpreter.buffer import SimpleView
from rpython.rlib import jit
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.rawstorage import RAW_STORAGE_PTR
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rtyper.lltypesystem import rffi
from rpython.tool.sourcetools import func_with_new_name
from pypy.module.micronumpy import descriptor, ufuncs, boxes, arrayops, loop, \
    support, constants as NPY
from pypy.module.micronumpy.appbridge import get_appbridge_cache
from pypy.module.micronumpy.arrayops import repeat, choose, put
from pypy.module.micronumpy.base import W_NDimArray, convert_to_array, \
    ArrayArgumentException, wrap_impl
from pypy.module.micronumpy.concrete import BaseConcreteArray, V_OBJECTSTORE
from pypy.module.micronumpy.converters import (
    multi_axis_converter, order_converter, shape_converter,
    searchside_converter, out_converter)
from pypy.module.micronumpy.flagsobj import W_FlagsObject
from pypy.module.micronumpy.strides import (
    get_shape_from_iterable, shape_agreement, shape_agreement_multiple,
    is_c_contiguous, is_f_contiguous, calc_strides, new_view, BooleanChunk,
    SliceChunk)
from pypy.module.micronumpy.casting import can_cast_array
from pypy.module.micronumpy.descriptor import get_dtype_cache



def _match_dot_shapes(space, left, right):
    left_shape = left.get_shape()
    right_shape = right.get_shape()
    my_critical_dim_size = left_shape[-1]
    right_critical_dim_size = right_shape[0]
    right_critical_dim = 0
    out_shape = []
    if len(right_shape) > 1:
        right_critical_dim = len(right_shape) - 2
        right_critical_dim_size = right_shape[right_critical_dim]
        assert right_critical_dim >= 0
        out_shape = (out_shape + left_shape[:-1] +
                     right_shape[0:right_critical_dim] +
                     right_shape[right_critical_dim + 1:])
    elif len(right_shape) > 0:
        #dot does not reduce for scalars
        out_shape = out_shape + left_shape[:-1]
    if my_critical_dim_size != right_critical_dim_size:
        raise oefmt(space.w_ValueError, "objects are not aligned")
    return out_shape, right_critical_dim

class __extend__(W_NDimArray):
    @jit.unroll_safe
    def descr_get_shape(self, space):
        shape = self.get_shape()
        return space.newtuple([space.newint(i) for i in shape])

    def descr_set_shape(self, space, w_new_shape):
        shape = get_shape_from_iterable(space, self.get_size(), w_new_shape)
        self.implementation = self.implementation.set_shape(space, self, shape)
        w_cls = space.type(self)
        if not space.is_w(w_cls, space.gettypefor(W_NDimArray)):
            # numpy madness - allow __array_finalize__(self, obj)
            # to run, in MaskedArray this modifies obj._mask
            wrap_impl(space, w_cls, self, self.implementation)

    def descr_get_strides(self, space):
        strides = self.implementation.get_strides()
        return space.newtuple([space.newint(i) for i in strides])

    def descr_get_dtype(self, space):
        return self.implementation.dtype

    def descr_set_dtype(self, space, w_dtype):
        dtype = space.interp_w(descriptor.W_Dtype, space.call_function(
            space.gettypefor(descriptor.W_Dtype), w_dtype))
        if (dtype.elsize != self.get_dtype().elsize or
                (not dtype.is_record() and self.get_dtype().is_flexible())):
            raise oefmt(space.w_ValueError,
                        "new type not compatible with array.")
        self.implementation.set_dtype(space, dtype)

    def descr_del_dtype(self, space):
        raise oefmt(space.w_AttributeError, "Cannot delete array dtype")

    def descr_get_ndim(self, space):
        return space.newint(self.ndims())

    def descr_get_itemsize(self, space):
        return space.newint(self.get_dtype().elsize)

    def descr_get_nbytes(self, space):
        return space.newint(self.get_size() * self.get_dtype().elsize)

    def descr_fill(self, space, w_value):
        self.fill(space, self.get_dtype().coerce(space, w_value))

    def descr_tostring(self, space, w_order=None):
        try:
            order = order_converter(space, w_order, NPY.CORDER)
        except:
            raise oefmt(space.w_TypeError, "order not understood")
        order = support.get_order_as_CF(self.get_order(), order)
        arr = self
        if order != arr.get_order():
            arr = W_NDimArray(self.implementation.transpose(self, None))
        return space.newtext(loop.tostring(space, arr))

    def getitem_filter(self, space, arr, axis=0):
        shape = self.get_shape()
        if arr.ndims() > 1 and arr.get_shape() != shape:
            raise oefmt(space.w_IndexError,
                        "boolean index array should have 1 dimension")
        if arr.get_size() > self.get_size():
            raise oefmt(space.w_IndexError, "index out of range for array")
        size = loop.count_all_true(arr)
        if arr.ndims() == 1:
            if self.ndims() > 1 and arr.get_shape()[0] != shape[axis]:
                msg = ("boolean index did not match indexed array along"
                      " dimension %d; dimension is %d but corresponding"
                      " boolean dimension is %d" % (axis, shape[axis],
                      arr.get_shape()[0]))
                #warning = space.gettypefor(support.W_VisibleDeprecationWarning)
                space.warn(space.newtext(msg), space.w_VisibleDeprecationWarning)
            res_shape = shape[:axis] + [size] + shape[axis+1:]
        else:
            res_shape = [size]
        w_res = W_NDimArray.from_shape(space, res_shape, self.get_dtype(),
                                       w_instance=self)
        return loop.getitem_filter(w_res, self, arr)

    def setitem_filter(self, space, idx, val):
        if idx.ndims() > 1 and idx.get_shape() != self.get_shape():
            raise oefmt(space.w_IndexError,
                        "boolean index array should have 1 dimension")
        if idx.get_size() > self.get_size():
            raise oefmt(space.w_IndexError, "index out of range for array")
        size = loop.count_all_true(idx)
        if size > val.get_size() and val.get_size() != 1:
            raise oefmt(space.w_ValueError,
                        "NumPy boolean array indexing assignment "
                        "cannot assign %d input values to "
                        "the %d output values where the mask is true",
                        val.get_size(), size)
        loop.setitem_filter(space, self, idx, val)

    def _prepare_array_index(self, space, w_index):
        if isinstance(w_index, W_NDimArray):
            return [], w_index.get_shape(), w_index.get_shape(), [w_index]
        if isinstance(w_index, boxes.W_GenericBox):
            return [], [1], [1], [w_index]
        w_lst = space.listview(w_index)
        for w_item in w_lst:
            if not (space.isinstance_w(w_item, space.w_int) or space.isinstance_w(w_item, space.w_float)):
                break
        else:
            arr = convert_to_array(space, w_index)
            return [], arr.get_shape(), arr.get_shape(), [arr]
        shape = None
        indexes_w = [None] * len(w_lst)
        res_shape = []
        arr_index_in_shape = False
        prefix = []
        for i, w_item in enumerate(w_lst):
            if isinstance(w_item, W_NDimArray) and w_item.get_dtype().is_bool():
                if w_item.ndims() > 0:
                    indexes_w[i] = w_item
                else:
                    raise oefmt(space.w_IndexError,
                        "in the future, 0-d boolean arrays will be "
                        "interpreted as a valid boolean index")
            elif (isinstance(w_item, W_NDimArray) or
                    space.isinstance_w(w_item, space.w_list)):
                w_item = convert_to_array(space, w_item)
                if shape is None:
                    shape = w_item.get_shape()
                else:
                    shape = shape_agreement(space, shape, w_item)
                indexes_w[i] = w_item
                if not arr_index_in_shape:
                    res_shape.append(-1)
                    arr_index_in_shape = True
            else:
                if space.isinstance_w(w_item, space.w_slice):
                    lgt = space.decode_index4(w_item, self.get_shape()[i])[3]
                    if not arr_index_in_shape:
                        prefix.append(w_item)
                    res_shape.append(lgt)
                indexes_w[i] = w_item
        real_shape = []
        for i in res_shape:
            if i == -1:
                real_shape += shape
            else:
                real_shape.append(i)
        return prefix, real_shape[:], shape, indexes_w

    def getitem_array_int(self, space, w_index):
        prefix, res_shape, iter_shape, indexes = \
            self._prepare_array_index(space, w_index)
        if iter_shape is None:
            # w_index is a list of slices, return a view
            chunks = self.implementation._prepare_slice_args(space, w_index)
            copy = False
            if isinstance(chunks[0], BooleanChunk):
                copy = True
            w_ret = new_view(space, self, chunks)
            if copy:
                w_ret = w_ret.descr_copy(space, space.newint(w_ret.get_order()))
            return w_ret
        shape = res_shape + self.get_shape()[len(indexes):]
        w_res = W_NDimArray.from_shape(space, shape, self.get_dtype(),
                                       self.get_order(), w_instance=self)
        if not w_res.get_size():
            return w_res
        return loop.getitem_array_int(space, self, w_res, iter_shape, indexes,
                                      prefix)

    def setitem_array_int(self, space, w_index, w_value):
        val_arr = convert_to_array(space, w_value)
        prefix, _, iter_shape, indexes = \
            self._prepare_array_index(space, w_index)
        if iter_shape is None:
            # w_index is a list of slices
            chunks = self.implementation._prepare_slice_args(space, w_index)
            dim = -1
            view = self
            for i, c in enumerate(chunks):
                if isinstance(c, BooleanChunk):
                    dim = i
                    idx = c.w_idx
                    chunks.pop(i)
                    chunks.insert(0, SliceChunk(space.newslice(space.newint(0),
                                 space.w_None, space.w_None)))
                    break
            if dim > 0:
                view = self.implementation.swapaxes(space, self, 0, dim)
            if dim >= 0:
                view = new_view(space, self, chunks)
                view.setitem_filter(space, idx, val_arr)
            else:
                view = new_view(space, self, chunks)
                view.implementation.setslice(space, val_arr)
            return
        if support.product(iter_shape) == 0:
            return
        loop.setitem_array_int(space, self, iter_shape, indexes, val_arr,
                               prefix)

    def descr_getitem(self, space, w_idx):
        if self.get_dtype().is_record():
            if space.isinstance_w(w_idx, space.w_text):
                idx = space.text_w(w_idx)
                return self.getfield(space, idx)
        if space.is_w(w_idx, space.w_Ellipsis):
            return self.descr_view(space, space.type(self))
        elif isinstance(w_idx, W_NDimArray) and w_idx.get_dtype().is_bool():
            if w_idx.ndims() > 0:
                w_ret = self.getitem_filter(space, w_idx)
            else:
                raise oefmt(space.w_IndexError,
                        "in the future, 0-d boolean arrays will be "
                        "interpreted as a valid boolean index")
        elif isinstance(w_idx, boxes.W_GenericBox):
            w_ret = self.getitem_array_int(space, w_idx)

            if isinstance(w_idx, boxes.W_IntegerBox):
                # if w_idx is integer then getitem_array_int must contain a single value and we must return it.
                # Get 0-th element of the w_ret.
                w_ret = w_ret.implementation.descr_getitem(space, self, space.newint(0))
        else:
            try:
                w_ret = self.implementation.descr_getitem(space, self, w_idx)
            except ArrayArgumentException:
                w_ret = self.getitem_array_int(space, w_idx)
        if isinstance(w_ret, boxes.W_ObjectBox):
            #return the W_Root object, not a scalar
            w_ret = w_ret.w_obj
        return w_ret

    def getitem(self, space, index_list):
        return self.implementation.getitem_index(space, index_list)

    def setitem(self, space, index_list, w_value):
        self.implementation.setitem_index(space, index_list, w_value)

    def descr_setitem(self, space, w_idx, w_value):
        if self.get_dtype().is_record():
            if space.isinstance_w(w_idx, space.w_text):
                idx = space.text_w(w_idx)
                view = self.getfield(space, idx)
                w_value = convert_to_array(space, w_value)
                view.implementation.setslice(space, w_value)
                return
        if space.is_w(w_idx, space.w_Ellipsis):
            self.implementation.setslice(space, convert_to_array(space, w_value))
            return
        # TODO: multiarray/mapping.c calls a subclass's __getitem__ here, which
        # is a big performance hit but necessary for the matrix class. The original
        # C code is like:
        #/*
        #* WARNING: There is a huge special case here. If this is not a
        #*          base class array, we have to get the view through its
        #*          very own index machinery.
        #*          Many subclasses should probably call __setitem__
        #*          with a base class ndarray view to avoid this.
        #*/
        #else if (!(index_type & (HAS_FANCY | HAS_SCALAR_ARRAY))
        #        && !PyArray_CheckExact(self)) {
        #view = (PyArrayObject *)PyObject_GetItem((PyObject *)self, ind);

        elif isinstance(w_idx, W_NDimArray) and w_idx.get_dtype().is_bool() \
                and w_idx.ndims() > 0:
            self.setitem_filter(space, w_idx, convert_to_array(space, w_value))
            return
        try:
            self.implementation.descr_setitem(space, self, w_idx, w_value)
        except ArrayArgumentException:
            self.setitem_array_int(space, w_idx, w_value)

    def getfield(self, space, field):
        dtype = self.get_dtype()
        if field not in dtype.fields:
            raise oefmt(space.w_ValueError, "no field of name %s", field)
        arr = self.implementation
        ofs, subdtype = arr.dtype.fields[field][:2]
        if subdtype.is_object() and arr.gcstruct is V_OBJECTSTORE:
            raise oefmt(space.w_NotImplementedError,
                "cannot read object from array with no gc hook")
        # ofs only changes start
        # create a view of the original array by extending
        # the shape, strides, backstrides of the array
        strides, backstrides = calc_strides(subdtype.shape,
                                            subdtype.subdtype, arr.order)
        final_shape = arr.shape + subdtype.shape
        final_strides = arr.get_strides() + strides
        final_backstrides = arr.get_backstrides() + backstrides
        final_dtype = subdtype
        if subdtype.subdtype:
            final_dtype = subdtype.subdtype
        return W_NDimArray.new_slice(space, arr.start + ofs, final_strides,
                                     final_backstrides,
                                     final_shape, arr, self, final_dtype)


    def descr_delitem(self, space, w_idx):
        raise oefmt(space.w_ValueError, "cannot delete array elements")

    def descr_len(self, space):
        shape = self.get_shape()
        if len(shape):
            return space.newint(shape[0])
        raise oefmt(space.w_TypeError, "len() of unsized object")

    def descr_repr(self, space):
        cache = get_appbridge_cache(space)
        if cache.w_array_repr is None:
            return space.newtext(self.dump_data())
        return space.call_function(cache.w_array_repr, self)

    def descr_str(self, space):
        cache = get_appbridge_cache(space)
        if cache.w_array_str is None:
            return space.newtext(self.dump_data(prefix='', separator='', suffix=''))
        return space.call_function(cache.w_array_str, self)

    def dump_data(self, prefix='array(', separator=',', suffix=')'):
        i, state = self.create_iter()
        first = True
        dtype = self.get_dtype()
        s = StringBuilder()
        s.append(prefix)
        if not self.is_scalar():
            s.append('[')
        while not i.done(state):
            if first:
                first = False
            else:
                s.append(separator)
                s.append(' ')
            if self.is_scalar() and dtype.is_str():
                s.append(i.getitem(state).raw_str())
            else:
                s.append(dtype.itemtype.str_format(i.getitem(state), add_quotes=True))
            state = i.next(state)
        if not self.is_scalar():
            s.append(']')
        s.append(suffix)
        return s.build()

    def create_iter(self, shape=None, backward_broadcast=False):
        assert isinstance(self.implementation, BaseConcreteArray)
        return self.implementation.create_iter(
            shape=shape, backward_broadcast=backward_broadcast)

    def is_scalar(self):
        return self.ndims() == 0

    def set_scalar_value(self, w_val):
        return self.implementation.setitem(self.implementation.start, w_val)

    def fill(self, space, box):
        self.implementation.fill(space, box)

    def descr_get_size(self, space):
        return space.newint(self.get_size())

    def get_size(self):
        return self.implementation.get_size()

    def get_scalar_value(self):
        assert self.get_size() == 1
        return self.implementation.getitem(self.implementation.start)

    def descr_copy(self, space, w_order=None):
        if w_order is None:
            order = NPY.CORDER
        elif space.isinstance_w(w_order, space.w_int):
            order = space.int_w(w_order)
        else:
            order = order_converter(space, w_order, NPY.CORDER)
        copy = self.implementation.copy(space, order)
        w_subtype = space.type(self)
        return wrap_impl(space, w_subtype, self, copy)

    def descr_get_real(self, space):
        ret = self.implementation.get_real(space, self)
        return wrap_impl(space, space.type(self), self, ret)

    def descr_get_imag(self, space):
        ret = self.implementation.get_imag(space, self)
        return wrap_impl(space, space.type(self), self, ret)

    def descr_set_real(self, space, w_value):
        # copy (broadcast) values into self
        self.implementation.set_real(space, self, w_value)

    def descr_set_imag(self, space, w_value):
        # if possible, copy (broadcast) values into self
        if not self.get_dtype().is_complex():
            raise oefmt(space.w_TypeError,
                        'array does not have imaginary part to set')
        self.implementation.set_imag(space, self, w_value)

    def reshape(self, space, w_shape, order=NPY.ANYORDER):
        new_shape = get_shape_from_iterable(space, self.get_size(), w_shape)
        new_impl = self.implementation.reshape(self, new_shape, order)
        if new_impl is not None:
            return wrap_impl(space, space.type(self), self, new_impl)
        # Create copy with contiguous data
        arr = self.descr_copy(space, space.newint(order))
        if arr.get_size() > 0:
            new_implementation = arr.implementation.reshape(self, new_shape, order)
            if new_implementation is None:
                raise oefmt(space.w_ValueError,
                            'could not reshape array of size %d to shape %s',
                            arr.get_size(), str(new_shape))
            arr.implementation = new_implementation
        else:
            arr.implementation.shape = new_shape
        return arr

    def descr_reshape(self, space, __args__):
        """reshape(...)
        a.reshape(shape)

        Returns an array containing the same data with a new shape.

        Refer to `numpy.reshape` for full documentation.

        See Also
        --------
        numpy.reshape : equivalent function
        """
        args_w, kw_w = __args__.unpack()
        order = NPY.CORDER
        if kw_w:
            if "order" in kw_w:
                order = order_converter(space, kw_w["order"], order)
                del kw_w["order"]
            if kw_w:
                raise oefmt(space.w_TypeError,
                            "reshape() got unexpected keyword argument(s)")
        if order == NPY.KEEPORDER:
            raise oefmt(space.w_ValueError,
                        "order 'K' is not permitted for reshaping")
        if len(args_w) == 1:
            if space.is_none(args_w[0]):
                return self.descr_view(space)
            w_shape = args_w[0]
        else:
            w_shape = space.newtuple(args_w)
        return self.reshape(space, w_shape, order)

    def descr_get_transpose(self, space, axes=None):
        return W_NDimArray(self.implementation.transpose(self, axes))

    def descr_transpose(self, space, args_w):
        if len(args_w) == 0 or len(args_w) == 1 and space.is_none(args_w[0]):
            return self.descr_get_transpose(space)
        else:
            if len(args_w) > 1:
                axes = args_w
            else:  # Iterable in the only argument (len(arg_w) == 1 and arg_w[0] is not None)
                axes = space.fixedview(args_w[0])

        axes = self._checked_axes(axes, space)
        return self.descr_get_transpose(space, axes)

    def _checked_axes(self, axes_raw, space):
        if len(axes_raw) != self.ndims():
            raise oefmt(space.w_ValueError, "axes don't match array")
        axes = []
        axes_seen = [False] * self.ndims()
        for elem in axes_raw:
            try:
                axis = support.index_w(space, elem)
            except OperationError:
                raise oefmt(space.w_TypeError, "an integer is required")
            if axis < 0 or axis >= self.ndims():
                raise oefmt(space.w_ValueError, "invalid axis for this array")
            if axes_seen[axis] is True:
                raise oefmt(space.w_ValueError, "repeated axis in transpose")
            axes.append(axis)
            axes_seen[axis] = True
        return axes

    @unwrap_spec(axis1=int, axis2=int)
    def descr_swapaxes(self, space, axis1, axis2):
        """a.swapaxes(axis1, axis2)

        Return a view of the array with `axis1` and `axis2` interchanged.

        Refer to `numpy.swapaxes` for full documentation.

        See Also
        --------
        numpy.swapaxes : equivalent function
        """
        if axis1 == axis2:
            return self.descr_view(space)
        n = self.ndims()
        if axis1 < 0:
            axis1 += n
        if axis2 < 0:
            axis2 += n
        if axis1 < 0 or axis1 >= n:
            raise oefmt(space.w_ValueError, "bad axis1 argument to swapaxes")
        if axis2 < 0 or axis2 >= n:
            raise oefmt(space.w_ValueError, "bad axis2 argument to swapaxes")
        if n <= 1:
            return self
        return self.implementation.swapaxes(space, self, axis1, axis2)

    def descr_nonzero(self, space):
        index_type = get_dtype_cache(space).w_int64dtype
        return self.implementation.nonzero(space, index_type)

    def descr_tolist(self, space):
        if self.ndims() == 0:
            return self.get_scalar_value().item(space)
        l_w = []
        for i in range(self.get_shape()[0]):
            item_w = self.descr_getitem(space, space.newint(i))
            if (isinstance(item_w, W_NDimArray) or
                    isinstance(item_w, boxes.W_GenericBox)):
                l_w.append(space.call_method(item_w, "tolist"))
            else:
                l_w.append(item_w)
        return space.newlist(l_w)

    def descr_ravel(self, space, w_order=None):
        order = order_converter(space, w_order, self.get_order())
        return self.reshape(space, space.newint(-1), order)

    @unwrap_spec(w_axis=WrappedDefault(None),
                 w_out=WrappedDefault(None),
                 w_mode=WrappedDefault('raise'))
    def descr_take(self, space, w_obj, w_axis=None, w_out=None, w_mode=None):
        return app_take(space, self, w_obj, w_axis, w_out, w_mode)

    def descr_compress(self, space, w_obj, w_axis=None):
        if not space.is_none(w_axis):
            raise oefmt(space.w_NotImplementedError,
                        "axis unsupported for compress")
            arr = self
        else:
            arr = self.reshape(space, space.newint(-1), self.get_order())
        index = convert_to_array(space, w_obj)
        return arr.getitem_filter(space, index)

    def descr_flatten(self, space, w_order=None):
        order = order_converter(space, w_order, self.get_order())
        if self.is_scalar():
            # scalars have no storage
            return self.reshape(space, space.newint(1), order)
        w_res = self.descr_ravel(space, w_order)
        if w_res.implementation.storage == self.implementation.storage:
            return w_res.descr_copy(space)
        return w_res

    @unwrap_spec(repeats=int)
    def descr_repeat(self, space, repeats, w_axis=None):
        return repeat(space, self, repeats, w_axis)

    def descr_set_flatiter(self, space, w_obj):
        iter, state = self.create_iter()
        dtype = self.get_dtype()
        w_arr = convert_to_array(space, w_obj)
        if dtype.is_record():
            return self.implementation.setslice(space, w_arr)
        loop.flatiter_setitem(space, dtype, w_arr, iter, state, 1, iter.size)

    def descr_get_flatiter(self, space):
        from .flatiter import W_FlatIterator
        return W_FlatIterator(self)

    def descr_item(self, space, args_w):
        if len(args_w) == 1 and space.isinstance_w(args_w[0], space.w_tuple):
            args_w = space.fixedview(args_w[0])
        shape = self.get_shape()
        coords = [0] * len(shape)
        if len(args_w) == 0:
            if self.get_size() == 1:
                w_obj = self.get_scalar_value()
                assert isinstance(w_obj, boxes.W_GenericBox)
                return w_obj.item(space)
            raise oefmt(space.w_ValueError,
                        "can only convert an array of size 1 to a Python scalar")
        elif len(args_w) == 1 and len(shape) != 1:
            value = support.index_w(space, args_w[0])
            value = support.check_and_adjust_index(space, value, self.get_size(), -1)
            for idim in range(len(shape) - 1, -1, -1):
                coords[idim] = value % shape[idim]
                value //= shape[idim]
        elif len(args_w) == len(shape):
            for idim in range(len(shape)):
                coords[idim] = support.index_w(space, args_w[idim])
        else:
            raise oefmt(space.w_ValueError, "incorrect number of indices for array")
        item = self.getitem(space, coords)
        assert isinstance(item, boxes.W_GenericBox)
        return item.item(space)

    def descr_itemset(self, space, args_w):
        if len(args_w) == 0:
            raise oefmt(space.w_ValueError,
                        "itemset must have at least one argument")
        if len(args_w) != self.ndims() + 1:
            raise oefmt(space.w_ValueError,
                        "incorrect number of indices for array")
        self.descr_setitem(space, space.newtuple(args_w[:-1]), args_w[-1])

    def descr___array__(self, space, w_dtype=None):
        if not space.is_none(w_dtype):
            raise oefmt(space.w_NotImplementedError,
                        "__array__(dtype) not implemented")
        if type(self) is W_NDimArray:
            return self
        # sz cannot overflow since self is valid
        sz = support.product(self.get_shape()) * self.get_dtype().elsize
        return W_NDimArray.from_shape_and_storage(
            space, self.get_shape(), self.implementation.storage,
            self.get_dtype(), storage_bytes=sz, w_base=self)

    def descr_array_iface(self, space):
        '''
        Note: arr.__array__.data[0] is a pointer so arr must be kept alive
              while it is in use
        '''
        with self.implementation as storage:
            addr = support.get_storage_as_int(storage, self.get_start())
            # will explode if it can't
            w_d = space.newdict()
            space.setitem_str(w_d, 'data',
                              space.newtuple([space.newint(addr), space.w_False]))
            space.setitem_str(w_d, 'shape', self.descr_get_shape(space))
            space.setitem_str(w_d, 'typestr', self.get_dtype().descr_get_str(space))
            if self.implementation.order == NPY.CORDER:
                # Array is contiguous, no strides in the interface.
                strides = space.w_None
            else:
                strides = self.descr_get_strides(space)
            space.setitem_str(w_d, 'strides', strides)
            space.setitem_str(w_d, 'version', space.newint(3))
            return w_d

    w_pypy_data = None

    def fget___pypy_data__(self, space):
        return self.w_pypy_data

    def fset___pypy_data__(self, space, w_data):
        self.w_pypy_data = w_data

    def fdel___pypy_data__(self, space):
        self.w_pypy_data = None

    __array_priority__ = 0.0

    def descr___array_priority__(self, space):
        return space.newfloat(self.__array_priority__)

    def descr_argsort(self, space, w_axis=None, w_kind=None, w_order=None):
        # happily ignore the kind
        # create a contiguous copy of the array
        # we must do that, because we need a working set. otherwise
        # we would modify the array in-place. Use this to our advantage
        # by converting nonnative byte order.
        if self.is_scalar():
            return space.newint(0)
        dtype = self.get_dtype().descr_newbyteorder(space, NPY.NATIVE)
        contig = self.implementation.astype(space, dtype, self.get_order())
        return contig.argsort(space, w_axis)

    @unwrap_spec(order='text', casting='text', subok=bool, copy=bool)
    def descr_astype(self, space, w_dtype, order='K', casting='unsafe', subok=True, copy=True):
        cur_dtype = self.get_dtype()
        new_dtype = space.interp_w(descriptor.W_Dtype, space.call_function(
            space.gettypefor(descriptor.W_Dtype), w_dtype))
        if new_dtype.num == NPY.VOID:
            raise oefmt(space.w_NotImplementedError,
                        "astype(%s) not implemented yet",
                        new_dtype.get_name())
        if new_dtype.is_str_or_unicode() and new_dtype.elsize == 0:
            elsize = 0
            ch = new_dtype.char
            itype = cur_dtype.itemtype
            for i in range(self.get_size()):
                elsize = max(elsize, space.len_w(itype.to_builtin_type(space, self.implementation.getitem(i))))
            new_dtype = descriptor.variable_dtype(
                    space, ch + str(elsize))
        if new_dtype.elsize == 0:
            # XXX Should not happen
            raise oefmt(space.w_ValueError, "new dtype has elsize of 0")
        if not can_cast_array(space, self, new_dtype, casting):
            raise oefmt(space.w_TypeError, "Cannot cast array from %R to %R"
                        "according to the rule %s", self.get_dtype(),
                        new_dtype, casting)
        order  = order_converter(space, space.newtext(order), self.get_order())
        if (not copy and new_dtype == self.get_dtype()
                and (order in (NPY.KEEPORDER, NPY.ANYORDER) or order == self.get_order())
                and (subok or type(self) is W_NDimArray)):
            return self
        impl = self.implementation
        new_impl = impl.astype(space, new_dtype, order)
        if new_impl is None:
            return self
        if subok:
            w_type = space.type(self)
        else:
            w_type = None
        return wrap_impl(space, w_type, self, new_impl)

    def descr_get_base(self, space):
        impl = self.implementation
        ret = impl.base()
        if ret is None:
            return space.w_None
        return ret

    @unwrap_spec(inplace=bool)
    def descr_byteswap(self, space, inplace=False):
        if inplace:
            loop.byteswap(self.implementation, self.implementation)
            return self
        else:
            w_res = W_NDimArray.from_shape(space, self.get_shape(),
                                           self.get_dtype(), w_instance=self)
            loop.byteswap(self.implementation, w_res.implementation)
            return w_res

    def descr_choose(self, space, w_choices, w_out=None, w_mode=None):
        return choose(space, self, w_choices, w_out, w_mode)

    def descr_clip(self, space, w_min=None, w_max=None, w_out=None):
        if space.is_none(w_min):
            w_min = None
        else:
            w_min = convert_to_array(space, w_min)
        if space.is_none(w_max):
            w_max = None
        else:
            w_max = convert_to_array(space, w_max)
        if space.is_none(w_out):
            w_out = None
        elif not isinstance(w_out, W_NDimArray):
            raise oefmt(space.w_TypeError,
                        "return arrays must be of ArrayType")
        if not w_min and not w_max:
            raise oefmt(space.w_ValueError, "One of max or min must be given.")
        shape = shape_agreement_multiple(space, [self, w_min, w_max, w_out])
        out = descriptor.dtype_agreement(space, [self, w_min, w_max], shape, w_out)
        loop.clip(space, self, shape, w_min, w_max, out)
        return out

    def descr_get_ctypes(self, space):
        w_result = space.appexec([self], """(arr):
            from numpy.core import _internal
            p_data = arr.__array_interface__['data'][0]
            return _internal._ctypes(arr, p_data)
        """)
        return w_result

    def buffer_w(self, space, flags):
        # XXX format isn't always 'B' probably
        return self.implementation.get_buffer(space, flags)

    def descr_get_data(self, space):
        return space.newmemoryview(
            self.implementation.get_buffer(space, space.BUF_FULL))

    @unwrap_spec(offset=int, axis1=int, axis2=int)
    def descr_diagonal(self, space, offset=0, axis1=0, axis2=1):
        if self.ndims() < 2:
            raise oefmt(space.w_ValueError,
                        "need at least 2 dimensions for diagonal")
        if (axis1 < 0 or axis2 < 0 or axis1 >= self.ndims() or
                axis2 >= self.ndims()):
            raise oefmt(space.w_ValueError,
                        "axis1(=%d) and axis2(=%d) must be within range "
                        "(ndim=%d)", axis1, axis2, self.ndims())
        if axis1 == axis2:
            raise oefmt(space.w_ValueError,
                        "axis1 and axis2 cannot be the same")
        return arrayops.diagonal(space, self.implementation, offset, axis1, axis2)

    @unwrap_spec(offset=int, axis1=int, axis2=int)
    def descr_trace(self, space, offset=0, axis1=0, axis2=1,
                    w_dtype=None, w_out=None):
        diag = self.descr_diagonal(space, offset, axis1, axis2)
        return diag.descr_sum(space, w_axis=space.newint(-1), w_dtype=w_dtype, w_out=w_out)

    def descr_dump(self, space, w_file):
        raise oefmt(space.w_NotImplementedError, "dump not implemented yet")

    def descr_dumps(self, space):
        raise oefmt(space.w_NotImplementedError, "dumps not implemented yet")

    w_flags = None

    def descr_get_flags(self, space):
        if self.w_flags is None:
            self.w_flags = W_FlagsObject(self)
        return self.w_flags

    @unwrap_spec(offset=int)
    def descr_getfield(self, space, w_dtype, offset):
        raise oefmt(space.w_NotImplementedError,
                    "getfield not implemented yet")

    @unwrap_spec(new_order='text')
    def descr_newbyteorder(self, space, new_order=NPY.SWAP):
        return self.descr_view(
            space, self.get_dtype().descr_newbyteorder(space, new_order))

    @unwrap_spec(w_axis=WrappedDefault(None),
                 w_out=WrappedDefault(None))
    def descr_ptp(self, space, w_axis=None, w_out=None):
        return app_ptp(space, self, w_axis, w_out)

    def descr_put(self, space, w_indices, w_values, w_mode=None):
        put(space, self, w_indices, w_values, w_mode)

    @unwrap_spec(w_refcheck=WrappedDefault(True))
    def descr_resize(self, space, w_new_shape, w_refcheck=None):
        raise oefmt(space.w_NotImplementedError, "resize not implemented yet")

    @unwrap_spec(decimals=int)
    def descr_round(self, space, decimals=0, w_out=None):
        if space.is_none(w_out):
            if self.get_dtype().is_bool():
                # numpy promotes bool.round() to float16. Go figure.
                w_out = W_NDimArray.from_shape(space, self.get_shape(),
                    get_dtype_cache(space).w_float16dtype)
            else:
                w_out = None
        elif not isinstance(w_out, W_NDimArray):
            raise oefmt(space.w_TypeError,
                        "return arrays must be of ArrayType")
        out = descriptor.dtype_agreement(space, [self], self.get_shape(), w_out)
        if out.get_dtype().is_bool() and self.get_dtype().is_bool():
            calc_dtype = get_dtype_cache(space).w_longdtype
        else:
            calc_dtype = out.get_dtype()

        if decimals == 0:
            out = out.descr_view(space, space.type(self))
        loop.round(space, self, calc_dtype, self.get_shape(), decimals, out)
        return out

    @unwrap_spec(w_side=WrappedDefault('left'), w_sorter=WrappedDefault(None))
    def descr_searchsorted(self, space, w_v, w_side=None, w_sorter=None):
        if not space.is_none(w_sorter):
            raise oefmt(space.w_NotImplementedError,
                        'sorter not supported in searchsort')
        side = searchside_converter(space, w_side)
        if self.ndims() != 1:
            raise oefmt(space.w_ValueError, "a must be a 1-d array")
        v = convert_to_array(space, w_v)
        ret = W_NDimArray.from_shape(
            space, v.get_shape(), get_dtype_cache(space).w_longdtype)
        if ret.get_size() < 1:
            return ret
        if side == NPY.SEARCHLEFT:
            binsearch = loop.binsearch_left
        else:
            binsearch = loop.binsearch_right
        binsearch(space, self, v, ret)
        if ret.is_scalar():
            return ret.get_scalar_value()
        return ret

    def descr_setasflat(self, space, w_v):
        raise oefmt(space.w_NotImplementedError,
                    "setasflat not implemented yet")

    def descr_setfield(self, space, w_val, w_dtype, w_offset=0):
        raise oefmt(space.w_NotImplementedError,
                    "setfield not implemented yet")

    def descr_setflags(self, space, w_write=None, w_align=None, w_uic=None):
        raise oefmt(space.w_NotImplementedError,
                    "setflags not implemented yet")

    @unwrap_spec(kind='text')
    def descr_sort(self, space, w_axis=None, kind='quicksort', w_order=None):
        # happily ignore the kind
        # modify the array in-place
        if self.is_scalar():
            return
        return self.implementation.sort(space, w_axis, w_order)

    def descr_partition(self, space, __args__):
        return get_appbridge_cache(space).call_method(
            space, 'numpy.core._partition_use', 'partition', __args__.prepend(self))

    def descr_squeeze(self, space, w_axis=None):
        cur_shape = self.get_shape()
        if not space.is_none(w_axis):
            axes = multi_axis_converter(space, w_axis, len(cur_shape))
            new_shape = []
            for i in range(len(cur_shape)):
                if axes[i]:
                    if cur_shape[i] != 1:
                        raise oefmt(space.w_ValueError,
                                    "cannot select an axis to squeeze out "
                                    "which has size not equal to one")
                else:
                    new_shape.append(cur_shape[i])
        else:
            new_shape = [s for s in cur_shape if s != 1]
        if len(cur_shape) == len(new_shape):
            return self
        # XXX need to call __array_wrap__
        return wrap_impl(space, space.type(self), self,
                         self.implementation.get_view(
                             space, self, self.get_dtype(), new_shape))

    def descr_strides(self, space):
        raise oefmt(space.w_NotImplementedError,
                    "strides not implemented yet")

    def descr_tofile(self, space, w_fid, w_sep="", w_format="%s"):
        raise oefmt(space.w_NotImplementedError,
                    "tofile not implemented yet")

    def descr_view(self, space, w_dtype=None, w_type=None):
        if not w_type and w_dtype:
            try:
                if space.issubtype_w(w_dtype, space.gettypefor(W_NDimArray)):
                    w_type = w_dtype
                    w_dtype = None
            except OperationError as e:
                if e.match(space, space.w_TypeError):
                    pass
                else:
                    raise
        if w_dtype:
            dtype = space.interp_w(descriptor.W_Dtype, space.call_function(
                space.gettypefor(descriptor.W_Dtype), w_dtype))
        else:
            dtype = self.get_dtype()
        old_itemsize = self.get_dtype().elsize
        new_itemsize = dtype.elsize
        impl = self.implementation
        if new_itemsize == 0:
            raise oefmt(space.w_TypeError, "data-type must not be 0-sized")
        if dtype.subdtype is None:
            new_shape = self.get_shape()[:]
            dims = len(new_shape)
        else:
            new_shape = self.get_shape() + dtype.shape
            dtype = dtype.subdtype
            dims = 0
        if dims == 0:
            # Cannot resize scalars
            if old_itemsize != new_itemsize:
                raise oefmt(space.w_ValueError,
                            "new type not compatible with array.")
            strides = None
            backstrides = None
            base = self
        else:
            base = impl.base()
            if base is None:
                base = self
            strides = impl.get_strides()[:]
            backstrides = impl.get_backstrides()[:]
            if old_itemsize != new_itemsize:
                if not is_c_contiguous(impl) and not is_f_contiguous(impl):
                    raise oefmt(space.w_ValueError,
                                "new type not compatible with array.")
                # Adapt the smallest dim to the new itemsize
                if self.get_order() == NPY.FORTRANORDER:
                    minstride = strides[0]
                    mini = 0
                else:
                    minstride = strides[-1]
                    mini = len(strides) - 1
                for i in range(len(strides)):
                    if strides[i] < minstride:
                        minstride = strides[i]
                        mini = i
                if new_shape[mini] * old_itemsize % new_itemsize != 0:
                    raise oefmt(space.w_ValueError,
                                "new type not compatible with array.")
                new_shape[mini] = new_shape[mini] * old_itemsize / new_itemsize
                strides[mini] = strides[mini] * new_itemsize / old_itemsize
                backstrides[mini] = strides[mini] * new_shape[mini]
        if dtype.is_object() != impl.dtype.is_object():
            raise oefmt(space.w_ValueError, 'expect trouble in ndarray.view,'
                ' one of target dtype or dtype is object dtype')
        w_type = w_type or space.type(self)
        v = impl.get_view(space, base, dtype, new_shape, strides, backstrides)
        w_ret = wrap_impl(space, w_type, self, v)
        return w_ret

    # --------------------- operations ----------------------------
    # TODO: support all kwargs like numpy ufunc_object.c
    sig = None
    cast = 'safe'
    extobj = None


    def _unaryop_impl(ufunc_name):
        def impl(self, space, w_out=None):
            return getattr(ufuncs.get(space), ufunc_name).call(
                space, [self, w_out], self.sig, self.cast, self.extobj)
        return func_with_new_name(impl, "unaryop_%s_impl" % ufunc_name)

    descr_pos = _unaryop_impl("positive")
    descr_neg = _unaryop_impl("negative")
    descr_abs = _unaryop_impl("absolute")
    descr_invert = _unaryop_impl("invert")

    descr_conj = _unaryop_impl('conjugate')

    def descr___nonzero__(self, space):
        if self.get_size() > 1:
            raise oefmt(space.w_ValueError,
                        "The truth value of an array with more than one "
                        "element is ambiguous. Use a.any() or a.all()")
        iter, state = self.create_iter()
        return space.newbool(space.is_true(iter.getitem(state)))

    def _binop_impl(ufunc_name):
        def impl(self, space, w_other, w_out=None):
            return getattr(ufuncs.get(space), ufunc_name).call(
                space, [self, w_other, w_out], self.sig, self.cast, self.extobj)
        return func_with_new_name(impl, "binop_%s_impl" % ufunc_name)

    descr_add = _binop_impl("add")
    descr_sub = _binop_impl("subtract")
    descr_mul = _binop_impl("multiply")
    descr_div = _binop_impl("divide")
    descr_truediv = _binop_impl("true_divide")
    descr_floordiv = _binop_impl("floor_divide")
    descr_mod = _binop_impl("mod")
    descr_pow = _binop_impl("power")
    descr_lshift = _binop_impl("left_shift")
    descr_rshift = _binop_impl("right_shift")
    descr_and = _binop_impl("bitwise_and")
    descr_or = _binop_impl("bitwise_or")
    descr_xor = _binop_impl("bitwise_xor")

    def descr_divmod(self, space, w_other):
        w_quotient = self.descr_div(space, w_other)
        w_remainder = self.descr_mod(space, w_other)
        return space.newtuple([w_quotient, w_remainder])

    def _binop_comp_impl(ufunc):
        def impl(self, space, w_other, w_out=None):
            try:
                return ufunc(self, space, w_other, w_out)
            except OperationError as e:
                if e.match(space, space.w_ValueError):
                    # and 'operands could not be broadcast together' in str(e.get_w_value(space)):
                    return space.w_False
                raise e

        return func_with_new_name(impl, ufunc.func_name)

    descr_eq = _binop_comp_impl(_binop_impl("equal"))
    descr_ne = _binop_comp_impl(_binop_impl("not_equal"))
    descr_lt = _binop_comp_impl(_binop_impl("less"))
    descr_le = _binop_comp_impl(_binop_impl("less_equal"))
    descr_gt = _binop_comp_impl(_binop_impl("greater"))
    descr_ge = _binop_comp_impl(_binop_impl("greater_equal"))

    def _binop_inplace_impl(ufunc_name):
        def impl(self, space, w_other):
            w_out = self
            ufunc = getattr(ufuncs.get(space), ufunc_name)
            return ufunc.call(space, [self, w_other, w_out], self.sig, self.cast, self.extobj)
        return func_with_new_name(impl, "binop_inplace_%s_impl" % ufunc_name)

    descr_iadd = _binop_inplace_impl("add")
    descr_isub = _binop_inplace_impl("subtract")
    descr_imul = _binop_inplace_impl("multiply")
    descr_idiv = _binop_inplace_impl("divide")
    descr_itruediv = _binop_inplace_impl("true_divide")
    descr_ifloordiv = _binop_inplace_impl("floor_divide")
    descr_imod = _binop_inplace_impl("mod")
    descr_ipow = _binop_inplace_impl("power")
    descr_ilshift = _binop_inplace_impl("left_shift")
    descr_irshift = _binop_inplace_impl("right_shift")
    descr_iand = _binop_inplace_impl("bitwise_and")
    descr_ior = _binop_inplace_impl("bitwise_or")
    descr_ixor = _binop_inplace_impl("bitwise_xor")

    def _binop_right_impl(ufunc_name):
        def impl(self, space, w_other, w_out=None):
            w_other = convert_to_array(space, w_other)
            return getattr(ufuncs.get(space), ufunc_name).call(
                space, [w_other, self, w_out], self.sig, self.cast, self.extobj)
        return func_with_new_name(impl, "binop_right_%s_impl" % ufunc_name)

    descr_radd = _binop_right_impl("add")
    descr_rsub = _binop_right_impl("subtract")
    descr_rmul = _binop_right_impl("multiply")
    descr_rdiv = _binop_right_impl("divide")
    descr_rtruediv = _binop_right_impl("true_divide")
    descr_rfloordiv = _binop_right_impl("floor_divide")
    descr_rmod = _binop_right_impl("mod")
    descr_rpow = _binop_right_impl("power")
    descr_rlshift = _binop_right_impl("left_shift")
    descr_rrshift = _binop_right_impl("right_shift")
    descr_rand = _binop_right_impl("bitwise_and")
    descr_ror = _binop_right_impl("bitwise_or")
    descr_rxor = _binop_right_impl("bitwise_xor")

    def descr_rdivmod(self, space, w_other):
        w_quotient = self.descr_rdiv(space, w_other)
        w_remainder = self.descr_rmod(space, w_other)
        return space.newtuple([w_quotient, w_remainder])

    def descr_dot(self, space, w_other, w_out=None):
        from .casting import find_result_type
        out = out_converter(space, w_out)
        other = convert_to_array(space, w_other)
        if other.is_scalar():
            #Note: w_out is not modified, this is numpy compliant.
            return self.descr_mul(space, other)
        elif self.ndims() < 2 and other.ndims() < 2:
            w_res = self.descr_mul(space, other)
            assert isinstance(w_res, W_NDimArray)
            return w_res.descr_sum(space, space.newint(-1), out)
        dtype = find_result_type(space, [self, other], [])
        if self.get_size() < 1 and other.get_size() < 1:
            # numpy compatability
            return W_NDimArray.new_scalar(space, dtype, space.newint(0))
        # Do the dims match?
        out_shape, other_critical_dim = _match_dot_shapes(space, self, other)
        if out:
            matches = True
            if dtype != out.get_dtype():
                matches = False
            elif not out.implementation.order == NPY.CORDER:
                matches = False
            elif out.ndims() != len(out_shape):
                matches = False
            else:
                for i in range(len(out_shape)):
                    if out.get_shape()[i] != out_shape[i]:
                        matches = False
                        break
            if not matches:
                raise oefmt(space.w_ValueError,
                            "output array is not acceptable (must have the "
                            "right type, nr dimensions, and be a C-Array)")
            w_res = out
            w_res.fill(space, self.get_dtype().coerce(space, None))
        else:
            w_res = W_NDimArray.from_shape(space, out_shape, dtype, w_instance=self)
        # This is the place to add fpypy and blas
        return loop.multidim_dot(space, self, other, w_res, dtype,
                                 other_critical_dim)

    def descr_mean(self, space, __args__):
        return get_appbridge_cache(space).call_method(
            space, 'numpy.core._methods', '_mean', __args__.prepend(self))

    def descr_var(self, space, __args__):
        return get_appbridge_cache(space).call_method(
            space, 'numpy.core._methods', '_var', __args__.prepend(self))

    def descr_std(self, space, __args__):
        return get_appbridge_cache(space).call_method(
            space, 'numpy.core._methods', '_std', __args__.prepend(self))

    # ----------------------- reduce -------------------------------

    def _reduce_ufunc_impl(ufunc_name, name, bool_result=False):
        @unwrap_spec(keepdims=bool)
        def impl(self, space, w_axis=None, w_dtype=None, w_out=None, keepdims=False):
            out = out_converter(space, w_out)
            if bool_result:
                w_dtype = get_dtype_cache(space).w_booldtype
            return getattr(ufuncs.get(space), ufunc_name).reduce(
                space, self, w_axis, keepdims, out, w_dtype)
        impl.__name__ = name
        return impl

    descr_sum = _reduce_ufunc_impl("add", "descr_sum")
    descr_prod = _reduce_ufunc_impl("multiply", "descr_prod")
    descr_max = _reduce_ufunc_impl("maximum", "descr_max")
    descr_min = _reduce_ufunc_impl("minimum", "descr_min")
    descr_all = _reduce_ufunc_impl('logical_and', "descr_all", bool_result=True)
    descr_any = _reduce_ufunc_impl('logical_or', "descr_any", bool_result=True)


    def _accumulate_method(ufunc_name, name):
        def method(self, space, w_axis=None, w_dtype=None, w_out=None):
            out = out_converter(space, w_out)
            if space.is_none(w_axis):
                w_axis = space.newint(0)
                arr = self.reshape(space, space.newint(-1), self.get_order())
            else:
                arr = self
            ufunc = getattr(ufuncs.get(space), ufunc_name)
            return ufunc.reduce(space, arr, w_axis, False, out, w_dtype,
                                variant=ufuncs.ACCUMULATE)
        method.__name__ = name
        return method

    descr_cumsum = _accumulate_method('add', 'descr_cumsum')
    descr_cumprod = _accumulate_method('multiply', 'descr_cumprod')

    def _reduce_argmax_argmin_impl(raw_name):
        op_name = "arg%s" % raw_name
        op_name_flat = "arg%s_flat" % raw_name
        def impl(self, space, w_axis=None, w_out=None):
            if self.get_size() == 0:
                raise oefmt(space.w_ValueError,
                            "Can't call %s on zero-size arrays", op_name)
            try:
                getattr(self.get_dtype().itemtype, raw_name)
            except AttributeError:
                raise oefmt(space.w_NotImplementedError,
                            '%s not implemented for %s',
                            op_name, self.get_dtype().get_name())
            shape = self.get_shape()
            if space.is_none(w_axis) or len(shape) <= 1:
                return space.newint(getattr(loop, op_name_flat)(self))
            else:
                axis = space.int_w(w_axis)
                assert axis >= 0
                out_shape = shape[:axis] + shape[axis+1:]
                dtype = get_dtype_cache(space).w_longdtype
                w_out = W_NDimArray.from_shape(space, out_shape, dtype)
                return getattr(loop, op_name)(space, self, w_out, axis)

        return func_with_new_name(impl, "reduce_%s_impl" % op_name)

    descr_argmax = _reduce_argmax_argmin_impl("max")
    descr_argmin = _reduce_argmax_argmin_impl("min")

    def descr_int(self, space):
        if self.get_size() != 1:
            raise oefmt(space.w_TypeError,
                        "only length-1 arrays can be converted to Python "
                        "scalars")
        if self.get_dtype().is_str_or_unicode():
            raise oefmt(space.w_TypeError,
                        "don't know how to convert scalar number to int")
        value = self.get_scalar_value()
        return space.int(value)

    def descr_float(self, space):
        if self.get_size() != 1:
            raise oefmt(space.w_TypeError,
                        "only length-1 arrays can be converted to Python "
                        "scalars")
        if self.get_dtype().is_str_or_unicode():
            raise oefmt(space.w_TypeError,
                        "don't know how to convert scalar number to float")
        value = self.get_scalar_value()
        return space.float(value)

    def descr_hex(self, space):
        if self.get_size() != 1:
            raise oefmt(space.w_TypeError,
                        "only length-1 arrays can be converted to Python scalars")
        if not self.get_dtype().is_int():
            raise oefmt(space.w_TypeError,
                        "don't know how to convert scalar number to hex")
        value = self.get_scalar_value()
        return space.call_method(space.builtin, 'hex', value)

    def descr_oct(self, space):
        if self.get_size() != 1:
            raise oefmt(space.w_TypeError,
                        "only length-1 arrays can be converted to Python scalars")
        if not self.get_dtype().is_int():
            raise oefmt(space.w_TypeError,
                        "don't know how to convert scalar number to oct")
        value = self.get_scalar_value()
        return space.call_method(space.builtin, 'oct', value)

    def descr_index(self, space):
        if self.get_size() != 1 or \
                not self.get_dtype().is_int() or self.get_dtype().is_bool():
            raise oefmt(space.w_TypeError,
                        "only integer arrays with one element can be "
                        "converted to an index")
        value = self.get_scalar_value()
        assert isinstance(value, boxes.W_GenericBox)
        return value.item(space)

    def descr_reduce(self, space):
        from rpython.rlib.rstring import StringBuilder
        from pypy.interpreter.mixedmodule import MixedModule
        from pypy.module.micronumpy.concrete import SliceArray

        _numpypy = space.getbuiltinmodule("_numpypy")
        assert isinstance(_numpypy, MixedModule)
        multiarray = _numpypy.get("multiarray")
        assert isinstance(multiarray, MixedModule)
        reconstruct = multiarray.get("_reconstruct")
        parameters = space.newtuple([self.getclass(space), space.newtuple(
            [space.newint(0)]), space.newtext("b")])

        builder = StringBuilder()
        if self.get_dtype().is_object():
            raise oefmt(space.w_NotImplementedError,
                    "reduce for 'object' dtype not supported yet")
        if isinstance(self.implementation, SliceArray):
            iter, state = self.implementation.create_iter()
            while not iter.done(state):
                box = iter.getitem(state)
                builder.append(box.raw_str())
                state = iter.next(state)
        else:
            with self.implementation as storage:
                builder.append_charpsize(storage,
                                     self.implementation.get_storage_size())

        state = space.newtuple([
            space.newint(1),      # version
            self.descr_get_shape(space),
            self.get_dtype(),
            space.newbool(False),  # is_fortran
            space.newbytes(builder.build()),
        ])

        return space.newtuple([reconstruct, parameters, state])

    def descr_setstate(self, space, w_state):
        lens = space.len_w(w_state)
        # numpy compatability, see multiarray/methods.c
        if lens == 5:
            base_index = 1
        elif lens == 4:
            base_index = 0
        else:
            raise oefmt(space.w_ValueError,
                        "__setstate__ called with len(args[1])==%d, not 5 or 4",
                        lens)
        shape = space.getitem(w_state, space.newint(base_index))
        dtype = space.getitem(w_state, space.newint(base_index+1))
        #isfortran = space.getitem(w_state, space.newint(base_index+2))
        storage = space.getitem(w_state, space.newint(base_index+3))
        if not isinstance(dtype, descriptor.W_Dtype):
            raise oefmt(space.w_ValueError,
                        "__setstate__(self, (shape, dtype, .. called with "
                        "improper dtype '%R'", dtype)
        self.implementation = W_NDimArray.from_shape_and_storage(
            space, [space.int_w(i) for i in space.listview(shape)],
            rffi.str2charp(space.bytes_w(storage), track_allocation=False),
            dtype, storage_bytes=space.len_w(storage), owning=True).implementation

    def descr___array_finalize__(self, space, w_obj):
        pass

    def descr___array_wrap__(self, space, w_obj, w_context=None):
        return w_obj

    def descr___array_prepare__(self, space, w_obj, w_context=None):
        return w_obj
        pass


@unwrap_spec(offset=int)
def descr_new_array(space, w_subtype, w_shape, w_dtype=None, w_buffer=None,
                    offset=0, w_strides=None, w_order=None):
    from pypy.module.micronumpy.concrete import ConcreteArray
    dtype = space.interp_w(descriptor.W_Dtype, space.call_function(
        space.gettypefor(descriptor.W_Dtype), w_dtype))
    shape = shape_converter(space, w_shape, dtype)
    if len(shape) > NPY.MAXDIMS:
        raise oefmt(space.w_ValueError,
            "sequence too large; cannot be greater than %d", NPY.MAXDIMS)
    if not space.is_none(w_buffer):
        if (not space.is_none(w_strides)):
            strides = [space.int_w(w_i) for w_i in
                       space.unpackiterable(w_strides)]
        else:
            strides = None

        try:
            buf = space.writebuf_w(w_buffer)
        except OperationError:
            buf = space.readbuf_w(w_buffer)
        try:
            raw_ptr = buf.get_raw_address()
        except ValueError:
            raise oefmt(space.w_TypeError, "Only raw buffers are supported")
        if not shape:
            raise oefmt(space.w_TypeError,
                        "numpy scalars from buffers not supported yet")
        storage = rffi.cast(RAW_STORAGE_PTR, raw_ptr)
        storage = rffi.ptradd(storage, offset)
        return W_NDimArray.from_shape_and_storage(space, shape, storage,
                                                  dtype, w_base=w_buffer,
                                                  storage_bytes=buf.getlength()-offset,
                                                  w_subtype=w_subtype,
                                                  writable=not buf.readonly,
                                                  strides=strides)

    order = order_converter(space, w_order, NPY.CORDER)
    if space.is_w(w_subtype, space.gettypefor(W_NDimArray)):
        return W_NDimArray.from_shape(space, shape, dtype, order)
    strides, backstrides = calc_strides(shape, dtype.base, order)
    try:
        totalsize = ovfcheck(support.product_check(shape) * dtype.base.elsize)
    except OverflowError as e:
        raise oefmt(space.w_ValueError, "array is too big.")
    impl = ConcreteArray(shape, dtype.base, order, strides, backstrides)
    w_ret = space.allocate_instance(W_NDimArray, w_subtype)
    W_NDimArray.__init__(w_ret, impl)
    space.call_function(space.getattr(w_ret,
                        space.newtext('__array_finalize__')), w_subtype)
    return w_ret


@unwrap_spec(addr=int, buf_len=int)
def descr__from_shape_and_storage(space, w_cls, w_shape, addr, w_dtype,
                buf_len=-1, w_subtype=None, w_strides=None):
    """
    Create an array from an existing buffer, given its address as int.
    PyPy-only implementation detail.
    """
    storage = rffi.cast(RAW_STORAGE_PTR, addr)
    dtype = space.interp_w(descriptor.W_Dtype, space.call_function(
        space.gettypefor(descriptor.W_Dtype), w_dtype))
    shape = shape_converter(space, w_shape, dtype)
    if not space.is_none(w_strides):
        strides = [space.int_w(w_i) for w_i in
                   space.unpackiterable(w_strides)]
    else:
        strides = None
    if w_subtype:
        if not space.isinstance_w(w_subtype, space.w_type):
            raise oefmt(space.w_ValueError,
                        "subtype must be a subtype of ndarray, not a class "
                        "instance")
        return W_NDimArray.from_shape_and_storage(space, shape, storage, dtype,
                                                  buf_len, NPY.CORDER, False, w_subtype,
                                                  strides=strides)
    else:
        return W_NDimArray.from_shape_and_storage(space, shape, storage, dtype,
                                                  storage_bytes=buf_len,
                                                  strides=strides)

app_take = applevel(r"""
    def take(a, indices, axis, out, mode):
        if mode != 'raise':
            raise NotImplementedError("mode != raise not implemented")
        if axis is None:
            from numpy import array
            indices = array(indices)
            res = a.ravel()[indices.ravel()].reshape(indices.shape)
        else:
            from operator import mul
            if axis < 0: axis += len(a.shape)
            s0, s1 = a.shape[:axis], a.shape[axis+1:]
            l0 = reduce(mul, s0) if s0 else 1
            l1 = reduce(mul, s1) if s1 else 1
            res = a.reshape((l0, -1, l1))[:,indices,:].reshape(s0 + (-1,) + s1)
        if out is not None:
            out[:] = res
            return out
        return res
""", filename=__file__).interphook('take')

app_ptp = applevel(r"""
    def ptp(a, axis, out):
        res = a.max(axis) - a.min(axis)
        if out is not None:
            out[:] = res
            return out
        return res
""", filename=__file__).interphook('ptp')

W_NDimArray.typedef = TypeDef("numpy.ndarray", None, None, 'read-write',
    __new__ = interp2app(descr_new_array),

    __len__ = interp2app(W_NDimArray.descr_len),
    __getitem__ = interp2app(W_NDimArray.descr_getitem),
    __setitem__ = interp2app(W_NDimArray.descr_setitem),
    __delitem__ = interp2app(W_NDimArray.descr_delitem),

    __repr__ = interp2app(W_NDimArray.descr_repr),
    __str__ = interp2app(W_NDimArray.descr_str),
    __int__ = interp2app(W_NDimArray.descr_int),
    __float__ = interp2app(W_NDimArray.descr_float),
    __hex__ = interp2app(W_NDimArray.descr_hex),
    __oct__ = interp2app(W_NDimArray.descr_oct),
    __index__ = interp2app(W_NDimArray.descr_index),

    __pos__ = interp2app(W_NDimArray.descr_pos),
    __neg__ = interp2app(W_NDimArray.descr_neg),
    __abs__ = interp2app(W_NDimArray.descr_abs),
    __invert__ = interp2app(W_NDimArray.descr_invert),
    __nonzero__ = interp2app(W_NDimArray.descr___nonzero__),

    __add__ = interp2app(W_NDimArray.descr_add),
    __sub__ = interp2app(W_NDimArray.descr_sub),
    __mul__ = interp2app(W_NDimArray.descr_mul),
    __div__ = interp2app(W_NDimArray.descr_div),
    __truediv__ = interp2app(W_NDimArray.descr_truediv),
    __floordiv__ = interp2app(W_NDimArray.descr_floordiv),
    __mod__ = interp2app(W_NDimArray.descr_mod),
    __divmod__ = interp2app(W_NDimArray.descr_divmod),
    __pow__ = interp2app(W_NDimArray.descr_pow),
    __lshift__ = interp2app(W_NDimArray.descr_lshift),
    __rshift__ = interp2app(W_NDimArray.descr_rshift),
    __and__ = interp2app(W_NDimArray.descr_and),
    __or__ = interp2app(W_NDimArray.descr_or),
    __xor__ = interp2app(W_NDimArray.descr_xor),

    __radd__ = interp2app(W_NDimArray.descr_radd),
    __rsub__ = interp2app(W_NDimArray.descr_rsub),
    __rmul__ = interp2app(W_NDimArray.descr_rmul),
    __rdiv__ = interp2app(W_NDimArray.descr_rdiv),
    __rtruediv__ = interp2app(W_NDimArray.descr_rtruediv),
    __rfloordiv__ = interp2app(W_NDimArray.descr_rfloordiv),
    __rmod__ = interp2app(W_NDimArray.descr_rmod),
    __rdivmod__ = interp2app(W_NDimArray.descr_rdivmod),
    __rpow__ = interp2app(W_NDimArray.descr_rpow),
    __rlshift__ = interp2app(W_NDimArray.descr_rlshift),
    __rrshift__ = interp2app(W_NDimArray.descr_rrshift),
    __rand__ = interp2app(W_NDimArray.descr_rand),
    __ror__ = interp2app(W_NDimArray.descr_ror),
    __rxor__ = interp2app(W_NDimArray.descr_rxor),

    __iadd__ = interp2app(W_NDimArray.descr_iadd),
    __isub__ = interp2app(W_NDimArray.descr_isub),
    __imul__ = interp2app(W_NDimArray.descr_imul),
    __idiv__ = interp2app(W_NDimArray.descr_idiv),
    __itruediv__ = interp2app(W_NDimArray.descr_itruediv),
    __ifloordiv__ = interp2app(W_NDimArray.descr_ifloordiv),
    __imod__ = interp2app(W_NDimArray.descr_imod),
    __ipow__ = interp2app(W_NDimArray.descr_ipow),
    __ilshift__ = interp2app(W_NDimArray.descr_ilshift),
    __irshift__ = interp2app(W_NDimArray.descr_irshift),
    __iand__ = interp2app(W_NDimArray.descr_iand),
    __ior__ = interp2app(W_NDimArray.descr_ior),
    __ixor__ = interp2app(W_NDimArray.descr_ixor),

    __eq__ = interp2app(W_NDimArray.descr_eq),
    __ne__ = interp2app(W_NDimArray.descr_ne),
    __lt__ = interp2app(W_NDimArray.descr_lt),
    __le__ = interp2app(W_NDimArray.descr_le),
    __gt__ = interp2app(W_NDimArray.descr_gt),
    __ge__ = interp2app(W_NDimArray.descr_ge),

    dtype = GetSetProperty(W_NDimArray.descr_get_dtype,
                           W_NDimArray.descr_set_dtype,
                           W_NDimArray.descr_del_dtype),
    shape = GetSetProperty(W_NDimArray.descr_get_shape,
                           W_NDimArray.descr_set_shape),
    strides = GetSetProperty(W_NDimArray.descr_get_strides),
    ndim = GetSetProperty(W_NDimArray.descr_get_ndim),
    size = GetSetProperty(W_NDimArray.descr_get_size),
    itemsize = GetSetProperty(W_NDimArray.descr_get_itemsize),
    nbytes = GetSetProperty(W_NDimArray.descr_get_nbytes),
    flags = GetSetProperty(W_NDimArray.descr_get_flags),

    fill = interp2app(W_NDimArray.descr_fill),
    tobytes = interp2app(W_NDimArray.descr_tostring),
    tostring = interp2app(W_NDimArray.descr_tostring),

    mean = interp2app(W_NDimArray.descr_mean),
    sum = interp2app(W_NDimArray.descr_sum),
    prod = interp2app(W_NDimArray.descr_prod),
    max = interp2app(W_NDimArray.descr_max),
    min = interp2app(W_NDimArray.descr_min),
    put = interp2app(W_NDimArray.descr_put),
    argmax = interp2app(W_NDimArray.descr_argmax),
    argmin = interp2app(W_NDimArray.descr_argmin),
    all = interp2app(W_NDimArray.descr_all),
    any = interp2app(W_NDimArray.descr_any),
    dot = interp2app(W_NDimArray.descr_dot),
    var = interp2app(W_NDimArray.descr_var),
    std = interp2app(W_NDimArray.descr_std),
    searchsorted = interp2app(W_NDimArray.descr_searchsorted),

    cumsum = interp2app(W_NDimArray.descr_cumsum),
    cumprod = interp2app(W_NDimArray.descr_cumprod),

    copy = interp2app(W_NDimArray.descr_copy),
    reshape = interp2app(W_NDimArray.descr_reshape),
    resize = interp2app(W_NDimArray.descr_resize),
    squeeze = interp2app(W_NDimArray.descr_squeeze),
    T = GetSetProperty(W_NDimArray.descr_get_transpose),
    transpose = interp2app(W_NDimArray.descr_transpose),
    tolist = interp2app(W_NDimArray.descr_tolist),
    flatten = interp2app(W_NDimArray.descr_flatten),
    ravel = interp2app(W_NDimArray.descr_ravel),
    take = interp2app(W_NDimArray.descr_take),
    ptp = interp2app(W_NDimArray.descr_ptp),
    compress = interp2app(W_NDimArray.descr_compress),
    repeat = interp2app(W_NDimArray.descr_repeat),
    swapaxes = interp2app(W_NDimArray.descr_swapaxes),
    nonzero = interp2app(W_NDimArray.descr_nonzero),
    flat = GetSetProperty(W_NDimArray.descr_get_flatiter,
                          W_NDimArray.descr_set_flatiter),
    item = interp2app(W_NDimArray.descr_item),
    itemset = interp2app(W_NDimArray.descr_itemset),
    real = GetSetProperty(W_NDimArray.descr_get_real,
                          W_NDimArray.descr_set_real),
    imag = GetSetProperty(W_NDimArray.descr_get_imag,
                          W_NDimArray.descr_set_imag),
    conj = interp2app(W_NDimArray.descr_conj),
    conjugate = interp2app(W_NDimArray.descr_conj),

    argsort  = interp2app(W_NDimArray.descr_argsort),
    sort  = interp2app(W_NDimArray.descr_sort),
    partition  = interp2app(W_NDimArray.descr_partition),
    astype   = interp2app(W_NDimArray.descr_astype),
    base     = GetSetProperty(W_NDimArray.descr_get_base),
    byteswap = interp2app(W_NDimArray.descr_byteswap),
    choose   = interp2app(W_NDimArray.descr_choose),
    clip     = interp2app(W_NDimArray.descr_clip),
    round    = interp2app(W_NDimArray.descr_round),
    data     = GetSetProperty(W_NDimArray.descr_get_data),
    diagonal = interp2app(W_NDimArray.descr_diagonal),
    trace = interp2app(W_NDimArray.descr_trace),
    view = interp2app(W_NDimArray.descr_view),
    newbyteorder = interp2app(W_NDimArray.descr_newbyteorder),

    ctypes = GetSetProperty(W_NDimArray.descr_get_ctypes), # XXX unimplemented
    __array_interface__ = GetSetProperty(W_NDimArray.descr_array_iface),
    __weakref__ = make_weakref_descr(W_NDimArray),
    _from_shape_and_storage = interp2app(descr__from_shape_and_storage,
                                         as_classmethod=True),
    __pypy_data__ = GetSetProperty(W_NDimArray.fget___pypy_data__,
                                   W_NDimArray.fset___pypy_data__,
                                   W_NDimArray.fdel___pypy_data__),
    __reduce__ = interp2app(W_NDimArray.descr_reduce),
    __setstate__ = interp2app(W_NDimArray.descr_setstate),
    __array_finalize__ = interp2app(W_NDimArray.descr___array_finalize__),
    __array_prepare__ = interp2app(W_NDimArray.descr___array_prepare__),
    __array_wrap__ = interp2app(W_NDimArray.descr___array_wrap__),
    __array_priority__ = GetSetProperty(W_NDimArray.descr___array_priority__),
    __array__         = interp2app(W_NDimArray.descr___array__),
)


def _reconstruct(space, w_subtype, w_shape, w_dtype):
    return descr_new_array(space, w_subtype, w_shape, w_dtype)
