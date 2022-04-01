#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS 1
#endif
#include <Python.h>
#include <stdlib.h>
#include <stdio.h>

/* 
 * Adapted from https://jakevdp.github.io/blog/2014/05/05/introduction-to-the-python-buffer-protocol,
 * which is copyright Jake Vanderplas and released under the BSD license
 */

/* Structure defines a 1-dimensional strided array */
typedef struct{
    int* arr;
    Py_ssize_t length;
} MyArray;

/* initialize the array with integers 0...length */
void initialize_MyArray(MyArray* a, long length){
    int i;
    a->length = length;
    a->arr = (int*)malloc(length * sizeof(int));
    for(i=0; i<length; i++){
        a->arr[i] = i;
    }
}

/* free the memory when finished */
void deallocate_MyArray(MyArray* a){
    free(a->arr);
    a->arr = NULL;
}

/* tools to print the array */
char* stringify(MyArray* a, int nmax){
    char* output = (char*) malloc(nmax * 20);
    int k, pos = sprintf(&output[0], "[");

    for (k=0; k < a->length && k < nmax; k++){
        pos += sprintf(&output[pos], " %d", a->arr[k]);
    }
    if(a->length > nmax)
        pos += sprintf(&output[pos], "...");
    sprintf(&output[pos], " ]");
    return output;
}

void print_MyArray(MyArray* a, int nmax){
    char* s = stringify(a, nmax);
    printf("%s", s);
    free(s);
}

/* This is where we define the PyMyArray object structure */
typedef struct {
    PyObject_HEAD
    /* Type-specific fields go below. */
    MyArray arr;
} PyMyArray;


/* This is the __init__ function, implemented in C */
static int
PyMyArray_init(PyMyArray *self, PyObject *args, PyObject *kwds)
{
    int length = 0;
    static char *kwlist[] = {"length", NULL};
    // init may have already been called
    if (self->arr.arr != NULL) {
        deallocate_MyArray(&self->arr);
    }

    if (! PyArg_ParseTupleAndKeywords(args, kwds, "|i", kwlist, &length))
        return -1;

    if (length < 0)
        length = 0;

    initialize_MyArray(&self->arr, length);

    return 0;
}


/* this function is called when the object is deallocated */
static void
PyMyArray_dealloc(PyMyArray* self)
{
    deallocate_MyArray(&self->arr);
    Py_TYPE(self)->tp_free((PyObject*)self);
}


/* This function returns the string representation of our object */
static PyObject *
PyMyArray_str(PyMyArray * self)
{
  char* s = stringify(&self->arr, 10);
  PyObject* ret = PyUnicode_FromString(s);
  free(s);
  return ret;
}

/* Here is the buffer interface function */
static int
PyMyArray_getbuffer(PyObject *obj, Py_buffer *view, int flags)
{
  PyMyArray* self = (PyMyArray*)obj;
  if (view == NULL) {
    PyErr_SetString(PyExc_ValueError, "NULL view in getbuffer");
    return -1;
  }
  if (flags == 0) {
    PyErr_SetString(PyExc_ValueError, "flags == 0 in getbuffer");
    return -1;
  }

  view->obj = (PyObject*)self;
  view->buf = (void*)self->arr.arr;
  view->len = self->arr.length * sizeof(int);
  view->readonly = 0;
  view->itemsize = sizeof(int);
  view->format = "i";  // integer
  view->ndim = 1;
  view->shape = &self->arr.length;  // length-1 sequence of dimensions
  view->strides = &view->itemsize;  // for the simple case we can do this
  view->suboffsets = NULL;
  view->internal = NULL;

  Py_INCREF(self);  // need to increase the reference count
  return 0;
}

static PyBufferProcs PyMyArray_as_buffer = {
#if PY_MAJOR_VERSION < 3
  (readbufferproc)0,
  (writebufferproc)0,
  (segcountproc)0,
  (charbufferproc)0,
#endif
  (getbufferproc)PyMyArray_getbuffer,
  (releasebufferproc)0,  // we do not require any special release function
};


/* Here is the type structure: we put the above functions in the appropriate place
   in order to actually define the Python object type */
static PyTypeObject PyMyArrayType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "pymyarray.PyMyArray",        /* tp_name */
    sizeof(PyMyArray),            /* tp_basicsize */
    0,                            /* tp_itemsize */
    (destructor)PyMyArray_dealloc,/* tp_dealloc */
    0,                            /* tp_print */
    0,                            /* tp_getattr */
    0,                            /* tp_setattr */
    0,                            /* tp_reserved */
    (reprfunc)PyMyArray_str,      /* tp_repr */
    0,                            /* tp_as_number */
    0,                            /* tp_as_sequence */
    0,                            /* tp_as_mapping */
    0,                            /* tp_hash  */
    0,                            /* tp_call */
    (reprfunc)PyMyArray_str,      /* tp_str */
    0,                            /* tp_getattro */
    0,                            /* tp_setattro */
    &PyMyArray_as_buffer,         /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT, /* tp_flags */
    "PyMyArray object",           /* tp_doc */
    0,                            /* tp_traverse */
    0,                            /* tp_clear */
    0,                            /* tp_richcompare */
    0,                            /* tp_weaklistoffset */
    0,                            /* tp_iter */
    0,                            /* tp_iternext */
    0,                            /* tp_methods */
    0,                            /* tp_members */
    0,                            /* tp_getset */
    0,                            /* tp_base */
    0,                            /* tp_dict */
    0,                            /* tp_descr_get */
    0,                            /* tp_descr_set */
    0,                            /* tp_dictoffset */
    (initproc)PyMyArray_init,     /* tp_init */
};

