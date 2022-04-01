import sys

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.baseobjspace import W_Root, SpaceCache
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.extregistry import ExtRegistryEntry
from pypy.module.cpyext.api import (
    cpython_api, bootstrap_function, PyObject, PyObjectP, ADDR,
    CANNOT_FAIL, Py_TPFLAGS_HEAPTYPE, PyTypeObjectPtr, is_PyObject,
    PyVarObject, Py_ssize_t, init_function, cts)
from pypy.module.cpyext.state import State
from pypy.objspace.std.typeobject import W_TypeObject
from pypy.objspace.std.noneobject import W_NoneObject
from pypy.objspace.std.boolobject import W_BoolObject
from pypy.objspace.std.objectobject import W_ObjectObject
from rpython.rlib.objectmodel import specialize, we_are_translated
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rtyper.annlowlevel import llhelper, cast_instance_to_base_ptr
from rpython.rlib import rawrefcount, jit
from rpython.rlib.debug import ll_assert, fatalerror


#________________________________________________________
# type description

class W_BaseCPyObject(W_ObjectObject):
    """ A subclass of W_ObjectObject that has one field for directly storing
    the link from the w_obj to the cpy ref. This is only used for C-defined
    types. """


def check_true(s_arg, bookeeper):
    assert s_arg.const is True

def w_root_as_pyobj(w_obj, space):
    from rpython.rlib.debug import check_annotation
    # make sure that translation crashes if we see this while translating
    # without cpyext
    check_annotation(space.config.objspace.usemodules.cpyext, check_true)
    # default implementation of _cpyext_as_pyobj
    return rawrefcount.from_obj(PyObject, w_obj)

def w_root_attach_pyobj(w_obj, space, py_obj):
    from rpython.rlib.debug import check_annotation
    check_annotation(space.config.objspace.usemodules.cpyext, check_true)
    assert space.config.objspace.usemodules.cpyext
    # default implementation of _cpyext_attach_pyobj
    rawrefcount.create_link_pypy(w_obj, py_obj)


def add_direct_pyobj_storage(cls):
    """ Add the necessary methods to a class to store a reference to the py_obj
    on its instances directly. """

    cls._cpy_ref = lltype.nullptr(PyObject.TO)

    def _cpyext_as_pyobj(self, space):
        return self._cpy_ref
    cls._cpyext_as_pyobj = _cpyext_as_pyobj

    def _cpyext_attach_pyobj(self, space, py_obj):
        self._cpy_ref = py_obj
        rawrefcount.create_link_pypy(self, py_obj)
    cls._cpyext_attach_pyobj = _cpyext_attach_pyobj

add_direct_pyobj_storage(W_BaseCPyObject) 
add_direct_pyobj_storage(W_TypeObject)
add_direct_pyobj_storage(W_NoneObject)
add_direct_pyobj_storage(W_BoolObject)


class BaseCpyTypedescr(object):
    basestruct = PyObject.TO
    W_BaseObject = W_ObjectObject

    def get_dealloc(self, space):
        state = space.fromcache(State)
        return state.C._PyPy_subtype_dealloc

    # CCC port to C
    def allocate(self, space, w_type, itemcount=0, immortal=False):
        # typically called from PyType_GenericAlloc via typedescr.allocate
        # this returns a PyObject with ob_refcnt == 1.

        pytype = as_pyobj(space, w_type)
        pytype = rffi.cast(PyTypeObjectPtr, pytype)
        assert pytype
        # Don't increase refcount for non-heaptypes
        flags = rffi.cast(lltype.Signed, pytype.c_tp_flags)
        if flags & Py_TPFLAGS_HEAPTYPE:
            incref(space, pytype)

        if pytype:
            size = pytype.c_tp_basicsize
        else:
            size = rffi.sizeof(self.basestruct)
        if pytype.c_tp_itemsize:
            size += itemcount * pytype.c_tp_itemsize
        assert size >= rffi.sizeof(PyObject.TO)
        buf = lltype.malloc(rffi.VOIDP.TO, size,
                            flavor='raw', zero=True,
                            add_memory_pressure=True, immortal=immortal)
        pyobj = rffi.cast(PyObject, buf)
        if pytype.c_tp_itemsize:
            pyvarobj = rffi.cast(PyVarObject, pyobj)
            pyvarobj.c_ob_size = itemcount
        pyobj.c_ob_refcnt = 1
        #pyobj.c_ob_pypy_link should get assigned very quickly
        pyobj.c_ob_type = pytype
        return pyobj

    def attach(self, space, pyobj, w_obj, w_userdata=None):
        pass

    def realize(self, space, obj):
        w_type = from_ref(space, rffi.cast(PyObject, obj.c_ob_type))
        assert isinstance(w_type, W_TypeObject)
        try:
            if w_type.flag_cpytype:
                w_obj = space.allocate_instance(W_BaseCPyObject, w_type)
            else:
                w_obj = space.allocate_instance(self.W_BaseObject, w_type)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                raise oefmt(space.w_SystemError,
                            "cpyext: don't know how to make a '%N' object "
                            "from a PyObject",
                            w_type)
            raise
        track_reference(space, obj, w_obj)
        return w_obj

