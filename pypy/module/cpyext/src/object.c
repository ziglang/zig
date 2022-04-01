/* Generic object operations; and implementation of None (NoObject) */

#include "Python.h"

extern void _PyPy_Free(void *ptr);
extern void *_PyPy_Malloc(Py_ssize_t size);

/* 
 * The actual value of this variable will be the address of
 * pyobject.w_marker_deallocating, and will be set by
 * pyobject.write_w_marker_deallocating().
 *
 * The value set here is used only as a marker by tests (because during the
 * tests we cannot call set_marker(), so we need to set a special value
 * directly here)
 */
void* _pypy_rawrefcount_w_marker_deallocating = (void*) 0xDEADFFF;

void
_Py_Dealloc(PyObject *obj)
{
    PyTypeObject *pto = obj->ob_type;
    /* this is the same as rawrefcount.mark_deallocating() */
    obj->ob_pypy_link = (Py_ssize_t)_pypy_rawrefcount_w_marker_deallocating;
    pto->tp_dealloc(obj);
}

void
_PyPy_object_dealloc(PyObject *obj)
{
    PyTypeObject *pto;
    assert(obj->ob_refcnt == 0);
    pto = obj->ob_type;
    pto->tp_free(obj);
    if (pto->tp_flags & Py_TPFLAGS_HEAPTYPE)
        Py_DECREF(pto);
}

void
PyObject_Free(void *obj)
{
    _PyPy_Free(obj);
}

void
PyObject_GC_Del(void *obj)
{
    _PyPy_Free(obj);
}

PyObject *
PyType_GenericAlloc(PyTypeObject *type, Py_ssize_t nitems)
{
    return (PyObject*)_PyObject_NewVar(type, nitems);
}

PyObject *
_PyObject_New(PyTypeObject *type)
{
    return (PyObject*)_PyObject_NewVar(type, 0);
}

PyObject * _PyObject_GC_Malloc(size_t size)
{
    return (PyObject *)PyObject_Malloc(size);
}

PyObject * _PyObject_GC_New(PyTypeObject *type)
{
    return _PyObject_New(type);
}

PyVarObject * _PyObject_GC_NewVar(PyTypeObject *type, Py_ssize_t nitems)
{
    return _PyObject_NewVar(type, nitems);
}

static PyObject *
_generic_alloc(PyTypeObject *type, Py_ssize_t nitems)
{
    Py_ssize_t size;
    PyObject *pyobj;
    if (type->tp_flags & Py_TPFLAGS_HEAPTYPE)
        Py_INCREF(type);

    size = type->tp_basicsize;
    if (type->tp_itemsize)
        size += nitems * type->tp_itemsize;

    pyobj = (PyObject*)_PyPy_Malloc(size);
    if (pyobj == NULL)
        return NULL;

    if (type->tp_itemsize)
        ((PyVarObject*)pyobj)->ob_size = nitems;

    pyobj->ob_refcnt = 1;
    /* pyobj->ob_pypy_link should get assigned very quickly */
    pyobj->ob_type = type;
    return pyobj;
}

PyVarObject *
_PyObject_NewVar(PyTypeObject *type, Py_ssize_t nitems)
{
    /* Note that this logic is slightly different than the one used by
       CPython. The plan is to try to follow as closely as possible the
       current cpyext logic here, and fix it when the migration to C is
       completed
    */
    PyObject *py_obj = _generic_alloc(type, nitems);
    if (!py_obj)
        return (PyVarObject*)PyErr_NoMemory();
    
    if (type->tp_itemsize == 0)
        return (PyVarObject*)PyObject_INIT(py_obj, type);
    else
        return PyObject_INIT_VAR((PyVarObject*)py_obj, type, nitems);
}

PyObject *
PyObject_Init(PyObject *obj, PyTypeObject *type)
{
    obj->ob_type = type;
    obj->ob_pypy_link = 0;
    obj->ob_refcnt = 1;
    return obj;
}

PyVarObject *
PyObject_InitVar(PyVarObject *obj, PyTypeObject *type, Py_ssize_t size)
{
    obj->ob_size = size;
    return (PyVarObject*)PyObject_Init((PyObject*)obj, type);
}

int
PyObject_CallFinalizerFromDealloc(PyObject *self)
{
    /* STUB */
    if (self->ob_type->tp_finalize) {
        fprintf(stderr, "WARNING: PyObject_CallFinalizerFromDealloc() "
                        "not implemented (objects of type '%s')\n",
                        self->ob_type->tp_name);
        self->ob_type->tp_finalize = NULL;   /* only once */
    }
    return 0;
}

const char *
_PyType_Name(PyTypeObject *type)
{
    assert(type->tp_name != NULL);
    const char *s = strrchr(type->tp_name, '.');
    if (s == NULL) {
        s = type->tp_name;
    }
    else {
        s++;
    }
    return s;
}
