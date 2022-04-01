# Provide implementation of PyException_ functions.

from pypy.module.cpyext.api import cpython_api
from pypy.module.cpyext.pyobject import PyObject, from_ref, decref
from rpython.rtyper.lltypesystem import rffi, lltype


@cpython_api([PyObject], PyObject)
def PyExceptionInstance_Class(space, w_obj):
    return space.type(w_obj)


@cpython_api([PyObject], PyObject)
def PyException_GetTraceback(space, w_exc):
    """Return the traceback associated with the exception as a new reference, as
    accessible from Python through __traceback__.  If there is no
    traceback associated, this returns NULL."""
    w_tb = space.getattr(w_exc, space.newtext('__traceback__'))
    if space.is_none(w_tb):
        return None
    return w_tb


@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyException_SetTraceback(space, w_exc, w_tb):
    """Set the traceback associated with the exception to tb.  Use Py_None to
    clear it."""
    space.setattr(w_exc, space.newtext('__traceback__'), w_tb)
    return 0


@cpython_api([PyObject], PyObject)
def PyException_GetContext(space, w_exc):
    """Return the context (another exception instance during whose handling ex was
    raised) associated with the exception as a new reference, as accessible from
    Python through __context__.  If there is no context associated, this
    returns NULL."""
    w_ctx = space.getattr(w_exc, space.newtext('__context__'))
    if space.is_none(w_ctx):
        return None
    return w_ctx


@cpython_api([PyObject, PyObject], lltype.Void)
def PyException_SetContext(space, w_exc, ctx):
    """Set the context associated with the exception to ctx.  Use NULL to clear
    it.  There is no type check to make sure that ctx is an exception instance.
    This steals a reference to ctx."""
    if ctx:
        w_ctx = from_ref(space, ctx)
        decref(space, ctx)
    else:
        w_ctx = space.w_None
    space.setattr(w_exc, space.newtext('__context__'), w_ctx)

@cpython_api([PyObject], PyObject)
def PyException_GetCause(space, w_exc):
    """Return the cause (another exception instance set by raise ... from ...)
    associated with the exception as a new reference, as accessible from Python
    through __cause__.  If there is no cause associated, this returns
    NULL."""
    w_cause = space.getattr(w_exc, space.newtext('__cause__'))
    if space.is_none(w_cause):
        return None
    return w_cause


@cpython_api([PyObject, PyObject], lltype.Void)
def PyException_SetCause(space, w_exc, cause):
    """Set the cause associated with the exception to cause.  Use NULL to clear
    it.  There is no type check to make sure that cause is an exception instance.
    This steals a reference to cause."""
    if cause:
        w_cause = from_ref(space, cause)
        decref(space, cause)
    else:
        w_cause = space.w_None
    space.setattr(w_exc, space.newtext('__cause__'), w_cause)