typedescr_cache = {}

def make_typedescr(typedef, **kw):
    """NOT_RPYTHON

    basestruct: The basic structure to allocate
    alloc     : allocate and basic initialization of a raw PyObject
    attach    : Function called to tie a raw structure to a pypy object
    realize   : Function called to create a pypy object from a raw struct
    dealloc   : a @slot_function(), similar to PyObject_dealloc
    """

    tp_basestruct = kw.pop('basestruct', PyObject.TO)
    tp_alloc      = kw.pop('alloc', None)
    tp_attach     = kw.pop('attach', None)
    tp_realize    = kw.pop('realize', None)
    tp_dealloc    = kw.pop('dealloc', None)
    assert not kw, "Extra arguments to make_typedescr"

    null_dealloc = lltype.nullptr(lltype.FuncType([PyObject], lltype.Void))
    assert not isinstance(tp_basestruct, lltype.Ptr), "should pass .TO"

    class CpyTypedescr(BaseCpyTypedescr):
        basestruct = tp_basestruct

        if tp_alloc:
            def allocate(self, space, w_type, itemcount=0, immortal=False):
                return tp_alloc(self, space, w_type, itemcount)

        if hasattr(tp_dealloc, 'api_func'):
            def get_dealloc(self, space):
                return tp_dealloc.api_func.get_llhelper(space)
        elif tp_dealloc:
            def get_dealloc(self, space):
                return tp_dealloc

        if tp_attach:
            def attach(self, space, pyobj, w_obj, w_userdata=None):
                tp_attach(space, pyobj, w_obj, w_userdata)

        if tp_realize:
            def realize(self, space, ref):
                return tp_realize(space, ref)
    if typedef:
        CpyTypedescr.__name__ = "CpyTypedescr_%s" % (typedef.name,)

    typedescr_cache[typedef] = CpyTypedescr()

@bootstrap_function
def init_pyobject(space):
    # typedescr for the 'object' type
    state = space.fromcache(State)
    make_typedescr(space.w_object.layout.typedef,
                   dealloc=state.C._PyPy_object_dealloc)
    # almost all types, which should better inherit from object.
    make_typedescr(None)

@specialize.memo()
def _get_typedescr_1(typedef):
    try:
        return typedescr_cache[typedef]
    except KeyError:
        if typedef.bases:
            return _get_typedescr_1(typedef.bases[0])
        return typedescr_cache[None]

def get_typedescr(typedef):
    if typedef is None:
        return typedescr_cache[None]
    else:
        return _get_typedescr_1(typedef)

#________________________________________________________
# refcounted object support

class InvalidPointerException(Exception):
    pass

@jit.dont_look_inside
def create_ref(space, w_obj, w_userdata=None, immortal=False):
    """
    Allocates a PyObject, and fills its fields with info from the given
    interpreter object.
    """
    w_type = space.type(w_obj)
    pytype = rffi.cast(PyTypeObjectPtr, as_pyobj(space, w_type))
    typedescr = get_typedescr(w_obj.typedef)
    if pytype.c_tp_itemsize != 0:
        # PyBytesObject, PyUnicode object, and subclasses
        itemcount = space.len_w(w_obj)
    else:
        itemcount = 0
    py_obj = typedescr.allocate(space, w_type, itemcount=itemcount, immortal=immortal)
    track_reference(space, py_obj, w_obj)
    #
    # py_obj.c_ob_refcnt should be exactly REFCNT_FROM_PYPY + 1 here,
    # and we want only REFCNT_FROM_PYPY, i.e. only count as attached
    # to the W_Root but not with any reference from the py_obj side.
    assert py_obj.c_ob_refcnt > rawrefcount.REFCNT_FROM_PYPY
    py_obj.c_ob_refcnt -= 1
    #
    typedescr.attach(space, py_obj, w_obj, w_userdata)
    return py_obj

