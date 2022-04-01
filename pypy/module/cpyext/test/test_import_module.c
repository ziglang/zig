#include "Python.h"
/* Initialize this module. */

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "test_import_module",
    NULL,
    -1,
    NULL, NULL, NULL, NULL, NULL
};

PyMODINIT_FUNC
PyInit_test_import_module(void)
{
    PyObject* m = PyModule_Create(&moduledef);
    if (m == NULL)
	    return NULL;
    PyModule_AddObject(m, "TEST", (PyObject *) Py_None);
    return m;
}
