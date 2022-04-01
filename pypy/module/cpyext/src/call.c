#include "Python.h"
#include <signal.h>

#define _PyTuple_ITEMS PySequence_Fast_ITEMS

PyObject*
_Py_CheckFunctionResult(PyObject *callable, PyObject *result, const char *where)
{
    int err_occurred = (PyErr_Occurred() != NULL);

    assert((callable != NULL) ^ (where != NULL));

    if (result == NULL) {
        if (!err_occurred) {
            if (callable)
                PyErr_Format(PyExc_SystemError,
                             "%R returned NULL without setting an error",
                             callable);
            else
                PyErr_Format(PyExc_SystemError,
                             "%s returned NULL without setting an error",
                             where);
#ifdef Py_DEBUG
            /* Ensure that the bug is caught in debug mode */
            Py_FatalError("a function returned NULL without setting an error");
#endif
            return NULL;
        }
    }
    else {
        if (err_occurred) {
            Py_DECREF(result);

            if (callable) {
                _PyErr_FormatFromCause(PyExc_SystemError,
                        "%R returned a result with an error set",
                        callable);
            }
            else {
                _PyErr_FormatFromCause(PyExc_SystemError,
                        "%s returned a result with an error set",
                        where);
            }
#ifdef Py_DEBUG
            /* Ensure that the bug is caught in debug mode */
            Py_FatalError("a function returned a result with an error set");
#endif
            return NULL;
        }
    }
    return result;
}

int
_PyStack_UnpackDict(PyObject *const *args, Py_ssize_t nargs, PyObject *kwargs,
                    PyObject *const **p_stack, PyObject **p_kwnames)
{
    PyObject **stack, **kwstack;
    Py_ssize_t nkwargs;
    Py_ssize_t pos, i;
    PyObject *key, *value;
    PyObject *kwnames;

    assert(nargs >= 0);
    assert(kwargs == NULL || PyDict_CheckExact(kwargs));

    if (kwargs == NULL || (nkwargs = PyDict_GET_SIZE(kwargs)) == 0) {
        *p_stack = args;
        *p_kwnames = NULL;
        return 0;
    }

    if ((size_t)nargs > PY_SSIZE_T_MAX / sizeof(stack[0]) - (size_t)nkwargs) {
        PyErr_NoMemory();
        return -1;
    }

    stack = PyMem_Malloc((nargs + nkwargs) * sizeof(stack[0]));
    if (stack == NULL) {
        PyErr_NoMemory();
        return -1;
    }

    kwnames = PyTuple_New(nkwargs);
    if (kwnames == NULL) {
        PyMem_Free(stack);
        return -1;
    }

    /* Copy positional arguments */
    for (i = 0; i < nargs; i++) {
        Py_INCREF(args[i]);
        stack[i] = args[i];
    }

    kwstack = stack + nargs;
    pos = i = 0;
    /* This loop doesn't support lookup function mutating the dictionary
       to change its size. It's a deliberate choice for speed, this function is
       called in the performance critical hot code. */
    while (PyDict_Next(kwargs, &pos, &key, &value)) {
        Py_INCREF(key);
        Py_INCREF(value);
        PyTuple_SET_ITEM(kwnames, i, key);
        kwstack[i] = value;
        i++;
    }

    *p_stack = stack;
    *p_kwnames = kwnames;
    return 0;
}

PyObject *
PyVectorcall_Call(PyObject *callable, PyObject *tuple, PyObject *kwargs)
{
    /* get vectorcallfunc as in _PyVectorcall_Function, but without
     * the _Py_TPFLAGS_HAVE_VECTORCALL check */
    vectorcallfunc func;
    Py_ssize_t offset = Py_TYPE(callable)->tp_vectorcall_offset;
    if (offset == 0) {
        /* On PyPy, a PyMethodObject will not set tp_vectorcall_offset since
         * it is an opaque PyObject. In this case, just make a regular call
         * TODO: how do we detect an error situation?
         */
        if (Py_TYPE(callable)->tp_call) {
            PyObject *result = Py_TYPE(callable)->tp_call(callable, tuple, kwargs);
            return _Py_CheckFunctionResult(callable, result, NULL);
        }
    }
    if (offset <= 0) {
        PyErr_Format(PyExc_TypeError, "'%.200s' object does not support vectorcall",
                     Py_TYPE(callable)->tp_name);
        return NULL;
    }
    memcpy(&func, (char *) callable + offset, sizeof(func));
    if (func == NULL) {
        PyErr_Format(PyExc_TypeError, "'%.200s' object does not support vectorcall",
                     Py_TYPE(callable)->tp_name);
        return NULL;
    }

    /* Convert arguments & call */
    PyObject *const *args;
    Py_ssize_t nargs = PyTuple_GET_SIZE(tuple);
    PyObject *kwnames;
    if (_PyStack_UnpackDict(_PyTuple_ITEMS(tuple), nargs,
        kwargs, &args, &kwnames) < 0) {
        return NULL;
    }
    PyObject *result = func(callable, args, nargs, kwnames);
    if (kwnames != NULL) {
        Py_ssize_t i, n = PyTuple_GET_SIZE(kwnames) + nargs;
        for (i = 0; i < n; i++) {
            Py_DECREF(args[i]);
        }
        PyMem_Free((PyObject **)args);
        Py_DECREF(kwnames);
    }

    return _Py_CheckFunctionResult(callable, result, NULL);
}