/* Copied from numpy tests */
/*
 * Create python string from a FLAG and or the corresponding PyBuf flag
 * for the use in get_buffer_info.
 */
#define GET_PYBUF_FLAG(FLAG)                                        \
    buf_flag = PyUnicode_FromString(#FLAG);                         \
    if (buf_flag == NULL) {                                         \
        Py_DECREF(tmp);                                             \
        return NULL;                                                \
    }                                                               \
    flag_matches = PyObject_RichCompareBool(buf_flag, tmp, Py_EQ);  \
    Py_DECREF(buf_flag);                                            \
    if (flag_matches == 1) {                                        \
        Py_DECREF(tmp);                                             \
        flags |= PyBUF_##FLAG;                                      \
        continue;                                                   \
    }                                                               \
    else if (flag_matches == -1) {                                  \
        Py_DECREF(tmp);                                             \
        return NULL;                                                \
    }


/*
 * Get information for a buffer through PyBuf_GetBuffer with the
 * corresponding flags or'ed. Note that the python caller has to
 * make sure that or'ing those flags actually makes sense.
 * More information should probably be returned for future tests.
 */
static PyObject *
get_buffer_info(PyObject *self, PyObject *args)
{
    PyObject *buffer_obj, *pyflags;
    PyObject *tmp, *buf_flag;
    Py_buffer buffer;
    PyObject *shape, *strides;
    Py_ssize_t i, n;
    int flag_matches;
    int flags = 0;

    if (!PyArg_ParseTuple(args, "OO", &buffer_obj, &pyflags)) {
        return NULL;
    }

    n = PySequence_Length(pyflags);
    if (n < 0) {
        return NULL;
    }

    for (i=0; i < n; i++) {
        tmp = PySequence_GetItem(pyflags, i);
        if (tmp == NULL) {
            return NULL;
        }

        GET_PYBUF_FLAG(SIMPLE);
        GET_PYBUF_FLAG(WRITABLE);
        GET_PYBUF_FLAG(STRIDES);
        GET_PYBUF_FLAG(ND);
        GET_PYBUF_FLAG(C_CONTIGUOUS);
        GET_PYBUF_FLAG(F_CONTIGUOUS);
        GET_PYBUF_FLAG(ANY_CONTIGUOUS);
        GET_PYBUF_FLAG(INDIRECT);
        GET_PYBUF_FLAG(FORMAT);
        GET_PYBUF_FLAG(STRIDED);
        GET_PYBUF_FLAG(STRIDED_RO);
        GET_PYBUF_FLAG(RECORDS);
        GET_PYBUF_FLAG(RECORDS_RO);
        GET_PYBUF_FLAG(FULL);
        GET_PYBUF_FLAG(FULL_RO);
        GET_PYBUF_FLAG(CONTIG);
        GET_PYBUF_FLAG(CONTIG_RO);

        Py_DECREF(tmp);

        /* One of the flags must match */
        PyErr_SetString(PyExc_ValueError, "invalid flag used.");
        return NULL;
    }

    if (PyObject_GetBuffer(buffer_obj, &buffer, flags) < 0) {
        return NULL;
    }

    if (buffer.shape == NULL) {
        Py_INCREF(Py_None);
        shape = Py_None;
    }
    else {
        shape = PyTuple_New(buffer.ndim);
        for (i=0; i < buffer.ndim; i++) {
            PyTuple_SET_ITEM(shape, i, PyLong_FromSsize_t(buffer.shape[i]));
        }
    }

    if (buffer.strides == NULL) {
        Py_INCREF(Py_None);
        strides = Py_None;
    }
    else {
        strides = PyTuple_New(buffer.ndim);
        for (i=0; i < buffer.ndim; i++) {
            PyTuple_SET_ITEM(strides, i, PyLong_FromSsize_t(buffer.strides[i]));
        }
    }

    PyBuffer_Release(&buffer);
    return Py_BuildValue("(NN)", shape, strides);
}



static PyMethodDef buffer_functions[] = {
    {"get_buffer_info",   (PyCFunction)get_buffer_info, METH_VARARGS, NULL},
    {NULL,        NULL}    /* Sentinel */
};

#if PY_MAJOR_VERSION >= 3
static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "buffer_test",
    "Module Doc",
    -1,
    buffer_functions,
    NULL,
    NULL,
    NULL,
    NULL,
};
#define INITERROR return NULL

/* Initialize this module. */
#ifdef __GNUC__
extern __attribute__((visibility("default")))
#else
extern __declspec(dllexport)
#endif

PyMODINIT_FUNC
PyInit_buffer_test(void)

#else

#define INITERROR return

/* Initialize this module. */
#ifdef __GNUC__
extern __attribute__((visibility("default")))
#else
#endif

PyMODINIT_FUNC
initbuffer_test(void)
#endif
{
#if PY_MAJOR_VERSION >= 3
    PyObject *m= PyModule_Create(&moduledef);
#else
    PyObject *m= Py_InitModule("buffer_test", buffer_functions);
#endif
    if (m == NULL)
        INITERROR;
    PyMyArrayType.tp_new = PyType_GenericNew;
    if (PyType_Ready(&PyMyArrayType) < 0)
        INITERROR;
    Py_INCREF(&PyMyArrayType);
    PyModule_AddObject(m, "PyMyArray", (PyObject *)&PyMyArrayType);
#if PY_MAJOR_VERSION >=3
    return m;
#endif
}
