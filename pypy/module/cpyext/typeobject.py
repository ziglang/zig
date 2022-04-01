from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib import jit, rawrefcount
from rpython.rlib.objectmodel import specialize, we_are_translated
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import widen

from pypy.interpreter.baseobjspace import DescrMismatch
from pypy.interpreter.error import oefmt
from pypy.interpreter.typedef import (
    GetSetProperty, TypeDef, interp_attrproperty, interp2app)
from pypy.module.__builtin__.abstractinst import abstract_issubclass_w
from pypy.module.cpyext import structmemberdefs
from pypy.module.cpyext.api import (
    cpython_api, cpython_struct, bootstrap_function, Py_ssize_t,
    slot_function, generic_cpy_call, METH_VARARGS, METH_KEYWORDS, CANNOT_FAIL,
    build_type_checkers_flags, cts, parse_dir, PyTypeObject,
    PyTypeObjectPtr, Py_buffer,
    Py_TPFLAGS_HEAPTYPE, Py_TPFLAGS_READY, Py_TPFLAGS_READYING,
    Py_TPFLAGS_LONG_SUBCLASS, Py_TPFLAGS_LIST_SUBCLASS,
    Py_TPFLAGS_TUPLE_SUBCLASS, Py_TPFLAGS_UNICODE_SUBCLASS,
    Py_TPFLAGS_DICT_SUBCLASS, Py_TPFLAGS_BASE_EXC_SUBCLASS,
    Py_TPFLAGS_TYPE_SUBCLASS,
    Py_TPFLAGS_BYTES_SUBCLASS,
    Py_TPPYPYFLAGS_FLOAT_SUBCLASS,
    )

from rpython.tool.cparser import CTypeSpace
from pypy.module.cpyext.methodobject import (W_PyCClassMethodObject,
    PyCFunction, PyMethodDef,
    W_PyCMethodObject, W_PyCFunctionObject, extract_doc, extract_txtsig,
    W_PyCWrapperObject)
from pypy.module.cpyext.modsupport import convert_method_defs
from pypy.module.cpyext.pyobject import (
    PyObject, make_ref, from_ref, get_typedescr, make_typedescr,
    track_reference, decref, as_pyobj, incref)
from pypy.module.cpyext.slotdefs import (
    slotdefs_for_tp_slots, slotdefs_for_wrappers, get_slot_tp_function,
    llslot)
from pypy.module.cpyext.state import State
from pypy.module.cpyext.structmember import PyMember_GetOne, PyMember_SetOne
from pypy.module.cpyext.typeobjectdefs import (
    PyGetSetDef, PyMemberDef, PyMappingMethods,
    PyNumberMethods, PySequenceMethods, PyBufferProcs)
from pypy.objspace.std.typeobject import W_TypeObject, find_best_base


#WARN_ABOUT_MISSING_SLOT_FUNCTIONS = False

PyType_Check, PyType_CheckExact = build_type_checkers_flags("Type")

PyHeapTypeObject = cts.gettype('PyHeapTypeObject *')

cts.parse_header(parse_dir / "typeslots.h")


class W_GetSetPropertyEx(GetSetProperty):
    def __init__(self, getset, w_type):
        self.getset = getset
        self.w_type = w_type
        doc = fset = fget = fdel = None
        if doc:
            # XXX dead code?
            doc = rffi.constcharp2str(getset.c_doc)
        if getset.c_get:
            fget = GettersAndSetters.getter.im_func
        if getset.c_set:
            fset = GettersAndSetters.setter.im_func
            fdel = GettersAndSetters.deleter.im_func
        GetSetProperty.__init__(self, fget, fset, fdel, doc,
                                cls=None, use_closure=True,
                                tag="cpyext_1")
        self.name = rffi.constcharp2str(getset.c_name)

    def readonly_attribute(self, space):   # overwritten
        raise oefmt(space.w_AttributeError,
            "attribute '%s' of '%N' objects is not writable",
            self.name, self.w_type)


@cpython_api([PyTypeObjectPtr, lltype.Ptr(PyGetSetDef)], PyObject, result_is_ll=True)
def PyDescr_NewGetSet(space, w_type, getset):
    # Note the arguments are reversed
    w_descr = W_GetSetPropertyEx(getset, w_type)
    return make_ref(space, w_descr, w_type)

def make_GetSet(space, getsetprop):
    py_getsetdef = lltype.malloc(PyGetSetDef, flavor='raw')
    doc = getsetprop.doc
    if doc:
        py_getsetdef.c_doc = rffi.cast(rffi.CONST_CCHARP, rffi.str2charp(doc))
    else:
        py_getsetdef.c_doc = rffi.cast(rffi.CONST_CCHARP, 0)
    py_getsetdef.c_name = rffi.cast(rffi.CONST_CCHARP,
                                    rffi.str2charp(getsetprop.getname(space)))
    # XXX FIXME - actually assign these !!!
    py_getsetdef.c_get = cts.cast('getter', 0)
    py_getsetdef.c_set = cts.cast('setter', 0)
    py_getsetdef.c_closure = cts.cast('void*', 0)
    return py_getsetdef


class W_MemberDescr(GetSetProperty):
    name = 'member_descriptor'
    def __init__(self, member, w_type):
        self.member = member
        self.name = rffi.constcharp2str(member.c_name)
        self.w_type = w_type
        flags = rffi.cast(lltype.Signed, member.c_flags)
        doc = set = None
        if member.c_doc:
            doc = rffi.constcharp2str(member.c_doc)
        get = GettersAndSetters.member_getter.im_func
        del_ = GettersAndSetters.member_delete.im_func
        if not (flags & structmemberdefs.READONLY):
            set = GettersAndSetters.member_setter.im_func
        GetSetProperty.__init__(self, get, set, del_, doc,
                                cls=None, use_closure=True,
                                tag="cpyext_2")

# change the typedef name
W_MemberDescr.typedef = TypeDef(
    "member_descriptor",
    __get__ = interp2app(GetSetProperty.descr_property_get),
    __set__ = interp2app(GetSetProperty.descr_property_set),
    __delete__ = interp2app(GetSetProperty.descr_property_del),
    __name__ = interp_attrproperty('name', cls=GetSetProperty,
        wrapfn="newtext_or_none"),
    __objclass__ = GetSetProperty(GetSetProperty.descr_get_objclass),
    __doc__ = interp_attrproperty('doc', cls=GetSetProperty,
        wrapfn="newtext_or_none"),
    )