def track_reference(space, py_obj, w_obj):
    """
    Ties together a PyObject and an interpreter object.
    The PyObject's refcnt is increased by REFCNT_FROM_PYPY.
    The reference in 'py_obj' is not stolen!  Remember to decref()
    it if you need to.
    """
    # XXX looks like a PyObject_GC_TRACK
    assert py_obj.c_ob_refcnt < rawrefcount.REFCNT_FROM_PYPY
    py_obj.c_ob_refcnt += rawrefcount.REFCNT_FROM_PYPY
    w_obj._cpyext_attach_pyobj(space, py_obj)


w_marker_deallocating = W_Root()

@jit.dont_look_inside
def from_ref(space, ref):
    """
    Finds the interpreter object corresponding to the given reference.  If the
    object is not yet realized (see bytesobject.py), creates it.
    """
    assert is_pyobj(ref)
    if not ref:
        return None
    w_obj = rawrefcount.to_obj(W_Root, rffi.cast(PyObject, ref))
    if w_obj is not None:
        if w_obj is not w_marker_deallocating:
            return w_obj
        type_name = rffi.charp2str(cts.cast('char*', ref.c_ob_type.c_tp_name))
        fatalerror(
            "*** Invalid usage of a dying CPython object ***\n"
            "\n"
            "cpyext, the emulation layer, detected that while it is calling\n"
            "an object's tp_dealloc, the C code calls back a function that\n"
            "tries to recreate the PyPy version of the object.  Usually it\n"
            "means that tp_dealloc calls some general PyXxx() API.  It is\n"
            "a dangerous and potentially buggy thing to do: even in CPython\n"
            "the PyXxx() function could, in theory, cause a reference to the\n"
            "object to be taken and stored somewhere, for an amount of time\n"
            "exceeding tp_dealloc itself.  Afterwards, the object will be\n"
            "freed, making that reference point to garbage.\n"
            ">>> PyPy could contain some workaround to still work if\n"
            "you are lucky, but it is not done so far; better fix the bug in\n"
            "the CPython extension.\n"
            ">>> This object is of type '%s'" % (type_name,))

    # This reference is not yet a real interpreter object.
    # Realize it.
    ref_type = rffi.cast(PyObject, ref.c_ob_type)
    if ref_type == ref: # recursion!
        raise InvalidPointerException(str(ref))
    w_type = from_ref(space, ref_type)
    assert isinstance(w_type, W_TypeObject)
    return get_typedescr(w_type.layout.typedef).realize(space, ref)

@jit.dont_look_inside
def as_pyobj(space, w_obj, w_userdata=None, immortal=False):
    """
    Returns a 'PyObject *' representing the given interpreter object.
    This doesn't give a new reference, but the returned 'PyObject *'
    is valid at least as long as 'w_obj' is.  **To be safe, you should
    use keepalive_until_here(w_obj) some time later.**  In case of
    doubt, use the safer make_ref().
    """
    assert not is_pyobj(w_obj)
    if w_obj is not None:
        py_obj = w_obj._cpyext_as_pyobj(space)
        if not py_obj:
            py_obj = create_ref(space, w_obj, w_userdata, immortal=immortal)
        #
        # Try to crash here, instead of randomly, if we don't keep w_obj alive
        ll_assert(py_obj.c_ob_refcnt >= rawrefcount.REFCNT_FROM_PYPY,
                  "Bug in cpyext: The W_Root object was garbage-collected "
                  "while being converted to PyObject.")
        return py_obj
    else:
        return lltype.nullptr(PyObject.TO)
as_pyobj._always_inline_ = 'try'

def pyobj_has_w_obj(pyobj):
    w_obj = rawrefcount.to_obj(W_Root, pyobj)
    return w_obj is not None and w_obj is not w_marker_deallocating

def w_obj_has_pyobj(w_obj):
    return bool(rawrefcount.from_obj(PyObject, w_obj))

def is_pyobj(x):
    if x is None or isinstance(x, W_Root):
        return False
    elif is_PyObject(lltype.typeOf(x)):
        return True
    else:
        raise TypeError(repr(type(x)))

