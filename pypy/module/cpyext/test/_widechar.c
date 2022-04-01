// Enable asserts. This used to fail in that case only.
#undef NDEBUG

#include "Python.h"

static PyObject *
test_widechar(PyObject *self)
{
    const wchar_t invalid[1] = {(wchar_t)0x110000u};
    PyObject *wide;

    wide = PyUnicode_FromUnicode(NULL, 1);
    if (wide == NULL)
        return NULL;
    PyUnicode_AS_UNICODE(wide)[0] = invalid[0];
    if (_PyUnicode_Ready(wide) < 0) {
        return NULL;
    }
    return wide;
}

static PyObject *
get_sizeof_wchar(PyObject *self)
{
    return PyLong_FromLong(sizeof(wchar_t));
}

static PyMethodDef TestMethods[] = {
    {"test_widechar",    (PyCFunction)test_widechar,   METH_NOARGS},
    {"get_sizeof_wchar", (PyCFunction)get_sizeof_wchar,METH_NOARGS},
    {NULL, NULL} /* sentinel */
};

static struct PyModuleDef _testcapimodule = {
    PyModuleDef_HEAD_INIT,
    "_widechar",
    NULL,
    -1,
    NULL,
};

PyMODINIT_FUNC
PyInit__widechar(void)
{
    PyObject *m;
    m = PyModule_Create(&_testcapimodule);
    if (m == NULL)
        return NULL;
    PyModule_AddFunctions(m, TestMethods);
    return m;
}
