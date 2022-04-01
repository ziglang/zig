from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.baseobjspace import BufferInterfaceNotFound
from pypy.interpreter.gateway import unwrap_spec, WrappedDefault
from pypy.interpreter.buffer import SubBuffer
from rpython.rlib.rstring import strip_spaces
from rpython.rlib.rawstorage import RAW_STORAGE_PTR
from rpython.rtyper.lltypesystem import lltype, rffi

from pypy.module.micronumpy import descriptor, loop, support
from pypy.module.micronumpy.base import (wrap_impl,
    W_NDimArray, convert_to_array, W_NumpyObject)
from pypy.module.micronumpy.converters import shape_converter, order_converter
import pypy.module.micronumpy.constants as NPY
from .casting import scalar2dtype


def build_scalar(space, w_dtype, w_state):
    if not isinstance(w_dtype, descriptor.W_Dtype):
        raise oefmt(space.w_TypeError,
                    "argument 1 must be numpy.dtype, not %T", w_dtype)
    if w_dtype.elsize == 0:
        raise oefmt(space.w_TypeError, "Empty data-type")
    if not space.isinstance_w(w_state, space.w_bytes): # py3 accepts unicode here too
        raise oefmt(space.w_TypeError, "initializing object must be a string")
    if space.len_w(w_state) != w_dtype.elsize:
        raise oefmt(space.w_ValueError, "initialization string is too small")
    state = rffi.str2charp(space.text_w(w_state))
    box = w_dtype.itemtype.box_raw_data(state)
    lltype.free(state, flavor="raw")
    return box


def try_array_method(space, w_object, w_dtype=None):
    w___array__ = space.lookup(w_object, "__array__")
    if w___array__ is None:
        return None
    if w_dtype is None:
        w_dtype = space.w_None
    w_array = space.get_and_call_function(w___array__, w_object, w_dtype)
    if isinstance(w_array, W_NDimArray):
        return w_array
    else:
        raise oefmt(space.w_ValueError,
                    "object __array__ method not producing an array")

def try_interface_method(space, w_object, copy):
    try:
        w_interface = space.getattr(w_object, space.newtext("__array_interface__"))
        if w_interface is None:
            return None, False
        version_w = space.finditem(w_interface, space.newtext("version"))
        if version_w is None:
            raise oefmt(space.w_ValueError, "__array_interface__ found without"
                        " 'version' key")
        if not space.isinstance_w(version_w, space.w_int):
            raise oefmt(space.w_ValueError, "__array_interface__ found with"
                        " non-int 'version' key")
        version = space.int_w(version_w)
        if version < 3:
            raise oefmt(space.w_ValueError,
                    "__array_interface__ version %d not supported", version)
        # make a view into the data
        w_shape = space.finditem(w_interface, space.newtext('shape'))
        w_dtype = space.finditem(w_interface, space.newtext('typestr'))
        w_descr = space.finditem(w_interface, space.newtext('descr'))
        w_data = space.finditem(w_interface, space.newtext('data'))
        w_strides = space.finditem(w_interface, space.newtext('strides'))
        if w_shape is None or w_dtype is None:
            raise oefmt(space.w_ValueError,
                    "__array_interface__ missing one or more required keys: shape, typestr"
                    )
        if w_descr is not None:
            raise oefmt(space.w_NotImplementedError,
                    "__array_interface__ descr not supported yet")
        if w_strides is None or space.is_w(w_strides, space.w_None):
            strides = None
        else:
            strides = [space.int_w(i) for i in space.listview(w_strides)]
        shape = [space.int_w(i) for i in space.listview(w_shape)]
        dtype = descriptor.decode_w_dtype(space, w_dtype)
        if dtype is None:
            raise oefmt(space.w_ValueError,
                    "__array_interface__ could not decode dtype %R", w_dtype
                    )
        if w_data is not None and (space.isinstance_w(w_data, space.w_tuple) or
                                   space.isinstance_w(w_data, space.w_list)):
            data_w = space.listview(w_data)
            w_data = rffi.cast(RAW_STORAGE_PTR, space.int_w(data_w[0]))
            read_only = space.is_true(data_w[1]) or copy
            offset = 0
            w_base = w_object
            if read_only:
                w_base = None
            return W_NDimArray.from_shape_and_storage(space, shape, w_data,
                                dtype, w_base=w_base, strides=strides,
                                start=offset), read_only
        if w_data is None:
            w_data = w_object
        w_offset = space.finditem(w_interface, space.newtext('offset'))
        if w_offset is None:
            offset = 0
        else:
            offset = space.int_w(w_offset)
        #print 'create view from shape',shape,'dtype',dtype,'data',data
        if strides is not None:
            raise oefmt(space.w_NotImplementedError,
                   "__array_interface__ strides not fully supported yet")
        arr = frombuffer(space, w_data, dtype, support.product(shape), offset)
        new_impl = arr.implementation.reshape(arr, shape)
        return W_NDimArray(new_impl), False

    except OperationError as e:
        if e.match(space, space.w_AttributeError):
            return None, False
        raise

