from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import (
    METH_STATIC, METH_CLASS, METH_COEXIST, CANNOT_FAIL, CONST_STRING,
    METH_NOARGS, METH_O, METH_VARARGS, build_type_checkers,
    parse_dir, bootstrap_function, generic_cpy_call, cts, cpython_api,
    generic_cpy_call_dont_convert_result, slot_function)
from pypy.module.cpyext.pyobject import (PyObject, as_pyobj, make_typedescr,
    keepalive_until_here)
from pypy.interpreter.module import Module
from pypy.module.cpyext.methodobject import (
    W_PyCFunctionObject, W_PyCMethodObject,
    PyMethodDef, W_PyCClassMethodObject, StaticMethod)
from pypy.module.cpyext.pyerrors import PyErr_BadInternalCall
from pypy.module.cpyext.state import State
from pypy.interpreter.error import oefmt

cts.parse_header(parse_dir / 'cpyext_moduleobject.h')
PyModuleDef = cts.gettype('PyModuleDef *')
PyModuleObject = cts.gettype('PyModuleObject *')
PyModuleDef_Slot = cts.gettype('PyModuleDef_Slot')

@bootstrap_function
def init_moduleobject(space):
    make_typedescr(Module.typedef, basestruct=PyModuleObject.TO,
                   dealloc=module_dealloc)

@slot_function([PyObject], lltype.Void)
def module_dealloc(space, py_obj):
    py_module = rffi.cast(PyModuleObject, py_obj)
    if py_module.c_md_state:
        lltype.free(py_module.c_md_state, flavor='raw')
    from pypy.module.cpyext.object import _dealloc
    _dealloc(space, py_obj)

PyModule_Check, PyModule_CheckExact = build_type_checkers("Module", Module)

@cpython_api([CONST_STRING], PyObject)
def PyModule_New(space, name):
    """
    Return a new module object with the __name__ attribute set to name.
    Only the module's __doc__ and __name__ attributes are filled in;
    the caller is responsible for providing a __file__ attribute."""
    return Module(space, space.newtext(rffi.charp2str(name)))

@cpython_api([PyObject], PyObject)
def PyModule_NewObject(space, w_name):
    """
    Return a new module object with the __name__ attribute set to name.
    Only the module's __doc__ and __name__ attributes are filled in;
    the caller is responsible for providing a __file__ attribute."""
    return Module(space, w_name)

@cpython_api([PyModuleDef, rffi.INT_real], PyObject)
def PyModule_Create2(space, module, api_version):
    """Create a new module object, given the definition in module, assuming the
    API version module_api_version.  If that version does not match the version
    of the running interpreter, a RuntimeWarning is emitted.

    Most uses of this function should be using PyModule_Create()
    instead; only use this if you are sure you need it."""

    modname = rffi.charp2str(rffi.cast(rffi.CCHARP, module.c_m_name))
    if module.c_m_doc:
        doc = rffi.charp2str(rffi.cast(rffi.CCHARP, module.c_m_doc))
    else:
        doc = None
    methods = module.c_m_methods

    state = space.fromcache(State)
    f_name, f_path = state.package_context
    if f_name is not None:
        modname = f_name
    w_mod = Module(space, space.newtext(modname))
    py_mod = rffi.cast(PyModuleObject, as_pyobj(space, w_mod))
    py_mod.c_md_def = module
    state.package_context = None, None

    if f_path is not None:
        dict_w = {'__file__': space.newfilename(f_path)}
    else:
        dict_w = {}
    convert_method_defs(space, dict_w, methods, None, w_mod, modname)
    for key, w_value in dict_w.items():
        space.setattr(w_mod, space.newtext(key), w_value)
    if doc:
        space.setattr(w_mod, space.newtext("__doc__"),
                      space.newtext(doc))

    if module.c_m_size > 0:
        py_mod.c_md_state = lltype.malloc(rffi.VOIDP.TO, module.c_m_size,
                                          flavor='raw', zero=True)
    return w_mod


