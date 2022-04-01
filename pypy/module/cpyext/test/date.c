#include "Python.h"

static PyMethodDef date_functions[] = {
    {NULL, NULL}
};

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "date",
    "Module Doc",
    -1,
    date_functions,
};

PyMODINIT_FUNC
PyInit_date(void)
{
    PyObject *module, *othermodule;
    module = PyModule_Create(&moduledef);
    othermodule = PyImport_ImportModule("apple.banana");
    if (!othermodule)
        return NULL;
    Py_DECREF(othermodule);
    return module;
}
