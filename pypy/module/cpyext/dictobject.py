from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.objectmodel import specialize
from pypy.interpreter.error import OperationError
from pypy.objspace.std.classdict import ClassDictStrategy
from pypy.objspace.std.dictmultiobject import W_DictMultiObject
from pypy.interpreter.typedef import GetSetProperty
from pypy.module.cpyext.api import (
    cpython_api, CANNOT_FAIL, build_type_checkers_flags, Py_ssize_t, cts,
    Py_ssize_tP, CONST_STRING, PyObjectFields, cpython_struct,
    bootstrap_function, slot_function)
from pypy.module.cpyext.pyobject import (PyObject, PyObjectP, as_pyobj,
        make_typedescr, track_reference, create_ref, from_ref, decref,
        incref)
from pypy.module.cpyext.object import _dealloc
from pypy.module.cpyext.pyerrors import PyErr_BadInternalCall

PyDictObjectStruct = lltype.ForwardReference()
PyDictObject = lltype.Ptr(PyDictObjectStruct)
PyDictObjectFields = PyObjectFields + \
    (("_tmpkeys", PyObject),)
cpython_struct("PyDictObject", PyDictObjectFields, PyDictObjectStruct)

@bootstrap_function
def init_dictobject(space):
    "Type description of PyDictObject"
    make_typedescr(space.w_dict.layout.typedef,
                   basestruct=PyDictObject.TO,
                   attach=dict_attach,
                   dealloc=dict_dealloc,
                   realize=dict_realize)

def dict_attach(space, py_obj, w_obj, w_userdata=None):
    """
    Fills a newly allocated PyDictObject with the given dict object.
    """
    py_dict = rffi.cast(PyDictObject, py_obj)
    py_dict.c__tmpkeys = lltype.nullptr(PyObject.TO)
    # Problems: if this dict is a typedict, we may have unbound GetSetProperty
    # functions in the dict. The corresponding PyGetSetDescrObject must be
    # bound to a class, but the actual w_type will be unavailable later on.
    # Solution: use the w_userdata argument when assigning a PyTypeObject's
    # tp_dict slot to pass a w_type in, and force creation of the pair here
    if not space.is_w(w_userdata, space.gettypefor(GetSetProperty)):
        # do not do this for type dict of GetSetProperty, that would recurse
        w_vals = space.call_method(space.w_dict, "values", w_obj)
        vals = space.listview(w_vals)
        for w_v in vals:
            if isinstance(w_v, GetSetProperty):
                pyobj = as_pyobj(space, w_v, w_userdata)
                # refcnt will be REFCNT_FROM_PYPY, no need to inc or dec

def dict_realize(space, py_obj):
    """
    Creates the dict in the interpreter
    """
    w_obj = space.newdict()
    track_reference(space, py_obj, w_obj)

@slot_function([PyObject], lltype.Void)
def dict_dealloc(space, py_obj):
    py_dict = rffi.cast(PyDictObject, py_obj)
    decref(space, py_dict.c__tmpkeys)
    py_dict.c__tmpkeys = lltype.nullptr(PyObject.TO)
    _dealloc(space, py_obj)

@cpython_api([], PyObject)
def PyDict_New(space):
    return space.newdict()

PyDict_Check, PyDict_CheckExact = build_type_checkers_flags("Dict")

@cpython_api([PyObject, PyObject], PyObject, error=CANNOT_FAIL,
             result_borrowed=True)
def PyDict_GetItem(space, w_dict, w_key):
    if not isinstance(w_dict, W_DictMultiObject):
        return None
    # NOTE: this works so far because all our dict strategies store
    # *values* as full objects, which stay alive as long as the dict is
    # alive and not modified.  So we can return a borrowed ref.
    # XXX this is wrong with IntMutableCell.  Hope it works...
    try:
        return w_dict.getitem(w_key)
    except OperationError:
        return None

@cpython_api([PyObject, PyObject], PyObject, result_borrowed=True)
def PyDict_GetItemWithError(space, w_dict, w_key):
    """Variant of PyDict_GetItem() that does not suppress
    exceptions. Return NULL with an exception set if an exception
    occurred.  Return NULL without an exception set if the key
    wasn't present."""
    if not isinstance(w_dict, W_DictMultiObject):
        PyErr_BadInternalCall(space)
    return w_dict.getitem(w_key)

@cpython_api([PyObject, PyObject, PyObject], rffi.INT_real, error=-1)
def PyDict_SetItem(space, w_dict, w_key, w_obj):
    if not isinstance(w_dict, W_DictMultiObject):
        PyErr_BadInternalCall(space)
    w_dict.setitem(w_key, w_obj)
    return 0

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyDict_DelItem(space, w_dict, w_key):
    if not isinstance(w_dict, W_DictMultiObject):
        PyErr_BadInternalCall(space)
    w_dict.descr_delitem(space, w_key)
    return 0