def _descriptor_from_pep3118_format(space, c_format):
    descr = descriptor.decode_w_dtype(space, space.newtext(c_format))
    if descr:
        return descr
    msg = "invalid PEP 3118 format string: '%s'" % c_format
    space.warn(space.newtext(msg), space.w_RuntimeWarning)
    return None

def _array_from_buffer_3118(space, w_object, dtype):
    try:
        w_buf = space.call_method(space.builtin, "memoryview", w_object)
    except OperationError as e:
        if e.match(space, space.w_TypeError):
            # object does not have buffer interface
            return w_object
        raise
    format = space.getattr(w_buf, space.newtext('format'))
    if format:
        descr = _descriptor_from_pep3118_format(space, space.text_w(format))
        if not descr:
            return w_object
        if dtype and descr:
            raise oefmt(space.w_NotImplementedError,
                "creating an array from a memoryview while specifying dtype "
                "not supported")
        if descr.elsize != space.int_w(space.getattr(w_buf, space.newbytes('itemsize'))):
            msg = ("Item size computed from the PEP 3118 buffer format "
                  "string does not match the actual item size.")
            space.warn(space.newtext(msg), space.w_RuntimeWarning)
            return w_object
        dtype = descr
    elif not dtype:
        dtype = descriptor.get_dtype_cache(space).w_stringdtype
        dtype.elsize = space.int_w(space.getattr(w_buf, space.newbytes('itemsize')))
    nd = space.int_w(space.getattr(w_buf, space.newbytes('ndim')))
    shape = [space.int_w(d) for d in space.listview(
                            space.getattr(w_buf, space.newbytes('shape')))]
    strides = []
    buflen = space.len_w(w_buf) * dtype.elsize
    if shape:
        strides = [space.int_w(d) for d in space.listview(
                            space.getattr(w_buf, space.newbytes('strides')))]
        if not strides:
            d = buflen
            strides = [0] * nd
            for k in range(nd):
                if shape[k] > 0:
                    d /= shape[k]
                    strides[k] = d
    else:
        if nd == 1:
            shape = [buflen / dtype.elsize, ]
            strides = [dtype.elsize, ]
        elif nd > 1:
            msg = ("ndim computed from the PEP 3118 buffer format "
                   "is greater than 1, but shape is NULL.")
            space.warn(space.newtext(msg), space.w_RuntimeWarning)
            return w_object
    try:
        w_data = rffi.cast(RAW_STORAGE_PTR, space.int_w(space.call_method(w_buf, '_pypy_raw_address')))
    except OperationError as e:
        if e.match(space, space.w_ValueError):
            return w_object
        else:
            raise e
    writable = not space.bool_w(space.getattr(w_buf, space.newbytes('readonly')))
    w_ret = W_NDimArray.from_shape_and_storage(space, shape, w_data,
               storage_bytes=buflen, dtype=dtype, w_base=w_object,
               writable=writable, strides=strides)
    if w_ret:
        return w_ret
    return w_object

