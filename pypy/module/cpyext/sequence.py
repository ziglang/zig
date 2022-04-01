
from rpython.rlib import rerased, jit
from rpython.rlib.objectmodel import keepalive_until_here
from pypy.interpreter.error import OperationError, oefmt
from pypy.objspace.std.listobject import (
    ListStrategy, UNROLL_CUTOFF, W_ListObject, ObjectListStrategy)
from pypy.module.cpyext.api import (
    cpython_api, CANNOT_FAIL, CONST_STRING, Py_ssize_t, PyObject, PyObjectP,
    generic_cpy_call, PyVarObject, PyObject)
from pypy.module.cpyext.pyobject import make_ref, from_ref, as_pyobj, incref
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.objspace.std import tupleobject

from pypy.module.cpyext.tupleobject import PyTuple_Check, PyTuple_SetItem
from pypy.module.cpyext.pyobject import decref

from pypy.module.cpyext.dictobject import PyDict_Check

@cpython_api([PyObject, Py_ssize_t], PyObject)
def PySequence_Repeat(space, w_obj, count):
    """Return the result of repeating sequence object o count times, or NULL on
    failure.  This is the equivalent of the Python expression o * count.
    """
    return space.mul(w_obj, space.newint(count))

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PySequence_Check(space, w_obj):
    """Return 1 if the object provides sequence protocol, and 0 otherwise.
    This function always succeeds."""
    return int(space.issequence_w(w_obj))

@cpython_api([PyObject], Py_ssize_t, error=-1)
def PySequence_Size(space, w_obj):
    """
    Returns the number of objects in sequence o on success, and -1 on failure.
    For objects that do not provide sequence protocol, this is equivalent to the
    Python expression len(o)."""
    return space.len_w(w_obj)

@cpython_api([PyObject], Py_ssize_t, error=-1)
def PySequence_Length(space, w_obj):
    return space.len_w(w_obj)

@cpython_api([PyObject, CONST_STRING], PyObject)
def PySequence_Fast(space, w_obj, m):
    """Returns the sequence o as a tuple, unless it is already a tuple or list, in
    which case o is returned.  Use PySequence_Fast_GET_ITEM() to access the
    members of the result.  Returns NULL on failure.  If the object cannot be
    converted to a sequence, and raises a TypeError, raise a new TypeError with
    m as the message text. If the conversion otherwise, fails, reraise the
    original exception"""
    if isinstance(w_obj, tupleobject.W_AbstractTupleObject):
        return w_obj   # CCC avoid the double conversion that occurs here
    if isinstance(w_obj, W_ListObject):
        # note: we used to call w_obj.convert_to_cpy_strategy() here,
        # but we really have to call it from PySequence_Fast_GET_ITEM()
        # because some people never call PySequence_Fast() if they know
        # the object is a list.
        return w_obj
    try:
        return tupleobject.W_TupleObject(space.fixedview(w_obj))
    except OperationError as e:
        if e.match(space, space.w_TypeError):
            raise OperationError(space.w_TypeError, space.newtext(rffi.charp2str(m)))
        raise e

# CCC this should be written as a C macro, at least for the tuple case
@cpython_api([rffi.VOIDP, Py_ssize_t], PyObject, result_is_ll=True)
def PySequence_Fast_GET_ITEM(space, py_obj, index):
    """Return the ith element of o, assuming that o was returned by
    PySequence_Fast(), o is not NULL, and that i is within bounds.
    """
    py_obj = rffi.cast(PyObject, py_obj)
    if PyTuple_Check(space, py_obj):
        from pypy.module.cpyext.tupleobject import PyTupleObject
        py_tuple = rffi.cast(PyTupleObject, py_obj)
        return py_tuple.c_ob_item[index]
    else:
        from pypy.module.cpyext.listobject import PyList_GET_ITEM
        w_obj = from_ref(space, py_obj)
        return PyList_GET_ITEM(space, w_obj, index)

@cpython_api([rffi.VOIDP], Py_ssize_t, error=CANNOT_FAIL)
def PySequence_Fast_GET_SIZE(space, py_obj):
    """Returns the length of o, assuming that o was returned by
    PySequence_Fast() and that o is not NULL.  The size can also be
    gotten by calling PySequence_Size() on o, but
    PySequence_Fast_GET_SIZE() is faster because it can assume o is a list
    or tuple."""
    py_obj = rffi.cast(PyObject, py_obj)
    if PyTuple_Check(space, py_obj):
        from pypy.module.cpyext.tupleobject import PyTupleObject
        py_varobj = rffi.cast(PyVarObject, py_obj)
        return py_varobj.c_ob_size
    else:
        from pypy.module.cpyext.listobject import PyList_GET_SIZE
        w_obj = from_ref(space, py_obj)
        return PyList_GET_SIZE(space, w_obj)

