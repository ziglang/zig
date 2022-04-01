#include "Python.h"

static PyMethodDef dotted_functions[] = {
    {NULL, NULL}
};

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "pypy.module.cpyext.test.dotted",
    "Module Doc",
    -1,
    dotted_functions
};

PyMODINIT_FUNC
PyInit_dotted(void)
{
    return PyModule_Create(&moduledef);
}
