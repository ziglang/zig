from pypy.module.cpyext.api import cpython_api
from pypy.module.cpyext.pyobject import PyObject, CANNOT_FAIL
from pypy.module._weakref.interp__weakref import W_Weakref, proxy
from pypy.module._weakref.interp__weakref import W_Proxy, W_CallableProxy
from rpython.rtyper.lltypesystem import rffi

@cpython_api([PyObject, PyObject], PyObject)
def PyWeakref_NewRef(space, w_obj, w_callback):
    """Return a weak reference object for the object ob.  This will always return
    a new reference, but is not guaranteed to create a new object; an existing
    reference object may be returned.  The second parameter, callback, can be a
    callable object that receives notification when ob is garbage collected; it
    should accept a single parameter, which will be the weak reference object
    itself. callback may also be None or NULL.  If ob is not a
    weakly-referencable object, or if callback is not callable, None, or
    NULL, this will return NULL and raise TypeError.
    """
    w_weakref = space.gettypeobject(W_Weakref.typedef)
    return space.call_function(w_weakref, w_obj, w_callback)

@cpython_api([PyObject, PyObject], PyObject)
def PyWeakref_NewProxy(space, w_obj, w_callback):
    """Return a weak reference proxy object for the object *ob*.  This will
    alwas return a new reference, but is not guaranteed to create a new
    object; an existing proxy object may be returned.  The second parameter,
    *callback*, can be a callable object that receives notification when *ob*
    is garbage collected; it should accept a single parameter, which will be
    the weak reference object itself. *callback* may also be ``None`` or
    *NULL*.  If *ob* is not a weakly-referencable object, or if *callback* is
    not callable, ``None``, or *NULL*, this will return *NULL* and raise
    :exc:`TypeError`.
    """
    return proxy(space, w_obj, w_callback)

@cpython_api([PyObject], PyObject, result_borrowed=True)
def PyWeakref_GetObject(space, w_ref):
    """Return the referenced object from a weak reference.  If the referent is
    no longer live, returns None. This function returns a borrowed reference.
    """
    return space.call_function(w_ref)     # borrowed ref

@cpython_api([rffi.VOIDP], PyObject, result_borrowed=True)
def PyWeakref_GET_OBJECT(space, w_ref):
    """Similar to PyWeakref_GetObject(), but implemented as a macro that does no
    error checking.
    """
    return space.call_function(w_ref)     # borrowed ref

@cpython_api([PyObject], PyObject)
def PyWeakref_LockObject(space, w_ref):
    """Return the referenced object from a weak reference.  If the referent is
    no longer live, returns None. This function returns a new reference.

    (A PyPy extension that may not be useful any more: use
    PyWeakref_GetObject() and Py_INCREF().)
    """
    return space.call_function(w_ref)

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyWeakref_CheckRef(space, w_obj):
    """Return true if ob is a reference object.
    """
    w_obj_type = space.type(w_obj)
    w_type = space.gettypeobject(W_Weakref.typedef)
    return (space.is_w(w_obj_type, w_type) or
            space.issubtype_w(w_obj_type, w_type))

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyWeakref_CheckRefExact(space, w_obj):
    w_obj_type = space.type(w_obj)
    w_type = space.gettypeobject(W_Weakref.typedef)
    return space.is_w(w_obj_type, w_type)

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyWeakref_CheckProxy(space, w_obj):
    """Return true if ob is a proxy object.
    """
    w_obj_type = space.type(w_obj)
    w_type1 = space.gettypeobject(W_Proxy.typedef)
    w_type2 = space.gettypeobject(W_CallableProxy.typedef)
    return space.is_w(w_obj_type, w_type1) or space.is_w(w_obj_type, w_type2)

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyWeakref_Check(space, w_obj):
    """Return true if ob is either a reference or proxy object.
    """
    return (PyWeakref_CheckRef(space, w_obj) or
            PyWeakref_CheckProxy(space, w_obj))