assert not W_MemberDescr.typedef.acceptable_as_base_class  # no __new__

@bootstrap_function
def init_memberdescrobject(space):
    make_typedescr(W_MemberDescr.typedef,
                   basestruct=cts.gettype('PyMemberDescrObject'),
                   attach=memberdescr_attach,
                   realize=memberdescr_realize,
                   dealloc=descr_dealloc,
                   )
    make_typedescr(W_GetSetPropertyEx.typedef,
                   basestruct=cts.gettype('PyGetSetDescrObject'),
                   attach=getsetdescr_attach,
                   dealloc=descr_dealloc,
                   )
    make_typedescr(W_PyCClassMethodObject.typedef,
                   basestruct=cts.gettype('PyMethodDescrObject'),
                   attach=methoddescr_attach,
                   realize=classmethoddescr_realize,
                   dealloc=descr_dealloc,
                   )
    make_typedescr(W_PyCMethodObject.typedef,
                   basestruct=cts.gettype('PyMethodDescrObject'),
                   attach=methoddescr_attach,
                   realize=methoddescr_realize,
                   dealloc=descr_dealloc,
                   )
    make_typedescr(W_PyCWrapperObject.typedef,
                   basestruct=cts.gettype('PyWrapperDescrObject'),
                   attach=wrapperdescr_attach,
                   realize=wrapperdescr_realize,
                   dealloc=wrapper_dealloc,
                   )

def init_descr(space, py_obj, w_type, name):
    """Initialises the common fields in a PyDescrObject

    Arguments:
        py_obj: PyObject* pointer to a PyDescrObject
        w_type: W_TypeObject
        c_name: char*
    """
    py_descr = cts.cast('PyDescrObject*', py_obj)
    py_descr.c_d_type = cts.cast(
        'PyTypeObject*', make_ref(space, w_type))
    py_descr.c_d_name = make_ref(space, space.newtext(name))

@slot_function([PyObject], lltype.Void)
def descr_dealloc(space, py_obj):
    from pypy.module.cpyext.object import _dealloc
    py_descr = cts.cast('PyDescrObject*', py_obj)
    decref(space, py_descr.c_d_type)
    decref(space, py_descr.c_d_name)
    _dealloc(space, py_obj)

def memberdescr_attach(space, py_obj, w_obj, w_userdata=None):
    """
    Fills a newly allocated PyMemberDescrObject with the given W_MemberDescr
    object. The values must not be modified.
    """
    py_memberdescr = cts.cast('PyMemberDescrObject*', py_obj)
    assert isinstance(w_obj, W_MemberDescr)
    py_memberdescr.c_d_member = w_obj.member
    init_descr(space, py_obj, w_obj.w_type, w_obj.name)

def memberdescr_realize(space, obj):
    # XXX NOT TESTED When is this ever called?
    member = cts.cast('PyMemberDef*', obj)
    w_type = from_ref(space, rffi.cast(PyObject, obj.c_ob_type))
    w_obj = space.allocate_instance(W_MemberDescr, w_type)
    w_obj.__init__(member, w_type)
    track_reference(space, obj, w_obj)
    return w_obj

def getsetdescr_attach(space, py_obj, w_obj, w_userdata=None):
    """
    Fills a newly allocated PyGetSetDescrObject with the given W_GetSetPropertyEx
    object. The values must not be modified.
    """
    py_getsetdescr = cts.cast('PyGetSetDescrObject*', py_obj)
    if isinstance(w_obj, GetSetProperty):
        py_getsetdef = make_GetSet(space, w_obj)
        assert space.isinstance_w(w_userdata, space.w_type)
        w_obj = W_GetSetPropertyEx(py_getsetdef, w_userdata)
        # now w_obj.getset is py_getsetdef, which was freshly allocated
        # XXX how is this ever released?
    assert isinstance(w_obj, W_GetSetPropertyEx)
    py_getsetdescr.c_d_getset = w_obj.getset
    init_descr(space, py_obj, w_obj.w_type, w_obj.name)

def methoddescr_attach(space, py_obj, w_obj, w_userdata=None):
    py_methoddescr = cts.cast('PyMethodDescrObject*', py_obj)
    assert isinstance(w_obj, W_PyCFunctionObject)
    py_methoddescr.c_d_method = w_obj.ml
    init_descr(space, py_obj, w_obj.w_objclass, w_obj.name)

def classmethoddescr_realize(space, obj):
    # XXX NOT TESTED When is this ever called?
    method = rffi.cast(lltype.Ptr(PyMethodDef), obj)
    w_type = from_ref(space, rffi.cast(PyObject, obj.c_ob_type))
    w_obj = space.allocate_instance(W_PyCClassMethodObject, w_type)
    w_obj.__init__(space, method, w_type)
    track_reference(space, obj, w_obj)
    return w_obj

def methoddescr_realize(space, obj):
    # XXX NOT TESTED When is this ever called?
    method = rffi.cast(lltype.Ptr(PyMethodDef), obj)
    w_type = from_ref(space, rffi.cast(PyObject, obj.c_ob_type))
    w_obj = space.allocate_instance(W_PyCMethodObject, w_type)
    w_obj.__init__(space, method, None, None, w_type)
    track_reference(space, obj, w_obj)
    return w_obj

def wrapperdescr_attach(space, py_obj, w_obj, w_userdata=None): 
    assert isinstance(w_obj, W_PyCWrapperObject)
    py_methoddescr = cts.cast('PyWrapperDescrObject*', py_obj)
    init_descr(space, py_obj, w_obj.w_objclass, w_obj.getname(space))
    py_methoddescr.c_d_wrapped = w_obj.get_func_to_call()
    # CPython starts from the d_base, since this is the basic structure
    # filled in by the slotdef macros in Objects/typeobject.c
    # We only need it for compatibility, so we leave it all 0.
    # see the way wrapperbase is modified in test/specmethdocstring.c,
    # which adds a docstring to the slot function via d_base.doc
    py_methoddescr.c_d_base = lltype.malloc(cts.gettype('struct wrapperbase'),
                                zero=True, flavor='raw', track_allocation=False)

def wrapperdescr_realize(space, obj):
    raise oefmt(space.w_RuntimeError,
        "cannot yet create a Python wrapper_descriptor from a C "
        "PyWrapperDescrObject. Please report this to PyPy")