@cpython_api([rffi.VOIDP], PyObjectP)
def PySequence_Fast_ITEMS(space, py_obj):
    """Return the underlying array of PyObject pointers.  Assumes that o was returned
    by PySequence_Fast() and o is not NULL.

    Note, if a list gets resized, the reallocation may relocate the items array.
    So, only use the underlying array pointer in contexts where the sequence
    cannot change.
    """
    py_obj = rffi.cast(PyObject, py_obj)
    if PyTuple_Check(space, py_obj):
        from pypy.module.cpyext.tupleobject import PyTupleObject
        py_tuple = rffi.cast(PyTupleObject, py_obj)
        return rffi.cast(PyObjectP, py_tuple.c_ob_item)
    else:
        from pypy.module.cpyext.listobject import get_list_storage
        w_obj = from_ref(space, py_obj)
        assert isinstance(w_obj, W_ListObject)
        storage = get_list_storage(space, w_obj)
        return rffi.cast(PyObjectP, storage._elems)

@cpython_api([PyObject, Py_ssize_t, Py_ssize_t], PyObject)
def PySequence_GetSlice(space, w_obj, start, end):
    """Return the slice of sequence object o between i1 and i2, or NULL on
    failure. This is the equivalent of the Python expression o[i1:i2]."""
    return space.getslice(w_obj, space.newint(start), space.newint(end))

@cpython_api([PyObject, Py_ssize_t, Py_ssize_t, PyObject], rffi.INT_real, error=-1)
def PySequence_SetSlice(space, w_obj, start, end, w_value):
    """Assign the sequence object v to the slice in sequence object o from i1 to
    i2.  This is the equivalent of the Python statement o[i1:i2] = v."""
    space.setslice(w_obj, space.newint(start), space.newint(end), w_value)
    return 0

@cpython_api([PyObject, Py_ssize_t, Py_ssize_t], rffi.INT_real, error=-1)
def PySequence_DelSlice(space, w_obj, start, end):
    """Delete the slice in sequence object o from i1 to i2.  Returns -1 on
    failure.  This is the equivalent of the Python statement del o[i1:i2]."""
    space.delslice(w_obj, space.newint(start), space.newint(end))
    return 0

@cpython_api([rffi.VOIDP, Py_ssize_t], PyObject, result_is_ll=True)
def PySequence_ITEM(space, w_obj, i):
    """Return the ith element of o or NULL on failure. Macro form of
    PySequence_GetItem() but without checking that
    PySequence_Check(o)() is true and without adjustment for negative
    indices.

    This function used an int type for i. This might require
    changes in your code for properly supporting 64-bit systems."""
    # XXX we should call Py*_GET_ITEM() instead of Py*_GetItem()
    # from here, but we cannot because we are also called from
    # PySequence_GetItem()
    py_obj = as_pyobj(space, w_obj)
    if isinstance(w_obj, tupleobject.W_TupleObject):
        from pypy.module.cpyext.tupleobject import PyTuple_GetItem
        py_res = PyTuple_GetItem(space, py_obj, i)
        incref(space, py_res)
        keepalive_until_here(w_obj)
        return py_res
    if isinstance(w_obj, W_ListObject):
        from pypy.module.cpyext.listobject import PyList_GetItem
        py_res = PyList_GetItem(space, py_obj, i)
        incref(space, py_res)
        keepalive_until_here(w_obj)
        return py_res
    as_sequence = py_obj.c_ob_type.c_tp_as_sequence
    if as_sequence and as_sequence.c_sq_item:
        ret = generic_cpy_call(space, as_sequence.c_sq_item, w_obj, i)
        return make_ref(space, ret)
    w_ret = space.getitem(w_obj, space.newint(i))
    return make_ref(space, w_ret)

@cpython_api([PyObject, Py_ssize_t], PyObject, result_is_ll=True)
def PySequence_GetItem(space, w_obj, i):
    """Return the ith element of o, or NULL on failure. This is the equivalent of
    the Python expression o[i]."""
    if i < 0:
        l = PySequence_Length(space, w_obj)
        i += l
        if i < 0:
            # Prevent things like 'abc'[-4] from turning into 'abc'[-1]
            # since this can end up calling space.getitem()
            raise oefmt(space.w_IndexError,
                "%T index out of range")
    return PySequence_ITEM(space, w_obj, i)

