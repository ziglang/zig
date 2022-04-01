#include <Python.h>
#include "hpy.h"

#ifdef HPY_UNIVERSAL_ABI
   // for _h2py and _py2h
#  include "handles.h"
#endif


_HPy_HIDDEN void
ctx_Dump(HPyContext *ctx, HPy h)
{
    // just use _PyObject_Dump for now, but we might want to add more info
    // about the handle itself in the future.
    _PyObject_Dump(_h2py(h));
}

/* NOTE: contrarily to CPython, the HPy have to check that h_type is a
   type. On CPython it's not necessarily because it passes a PyTypeObject*,
   but here we can only receive an HPy.

   However, we can't/don't want to raise an exception if you pass a non-type,
   because the CPython version (PyObject_TypeCheck) always succeed and it
   would be too easy to forget to check the return value. We just raise a
   fatal error instead.

   Hopefully the slowdown is not too much. If it proves to be too much, we
   could say that the function is allowed to crash if you pass a non-type, and
   do the check only in debug mode.
*/
_HPy_HIDDEN int
ctx_TypeCheck(HPyContext *ctx, HPy h_obj, HPy h_type)
{
    PyObject *type= _h2py(h_type);
    assert(type != NULL);
    if (!PyType_Check(type)) {
        Py_FatalError("HPy_TypeCheck arg 2 must be a type");
    }
    return PyObject_TypeCheck(_h2py(h_obj), (PyTypeObject*)type);
}

_HPy_HIDDEN int
ctx_Is(HPyContext *ctx, HPy h_obj, HPy h_other)
{
    return _h2py(h_obj) == _h2py(h_other);
}

_HPy_HIDDEN HPy
ctx_GetItem_i(HPyContext *ctx, HPy obj, HPy_ssize_t idx) {
    PyObject* key = PyLong_FromSsize_t(idx);
    if (key == NULL)
        return HPy_NULL;
    HPy result = _py2h(PyObject_GetItem(_h2py(obj), key));
    Py_DECREF(key);
    return result;
}

_HPy_HIDDEN HPy
ctx_GetItem_s(HPyContext *ctx, HPy obj, const char *key) {
    PyObject* key_o = PyUnicode_FromString(key);
    if (key_o == NULL)
        return HPy_NULL;
    HPy result = _py2h(PyObject_GetItem(_h2py(obj), key_o));
    Py_DECREF(key_o);
    return result;
}

_HPy_HIDDEN int
ctx_SetItem_i(HPyContext *ctx, HPy obj, HPy_ssize_t idx, HPy value) {
    PyObject* key = PyLong_FromSsize_t(idx);
    if (key == NULL)
        return -1;
    int result = PyObject_SetItem(_h2py(obj), key, _h2py(value));
    Py_DECREF(key);
    return result;
}

_HPy_HIDDEN int
ctx_SetItem_s(HPyContext *ctx, HPy obj, const char *key, HPy value) {
    PyObject* key_o = PyUnicode_FromString(key);
    if (key_o == NULL)
        return -1;
    int result = PyObject_SetItem(_h2py(obj), key_o, _h2py(value));
    Py_DECREF(key_o);
    return result;
}