@slot_function([PyObject], lltype.Void)
def wrapper_dealloc(space, py_obj):
    from pypy.module.cpyext.object import _dealloc
    py_descr = cts.cast('PyDescrObject*', py_obj)
    if py_descr:
        decref(space, py_descr.c_d_type)
        decref(space, py_descr.c_d_name)
        py_wrapperdescr = cts.cast('PyWrapperDescrObject*', py_obj)
        if py_wrapperdescr.c_d_base:
            lltype.free(py_wrapperdescr.c_d_base, flavor="raw", track_allocation=False)
            py_wrapperdescr.c_d_base = rffi.cast(cts.gettype('struct wrapperbase*'), 0)
    _dealloc(space, py_obj)

def convert_getset_defs(space, dict_w, getsets, w_type):
    getsets = rffi.cast(rffi.CArrayPtr(PyGetSetDef), getsets)
    if getsets:
        i = -1
        while True:
            i = i + 1
            getset = getsets[i]
            name = getset.c_name
            if not name:
                break
            name = rffi.constcharp2str(name)
            w_descr = W_GetSetPropertyEx(getset, w_type)
            dict_w[name] = w_descr

def convert_member_defs(space, dict_w, members, w_type):
    members = rffi.cast(rffi.CArrayPtr(PyMemberDef), members)
    if members:
        i = 0
        while True:
            member = members[i]
            name = member.c_name
            if not name:
                break
            name = rffi.constcharp2str(name)
            w_descr = W_MemberDescr(member, w_type)
            dict_w[name] = w_descr
            i += 1

WARN_MISSING_SLOTS = False
missing_slots={}
def warn_missing_slot(space, method_name, slot_name, w_type):
    if WARN_MISSING_SLOTS and not we_are_translated():
        if slot_name not in missing_slots:
            missing_slots[slot_name] = w_type.getname(space)
            print "missing slot %r/%r, discovered on %r" % (
                method_name, slot_name, w_type.getname(space))

def update_all_slots(space, w_type, pto):
    # fill slots in pto
    for method_name, slot_name, slot_names, slot_apifunc in slotdefs_for_tp_slots:
        slot_func_helper = None
        w_descr = w_type.dict_w.get(method_name, None)
        if w_descr:
            # use the slot_apifunc (userslots) to lookup at runtime
            pass
        elif len(slot_names) ==1:
            # 'inherit' from tp_base
            slot_func_helper = getattr(pto.c_tp_base, slot_names[0])
        else:
            struct = getattr(pto.c_tp_base, slot_names[0])
            if struct:
                slot_func_helper = getattr(struct, slot_names[1])

        if not slot_func_helper:
            if not slot_apifunc:
                warn_missing_slot(space, method_name, slot_name, w_type)
                continue
            slot_func_helper = slot_apifunc.get_llhelper(space)
        fill_slot(space, pto, w_type, slot_names, slot_func_helper)

def update_all_slots_builtin(space, w_type, pto):
    typedef = w_type.layout.typedef
    for method_name, slot_name, slot_names, slot_apifunc in slotdefs_for_tp_slots:
        slot_apifunc = get_slot_tp_function(space, typedef, slot_name, method_name)
        if not slot_apifunc:
            warn_missing_slot(space, method_name, slot_name, w_type)
            continue
        slot_llfunc = slot_apifunc.get_llhelper(space)
        fill_slot(space, pto, w_type, slot_names, slot_llfunc)

@specialize.arg(3)
def fill_slot(space, pto, w_type, slot_names, slot_func_helper):
    # XXX special case wrapper-functions and use a "specific" slot func
    if len(slot_names) == 1:
        setattr(pto, slot_names[0], slot_func_helper)
    elif ((w_type is space.w_list or w_type is space.w_tuple) and
            slot_names[0] == 'c_tp_as_number'):
        # XXX hack - how can we generalize this? The problem is method
        # names like __mul__ map to more than one slot, and we have no
        # convenient way to indicate which slots CPython have filled
        #
        # We need at least this special case since Numpy checks that
        # (list, tuple) do __not__ fill tp_as_number
        pass
    elif ((space.issubtype_w(w_type, space.w_bytes) or
            space.issubtype_w(w_type, space.w_unicode)) and
            slot_names[0] == 'c_tp_as_number'):
        # like above but for any str type
        pass
    else:
        assert len(slot_names) == 2
        struct = getattr(pto, slot_names[0])
        if not struct:
            #assert not space.config.translating
            assert not widen(pto.c_tp_flags) & Py_TPFLAGS_HEAPTYPE
            if slot_names[0] == 'c_tp_as_number':
                STRUCT_TYPE = PyNumberMethods
            elif slot_names[0] == 'c_tp_as_sequence':
                STRUCT_TYPE = PySequenceMethods
            elif slot_names[0] == 'c_tp_as_buffer':
                STRUCT_TYPE = PyBufferProcs
            elif slot_names[0] == 'c_tp_as_mapping':
                STRUCT_TYPE = PyMappingMethods
            else:
                raise AssertionError(
                    "Structure not allocated: %s" % (slot_names[0],))
            struct = lltype.malloc(STRUCT_TYPE, flavor='raw', zero=True)
            setattr(pto, slot_names[0], struct)

        setattr(struct, slot_names[1], slot_func_helper)

def add_operators(space, w_type, dict_w, pto, name):
    from pypy.module.cpyext.object import PyObject_HashNotImplemented
    hash_not_impl = llslot(space, PyObject_HashNotImplemented)
    for method_name, slot_names, wrapper_class, doc in slotdefs_for_wrappers:
        if method_name in dict_w:
            continue
        if len(slot_names) == 1:
            func = getattr(pto, slot_names[0])
            if slot_names[0] == 'c_tp_hash':
                # two special cases where __hash__ is explicitly set to None
                # (which leads to an unhashable type):
                # 1) tp_hash == PyObject_HashNotImplemented
                # 2) tp_hash == NULL and tp_richcompare not NULL
                if hash_not_impl == func or (
                        not func and pto.c_tp_richcompare):
                    dict_w[method_name] = space.w_None
                    continue
        else:
            assert len(slot_names) == 2
            struct = getattr(pto, slot_names[0])
            if not struct:
                continue
            func = getattr(struct, slot_names[1])
        func_voidp = rffi.cast(rffi.VOIDP, func)
        if not func:
            continue
        if wrapper_class is None:
            continue

        assert issubclass(wrapper_class, W_PyCWrapperObject)

        w_obj = wrapper_class(space, w_type, method_name, doc, func_voidp)
        dict_w[method_name] = w_obj
    if pto.c_tp_doc:
        raw_doc = rffi.constcharp2str(pto.c_tp_doc)
        dict_w['__doc__'] = space.newtext_or_none(extract_doc(raw_doc, name))
    if pto.c_tp_new:
        add_tp_new_wrapper(space, dict_w, pto)

