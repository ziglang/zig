from pypy.interpreter.error import OperationError, oefmt
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import (
    cpython_api, Py_ssize_t, Py_ssize_tP, CANNOT_FAIL, build_type_checkers,
    PyObjectFields, cpython_struct, bootstrap_function, slot_function)
from pypy.module.cpyext.pyobject import (PyObject, PyObjectP,
    make_ref, from_ref, as_pyobj, create_ref, make_typedescr, incref, decref)
from pypy.module.cpyext.object import _dealloc
from pypy.module.cpyext.pyerrors import PyErr_BadInternalCall
from pypy.objspace.std.setobject import W_SetObject, W_FrozensetObject, newset

PySetObjectStruct = lltype.ForwardReference()
PySetObject = lltype.Ptr(PySetObjectStruct)
PySetObjectFields = PyObjectFields + \
    (("_tmplist", PyObject),)
cpython_struct("PySetObject", PySetObjectFields, PySetObjectStruct)

@bootstrap_function
def init_setobject(space):
    "Type description of PySetObject"
    make_typedescr(space.w_set.layout.typedef,
                   basestruct=PySetObject.TO,
                   attach=set_attach,
                   dealloc=set_dealloc)
    make_typedescr(space.w_frozenset.layout.typedef,   # same as 'set'
                   basestruct=PySetObject.TO,
                   attach=set_attach,
                   dealloc=set_dealloc)

def set_attach(space, py_obj, w_obj, w_userdata=None):
    """
    Fills a newly allocated PySetObject with the given set object.
    """
    py_set = rffi.cast(PySetObject, py_obj)
    py_set.c__tmplist = lltype.nullptr(PyObject.TO)

@slot_function([PyObject], lltype.Void)
def set_dealloc(space, py_obj):
    py_set = rffi.cast(PySetObject, py_obj)
    decref(space, py_set.c__tmplist)
    py_set.c__tmplist = lltype.nullptr(PyObject.TO)
    _dealloc(space, py_obj)

PySet_Check, PySet_CheckExact = build_type_checkers("Set")
PyFrozenSet_Check, PyFrozenSet_CheckExact = build_type_checkers("FrozenSet")

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyAnySet_Check(space, w_obj):
    """Return true if obj is a set object, a frozenset object, or an
    instance of a subtype."""
    return (space.isinstance_w(w_obj, space.gettypefor(W_SetObject)) or
            space.isinstance_w(w_obj, space.gettypefor(W_FrozensetObject)))

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyAnySet_CheckExact(space, w_obj):
    """Return true if obj is a set object or a frozenset object but
    not an instance of a subtype."""
    w_obj_type = space.type(w_obj)
    return (space.is_w(w_obj_type, space.gettypefor(W_SetObject)) or
            space.is_w(w_obj_type, space.gettypefor(W_FrozensetObject)))

@cpython_api([PyObject], PyObject)
def PySet_New(space, w_iterable):
    """Return a new set containing objects returned by the iterable.  The
    iterable may be NULL to create a new empty set.  Return the new set on
    success or NULL on failure.  Raise TypeError if iterable is not
    actually iterable.  The constructor is also useful for copying a set
    (c=set(s))."""
    if w_iterable is None:
        return space.call_function(space.w_set)
    else:
        return space.call_function(space.w_set, w_iterable)

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PySet_Add(space, w_s, w_obj):
    """Add key to a set instance.  Does not apply to frozenset
    instances.  Return 0 on success or -1 on failure. Raise a TypeError if
    the key is unhashable. Raise a MemoryError if there is no room to grow.
    Raise a SystemError if set is an not an instance of set or its
    subtype.

    Now works with instances of frozenset or its subtypes.
    Like PyTuple_SetItem() in that it can be used to fill-in the
    values of brand new frozensets before they are exposed to other code."""
    if not PySet_Check(space, w_s):
        if isinstance(w_s, W_FrozensetObject) and w_s.cpyext_add_frozen(w_obj):
            return 0
        PyErr_BadInternalCall(space)
    space.call_method(space.w_set, 'add', w_s, w_obj)
    return 0

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PySet_Discard(space, w_s, w_obj):
    """Return 1 if found and removed, 0 if not found (no action taken), and -1 if an
    error is encountered.  Does not raise KeyError for missing keys.  Raise a
    TypeError if the key is unhashable.  Unlike the Python discard()
    method, this function does not automatically convert unhashable sets into
    temporary frozensets. Raise PyExc_SystemError if set is an not an
    instance of set or its subtype."""
    if not PySet_Check(space, w_s):
        PyErr_BadInternalCall(space)
    try:
        space.call_method(space.w_set, 'remove', w_s, w_obj)
    except OperationError as e:
        if e.match(space, space.w_KeyError):
            return 0
        raise
    return 1


