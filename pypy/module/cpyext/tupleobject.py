from pypy.interpreter.error import oefmt
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.debug import fatalerror_notb
from pypy.module.cpyext.api import (
    cpython_api, Py_ssize_t, build_type_checkers_flags, PyVarObject,
    PyVarObjectFields, cpython_struct, bootstrap_function, slot_function)
from pypy.module.cpyext.pyobject import (
    PyObject, PyObjectP, make_ref, from_ref, decref, incref, BaseCpyTypedescr,
    track_reference, make_typedescr, get_typedescr, pyobj_has_w_obj)
from pypy.module.cpyext.state import State
from pypy.module.cpyext.pyerrors import PyErr_BadInternalCall
from pypy.objspace.std.tupleobject import W_TupleObject

##
## Implementation of PyTupleObject
## ===============================
##
## Similar to stringobject.py.  The reason is only the existance of
## W_SpecialisedTupleObject_ii and W_SpecialisedTupleObject_ff.
## These two PyPy classes implement getitem() by returning a freshly
## constructed W_IntObject or W_FloatObject.  This is not compatible
## with PyTuple_GetItem, which returns a borrowed reference.
##
## So we use this more advanced (but also likely faster) solution:
## tuple_attach makes a real PyTupleObject with an array of N
## 'PyObject *', which are created immediately and own a reference.
## Then the macro PyTuple_GET_ITEM can be implemented like CPython.
##

PyTupleObjectStruct = lltype.ForwardReference()
PyTupleObject = lltype.Ptr(PyTupleObjectStruct)
ObjectItems = rffi.CArray(PyObject)
PyTupleObjectFields = PyVarObjectFields + \
    (("ob_item", ObjectItems),)
cpython_struct("PyTupleObject", PyTupleObjectFields, PyTupleObjectStruct)

@bootstrap_function
def init_tupleobject(space):
    "Type description of PyTupleObject"
    state = space.fromcache(State)
    make_typedescr(space.w_tuple.layout.typedef,
                   basestruct=PyTupleObject.TO,
                   attach=tuple_attach,
                   alloc=tuple_alloc,
                   dealloc=state.C._PyPy_tuple_dealloc,
                   realize=tuple_realize)

PyTuple_Check, PyTuple_CheckExact = build_type_checkers_flags("Tuple")

def tuple_check_ref(space, ref):
    w_type = from_ref(space, rffi.cast(PyObject, ref.c_ob_type))
    return (w_type is space.w_tuple or
            space.issubtype_w(w_type, space.w_tuple))

_BAD_ITEMCOUNT = None    # patched in test_badinternalcall_from_rpy

def tuple_alloc(typedescr, space, w_type, itemcount):
    state = space.fromcache(State)
    if w_type is space.w_tuple:
        if not we_are_translated() and itemcount == _BAD_ITEMCOUNT:
            itemcount = -42
        ptup = state.ccall("PyTuple_New", itemcount)
        if not ptup:
            state.check_and_raise_exception(always=True)
        return ptup
    else:
        return BaseCpyTypedescr.allocate(typedescr, space, w_type, itemcount)

def tuple_attach(space, py_obj, w_obj, w_userdata=None):
    """
    Fills a newly allocated PyTupleObject with the given tuple object. The
    buffer must not be modified.
    """
    items_w = space.fixedview(w_obj)
    py_tup = rffi.cast(PyTupleObject, py_obj)
    py_varobj = rffi.cast(PyVarObject, py_obj)
    length = len(items_w)
    if py_varobj.c_ob_size < length:
        raise oefmt(space.w_ValueError,
            "tuple_attach called on object with ob_size %d but trying to store %d",
            py_varobj.c_ob_size, length)
    i = 0
    try:
        while i < length:
            py_tup.c_ob_item[i] = make_ref(space, items_w[i])
            i += 1
    except:
        while i > 0:
            i -= 1
            ob = py_tup.c_ob_item[i]
            py_tup.c_ob_item[i] = lltype.nullptr(PyObject.TO)
            decref(space, ob)
        raise

def tuple_realize(space, py_obj):
    """
    Creates the tuple in the interpreter. The PyTupleObject must not
    be modified after this call.  We check that it does not contain
    any NULLs at this point (which would correspond to half-broken
    W_TupleObjects).
    """
    py_tup = rffi.cast(PyTupleObject, py_obj)
    l = rffi.cast(PyVarObject, py_tup).c_ob_size
    p = py_tup.c_ob_item
    items_w = [None] * l
    for i in range(l):
        w_item = from_ref(space, p[i])
        if w_item is None:
            fatalerror_notb(
                "Fatal error in cpyext, CPython compatibility layer: "
                "converting a PyTupleObject into a W_TupleObject, "
                "but found NULLs as items")
        items_w[i] = w_item
    w_type = from_ref(space, rffi.cast(PyObject, py_obj.c_ob_type))
    w_obj = space.allocate_instance(W_TupleObject, w_type)
    w_obj.__init__(items_w)
    track_reference(space, py_obj, w_obj)
    return w_obj