@slot_function([PyObject, PyObject, PyObject], PyObject)
def tp_new_wrapper(space, self, w_args, w_kwds):
    self_pytype = rffi.cast(PyTypeObjectPtr, self)
    tp_new = self_pytype.c_tp_new

    # Check that the user doesn't do something silly and unsafe like
    # object.__new__(dict).  To do this, we check that the most
    # derived base that's not a heap type is this type.
    # XXX do it

    args_w = space.fixedview(w_args)
    w_subtype = args_w[0]
    w_args = space.newtuple(args_w[1:])
    subtype = rffi.cast(PyTypeObjectPtr, make_ref(space, w_subtype))
    try:
        w_obj = generic_cpy_call(space, tp_new, subtype, w_args, w_kwds)
    finally:
        decref(space, subtype)
    return w_obj

@specialize.memo()
def get_new_method_def(space):
    state = space.fromcache(State)
    if state.new_method_def:
        return state.new_method_def
    ptr = lltype.malloc(PyMethodDef, flavor="raw", zero=True,
                        immortal=True)
    ptr.c_ml_name = rffi.cast(rffi.CONST_CCHARP, rffi.str2charp("__new__"))
    lltype.render_immortal(ptr.c_ml_name)
    rffi.setintfield(ptr, 'c_ml_flags', METH_VARARGS | METH_KEYWORDS)
    ptr.c_ml_doc = rffi.cast(rffi.CONST_CCHARP, rffi.str2charp(
        "Create and return a new object.  "
        "See help(type) for accurate signature."))
    lltype.render_immortal(ptr.c_ml_doc)
    state.new_method_def = ptr
    return ptr

def setup_new_method_def(space):
    ptr = get_new_method_def(space)
    ptr.c_ml_meth = rffi.cast(PyCFunction, llslot(space, tp_new_wrapper))

@jit.dont_look_inside
def is_tp_new_wrapper(space, ml):
    return ml.c_ml_meth == rffi.cast(PyCFunction, llslot(space, tp_new_wrapper))

def add_tp_new_wrapper(space, dict_w, pto):
    if "__new__" in dict_w:
        return
    pyo = rffi.cast(PyObject, pto)
    dict_w["__new__"] = W_PyCFunctionObject(space, get_new_method_def(space),
                                          from_ref(space, pyo), None)

def inherit_special(space, pto, w_obj, base_pto):
    # XXX missing: copy basicsize and flags in a magical way
    # (minimally, if tp_basicsize is zero or too low, we copy it from the base)
    if pto.c_tp_basicsize < base_pto.c_tp_basicsize:
        pto.c_tp_basicsize = base_pto.c_tp_basicsize
    if pto.c_tp_itemsize < base_pto.c_tp_itemsize:
        pto.c_tp_itemsize = base_pto.c_tp_itemsize

    #/* Setup fast subclass flags */
    flags = widen(pto.c_tp_flags)
    if space.issubtype_w(w_obj, space.w_BaseException):
        flags |= Py_TPFLAGS_BASE_EXC_SUBCLASS
    elif space.issubtype_w(w_obj, space.w_type):
        flags |= Py_TPFLAGS_TYPE_SUBCLASS
    elif space.issubtype_w(w_obj, space.w_int):
        flags |= Py_TPFLAGS_LONG_SUBCLASS
    elif space.issubtype_w(w_obj, space.w_bytes):
        flags |= Py_TPFLAGS_BYTES_SUBCLASS
    elif space.issubtype_w(w_obj, space.w_unicode):
        flags |= Py_TPFLAGS_UNICODE_SUBCLASS
    elif space.issubtype_w(w_obj, space.w_tuple):
        flags |= Py_TPFLAGS_TUPLE_SUBCLASS
    elif space.issubtype_w(w_obj, space.w_list):
        flags |= Py_TPFLAGS_LIST_SUBCLASS
    elif space.issubtype_w(w_obj, space.w_dict):
        flags |= Py_TPFLAGS_DICT_SUBCLASS
    # the following types are a pypy-specific extensions, using tp_pypy_flags
    elif space.issubtype_w(w_obj, space.w_float):
        pto.c_tp_pypy_flags = rffi.cast(rffi.LONG, widen(pto.c_tp_pypy_flags) | Py_TPPYPYFLAGS_FLOAT_SUBCLASS)
    pto.c_tp_flags = rffi.cast(rffi.ULONG, flags)

def check_descr(space, w_self, w_type):
    if not space.isinstance_w(w_self, w_type):
        raise DescrMismatch()

class GettersAndSetters:
    def getter(self, space, w_self):
        assert isinstance(self, W_GetSetPropertyEx)
        check_descr(space, w_self, self.w_type)
        return generic_cpy_call(
            space, self.getset.c_get, w_self,
            self.getset.c_closure)

    def setter(self, space, w_self, w_value):
        assert isinstance(self, W_GetSetPropertyEx)
        check_descr(space, w_self, self.w_type)
        res = generic_cpy_call(
            space, self.getset.c_set, w_self, w_value,
            self.getset.c_closure)
        if rffi.cast(lltype.Signed, res) < 0:
            state = space.fromcache(State)
            state.check_and_raise_exception()

    def deleter(self, space, w_self):
        assert isinstance(self, W_GetSetPropertyEx)
        check_descr(space, w_self, self.w_type)
        res = generic_cpy_call(
            space, self.getset.c_set, w_self, None,
            self.getset.c_closure)
        if rffi.cast(lltype.Signed, res) < 0:
            state = space.fromcache(State)
            state.check_and_raise_exception()

    def member_getter(self, space, w_self):
        assert isinstance(self, W_MemberDescr)
        check_descr(space, w_self, self.w_type)
        pyref = make_ref(space, w_self)
        try:
            return PyMember_GetOne(
                space, rffi.cast(rffi.CCHARP, pyref), self.member)
        finally:
            decref(space, pyref)

    def member_delete(self, space, w_self):
        assert isinstance(self, W_MemberDescr)
        check_descr(space, w_self, self.w_type)
        pyref = make_ref(space, w_self)
        try:
            PyMember_SetOne(
                space, rffi.cast(rffi.CCHARP, pyref), self.member, None)
        finally:
            decref(space, pyref)

    def member_setter(self, space, w_self, w_value):
        assert isinstance(self, W_MemberDescr)
        check_descr(space, w_self, self.w_type)
        pyref = make_ref(space, w_self)
        try:
            PyMember_SetOne(
                space, rffi.cast(rffi.CCHARP, pyref), self.member, w_value)
        finally:
            decref(space, pyref)