class Entry(ExtRegistryEntry):
    _about_ = is_pyobj
    def compute_result_annotation(self, s_x):
        from rpython.rtyper.llannotation import SomePtr
        return self.bookkeeper.immutablevalue(isinstance(s_x, SomePtr))
    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Bool, hop.s_result.const)

def get_pyobj_and_incref(space, w_obj, w_userdata=None, immortal=False):
    pyobj = as_pyobj(space, w_obj, w_userdata, immortal=immortal)
    if pyobj:  # != NULL
        assert pyobj.c_ob_refcnt >= rawrefcount.REFCNT_FROM_PYPY
        pyobj.c_ob_refcnt += 1
        keepalive_until_here(w_obj)
    return pyobj

def hack_for_result_often_existing_obj(space, w_obj):
    # Equivalent to get_pyobj_and_incref() and not to make_ref():
    # it builds a PyObject from a W_Root, but ensures that the result
    # gets attached to the original W_Root.  This is needed to work around
    # some obscure abuses: https://github.com/numpy/numpy/issues/9850
    return get_pyobj_and_incref(space, w_obj)

def make_ref(space, w_obj, w_userdata=None, immortal=False):
    """Turn the W_Root into a corresponding PyObject.  You should
    decref the returned PyObject later.  Note that it is often the
    case, but not guaranteed, that make_ref() returns always the
    same PyObject for the same W_Root; for example, integers.
    """
    assert not is_pyobj(w_obj)
    if False and w_obj is not None and space.type(w_obj) is space.w_int:
        # XXX: adapt for pypy3
        state = space.fromcache(State)
        intval = space.int_w(w_obj)
        return state.ccall("PyInt_FromLong", intval)
    return get_pyobj_and_incref(space, w_obj, w_userdata, immortal=False)

@specialize.ll()
def get_w_obj_and_decref(space, pyobj):
    """Decrement the reference counter of the PyObject and return the
    corresponding W_Root object (so the reference count after the decref
    is at least REFCNT_FROM_PYPY and cannot be zero).
    """
    assert is_pyobj(pyobj)
    pyobj = rffi.cast(PyObject, pyobj)
    w_obj = from_ref(space, pyobj)
    if pyobj:
        pyobj.c_ob_refcnt -= 1
        assert pyobj.c_ob_refcnt >= rawrefcount.REFCNT_FROM_PYPY
        keepalive_until_here(w_obj)
    return w_obj


@specialize.ll()
def incref(space, pyobj):
    assert is_pyobj(pyobj)
    pyobj = rffi.cast(PyObject, pyobj)
    assert pyobj.c_ob_refcnt >= 1
    pyobj.c_ob_refcnt += 1

@specialize.ll()
def decref(space, pyobj):
    from pypy.module.cpyext.api import generic_cpy_call
    assert is_pyobj(pyobj)
    pyobj = rffi.cast(PyObject, pyobj)
    if pyobj:
        assert pyobj.c_ob_refcnt > 0
        assert (pyobj.c_ob_pypy_link == 0 or
                pyobj.c_ob_refcnt > rawrefcount.REFCNT_FROM_PYPY)
        pyobj.c_ob_refcnt -= 1
        if pyobj.c_ob_refcnt == 0:
            state = space.fromcache(State)
            generic_cpy_call(space, state.C._Py_Dealloc, pyobj)
        #else:
        #    w_obj = rawrefcount.to_obj(W_Root, ref)
        #    if w_obj is not None:
        #        assert pyobj.c_ob_refcnt >= rawrefcount.REFCNT_FROM_PYPY


@init_function
def write_w_marker_deallocating(space):
    if we_are_translated():
        llptr = cast_instance_to_base_ptr(w_marker_deallocating)
        state = space.fromcache(State)
        state.C.set_marker(llptr)

@cpython_api([rffi.VOIDP], lltype.Signed, error=CANNOT_FAIL)
def _Py_HashPointer(space, ptr):
    return rffi.cast(lltype.Signed, ptr)

@cpython_api([PyObject], lltype.Void)
def Py_IncRef(space, obj):
    # used only ifdef PYPY_DEBUG_REFCOUNT
    if obj:
        incref(space, obj)

@cpython_api([PyObject], lltype.Void)
def Py_DecRef(space, obj):
    # used only ifdef PYPY_DEBUG_REFCOUNT
    decref(space, obj)