@unwrap_spec(ndmin=int, copy=bool, subok=bool)
def array(space, w_object, w_dtype=None, copy=True, w_order=None, subok=False,
          ndmin=0):
    w_res = _array(space, w_object, w_dtype, copy, w_order, subok)
    shape = w_res.get_shape()
    if len(shape) < ndmin:
        shape = [1] * (ndmin - len(shape)) + shape
        impl = w_res.implementation.set_shape(space, w_res, shape)
        if w_res is w_object:
            return W_NDimArray(impl)
        else:
            w_res.implementation = impl
    return w_res

def _array(space, w_object, w_dtype=None, copy=True, w_order=None, subok=False):

    from pypy.module.micronumpy.boxes import W_GenericBox
    # numpy testing calls array(type(array([]))) and expects a ValueError
    if space.isinstance_w(w_object, space.w_type):
        raise oefmt(space.w_ValueError, "cannot create ndarray from type instance")
    # for anything that isn't already an array, try __array__ method first
    dtype = descriptor.decode_w_dtype(space, w_dtype)
    if not isinstance(w_object, W_NDimArray):
        w_array = try_array_method(space, w_object, w_dtype)
        if w_array is None:
            if (    not space.isinstance_w(w_object, space.w_bytes) and
                    not space.isinstance_w(w_object, space.w_unicode) and
                    not isinstance(w_object, W_GenericBox)):
                # use buffer interface
                w_object = _array_from_buffer_3118(space, w_object, dtype)
        else:
            # continue with w_array, but do further operations in place
            w_object = w_array
            copy = False
            dtype = w_object.get_dtype()
    if not isinstance(w_object, W_NDimArray):
        w_array, _copy = try_interface_method(space, w_object, copy)
        if w_array is not None:
            w_object = w_array
            copy = _copy
            dtype = w_object.get_dtype()

    if isinstance(w_object, W_NDimArray):
        npy_order = order_converter(space, w_order, NPY.ANYORDER)
        if (dtype is None or w_object.get_dtype() is dtype) and (subok or
                type(w_object) is W_NDimArray):
            flags = w_object.get_flags()
            must_copy = copy
            must_copy |= (npy_order == NPY.CORDER and not flags & NPY.ARRAY_C_CONTIGUOUS)
            must_copy |= (npy_order == NPY.FORTRANORDER and not flags & NPY.ARRAY_F_CONTIGUOUS)
            if must_copy:
                return w_object.descr_copy(space, space.newint(npy_order))
            else:
                return w_object
        if subok and not type(w_object) is W_NDimArray:
            raise oefmt(space.w_NotImplementedError,
                "array(..., subok=True) only partially implemented")
        # we have a ndarray, but need to copy or change dtype
        if dtype is None:
            dtype = w_object.get_dtype()
        if dtype != w_object.get_dtype():
            # silently reject the copy value
            copy = True
        if copy:
            shape = w_object.get_shape()
            order = support.get_order_as_CF(w_object.get_order(), npy_order)
            w_arr = W_NDimArray.from_shape(space, shape, dtype, order=order)
            if support.product(shape) == 1:
                w_arr.set_scalar_value(dtype.coerce(space,
                        w_object.implementation.getitem(0)))
            else:
                loop.setslice(space, shape, w_arr.implementation, w_object.implementation)
            return w_arr
        else:
            imp = w_object.implementation
            w_base = w_object
            sz = w_base.get_size() * dtype.elsize
            if imp.base() is not None:
                w_base = imp.base()
                if type(w_base) is W_NDimArray:
                    sz = w_base.get_size() * dtype.elsize
                else:
                    # this must succeed (mmap, buffer, ...)
                    sz = space.int_w(space.call_method(w_base, 'size'))
            with imp as storage:
                return W_NDimArray.from_shape_and_storage(space,
                    w_object.get_shape(), storage, dtype, storage_bytes=sz,
                    w_base=w_base, strides=imp.strides, start=imp.start)
    else:
        # not an array
        npy_order = order_converter(space, w_order, NPY.CORDER)
        shape, elems_w = find_shape_and_elems(space, w_object, dtype)
    if dtype is None and space.isinstance_w(w_object, space.w_memoryview):
        dtype = descriptor.get_dtype_cache(space).w_uint8dtype
    if dtype is None or (dtype.is_str_or_unicode() and dtype.elsize < 1):
        dtype = find_dtype_for_seq(space, elems_w, dtype)

    w_arr = W_NDimArray.from_shape(space, shape, dtype, order=npy_order)
    if support.product(shape) == 1: # safe from overflow since from_shape checks
        w_arr.set_scalar_value(dtype.coerce(space, elems_w[0]))
    else:
        loop.assign(space, w_arr, elems_w)
    return w_arr