class W_PyCTypeObject(W_TypeObject):
    @jit.dont_look_inside
    def __init__(self, space, pto):
        bases_w = space.fixedview(from_ref(space, pto.c_tp_bases))
        dict_w = {}

        flag_heaptype = widen(pto.c_tp_flags) & Py_TPFLAGS_HEAPTYPE
        if flag_heaptype:
            hto = cts.cast('PyHeapTypeObject*', pto)
            name = space.text_w(from_ref(space, hto.c_ht_name))
        else:
            name = rffi.constcharp2str(pto.c_tp_name)
        add_operators(space, self, dict_w, pto, name)
        convert_method_defs(space, dict_w, pto.c_tp_methods, self)
        convert_getset_defs(space, dict_w, pto.c_tp_getset, self)
        convert_member_defs(space, dict_w, pto.c_tp_members, self)

        w_dict = from_ref(space, pto.c_tp_dict)
        if w_dict is not None:
            dictkeys_w = space.listview(w_dict)
            for w_key in dictkeys_w:
                key = space.text_w(w_key)
                dict_w[key] = space.getitem(w_dict, w_key)

        if flag_heaptype:
            minsize = rffi.sizeof(PyHeapTypeObject.TO)
        else:
            minsize = rffi.sizeof(PyObject.TO)
        new_layout = (pto.c_tp_basicsize > minsize or pto.c_tp_itemsize > 0)

        self.flag_cpytype = True
        W_TypeObject.__init__(self, space, name,
            bases_w or [space.w_object], dict_w, force_new_layout=new_layout,
            is_heaptype=flag_heaptype)
        # if a sequence or a mapping, then set the flag to force it
        if pto.c_tp_as_sequence and pto.c_tp_as_sequence.c_sq_item:
            self.flag_map_or_seq = 'S'
        elif pto.c_tp_as_mapping and pto.c_tp_as_mapping.c_mp_subscript:
            self.flag_map_or_seq = 'M'
        if pto.c_tp_doc:
            rawdoc = rffi.constcharp2str(pto.c_tp_doc)
            self.w_doc = space.newtext_or_none(extract_doc(rawdoc, name))
            self.text_signature = extract_txtsig(rawdoc, name)

    def _cpyext_attach_pyobj(self, space, py_obj):
        self._cpy_ref = py_obj
        rawrefcount.create_link_pyobj(self, py_obj)

@bootstrap_function
def init_typeobject(space):
    make_typedescr(space.w_type.layout.typedef,
                   basestruct=PyHeapTypeObject.TO,
                   alloc=type_alloc,
                   attach=type_attach,
                   realize=type_realize,
                   dealloc=type_dealloc)

@slot_function([PyObject], lltype.Void)
def type_dealloc(space, obj):
    from pypy.module.cpyext.object import _dealloc
    obj_pto = rffi.cast(PyTypeObjectPtr, obj)
    base_pyo = rffi.cast(PyObject, obj_pto.c_tp_base)
    decref(space, obj_pto.c_tp_bases)
    decref(space, obj_pto.c_tp_mro)
    decref(space, obj_pto.c_tp_cache) # let's do it like cpython
    decref(space, obj_pto.c_tp_dict)
    if widen(obj_pto.c_tp_flags) & Py_TPFLAGS_HEAPTYPE:
        heaptype = rffi.cast(PyHeapTypeObject, obj)
        decref(space, heaptype.c_ht_name)
        decref(space, heaptype.c_ht_qualname)
        decref(space, base_pyo)
        _dealloc(space, obj)


# CCC port it to C
def type_alloc(typedescr, space, w_metatype, itemsize=0):
    metatype = rffi.cast(PyTypeObjectPtr, make_ref(space, w_metatype))
    # Don't increase refcount for non-heaptypes
    if metatype:
        flags = widen(metatype.c_tp_flags)
        if not flags & Py_TPFLAGS_HEAPTYPE:
            decref(space, metatype)

    heaptype = lltype.malloc(PyHeapTypeObject.TO,
                             flavor='raw', zero=True,
                             add_memory_pressure=True)
    pto = heaptype.c_ht_type
    rffi.cast(PyObject, pto).c_ob_refcnt = 1
    rffi.cast(PyObject, pto).c_ob_pypy_link = 0
    rffi.cast(PyObject, pto).c_ob_type = metatype
    pto.c_tp_flags = rffi.cast(rffi.ULONG, widen(pto.c_tp_flags) | Py_TPFLAGS_HEAPTYPE)
    pto.c_tp_as_async = heaptype.c_as_async
    pto.c_tp_as_number = heaptype.c_as_number
    pto.c_tp_as_sequence = heaptype.c_as_sequence
    pto.c_tp_as_mapping = heaptype.c_as_mapping
    pto.c_tp_as_buffer = heaptype.c_as_buffer
    pto.c_tp_basicsize = -1 # hopefully this makes malloc bail out
    pto.c_tp_itemsize = 0

    return rffi.cast(PyObject, heaptype)