@cpython_api([PyObject], PyObject)
def PySequence_List(space, w_obj):
    """Return a list object with the same contents as the arbitrary sequence o.  The
    returned list is guaranteed to be new."""
    return space.call_function(space.w_list, w_obj)

@cpython_api([PyObject], PyObject)
def PySequence_Tuple(space, w_obj):
    """Return a tuple object with the same contents as the arbitrary sequence o or
    NULL on failure.  If o is a tuple, a new reference will be returned,
    otherwise a tuple will be constructed with the appropriate contents.  This is
    equivalent to the Python expression tuple(o)."""
    return space.call_function(space.w_tuple, w_obj)

@cpython_api([PyObject, PyObject], PyObject)
def PySequence_Concat(space, w_o1, w_o2):
    """Return the concatenation of o1 and o2 on success, and NULL on failure.
    This is the equivalent of the Python expression o1 + o2."""
    return space.add(w_o1, w_o2)

@cpython_api([PyObject, PyObject], PyObject)
def PySequence_InPlaceConcat(space, w_o1, w_o2):
    """Return the concatenation of o1 and o2 on success, and NULL on failure.
    The operation is done in-place when o1 supports it.  This is the equivalent
    of the Python expression o1 += o2."""
    return space.inplace_add(w_o1, w_o2)

@cpython_api([PyObject, Py_ssize_t], PyObject)
def PySequence_InPlaceRepeat(space, w_o, count):
    """Return the result of repeating sequence object o count times, or NULL on
    failure.  The operation is done in-place when o supports it.  This is the
    equivalent of the Python expression o *= count.

    This function used an int type for count. This might require
    changes in your code for properly supporting 64-bit systems."""
    return space.inplace_mul(w_o, space.newint(count))


@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PySequence_Contains(space, w_obj, w_value):
    """Determine if o contains value.  If an item in o is equal to value,
    return 1, otherwise return 0. On error, return -1.  This is
    equivalent to the Python expression value in o."""
    w_res = space.contains(w_obj, w_value)
    return space.int_w(w_res)

@cpython_api([PyObject], PyObject)
def PySeqIter_New(space, w_seq):
    """Return an iterator that works with a general sequence object, seq.  The
    iteration ends when the sequence raises IndexError for the subscripting
    operation.
    """
    # XXX check for bad internal call
    return space.newseqiter(w_seq)

@cpython_api([PyObject, Py_ssize_t, PyObject], rffi.INT_real, error=-1)
def PySequence_SetItem(space, w_o, i, w_v):
    """Assign object v to the ith element of o.  Returns -1 on failure.  This
    is the equivalent of the Python statement o[i] = v.  This function does
    not steal a reference to v."""
    if PyDict_Check(space, w_o) or not PySequence_Check(space, w_o):
        raise oefmt(space.w_TypeError,
                    "'%T' object does not support item assignment", w_o)
    space.setitem(w_o, space.newint(i), w_v)
    return 0

@cpython_api([PyObject, Py_ssize_t], rffi.INT_real, error=-1)
def PySequence_DelItem(space, w_o, i):
    """Delete the ith element of object o.  Returns -1 on failure.  This is the
    equivalent of the Python statement del o[i]."""
    space.delitem(w_o, space.newint(i))
    return 0

@cpython_api([PyObject, PyObject], Py_ssize_t, error=-1)
def PySequence_Index(space, w_seq, w_obj):
    """Return the first index i for which o[i] == value.  On error, return
    -1.    This is equivalent to the Python expression o.index(value).

    This function returned an int type. This might require changes
    in your code for properly supporting 64-bit systems."""

    w_iter = space.iter(w_seq)
    idx = 0
    while True:
        try:
            w_next = space.next(w_iter)
        except OperationError as e:
            if e.match(space, space.w_StopIteration):
                break
            raise
        if space.eq_w(w_next, w_obj):
            return idx
        idx += 1

    raise oefmt(space.w_ValueError, "sequence.index(x): x not in sequence")

