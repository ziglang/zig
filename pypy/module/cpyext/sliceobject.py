import sys
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import (
    cpython_api, cpython_struct, bootstrap_function, build_type_checkers,
    CANNOT_FAIL, Py_ssize_t, Py_ssize_tP, PyObjectFields, slot_function)
from pypy.module.cpyext.pyobject import (
    decref, PyObject, make_ref, make_typedescr)
from pypy.module.cpyext.pyerrors import PyErr_BadInternalCall
from pypy.interpreter.error import oefmt
from pypy.objspace.std.sliceobject import W_SliceObject

# Slice objects directly expose their members as PyObject.
# Don't change them!

PySliceObjectStruct = lltype.ForwardReference()
PySliceObject = lltype.Ptr(PySliceObjectStruct)
PySliceObjectFields = PyObjectFields + \
    (("start", PyObject), ("step", PyObject), ("stop", PyObject), )
cpython_struct("PySliceObject", PySliceObjectFields, PySliceObjectStruct)

@bootstrap_function
def init_sliceobject(space):
    "Type description of PySliceObject"
    make_typedescr(W_SliceObject.typedef,
                   basestruct=PySliceObject.TO,
                   attach=slice_attach,
                   dealloc=slice_dealloc)

def slice_attach(space, py_obj, w_obj, w_userdata=None):
    """
    Fills a newly allocated PySliceObject with the given slice object. The
    fields must not be modified.
    """
    py_slice = rffi.cast(PySliceObject, py_obj)
    assert isinstance(w_obj, W_SliceObject)
    py_slice.c_start = make_ref(space, w_obj.w_start)
    py_slice.c_stop = make_ref(space, w_obj.w_stop)
    py_slice.c_step = make_ref(space, w_obj.w_step)

@slot_function([PyObject], lltype.Void)
def slice_dealloc(space, py_obj):
    """Frees allocated PySliceObject resources.
    """
    py_slice = rffi.cast(PySliceObject, py_obj)
    decref(space, py_slice.c_start)
    decref(space, py_slice.c_stop)
    decref(space, py_slice.c_step)
    from pypy.module.cpyext.object import _dealloc
    _dealloc(space, py_obj)


@cpython_api([PyObject, PyObject, PyObject], PyObject)
def PySlice_New(space, w_start, w_stop, w_step):
    """Return a new slice object with the given values.  The start, stop, and
    step parameters are used as the values of the slice object attributes of
    the same names.  Any of the values may be NULL, in which case the
    None will be used for the corresponding attribute.  Return NULL if
    the new object could not be allocated."""
    if w_start is None:
        w_start = space.w_None
    if w_stop is None:
        w_stop = space.w_None
    if w_step is None:
        w_step = space.w_None
    return W_SliceObject(w_start, w_stop, w_step)

@cpython_api([PyObject, Py_ssize_t, Py_ssize_tP, Py_ssize_tP, Py_ssize_tP,
                Py_ssize_tP], rffi.INT_real, error=-1)
def PySlice_GetIndicesEx(space, w_slice, length, start_p, stop_p, step_p,
                         slicelength_p):
    """Usable replacement for PySlice_GetIndices().  Retrieve the start,
    stop, and step indices from the slice object slice assuming a sequence of
    length length, and store the length of the slice in slicelength.  Out
    of bounds indices are clipped in a manner consistent with the handling of
    normal slices.

    Returns 0 on success and -1 on error with exception set."""
    if not isinstance(w_slice, W_SliceObject):
        raise PyErr_BadInternalCall(space)
    start_p[0], stop_p[0], step_p[0], slicelength_p[0] = \
            w_slice.indices4(space, length)
    return 0

@cpython_api([PyObject, Py_ssize_t, Py_ssize_tP, Py_ssize_tP, Py_ssize_tP],
                rffi.INT_real, error=-1)
def PySlice_GetIndices(space, w_slice, length, start_p, stop_p, step_p):
    """Retrieve the start, stop and step indices from the slice object slice,
    assuming a sequence of length length. Treats indices greater than
    length as errors.

    Returns 0 on success and -1 on error with no exception set (unless one of
    the indices was not None and failed to be converted to an integer,
    in which case -1 is returned with an exception set).

    You probably do not want to use this function.  If you want to use slice
    objects in versions of Python prior to 2.3, you would probably do well to
    incorporate the source of PySlice_GetIndicesEx(), suitably renamed,
    in the source of your extension."""
    if not isinstance(w_slice, W_SliceObject):
        raise PyErr_BadInternalCall(space)
    start_p[0], stop_p[0], step_p[0] = \
            w_slice.indices3(space, length)
    return 0

@cpython_api([PyObject, Py_ssize_tP, Py_ssize_tP, Py_ssize_tP],
             rffi.INT_real, error=-1)
def PySlice_Unpack(space, w_slice, start_p, stop_p, step_p):
    if not isinstance(w_slice, W_SliceObject):
        raise PyErr_BadInternalCall(space)

    if space.is_none(w_slice.w_step):
        step = 1
    else:
        step = W_SliceObject.eval_slice_index(space, w_slice.w_step)
        if step == 0:
            raise oefmt(space.w_ValueError, "slice step cannot be zero")
        if step < -sys.maxint:
            step = -sys.maxint
    step_p[0] = step

    if space.is_none(w_slice.w_start):
        start = sys.maxint if step < 0 else 0
    else:
        start = W_SliceObject.eval_slice_index(space, w_slice.w_start)
    start_p[0] = start

    if space.is_none(w_slice.w_stop):
        stop = -sys.maxint-1 if step < 0 else sys.maxint
    else:
        stop = W_SliceObject.eval_slice_index(space, w_slice.w_stop)
    stop_p[0] = stop

    return 0
