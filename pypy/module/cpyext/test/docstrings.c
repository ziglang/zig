#include "Python.h"

static PyObject *
test_with_docstring(PyObject *self)
{
    Py_RETURN_NONE;
}

PyDoc_STRVAR(empty_doc,
""
);

PyDoc_STRVAR(no_sig,
"This docstring has no signature."
);

PyDoc_STRVAR(invalid_sig,
"invalid_sig($module, /, boo)\n"
"\n"
"This docstring has an invalid signature."
);

PyDoc_STRVAR(invalid_sig2,
"invalid_sig2($module, /, boo)\n"
"\n"
"--\n"
"\n"
"This docstring also has an invalid signature."
);

PyDoc_STRVAR(with_sig,
"with_sig($module, /, sig)\n"
"--\n"
"\n"
"This docstring has a valid signature."
);

PyDoc_STRVAR(with_sig_but_no_doc,
"with_sig_but_no_doc($module, /, sig)\n"
"--\n"
"\n"
);

PyDoc_STRVAR(with_signature_and_extra_newlines,
"with_signature_and_extra_newlines($module, /, parameter)\n"
"--\n"
"\n"
"\n"
"This docstring has a valid signature and some extra newlines."
);


static PyMethodDef methods[] = {
    {"no_doc",
        (PyCFunction)test_with_docstring, METH_NOARGS},
    {"empty_doc",
        (PyCFunction)test_with_docstring, METH_NOARGS,
        empty_doc},
    {"no_sig",
        (PyCFunction)test_with_docstring, METH_NOARGS,
        no_sig},
    {"invalid_sig",
        (PyCFunction)test_with_docstring, METH_NOARGS,
        invalid_sig},
    {"invalid_sig2",
        (PyCFunction)test_with_docstring, METH_NOARGS,
        invalid_sig2},
    {"with_sig",
        (PyCFunction)test_with_docstring, METH_NOARGS,
        with_sig},
    {"with_sig_but_no_doc",
        (PyCFunction)test_with_docstring, METH_NOARGS,
        with_sig_but_no_doc},
    {"with_signature_and_extra_newlines",
        (PyCFunction)test_with_docstring, METH_NOARGS,
        with_signature_and_extra_newlines},
    {NULL, NULL} /* sentinel */
};


static PyType_Slot HeapType_slots[] = {
    {Py_tp_doc, "HeapType()\n--\n\nA type with a signature"},
    {0, 0},
};

static PyType_Spec HeapType_spec = {
    "docstrings.HeapType",
    sizeof(PyObject),
    0,
    Py_TPFLAGS_DEFAULT,
    HeapType_slots
};

static PyTypeObject SomeType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "docstrings.SomeType",      /* tp_name */
    sizeof(PyObject),           /* tp_basicsize */
    0,                         /* tp_itemsize */
    0,                         /* tp_dealloc */
    0,                         /* tp_print */
    0,                         /* tp_getattr */
    0,                         /* tp_setattr */
    0,                         /* tp_reserved */
    0,                         /* tp_repr */
    0,                         /* tp_as_number */
    0,                         /* tp_as_sequence */
    0,                         /* tp_as_mapping */
    0,                         /* tp_hash  */
    0,                         /* tp_call */
    0,                         /* tp_str */
    0,                         /* tp_getattro */
    0,                         /* tp_setattro */
    0,                         /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT,        /* tp_flags */
    "SomeType()\n--\n\nA type with a signature",    /* tp_doc */
};


static struct PyModuleDef def = {
    PyModuleDef_HEAD_INIT,
    "docstrings",
    NULL,
    -1,
    methods,
    NULL,
    NULL,
    NULL,
    NULL
};


PyMODINIT_FUNC
PyInit_docstrings(void)
{
    PyObject *m, *tmp;
    m = PyModule_Create(&def);
    if (m == NULL)
        return NULL;
    tmp = PyType_FromSpec(&HeapType_spec);
    if (tmp == NULL)
        return NULL;
    if (PyModule_AddObject(m, "HeapType", tmp) != 0)
        return NULL;
    if (PyType_Ready(&SomeType) < 0)
        return NULL;
    if (PyModule_AddObject(m, "SomeType", (PyObject*)&SomeType) != 0)
        return NULL;
    return m;
}
