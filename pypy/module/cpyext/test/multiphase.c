#include "Python.h"

static struct PyModuleDef multiphase_def;

static PyObject *check_getdef_same(PyObject *self, PyObject *args) {
    return PyBool_FromLong(PyModule_GetDef(self) == &multiphase_def);
}

static PyMethodDef methods[] = {
    {"check_getdef_same", check_getdef_same, METH_NOARGS},
    {NULL}
};

static PyModuleDef multiphase_def = {
    PyModuleDef_HEAD_INIT, /* m_base */
    "multiphase",          /* m_name */
    "example docstring",   /* m_doc */
    0,                     /* m_size */
    methods,               /* m_methods */
    NULL,                  /* m_slots */
    NULL,                  /* m_traverse */
    NULL,                  /* m_clear */
    NULL,                  /* m_free */
};

PyMODINIT_FUNC PyInit_multiphase(void) {
    return PyModuleDef_Init(&multiphase_def);
}