createfunctype = lltype.Ptr(lltype.FuncType([PyObject, PyModuleDef], PyObject))
execfunctype = lltype.Ptr(lltype.FuncType([PyObject], rffi.INT_real))


def create_module_from_def_and_spec(space, moddef, w_spec, name):
    moddef = rffi.cast(PyModuleDef, moddef)
    if moddef.c_m_size < 0:
        raise oefmt(space.w_SystemError,
                    "module %s: m_size may not be negative for multi-phase "
                    "initialization", name)
    createf = lltype.nullptr(rffi.VOIDP.TO)
    has_execution_slots = False
    cur_slot = rffi.cast(rffi.CArrayPtr(PyModuleDef_Slot), moddef.c_m_slots)
    if cur_slot:
        while True:
            slot = rffi.cast(lltype.Signed, cur_slot[0].c_slot)
            if slot == 0:
                break
            elif slot == 1:
                if createf:
                    raise oefmt(space.w_SystemError,
                                "module %s has multiple create slots", name)
                createf = cur_slot[0].c_value
            elif slot < 0 or slot > 2:
                raise oefmt(space.w_SystemError,
                            "module %s uses unknown slot ID %d", name, slot)
            else:
                has_execution_slots = True
            cur_slot = rffi.ptradd(cur_slot, 1)
    if createf:
        createf = rffi.cast(createfunctype, createf)
        w_mod = generic_cpy_call(space, createf, w_spec, moddef)
    else:
        w_mod = Module(space, space.newtext(name))
    if isinstance(w_mod, Module):
        mod = rffi.cast(PyModuleObject, as_pyobj(space, w_mod))
        #mod.c_md_state = None
        mod.c_md_def = moddef
    else:
        if moddef.c_m_size > 0 or moddef.c_m_traverse or moddef.c_m_clear or \
           moddef.c_m_free:
            raise oefmt(space.w_SystemError,
                        "module %s is not a module object, but requests "
                        "module state", name)
        if has_execution_slots:
            raise oefmt(space.w_SystemError,
                        "module %s specifies execution slots, but did not "
                        "create a ModuleType instance", name)
    dict_w = {}
    convert_method_defs(space, dict_w, moddef.c_m_methods, None, w_mod, name)
    for key, w_value in dict_w.items():
        space.setattr(w_mod, space.newtext(key), w_value)
    if moddef.c_m_doc:
        doc = rffi.charp2str(rffi.cast(rffi.CCHARP, moddef.c_m_doc))
        space.setattr(w_mod, space.newtext('__doc__'), space.newtext(doc))
    return w_mod


def exec_def(space, mod, moddef):
    from pypy.module.cpyext.pyerrors import PyErr_Occurred
    cur_slot = rffi.cast(rffi.CArrayPtr(PyModuleDef_Slot), moddef.c_m_slots)
    if moddef.c_m_size >= 0 and not mod.c_md_state:
        # Always set md_state, to use as marker for exec_extension_module()
        # (cf. CPython's PyModule_ExecDef)
        mod.c_md_state = lltype.malloc(
            rffi.VOIDP.TO, moddef.c_m_size, flavor='raw', zero=True)
    pyobj = rffi.cast(PyObject, mod)
    while cur_slot and rffi.cast(lltype.Signed, cur_slot[0].c_slot):
        if rffi.cast(lltype.Signed, cur_slot[0].c_slot) == 2:
            execf = rffi.cast(execfunctype, cur_slot[0].c_value)
            res = generic_cpy_call_dont_convert_result(space, execf, pyobj)
            state = space.fromcache(State)
            if rffi.cast(lltype.Signed, res):
                state.check_and_raise_exception()
                raise oefmt(space.w_SystemError,
                            "execution of module %s failed without setting an "
                            "exception", rffi.constcharp2str(moddef.c_m_name))
            else:
                if state.clear_exception():
                    raise oefmt(space.w_SystemError,
                                "execution of module %s raised unreported "
                                "exception", rffi.constcharp2str(moddef.c_m_name))
        cur_slot = rffi.ptradd(cur_slot, 1)

