/*
 * In numpy this is a convenience header file providing compatibility utilities
 * for supporting Python 2 and Python 3 in the same code base.
 *
 * PyPy uses it as a convenient place to add compatability declarations
 * It will be copied by numpy/core/setup.py by install_data to
 * site-packages/numpy/core/includes/numpy  
*/

#ifndef _NPY_3KCOMPAT_H_
#define _NPY_3KCOMPAT_H_

#include "npy_common.h"

#define npy_PyFile_Dup(file, mode) (NULL)
#define npy_PyFile_DupClose(file, handle) (0)

static NPY_INLINE PyObject*
npy_PyFile_OpenFile(PyObject *filename, const char *mode)
{
    PyObject *open;
    open = PyDict_GetItemString(PyEval_GetBuiltins(), "open");
    if (open == NULL) {
        return NULL;
    }
    return PyObject_CallFunction(open, "Os", filename, mode);
}

static NPY_INLINE int
npy_PyFile_CloseFile(PyObject *file)
{
    PyObject *ret;

    ret = PyObject_CallMethod(file, "close", NULL);
    if (ret == NULL) {
        return -1;
    }
    Py_DECREF(ret);
    return 0;
}
#endif
