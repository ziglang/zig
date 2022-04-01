
#include "Python.h"

Py_complex
PyComplex_AsCComplex(PyObject *obj)
{
    Py_complex result;
    _PyComplex_AsCComplex(obj, &result);
    return result;
}

PyObject *
PyComplex_FromCComplex(Py_complex c)
{
    return _PyComplex_FromCComplex(&c);
}
