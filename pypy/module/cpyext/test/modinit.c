
/*
 * Trivial module which uses the PyMODINIT_FUNC macro.
 */

#include <Python.h>

static PyMethodDef methods[] = {
    { NULL }
};

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "modinit",
    "",
    -1,
    methods
};

PyMODINIT_FUNC
PyInit_modinit(void) {
    return PyModule_Create(&moduledef);
}