def type_attach(space, py_obj, w_type, w_userdata=None):
    """
    Fills a newly allocated PyTypeObject from an existing type.
    """
    assert isinstance(w_type, W_TypeObject)

    pto = rffi.cast(PyTypeObjectPtr, py_obj)

    typedescr = get_typedescr(w_type.layout.typedef)

    if space.is_w(w_type, space.w_bytes) or space.is_w(w_type, space.w_text):
        pto.c_tp_itemsize = 1
    elif space.is_w(w_type, space.w_tuple):
        pto.c_tp_itemsize = rffi.sizeof(PyObject)

    state = space.fromcache(State)
    pto.c_tp_free = state.C.PyObject_Free
    pto.c_tp_alloc = state.C.PyType_GenericAlloc
    builder = state.builder
    if ((widen(pto.c_tp_flags) & Py_TPFLAGS_HEAPTYPE) != 0
            and builder.cpyext_type_init is None):
            # this ^^^ is not None only during startup of cpyext.  At that
            # point we might get into troubles by doing make_ref() when
            # things are not initialized yet.  So in this case, simply use
            # str2charp() and "leak" the string.
        w_typename = space.getattr(w_type, space.newtext('__name__'))
        heaptype = cts.cast('PyHeapTypeObject*', pto)
        heaptype.c_ht_name = make_ref(space, w_typename)
        from pypy.module.cpyext.unicodeobject import PyUnicode_AsUTF8
        pto.c_tp_name = cts.cast('const char *',
            PyUnicode_AsUTF8(space, heaptype.c_ht_name))
    else:
        pto.c_tp_name = cts.cast('const char*', rffi.str2charp(w_type.name))
    # uninitialized fields:
    # c_tp_print
    # XXX implement
    # c_tp_compare and more?
    w_base = best_base(space, w_type.bases_w)
    pto.c_tp_base = rffi.cast(PyTypeObjectPtr, make_ref(space, w_base))

    # dealloc
    if space.gettypeobject(w_type.layout.typedef) is w_type:
        # only for the exact type, like 'space.w_tuple' or 'space.w_list'
        pto.c_tp_dealloc = typedescr.get_dealloc(space)
    else:
        # for all subtypes, use base's dealloc (requires sorting in attach_all)
        pto.c_tp_dealloc = pto.c_tp_base.c_tp_dealloc
        if not pto.c_tp_dealloc:
            # strange, but happens (ABCMeta)
            pto.c_tp_dealloc = state.C._PyPy_subtype_dealloc

    if builder.cpyext_type_init is not None:
        builder.cpyext_type_init.append((pto, w_type))
    else:
        finish_type_1(space, pto, w_type.bases_w)
        finish_type_2(space, pto, w_type)

    pto.c_tp_basicsize = rffi.sizeof(typedescr.basestruct)
    if pto.c_tp_base:
        if pto.c_tp_base.c_tp_basicsize > pto.c_tp_basicsize:
            pto.c_tp_basicsize = pto.c_tp_base.c_tp_basicsize
        if pto.c_tp_itemsize < pto.c_tp_base.c_tp_itemsize:
            pto.c_tp_itemsize = pto.c_tp_base.c_tp_itemsize

    if w_type.is_heaptype():
        update_all_slots(space, w_type, pto)
    else:
        update_all_slots_builtin(space, w_type, pto)

    # XXX generlize this pattern for various slot functions implemented in C
    if space.is_w(w_type, space.w_tuple):
        pto.c_tp_new = state.C.tuple_new

    if not pto.c_tp_new:
        base_object_pyo = make_ref(space, space.w_object)
        base_object_pto = rffi.cast(PyTypeObjectPtr, base_object_pyo)
        flags = widen(pto.c_tp_flags)
        if pto.c_tp_base != base_object_pto or flags & Py_TPFLAGS_HEAPTYPE:
                pto.c_tp_new = pto.c_tp_base.c_tp_new
        decref(space, base_object_pyo)
    pto.c_tp_flags = rffi.cast(rffi.ULONG, widen(pto.c_tp_flags) | Py_TPFLAGS_READY)
    return pto

def py_type_ready(space, pto):
    if widen(pto.c_tp_flags) & Py_TPFLAGS_READY:
        return
    type_realize(space, rffi.cast(PyObject, pto))

@cpython_api([PyTypeObjectPtr], rffi.INT_real, error=-1)
def PyType_Ready(space, pto):
    py_type_ready(space, pto)
    return 0

def type_realize(space, py_obj):
    pto = rffi.cast(PyTypeObjectPtr, py_obj)
    assert widen(pto.c_tp_flags) & Py_TPFLAGS_READY == 0
    assert widen(pto.c_tp_flags) & Py_TPFLAGS_READYING == 0
    pto.c_tp_flags = rffi.cast(rffi.ULONG, widen(pto.c_tp_flags) | Py_TPFLAGS_READYING)
    try:
        w_obj = _type_realize(space, py_obj)
    finally:
        pto.c_tp_flags = rffi.cast(rffi.ULONG, widen(pto.c_tp_flags) & ~Py_TPFLAGS_READYING)
    pto.c_tp_flags = rffi.cast(rffi.ULONG, widen(pto.c_tp_flags) | Py_TPFLAGS_READY)
    return w_obj

def solid_base(space, w_type):
    typedef = w_type.layout.typedef
    return space.gettypeobject(typedef)

def best_base(space, bases_w):
    if not bases_w:
        return None
    return find_best_base(bases_w)

def inherit_slots(space, pto, w_base):
    base_pyo = make_ref(space, w_base)
    try:
        base = rffi.cast(PyTypeObjectPtr, base_pyo)
        if not pto.c_tp_dealloc:
            pto.c_tp_dealloc = base.c_tp_dealloc
        if not pto.c_tp_init:
            pto.c_tp_init = base.c_tp_init
        if not pto.c_tp_alloc:
            pto.c_tp_alloc = base.c_tp_alloc
        # XXX check for correct GC flags!
        if not pto.c_tp_free:
            pto.c_tp_free = base.c_tp_free
        if not pto.c_tp_setattro:
            pto.c_tp_setattro = base.c_tp_setattro
        if not pto.c_tp_getattro:
            pto.c_tp_getattro = base.c_tp_getattro
        if not pto.c_tp_as_buffer:
            pto.c_tp_as_buffer = base.c_tp_as_buffer
        if base.c_tp_as_buffer:
            # inherit base.c_tp_as_buffer functions not inherited from w_type
            pto_as = pto.c_tp_as_buffer
            base_as = base.c_tp_as_buffer
            if not pto_as.c_bf_getbuffer:
                pto_as.c_bf_getbuffer = base_as.c_bf_getbuffer
            if not pto_as.c_bf_releasebuffer:
                pto_as.c_bf_releasebuffer = base_as.c_bf_releasebuffer
        if pto.c_tp_vectorcall_offset == 0:
            pto.c_tp_vectorcall_offset = base.c_tp_vectorcall_offset
    finally:
        decref(space, base_pyo)