class CPyListStrategy(ListStrategy):
    erase, unerase = rerased.new_erasing_pair("cpylist")
    erase = staticmethod(erase)
    unerase = staticmethod(unerase)

    def _check_index(self, index, length):
        if index < 0:
            index = length + index
        if index < 0 or index >= length:
            raise IndexError
        return index

    def getitem(self, w_list, index):
        storage = self.unerase(w_list.lstorage)
        index = self._check_index(index, storage._length)
        return from_ref(w_list.space, storage._elems[index])

    def setitem(self, w_list, index, w_obj):
        storage = self.unerase(w_list.lstorage)
        index = self._check_index(index, storage._length)
        py_old = storage._elems[index]
        storage._elems[index] = make_ref(w_list.space, w_obj)
        decref(w_list.space, py_old)

    def length(self, w_list):
        storage = self.unerase(w_list.lstorage)
        return storage._length

    def getslice(self, w_list, start, stop, step, length):
        w_list.switch_to_object_strategy()
        return w_list.strategy.getslice(w_list, start, stop, step, length)

    def getitems(self, w_list):
        # called when switching list strategy, so convert storage
        storage = self.unerase(w_list.lstorage)
        retval = [None] * storage._length
        for i in range(storage._length):
            retval[i] = from_ref(w_list.space, storage._elems[i])
        return retval

    @jit.unroll_safe
    def getitems_unroll(self, w_list):
        storage = self.unerase(w_list.lstorage)
        retval = [None] * storage._length
        for i in range(storage._length):
            retval[i] = from_ref(w_list.space, storage._elems[i])
        return retval

    @jit.look_inside_iff(lambda self, w_list:
            jit.loop_unrolling_heuristic(w_list, w_list.length(),
                                         UNROLL_CUTOFF))
    def getitems_fixedsize(self, w_list):
        return self.getitems_unroll(w_list)

    def copy_into(self, w_list, w_other):
        w_other.strategy = self
        w_other.lstorage = self.getstorage_copy(w_list)

    def clone(self, w_list):
        storage = self.getstorage_copy(w_list)
        w_clone = W_ListObject.from_storage_and_strategy(self.space, storage,
                                                         self)
        return w_clone

    def getitems_copy(self, w_list):
        return self.getitems(w_list) # getitems copies anyway

    def getstorage_copy(self, w_list):
        lst = self.getitems(w_list)
        return self.erase(CPyListStorage(w_list.space, lst))

    #------------------------------------------
    # all these methods fail or switch strategy and then call ListObjectStrategy's method

    def setslice(self, w_list, start, stop, step, length):
        w_list.switch_to_object_strategy()
        w_list.strategy.setslice(w_list, start, stop, step, length)

    def init_from_list_w(self, w_list, list_w):
        raise NotImplementedError

    def _resize_hint(self, w_list, hint):
        pass

    def find(self, w_list, w_item, start, stop):
        w_list.switch_to_object_strategy()
        return w_list.strategy.find(w_list, w_item, start, stop)

    def append(self, w_list, w_item):
        w_list.switch_to_object_strategy()
        w_list.strategy.append(w_list, w_item)

    def inplace_mul(self, w_list, times):
        w_list.switch_to_object_strategy()
        w_list.strategy.inplace_mul(w_list, times)

    def deleteslice(self, w_list, start, step, slicelength):
        w_list.switch_to_object_strategy()
        w_list.strategy.deleteslice(w_list, start, step, slicelength)

    def pop(self, w_list, index):
        w_list.switch_to_object_strategy()
        return w_list.strategy.pop(w_list, index)

    def pop_end(self, w_list):
        w_list.switch_to_object_strategy()
        return w_list.strategy.pop_end(w_list)

    def insert(self, w_list, index, w_item):
        w_list.switch_to_object_strategy()
        w_list.strategy.insert(w_list, index, w_item)

    def extend(self, w_list, w_any):
        w_list.switch_to_object_strategy()
        w_list.strategy.extend(w_list, w_any)

    def _extend_from_list(self, w_list, w_other):
        w_list.switch_to_object_strategy()
        w_list.strategy._extend_from_list(w_list, w_other)

    def _extend_from_iterable(self, w_list, w_iterable):
        w_list.switch_to_object_strategy()
        w_list.strategy._extend_from_iterable(w_list, w_iterable)

    def reverse(self, w_list):
        w_list.switch_to_object_strategy()
        w_list.strategy.reverse(w_list)

    def sort(self, w_list, reverse):
        w_list.switch_to_object_strategy()
        w_list.descr_sort(w_list.space, reverse=reverse)

    def is_empty_strategy(self):
        return False


PyObjectList = lltype.Ptr(lltype.Array(PyObject, hints={'nolength': True}))

class CPyListStorage(object):
    def __init__(self, space, lst):
        self.space = space
        self._elems = lltype.malloc(PyObjectList.TO, len(lst), flavor='raw')
        self._length = len(lst)
        self._allocated = len(lst)
        for i, item in enumerate(lst):
            self._elems[i] = make_ref(space, lst[i])

    def __del__(self):
        for i in range(self._length):
            decref(self.space, self._elems[i])
        lltype.free(self._elems, flavor='raw')