@cpython_api([PyObject, CONST_STRING, PyObject], rffi.INT_real, error=-1)
def PyDict_SetItemString(space, w_dict, key_ptr, w_obj):
    w_key = space.newtext(rffi.charp2str(key_ptr))
    if not isinstance(w_dict, W_DictMultiObject):
        PyErr_BadInternalCall(space)
    w_dict.setitem(w_key, w_obj)
    return 0

@cpython_api([PyObject, CONST_STRING], PyObject, error=CANNOT_FAIL,
             result_borrowed=True)
def PyDict_GetItemString(space, w_dict, key):
    """This is the same as PyDict_GetItem(), but key is specified as a
    char*, rather than a PyObject*."""
    w_key = space.newtext(rffi.charp2str(key))
    if not isinstance(w_dict, W_DictMultiObject):
        return None
    # NOTE: this works so far because all our dict strategies store
    # *values* as full objects, which stay alive as long as the dict is
    # alive and not modified.  So we can return a borrowed ref.
    # XXX this is wrong with IntMutableCell.  Hope it works...
    return w_dict.getitem(w_key)


@cpython_api([PyObject, CONST_STRING], PyObject,
             result_borrowed=True)
def _PyDict_GetItemStringWithError(space, w_dict, key):
    w_key = space.newtext(rffi.charp2str(key))
    if not isinstance(w_dict, W_DictMultiObject):
        PyErr_BadInternalCall(space)
    return w_dict.getitem(w_key)

@cpython_api([PyObject, CONST_STRING], rffi.INT_real, error=-1)
def PyDict_DelItemString(space, w_dict, key_ptr):
    """Remove the entry in dictionary p which has a key specified by the string
    key.  Return 0 on success or -1 on failure."""
    w_key = space.newtext(rffi.charp2str(key_ptr))
    if not isinstance(w_dict, W_DictMultiObject):
        raise PyErr_BadInternalCall(space)
    w_dict.descr_delitem(space, w_key)
    return 0

@cpython_api([PyObject], Py_ssize_t, error=-1)
def PyDict_Size(space, w_obj):
    """
    Return the number of items in the dictionary.  This is equivalent to
    len(p) on a dictionary."""
    return space.len_w(w_obj)

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyDict_Contains(space, w_obj, w_value):
    """Determine if dictionary p contains key.  If an item in p is matches
    key, return 1, otherwise return 0.  On error, return -1.
    This is equivalent to the Python expression key in p.
    """
    w_res = space.contains(w_obj, w_value)
    return space.int_w(w_res)

@cpython_api([PyObject], lltype.Void)
def PyDict_Clear(space, w_obj):
    """Empty an existing dictionary of all key-value pairs."""
    space.call_method(space.w_dict, "clear", w_obj)

@cts.decl("""PyObject *
    PyDict_SetDefault(PyObject *d, PyObject *key, PyObject *defaultobj)""")
def PyDict_SetDefault(space, w_dict, w_key, w_defaultobj):
    if not PyDict_Check(space, w_dict):
        PyErr_BadInternalCall(space)
    else:
        return space.call_method(
            space.w_dict, "setdefault", w_dict, w_key, w_defaultobj)

@cpython_api([PyObject], PyObject)
def PyDict_Copy(space, w_obj):
    """Return a new dictionary that contains the same key-value pairs as p.
    """
    return space.call_method(space.w_dict, "copy", w_obj)

def _has_val(space, w_dict, w_key):
    try:
        w_val = space.getitem(w_dict, w_key)
    except OperationError as e:
        if e.match(space, space.w_KeyError):
            return False
        else:
            raise
    return True

@cpython_api([PyObject, PyObject, rffi.INT_real], rffi.INT_real, error=-1)
def PyDict_Merge(space, w_a, w_b, override):
    """Iterate over mapping object b adding key-value pairs to dictionary a.
    b may be a dictionary, or any object supporting PyMapping_Keys()
    and PyObject_GetItem(). If override is true, existing pairs in a
    will be replaced if a matching key is found in b, otherwise pairs will
    only be added if there is not a matching key in a. Return 0 on
    success or -1 if an exception was raised.
    """
    override = rffi.cast(lltype.Signed, override)
    w_keys = space.call_method(w_b, "keys")
    w_iter = space.iter(w_keys)
    while 1:
        try:
            w_key = space.next(w_iter)
        except OperationError as e:
            if not e.match(space, space.w_StopIteration):
                raise
            break
        if not _has_val(space, w_a, w_key) or override != 0:
            space.setitem(w_a, w_key, space.getitem(w_b, w_key))
    return 0

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1)
def PyDict_Update(space, w_obj, w_other):
    """This is the same as PyDict_Merge(a, b, 1) in C, or a.update(b) in
    Python.  Return 0 on success or -1 if an exception was raised.
    """
    return PyDict_Merge(space, w_obj, w_other, 1)