def tuple_from_args_w(space, args_w):
    state = space.fromcache(State)
    n = len(args_w)
    py_tuple = state.ccall("PyTuple_New", n)
    if not py_tuple:
        state.check_and_raise_exception(always=True)
    py_tuple = rffi.cast(PyTupleObject, py_tuple)
    for i, w_obj in enumerate(args_w):
        py_tuple.c_ob_item[i] = make_ref(space, w_obj)
    return rffi.cast(PyObject, py_tuple)

@cpython_api([PyObject, Py_ssize_t, PyObject], rffi.INT_real, error=-1)
def PyTuple_SetItem(space, ref, index, py_obj):
    if not tuple_check_ref(space, ref):
        decref(space, py_obj)
        PyErr_BadInternalCall(space)
    tupleobj = rffi.cast(PyTupleObject, ref)
    size = rffi.cast(PyVarObject, tupleobj).c_ob_size
    if index < 0 or index >= size:
        decref(space, py_obj)
        raise oefmt(space.w_IndexError, "tuple assignment index out of range")
    old_ref = tupleobj.c_ob_item[index]
    if pyobj_has_w_obj(ref):
        # similar but not quite equal to ref.c_ob_refcnt != 1 on CPython
        decref(space, py_obj)
        raise oefmt(space.w_SystemError, "PyTuple_SetItem called on tuple after"
                                        " use of tuple")
    tupleobj.c_ob_item[index] = py_obj    # consumes a reference
    if old_ref:
        decref(space, old_ref)
    return 0

@cpython_api([PyObject, Py_ssize_t], PyObject,
             result_borrowed=True, result_is_ll=True)
def PyTuple_GetItem(space, ref, index):
    if not tuple_check_ref(space, ref):
        PyErr_BadInternalCall(space)
    ref = rffi.cast(PyTupleObject, ref)
    size = rffi.cast(PyVarObject, ref).c_ob_size
    if index < 0 or index >= size:
        raise oefmt(space.w_IndexError, "tuple index out of range")
    return ref.c_ob_item[index]     # borrowed ref

@cpython_api([PyObject], Py_ssize_t, error=-1)
def PyTuple_Size(space, ref):
    """Take a pointer to a tuple object, and return the size of that tuple."""
    if not tuple_check_ref(space, ref):
        PyErr_BadInternalCall(space)
    ref = rffi.cast(PyVarObject, ref)
    return ref.c_ob_size


@cpython_api([PyObjectP, Py_ssize_t], rffi.INT_real, error=-1)
def _PyTuple_Resize(space, p_ref, newsize):
    """Can be used to resize a tuple.  newsize will be the new length of the tuple.
    Because tuples are supposed to be immutable, this should only be used if there
    is only one reference to the object.  Do not use this if the tuple may already
    be known to some other part of the code.  The tuple will always grow or shrink
    at the end.  Think of this as destroying the old tuple and creating a new one,
    only more efficiently.  Returns 0 on success. Client code should never
    assume that the resulting value of *p will be the same as before calling
    this function. If the object referenced by *p is replaced, the original
    *p is destroyed.  On failure, returns -1 and sets *p to NULL, and
    raises MemoryError or SystemError."""
    state = space.fromcache(State)
    ref = p_ref[0]
    if not tuple_check_ref(space, ref):
        PyErr_BadInternalCall(space)
    oldref = rffi.cast(PyTupleObject, ref)
    oldsize = rffi.cast(PyVarObject, oldref).c_ob_size
    if oldsize == newsize:
        return 0
    ptup = state.ccall("PyTuple_New", newsize)
    if not ptup:
        state.check_and_raise_exception(always=True)
    p_ref[0] = ptup
    newref = rffi.cast(PyTupleObject, p_ref[0])
    try:
        if oldsize < newsize:
            to_cp = oldsize
        else:
            to_cp = newsize
        for i in range(to_cp):
            ob = oldref.c_ob_item[i]
            if ob:
                incref(space, ob)
                newref.c_ob_item[i] = ob
    except:
        decref(space, p_ref[0])
        p_ref[0] = lltype.nullptr(PyObject.TO)
        raise
    finally:
        decref(space, ref)
    return 0

@cpython_api([PyObject, Py_ssize_t, Py_ssize_t], PyObject)
def PyTuple_GetSlice(space, w_obj, low, high):
    """Take a slice of the tuple pointed to by p from low to high and return it
    as a new tuple.
    """
    return space.getslice(w_obj, space.newint(low), space.newint(high))