def convert_method_defs(space, dict_w, methods, w_type, w_self=None, name=None):
    w_name = space.newtext_or_none(name)
    methods = rffi.cast(rffi.CArrayPtr(PyMethodDef), methods)
    if methods:
        i = -1
        while True:
            i = i + 1
            method = methods[i]
            if not method.c_ml_name: break

            methodname = rffi.charp2str(rffi.cast(rffi.CCHARP, method.c_ml_name))
            flags = rffi.cast(lltype.Signed, method.c_ml_flags)

            if w_type is None:
                if flags & METH_CLASS or flags & METH_STATIC:
                    raise oefmt(space.w_ValueError,
                            "module functions cannot set METH_CLASS or "
                            "METH_STATIC")
                w_obj = W_PyCFunctionObject(space, method, w_self, w_name)
            else:
                if methodname in dict_w and not (flags & METH_COEXIST):
                    continue
                if flags & METH_CLASS:
                    if flags & METH_STATIC:
                        raise oefmt(space.w_ValueError,
                                    "method cannot be both class and static")
                    w_obj = W_PyCClassMethodObject(space, method, w_type)
                elif flags & METH_STATIC:
                    w_func = W_PyCFunctionObject(space, method, None, None)
                    w_obj = StaticMethod(w_func)
                else:
                    w_obj = W_PyCMethodObject(space, method, None, None, w_type)

            dict_w[methodname] = w_obj


@cpython_api([PyObject], PyObject, result_borrowed=True)
def PyModule_GetDict(space, w_mod):
    if PyModule_Check(space, w_mod):
        assert isinstance(w_mod, Module)
        w_dict = w_mod.getdict(space)
        return w_dict    # borrowed reference, likely from w_mod.w_dict
    else:
        PyErr_BadInternalCall(space)

@cpython_api([PyObject], rffi.CCHARP)
def PyModule_GetName(space, w_mod):
    """
    Return module's __name__ value.  If the module does not provide one,
    or if it is not a string, SystemError is raised and NULL is returned.
    """
    # NOTE: this version of the code works only because w_mod.w_name is
    # a wrapped string object attached to w_mod; so it makes a
    # PyStringObject that will live as long as the module itself,
    # and returns a "char *" inside this PyStringObject.
    if not isinstance(w_mod, Module):
        raise oefmt(space.w_SystemError, "PyModule_GetName(): not a module")
    from pypy.module.cpyext.unicodeobject import PyUnicode_AsUTF8
    return PyUnicode_AsUTF8(space, as_pyobj(space, w_mod.w_name))

@cpython_api([PyObject, lltype.Ptr(PyMethodDef)], rffi.INT_real, error=-1)
def PyModule_AddFunctions(space, w_mod, methods):
    if not isinstance(w_mod, Module):
        raise oefmt(space.w_SystemError, "PyModule_AddFuntions(): not a module")
    name = space.utf8_w(w_mod.w_name)
    dict_w = {}
    convert_method_defs(space, dict_w, methods, None, w_mod, name=name)
    for key, w_value in dict_w.items():
        space.setattr(w_mod, space.newtext(key), w_value)
    return 0

@cpython_api([PyObject, PyModuleDef], rffi.INT_real, error=-1)
def PyModule_ExecDef(space, w_mod, c_def):
    if not isinstance(w_mod, Module):
        raise oefmt(space.w_SystemError, "PyModule_ExecDef(): not a module")
    py_mod = rffi.cast(PyModuleObject, as_pyobj(space, w_mod))
    exec_def(space, py_mod, c_def)
    keepalive_until_here(w_mod)
    return 0