def _type_realize(space, py_obj):
    """
    Creates an interpreter type from a PyTypeObject structure.
    """
    # missing:
    # unsupported:
    # tp_mro, tp_subclasses
    py_type = rffi.cast(PyTypeObjectPtr, py_obj)

    if not py_type.c_tp_base:
        # borrowed reference, but w_object is unlikely to disappear
        base = as_pyobj(space, space.w_object)
        py_type.c_tp_base = rffi.cast(PyTypeObjectPtr, base)

    finish_type_1(space, py_type)
    ob_type = rffi.cast(PyObject, py_type).c_ob_type

    if ob_type:
        w_metatype = from_ref(space, rffi.cast(PyObject, ob_type))
    else:
        # Somehow the tp_base type is created with no ob_type, notably
        # PyString_Type and PyBaseString_Type
        # While this is a hack, cpython does it as well.
        w_metatype = space.w_type

    w_obj = rawrefcount.to_obj(W_PyCTypeObject, py_obj)
    if w_obj is None:
        w_obj = space.allocate_instance(W_PyCTypeObject, w_metatype)
        track_reference(space, py_obj, w_obj)
    # __init__ wraps all slotdefs functions from py_type via add_operators
    w_obj.__init__(space, py_type)
    w_obj.ready()

    finish_type_2(space, py_type, w_obj)
    base = py_type.c_tp_base
    if base:
        # XXX refactor - parts of this are done in finish_type_2 -> inherit_slots
        if not py_type.c_tp_as_number:
            py_type.c_tp_as_number = base.c_tp_as_number
        if not py_type.c_tp_as_sequence:
            py_type.c_tp_as_sequence = base.c_tp_as_sequence
        if not py_type.c_tp_as_mapping:
            py_type.c_tp_as_mapping = base.c_tp_as_mapping
        #if not py_type.c_tp_as_buffer: py_type.c_tp_as_buffer = base.c_tp_as_buffer

    return w_obj

def finish_type_1(space, pto, bases_w=None):
    """
    Sets up tp_bases, necessary before creating the interpreter type.
    """
    base = pto.c_tp_base
    base_pyo = rffi.cast(PyObject, base)
    if base and not widen(base.c_tp_flags) & Py_TPFLAGS_READY:
        type_realize(space, base_pyo)
    pto_pyobj = rffi.cast(PyObject, pto)
    if base and not pto_pyobj.c_ob_type: # will be filled later
        pto_pyobj.c_ob_type = rffi.cast(PyObject, base).c_ob_type
    if not pto.c_tp_bases:
        if bases_w is None:
            if not base:
                bases_w = []
            else:
                bases_w = [from_ref(space, base_pyo)]
        is_heaptype = bool(widen(pto.c_tp_flags) & Py_TPFLAGS_HEAPTYPE)
        pto.c_tp_bases = make_ref(space, space.newtuple(bases_w),
                                  immortal=not is_heaptype)

def finish_type_2(space, pto, w_obj):
    """
    Sets up other attributes, when the interpreter type has been created.
    """
    pto.c_tp_mro = make_ref(space, space.newtuple(w_obj.mro_w))
    base = pto.c_tp_base
    if base:
        inherit_special(space, pto, w_obj, base)
    for w_base in space.fixedview(from_ref(space, pto.c_tp_bases)):
        if isinstance(w_base, W_TypeObject):
            inherit_slots(space, pto, w_base)
        #else:
        #   w_base is a W_ClassObject, ignore it

    if not pto.c_tp_setattro:
        from pypy.module.cpyext.object import PyObject_GenericSetAttr
        pto.c_tp_setattro = llslot(space, PyObject_GenericSetAttr)

    if not pto.c_tp_getattro:
        from pypy.module.cpyext.object import PyObject_GenericGetAttr
        pto.c_tp_getattro = llslot(space, PyObject_GenericGetAttr)

    if w_obj.is_cpytype():
        decref(space, pto.c_tp_dict)
    w_dict = w_obj.getdict(space)
    # pass in the w_obj to convert any values that are
    # unbound GetSetProperty into bound PyGetSetDescrObject
    pto.c_tp_dict = make_ref(space, w_dict, w_obj)

@cpython_api([PyTypeObjectPtr, PyTypeObjectPtr], rffi.INT_real, error=CANNOT_FAIL)
def PyType_IsSubtype(space, a, b):
    """Return true if a is a subtype of b.
    """
    w_type1 = from_ref(space, rffi.cast(PyObject, a))
    w_type2 = from_ref(space, rffi.cast(PyObject, b))
    return int(abstract_issubclass_w(space, w_type1, w_type2)) #XXX correct?

@cpython_api([PyTypeObjectPtr, PyObject, PyObject], PyObject)
def PyType_GenericNew(space, type, w_args, w_kwds):
    return generic_cpy_call(
        space, type.c_tp_alloc, type, 0)

def _parse_typeslots():
    slots_hdr = CTypeSpace()
    slots_hdr.parse_header(parse_dir / "typeslots.h")
    prefix2member = {
        'tp': "ht_type",
        'am': "as_async",
        'nb': "as_number",
        'mp': "as_mapping",
        'sq': "as_sequence",
        'bf': "as_buffer"}

    TABLE = []
    HTO = cts.gettype('PyHeapTypeObject')
    for name, num in slots_hdr.macros.items():
        assert isinstance(num, int)
        assert name.startswith('Py_')
        name = name[3:]
        membername = 'c_' + prefix2member[name[:2]]
        slotname = 'c_' + name
        TARGET = HTO._flds[membername]._flds[slotname]
        TABLE.append((num, membername, slotname, TARGET))
    return unrolling_iterable(TABLE)
SLOT_TABLE = _parse_typeslots()

def fill_ht_slot(ht, slotnum, ptr):
    for num, membername, slotname, TARGET in SLOT_TABLE:
        if num == slotnum:
            setattr(getattr(ht, membername), slotname, rffi.cast(TARGET, ptr))

def get_ht_slot(ht, slotnum):
    for num, membername, slotname, TARGET in SLOT_TABLE:
        if num == slotnum:
            return rffi.cast(rffi.VOIDP, getattr(getattr(ht, membername), slotname))
    return rffi.cast(rffi.VOIDP, 0)