@cpython_api([PyObject], PyObject)
def PyDict_Keys(space, w_obj):
    """Return a PyListObject containing all the keys from the dictionary,
    as in the dictionary method dict.keys()."""
    return space.call_function(space.w_list, space.call_method(space.w_dict, "keys", w_obj))

@cpython_api([PyObject], PyObject)
def PyDict_Values(space, w_obj):
    """Return a PyListObject containing all the values from the
    dictionary p, as in the dictionary method dict.values()."""
    return space.call_function(space.w_list, space.call_method(space.w_dict, "values", w_obj))

@cpython_api([PyObject], PyObject)
def PyDict_Items(space, w_obj):
    """Return a PyListObject containing all the items from the
    dictionary, as in the dictionary method dict.items()."""
    return space.call_function(space.w_list, space.call_method(space.w_dict, "items", w_obj))

@cpython_api([PyObject, Py_ssize_tP, PyObjectP, PyObjectP], rffi.INT_real, error=CANNOT_FAIL)
def PyDict_Next(space, w_dict, ppos, pkey, pvalue):
    """Iterate over all key-value pairs in the dictionary p.  The
    Py_ssize_t referred to by ppos must be initialized to 0
    prior to the first call to this function to start the iteration; the
    function returns true for each pair in the dictionary, and false once all
    pairs have been reported.  The parameters pkey and pvalue should either
    point to PyObject* variables that will be filled in with each key
    and value, respectively, or may be NULL.  Any references returned through
    them are borrowed.  ppos should not be altered during iteration. Its
    value represents offsets within the internal dictionary structure, and
    since the structure is sparse, the offsets are not consecutive.

    For example:

    PyObject *key, *value;
    Py_ssize_t pos = 0;

    while (PyDict_Next(self->dict, &pos, &key, &value)) {
        /* do something interesting with the values... */
        ...
    }

    The dictionary p should not be mutated during iteration.  It is safe
    (since Python 2.1) to modify the values but not the keys as you iterate
    over the dictionary, the keys must not change.
    For example:

    PyObject *key, *value;
    Py_ssize_t pos = 0;

    while (PyDict_Next(self->dict, &pos, &key, &value)) {
        int i = PyLong_AS_LONG(value) + 1;
        PyObject *o = PyLong_FromLong(i);
        if (o == NULL)
            return -1;
        if (PyDict_SetItem(self->dict, key, o) < 0) {
            Py_DECREF(o);
            return -1;
        }
        Py_DECREF(o);
    }"""

    if w_dict is None:
        return 0
    if not space.isinstance_w(w_dict, space.w_dict):
        return 0
    pos = ppos[0]
    py_obj = as_pyobj(space, w_dict)
    py_dict = rffi.cast(PyDictObject, py_obj)
    if pos == 0:
        # Store the current keys in the PyDictObject.
        w_keyview = space.call_method(space.w_dict, "keys", w_dict)
        # w_keys must use the object strategy in order to keep the keys alive
        w_keys = space.newlist(space.listview(w_keyview))
        w_keys.switch_to_object_strategy()
        oldkeys = py_dict.c__tmpkeys
        py_dict.c__tmpkeys = create_ref(space, w_keys)
        incref(space, py_dict.c__tmpkeys)
        decref(space, oldkeys)
    else:
        if not py_dict.c__tmpkeys:
            # pos should have been 0, cannot fail so return 0
            return 0;
        w_keys = from_ref(space, py_dict.c__tmpkeys)
    ppos[0] += 1
    if pos >= space.len_w(w_keys):
        decref(space, py_dict.c__tmpkeys)
        py_dict.c__tmpkeys = lltype.nullptr(PyObject.TO)
        return 0
    w_key = space.listview(w_keys)[pos]  # fast iff w_keys uses object strat
    w_value = space.getitem(w_dict, w_key)
    if pkey:
        pkey[0] = as_pyobj(space, w_key)
    if pvalue:
        pvalue[0] = as_pyobj(space, w_value)
    return 1

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def _PyDict_HasOnlyStringKeys(space, w_dict):
    keys_w = space.unpackiterable(w_dict)
    for w_key in keys_w:
        if not space.isinstance_w(w_key, space.w_unicode):
            return 0
    return 1

#def PyObject_GenericGetDict(space, w_obj, context):
#    unlike CPython, you'll find this one in object.py together with ..SetDict