def numpify(space, w_object):
    """Convert the object to a W_NumpyObject"""
    # XXX: code duplication with _array()
    if isinstance(w_object, W_NumpyObject):
        return w_object
    # for anything that isn't already an array, try __array__ method first
    w_array = try_array_method(space, w_object)
    if w_array is not None:
        return w_array

    if is_scalar_like(space, w_object, dtype=None):
        dtype = scalar2dtype(space, w_object)
        if dtype.is_str_or_unicode() and dtype.elsize < 1:
            # promote S0 -> S1, U0 -> U1
            dtype = descriptor.variable_dtype(space, dtype.char + '1')
        return dtype.coerce(space, w_object)

    shape, elems_w = _find_shape_and_elems(space, w_object)
    dtype = find_dtype_for_seq(space, elems_w, None)
    w_arr = W_NDimArray.from_shape(space, shape, dtype)
    loop.assign(space, w_arr, elems_w)
    return w_arr


def find_shape_and_elems(space, w_iterable, dtype):
    if is_scalar_like(space, w_iterable, dtype):
        return [], [w_iterable]
    is_rec_type = dtype is not None and dtype.is_record()
    return _find_shape_and_elems(space, w_iterable, is_rec_type)

def is_scalar_like(space, w_obj, dtype):
    isstr = space.isinstance_w(w_obj, space.w_bytes)
    if not support.issequence_w(space, w_obj) or isstr:
        if dtype is None or dtype.char != NPY.CHARLTR:
            return True
    is_rec_type = dtype is not None and dtype.is_record()
    if is_rec_type and is_single_elem(space, w_obj, is_rec_type):
        return True
    if isinstance(w_obj, W_NDimArray) and w_obj.is_scalar():
        return True
    return False

def _find_shape_and_elems(space, w_iterable, is_rec_type=False):
    from pypy.objspace.std.bufferobject import W_Buffer
    shape = [space.len_w(w_iterable)]
    if space.isinstance_w(w_iterable, space.w_buffer):
        batch = [space.newint(0)] * shape[0]
        for i in range(shape[0]):
            batch[i] = space.ord(space.getitem(w_iterable, space.newint(i)))
    else:
        batch = space.listview(w_iterable)
    while True:
        if not batch:
            return shape[:], []
        if is_single_elem(space, batch[0], is_rec_type):
            for w_elem in batch:
                if not is_single_elem(space, w_elem, is_rec_type):
                    raise oefmt(space.w_ValueError,
                                "setting an array element with a sequence")
            return shape[:], batch
        new_batch = []
        size = space.len_w(batch[0])
        for w_elem in batch:
            if (is_single_elem(space, w_elem, is_rec_type) or
                    space.len_w(w_elem) != size):
                raise oefmt(space.w_ValueError,
                            "setting an array element with a sequence")
            w_array = space.lookup(w_elem, '__array__')
            if w_array is not None:
                # Make sure we call the array implementation of listview,
                # since for some ndarray subclasses (matrix, for instance)
                # listview does not reduce but rather returns the same class
                w_elem = space.get_and_call_function(w_array, w_elem, space.w_None)
            new_batch += space.listview(w_elem)
        shape.append(size)
        batch = new_batch

def is_single_elem(space, w_elem, is_rec_type):
    if (is_rec_type and space.isinstance_w(w_elem, space.w_tuple)):
        return True
    if (space.isinstance_w(w_elem, space.w_tuple) or
            space.isinstance_w(w_elem, space.w_list)):
        return False
    if isinstance(w_elem, W_NDimArray) and not w_elem.is_scalar():
        return False
    return True