@cts.decl("""PyObject *
    PyType_FromSpecWithBases(PyType_Spec *spec, PyObject *bases)""",
    result_is_ll=True)
def PyType_FromSpecWithBases(space, spec, bases):
    return PyType_FromSpecWithBases(space, None, spec, bases)

@cts.decl("""PyObject *
    PyType_FromModuleAndSpec(PyObject *, PyType_Spec *spec, PyObject *bases)""",
    result_is_ll=True)
def PyType_FromSpecWithBases(space, module, spec, bases):
    from pypy.module.cpyext.unicodeobject import PyUnicode_FromString
    state = space.fromcache(State)
    p_type = cts.cast('PyTypeObject*', make_ref(space, space.w_type))
    res = state.ccall("PyType_GenericAlloc", p_type, 0)
    res = cts.cast('PyHeapTypeObject *', res)
    typ = res.c_ht_type
    typ.c_tp_flags = rffi.cast(rffi.ULONG, widen(spec.c_flags) | Py_TPFLAGS_HEAPTYPE)
    specname = rffi.constcharp2str(spec.c_name)
    dotpos = specname.rfind('.')
    if dotpos < 0:
        name = specname
        modname = None
    else:
        name = specname[dotpos + 1:]
        modname = specname[:dotpos]
    res.c_ht_name = make_ref(space, space.newtext(name))
    res.c_ht_qualname = res.c_ht_name
    incref(space, res.c_ht_qualname)
    if module:
        incref(space, module)
        res.c_ht_module = module
    typ.c_tp_name = spec.c_name
    slotdefs = rffi.cast(rffi.CArrayPtr(cts.gettype('PyType_Slot')), spec.c_slots)
    if not bases:
        w_base = space.w_object
        bases_w = []
        i = 0
        while True:
            slotdef = slotdefs[i]
            slotnum = rffi.cast(lltype.Signed, slotdef.c_slot)
            if slotnum == 0:
                break
            elif slotnum == cts.macros['Py_tp_base']:
                w_base = from_ref(space, cts.cast('PyObject*', slotdef.c_pfunc))
            elif slotnum == cts.macros['Py_tp_bases']:
                bases = cts.cast('PyObject*', slotdef.c_pfunc)
                bases_w = space.fixedview(from_ref(space, bases))
            i += 1
        if not bases_w:
            bases_w = [w_base]
    else:
        bases_w = space.fixedview(from_ref(space, bases))
    w_base = best_base(space, bases_w)
    base = cts.cast('PyTypeObject*', make_ref(space, w_base))
    if False:  # not widen(base.c_tp_flags) & Py_TPFLAGS_BASETYPE:
        raise oefmt(space.w_TypeError,
            "type '%s' is not an acceptable base type",
            rffi.charp2str(base.c_tp_name))

    typ.c_tp_as_async = res.c_as_async
    typ.c_tp_as_number = res.c_as_number
    typ.c_tp_as_sequence = res.c_as_sequence
    typ.c_tp_as_mapping = res.c_as_mapping
    typ.c_tp_as_buffer = res.c_as_buffer
    typ.c_tp_bases = bases
    typ.c_tp_base = base
    typ.c_tp_basicsize = cts.cast('Py_ssize_t', spec.c_basicsize)
    typ.c_tp_itemsize = cts.cast('Py_ssize_t', spec.c_itemsize)

    i = 0
    while True:
        slotdef = slotdefs[i]
        slot = rffi.cast(lltype.Signed, slotdef.c_slot)
        if slot == 0:
            break
        if slot < 0:  # or slot > len(slotoffsets):
            raise oefmt(space.w_RuntimeError, "invalid slot offset")
        if slot in (cts.macros['Py_tp_base'], cts.macros['Py_tp_bases']):
            # Processed above
            i += 1
            continue
        fill_ht_slot(res, slot, slotdef.c_pfunc)
        # XXX: need to make a copy of the docstring slot, which usually
        # points to a static string literal
        i += 1

    if not typ.c_tp_dealloc:
        typ.c_tp_dealloc = state.C._PyPy_subtype_dealloc
    py_type_ready(space, typ)
    res = cts.cast('PyObject*', res)
    if modname is not None:
        w_type = from_ref(space, res)
        w_type.setdictvalue(space, '__module__', space.newtext(modname))
    return res

@cpython_api([PyTypeObjectPtr, rffi.INT], rffi.VOIDP)
def PyType_GetSlot(space, typ, slot):
    """ Use the Py_tp* macros in typeslots.h to return a slot function
    """
    slot = widen(slot)
    if slot < 0 or not widen(typ.c_tp_flags) & Py_TPFLAGS_HEAPTYPE:
        raise oefmt(space.w_SystemError, "Bad internal call!")
    heapobj = rffi.cast(PyHeapTypeObject, typ)
    return get_ht_slot(heapobj, slot)

@cpython_api([PyTypeObjectPtr, PyObject], PyObject, error=CANNOT_FAIL,
             result_borrowed=True)
def _PyType_Lookup(space, type, w_name):
    """Internal API to look for a name through the MRO.
    This returns a borrowed reference, and doesn't set an exception!"""
    w_type = from_ref(space, rffi.cast(PyObject, type))
    assert isinstance(w_type, W_TypeObject)

    if not space.isinstance_w(w_name, space.w_text):
        return None
    name = space.text_w(w_name)
    w_obj = w_type.lookup(name)
    # this assumes that w_obj is not dynamically created, but will stay alive
    # until w_type is modified or dies.  Assuming this, we return a borrowed ref
    return w_obj

@cpython_api([PyTypeObjectPtr], lltype.Void)
def PyType_Modified(space, w_obj):
    """Invalidate the internal lookup cache for the type and all of its
    subtypes.  This function must be called after any manual
    modification of the attributes or base classes of the type.
    """
    # Invalidate the type cache in case of a builtin type.
    if not isinstance(w_obj, W_TypeObject):
        return
    if w_obj.is_cpytype():
        w_obj.mutated(None)

@cpython_api([PyObject, PyObject], PyObject, header='genericaliasobject.h')
def Py_GenericAlias(space, w_cls, w_item):
    from pypy.objspace.std.util import generic_alias_class_getitem
    return generic_alias_class_getitem(space, w_cls, w_item)