@cpython_api([PyObject], PyObject)
def PySet_Pop(space, w_set):
    """Return a new reference to an arbitrary object in the set, and removes the
    object from the set.  Return NULL on failure.  Raise KeyError if the
    set is empty. Raise a SystemError if set is an not an instance of
    set or its subtype."""
    return space.call_method(space.w_set, "pop", w_set)

@cpython_api([PyObject], rffi.INT_real, error=-1)
def PySet_Clear(space, w_set):
    """Empty an existing set of all elements."""
    space.call_method(space.w_set, 'clear', w_set)
    return 0

@cpython_api([rffi.VOIDP], Py_ssize_t, error=CANNOT_FAIL)
def PySet_GET_SIZE(space, w_s):
    """Macro form of PySet_Size() without error checking."""
    return space.int_w(space.len(w_s))

@cpython_api([PyObject], Py_ssize_t, error=-1)
def PySet_Size(space, ref):
    """Return the length of a set or frozenset object. Equivalent to
    len(anyset).  Raises a PyExc_SystemError if anyset is not a set, frozenset,
    or an instance of a subtype."""
    if not PyAnySet_Check(space, ref):
        raise oefmt(space.w_TypeError, "expected set object")
    return PySet_GET_SIZE(space, ref)

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PySet_Contains(space, w_obj, w_key):
    """Return 1 if found, 0 if not found, and -1 if an error is encountered.  Unlike
    the Python __contains__() method, this function does not automatically
    convert unhashable sets into temporary frozensets.  Raise a TypeError if
    the key is unhashable. Raise PyExc_SystemError if anyset is not a
    set, frozenset, or an instance of a subtype."""
    w_res = space.contains(w_obj, w_key)
    return space.int_w(w_res)

@cpython_api([PyObject], PyObject)
def PyFrozenSet_New(space, w_iterable):
    """Return a new frozenset containing objects returned by the iterable.
    The iterable may be NULL to create a new empty frozenset.  Return the new
    set on success or NULL on failure.  Raise TypeError if iterable is
    not actually iterable.

    Now guaranteed to return a brand-new frozenset.  Formerly,
    frozensets of zero-length were a singleton.  This got in the way of
    building-up new frozensets with PySet_Add()."""
    if w_iterable is None:
        return space.call_function(space.w_frozenset)
    else:
        return space.call_function(space.w_frozenset, w_iterable)

@cpython_api([PyObject, Py_ssize_tP, PyObjectP, Py_ssize_tP], rffi.INT_real, error=-1)
def _PySet_NextEntry(space, w_set, ppos, pkey, phash):
    if w_set is None or not PyAnySet_Check(space, w_set):
        PyErr_BadInternalCall(space)
        return -1
    if not pkey:
        PyErr_BadInternalCall(space)
        return -1
    pos = ppos[0]
    py_obj = as_pyobj(space, w_set)
    py_set = rffi.cast(PySetObject, py_obj)
    if pos == 0:
        # Store the current item list in the PySetObject.
        # w_keys must use the object strategy in order to keep the keys alive
        w_keys = space.newlist(space.listview(w_set))
        w_keys.switch_to_object_strategy()
        oldlist = py_set.c__tmplist
        py_set.c__tmplist = create_ref(space, w_keys)
        incref(space, py_set.c__tmplist)
        decref(space, oldlist)
    else:
        if not py_set.c__tmplist:
            # pos should have been 0, cannot fail so return 0
            return 0;
        w_keys = from_ref(space, py_set.c__tmplist)
    ppos[0] += 1
    if pos >= space.len_w(w_keys):
        decref(space, py_set.c__tmplist)
        py_set.c__tmplist = lltype.nullptr(PyObject.TO)
        return 0
    w_key = space.listview(w_keys)[pos]
    pkey[0] = as_pyobj(space, w_key)
    if phash:
        phash[0] = space.hash_w(w_key)
    return 1

@cpython_api([PyObject, Py_ssize_tP, PyObjectP], rffi.INT_real, error=-1)
def _PySet_Next(space, w_set, ppos, pkey):
    null = lltype.nullptr(Py_ssize_tP.TO)
    return _PySet_NextEntry(space, w_set, ppos, pkey, null)