def _dtype_guess(space, dtype, w_elem):
    from .casting import scalar2dtype, find_binop_result_dtype
    if isinstance(w_elem, W_NDimArray) and w_elem.is_scalar():
        w_elem = w_elem.get_scalar_value()
    elem_dtype = scalar2dtype(space, w_elem)
    return find_binop_result_dtype(space, elem_dtype, dtype)

def find_dtype_for_seq(space, elems_w, dtype):
    if len(elems_w) == 1:
        w_elem = elems_w[0]
        return _dtype_guess(space, dtype, w_elem)
    for w_elem in elems_w:
        dtype = _dtype_guess(space, dtype, w_elem)
    if dtype is None:
        dtype = descriptor.get_dtype_cache(space).w_float64dtype
    elif dtype.is_str_or_unicode() and dtype.elsize < 1:
        # promote S0 -> S1, U0 -> U1
        dtype = descriptor.variable_dtype(space, dtype.char + '1')
    return dtype


def _zeros_or_empty(space, w_shape, w_dtype, w_order, zero):
    # w_order can be None, str, or boolean
    order = order_converter(space, w_order, NPY.CORDER)
    dtype = space.interp_w(descriptor.W_Dtype,
        space.call_function(space.gettypefor(descriptor.W_Dtype), w_dtype))
    if dtype.is_str_or_unicode() and dtype.elsize < 1:
        dtype = descriptor.variable_dtype(space, dtype.char + '1')
    shape = shape_converter(space, w_shape, dtype)
    for dim in shape:
        if dim < 0:
            raise oefmt(space.w_ValueError,
                        "negative dimensions are not allowed")
    try:
        support.product_check(shape)
    except OverflowError:
        raise oefmt(space.w_ValueError, "array is too big.")
    return W_NDimArray.from_shape(space, shape, dtype, order, zero=zero)

def empty(space, w_shape, w_dtype=None, w_order=None):
    return _zeros_or_empty(space, w_shape, w_dtype, w_order, zero=False)

def zeros(space, w_shape, w_dtype=None, w_order=None):
    return _zeros_or_empty(space, w_shape, w_dtype, w_order, zero=True)


@unwrap_spec(subok=bool)
def empty_like(space, w_a, w_dtype=None, w_order=None, subok=True):
    w_a = convert_to_array(space, w_a)
    npy_order = order_converter(space, w_order, w_a.get_order())
    if space.is_none(w_dtype):
        dtype = w_a.get_dtype()
    else:
        dtype = space.interp_w(descriptor.W_Dtype,
            space.call_function(space.gettypefor(descriptor.W_Dtype), w_dtype))
        if dtype.is_str_or_unicode() and dtype.elsize < 1:
            dtype = descriptor.variable_dtype(space, dtype.char + '1')
    if npy_order in (NPY.KEEPORDER, NPY.ANYORDER):
        # Try to copy the stride pattern
        impl = w_a.implementation.astype(space, dtype, NPY.KEEPORDER)
        if subok:
            w_type = space.type(w_a)
        else:
            w_type = None
        return wrap_impl(space, w_type, w_a, impl)
    return W_NDimArray.from_shape(space, w_a.get_shape(), dtype=dtype,
                                  order=npy_order,
                                  w_instance=w_a if subok else None,
                                  zero=False)


