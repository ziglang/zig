from pypy.interpreter.error import OperationError
from pypy.module.cpyext.api import (generic_cpy_call, cpython_api, PyObject,
    CANNOT_FAIL)
import pypy.module.__builtin__.operation as operation
from rpython.rtyper.lltypesystem import rffi


@cpython_api([PyObject, PyObject], PyObject)
def PyCallIter_New(space, w_callable, w_sentinel):
    """Return a new iterator.  The first parameter, callable, can be any Python
    callable object that can be called with no parameters; each call to it should
    return the next item in the iteration.  When callable returns a value equal to
    sentinel, the iteration will be terminated.
    """
    return operation.iter_sentinel(space, w_callable, w_sentinel)

@cpython_api([PyObject], PyObject)
def PyObject_GetIter(space, w_obj):
    """This is equivalent to the Python expression iter(o). It returns a new
    iterator for the object argument, or the object itself if the object is
    already an iterator.  Raises TypeError and returns NULL if the object
    cannot be iterated."""
    return space.iter(w_obj)

@cpython_api([PyObject], PyObject)
def PyIter_Next(space, w_obj):
    """Return the next value from the iteration o.  If the object is an
    iterator, this retrieves the next value from the iteration, and returns
    NULL with no exception set if there are no remaining items.  If the object
    is not an iterator, TypeError is raised, or if there is an error in
    retrieving the item, returns NULL and passes along the exception."""
    try:
        return space.next(w_obj)
    except OperationError as e:
        if not e.match(space, space.w_StopIteration):
            raise
    return None

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyIter_Check(space, w_obj):
    """Return true if the object o supports the iterator protocol."""
    try:
        w_attr = space.getattr(space.type(w_obj), space.newtext("__next__"))
    except:
        return False
    else:
        return space.is_true(space.callable(w_attr))
