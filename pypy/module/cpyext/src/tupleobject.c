
/* Tuple object implementation, stolen&adapted from CPython.  

   One important difference is that CPython caches the empty tuple separately
   and always return the very same object, while we always return a fresh one.
   The reasons is that space.newtuple([]) always return different objects, and
   we want to ensure that the following is always true:

       w_a != w_b ==> as_pyobj(w_b) != as_pyobj(w_b)
 */

#include "Python.h"

/* Speed optimization to avoid frequent malloc/free of small tuples */
#ifndef PyTuple_MAXSAVESIZE
#define PyTuple_MAXSAVESIZE     20  /* Largest tuple to save on free list */
#endif
#ifndef PyTuple_MAXFREELIST
#define PyTuple_MAXFREELIST  2000  /* Maximum number of tuples of each size to save */
#endif

#if PyTuple_MAXSAVESIZE > 0
static PyTupleObject *free_list[PyTuple_MAXSAVESIZE];
static int numfree[PyTuple_MAXSAVESIZE];
#endif

PyObject *
PyTuple_New(register Py_ssize_t size)
{
    register PyTupleObject *op;
    Py_ssize_t i;
    if (size < 0) {
        PyErr_BadInternalCall();
        return NULL;
    }
#if PyTuple_MAXSAVESIZE > 0
    if (size < PyTuple_MAXSAVESIZE && (op = free_list[size]) != NULL) {
        free_list[size] = (PyTupleObject *) op->ob_item[0];
        numfree[size]--;
        _Py_NewReference((PyObject *)op);
    }
    else
#endif
    {
        Py_ssize_t nbytes = size * sizeof(PyObject *);
        /* Check for overflow */
        if (nbytes / sizeof(PyObject *) != (size_t)size ||
            (nbytes > PY_SSIZE_T_MAX - sizeof(PyTupleObject) - sizeof(PyObject *)))
        {
            return PyErr_NoMemory();
        }

        op = PyObject_GC_NewVar(PyTupleObject, &PyTuple_Type, size);
        if (op == NULL)
            return NULL;
    }
    for (i=0; i < size; i++)
        op->ob_item[i] = NULL;
    _PyObject_GC_TRACK(op);
    return (PyObject *) op;
}

/* this is CPython's tupledealloc */
void
_PyPy_tuple_dealloc(register PyObject *_op)
{
    register PyTupleObject *op = (PyTupleObject *)_op;
    register Py_ssize_t i;
    register Py_ssize_t len =  Py_SIZE(op);
    PyObject_GC_UnTrack(op);
    Py_TRASHCAN_SAFE_BEGIN(op)
    if (len >= 0) {
        i = len;
        while (--i >= 0)
            Py_XDECREF(op->ob_item[i]);
#if PyTuple_MAXSAVESIZE > 0
        if (len < PyTuple_MAXSAVESIZE &&
            numfree[len] < PyTuple_MAXFREELIST &&
            Py_TYPE(op) == &PyTuple_Type)
        {
            op->ob_item[0] = (PyObject *) free_list[len];
            numfree[len]++;
            free_list[len] = op;
            goto done; /* return */
        }
#endif
    }
    Py_TYPE(op)->tp_free((PyObject *)op);
done:
    Py_TRASHCAN_SAFE_END(op)
}

static PyObject *
tuple_subtype_new(PyTypeObject *type, PyObject *args, PyObject *kwds);

/* 
 * Mangle to _PyPy_tuple_new for translation.
 * For tests, we want to mangle as if it were a c-api function so
 * it will not be confused with the host's similarly named function
 */
#ifdef CPYEXT_TESTS
#define _Py_tuple_new _cpyexttest_tuple_new
#ifdef __GNUC__
__attribute__((visibility("default")))
#else
__declspec(dllexport)
#endif
#else  /* CPYEXT_TESTS */
#define _Py_tuple_new _PyPy_tuple_new
#endif  /* CPYEXT_TESTS */
PyObject *
_Py_tuple_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    PyObject *arg = NULL;
    static char *kwlist[] = {"sequence", 0};

    if (type != &PyTuple_Type)
        return tuple_subtype_new(type, args, kwds);
    if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O:tuple", kwlist, &arg))
        return NULL;

    if (arg == NULL)
        return PyTuple_New(0);
    else
        return PySequence_Tuple(arg);
}

static PyObject *
tuple_subtype_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    PyObject *tmp, *newobj, *item;
    Py_ssize_t i, n;

    assert(PyType_IsSubtype(type, &PyTuple_Type));
    tmp = _Py_tuple_new(&PyTuple_Type, args, kwds);
    if (tmp == NULL)
        return NULL;
    assert(PyTuple_Check(tmp));
    newobj = type->tp_alloc(type, n = PyTuple_GET_SIZE(tmp));
    if (newobj == NULL)
        return NULL;
    for (i = 0; i < n; i++) {
        item = PyTuple_GET_ITEM(tmp, i);
        Py_INCREF(item);
        PyTuple_SET_ITEM(newobj, i, item);
    }
    Py_DECREF(tmp);
    return newobj;
}