def _fromstring_text(space, s, count, sep, length, dtype):
    sep_stripped = strip_spaces(sep)
    skip_bad_vals = len(sep_stripped) == 0

    items = []
    num_items = 0
    idx = 0

    while (num_items < count or count == -1) and idx < len(s):
        nextidx = s.find(sep, idx)
        if nextidx < 0:
            nextidx = length
        piece = strip_spaces(s[idx:nextidx])
        if len(piece) > 0 or not skip_bad_vals:
            if len(piece) == 0 and not skip_bad_vals:
                val = dtype.itemtype.default_fromstring(space)
            else:
                try:
                    val = dtype.coerce(space, space.newtext(piece))
                except OperationError as e:
                    if not e.match(space, space.w_ValueError):
                        raise
                    gotit = False
                    while not gotit and len(piece) > 0:
                        piece = piece[:-1]
                        try:
                            val = dtype.coerce(space, space.newtext(piece))
                            gotit = True
                        except OperationError as e:
                            if not e.match(space, space.w_ValueError):
                                raise
                    if not gotit:
                        val = dtype.itemtype.default_fromstring(space)
                    nextidx = length
            items.append(val)
            num_items += 1
        idx = nextidx + 1

    if count > num_items:
        raise oefmt(space.w_ValueError,
                    "string is smaller than requested size")

    a = W_NDimArray.from_shape(space, [num_items], dtype=dtype)
    ai, state = a.create_iter()
    for val in items:
        ai.setitem(state, val)
        state = ai.next(state)

    return a


def _fromstring_bin(space, s, count, length, dtype):
    itemsize = dtype.elsize
    assert itemsize >= 0
    if count == -1:
        count = length / itemsize
    if length % itemsize != 0:
        raise oefmt(space.w_ValueError,
                    "string length %d not divisable by item size %d",
                    length, itemsize)
    if count * itemsize > length:
        raise oefmt(space.w_ValueError,
                    "string is smaller than requested size")

    a = W_NDimArray.from_shape(space, [count], dtype=dtype)
    loop.fromstring_loop(space, a, dtype, itemsize, s)
    return a


@unwrap_spec(s='text', count=int, sep='text', w_dtype=WrappedDefault(None))
def fromstring(space, s, w_dtype=None, count=-1, sep=''):
    dtype = space.interp_w(descriptor.W_Dtype,
        space.call_function(space.gettypefor(descriptor.W_Dtype), w_dtype))
    length = len(s)
    if sep == '':
        return _fromstring_bin(space, s, count, length, dtype)
    else:
        return _fromstring_text(space, s, count, sep, length, dtype)


def _getbuffer(space, w_buffer):
    try:
        return space.writebuf_w(w_buffer)
    except OperationError as e:
        if not e.match(space, space.w_TypeError):
            raise
        return space.readbuf_w(w_buffer)


@unwrap_spec(count=int, offset=int)
def frombuffer(space, w_buffer, w_dtype=None, count=-1, offset=0):
    dtype = space.interp_w(descriptor.W_Dtype,
        space.call_function(space.gettypefor(descriptor.W_Dtype), w_dtype))
    if dtype.elsize == 0:
        raise oefmt(space.w_ValueError, "itemsize cannot be zero in type")

    try:
        buf = _getbuffer(space, w_buffer)
    except OperationError as e:
        if not e.match(space, space.w_TypeError):
            raise
        w_buffer = space.call_method(w_buffer, '__buffer__',
                                    space.newint(space.BUF_FULL_RO))
        buf = _getbuffer(space, w_buffer)

    ts = buf.getlength()
    if offset < 0 or offset > ts:
        raise oefmt(space.w_ValueError,
                    "offset must be non-negative and no greater than "
                    "buffer length (%d)", ts)

    s = ts - offset
    if offset:
        buf = SubBuffer(buf, offset, s)

    n = count
    itemsize = dtype.elsize
    assert itemsize > 0
    if n < 0:
        if s % itemsize != 0:
            raise oefmt(space.w_ValueError,
                        "buffer size must be a multiple of element size")
        n = s / itemsize
    else:
        if s < n * itemsize:
            raise oefmt(space.w_ValueError,
                        "buffer is smaller than requested size")

    try:
        storage = buf.get_raw_address()
    except ValueError:
        a = W_NDimArray.from_shape(space, [n], dtype=dtype)
        loop.fromstring_loop(space, a, dtype, itemsize, buf.as_str())
        return a
    else:
        writable = not buf.readonly
    return W_NDimArray.from_shape_and_storage(space, [n], storage, storage_bytes=s,
                                dtype=dtype, w_base=w_buffer, writable=writable)
