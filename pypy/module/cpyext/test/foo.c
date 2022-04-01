#include "Python.h"
#include "structmember.h"

#if PY_MAJOR_VERSION >= 3
    #define PyInt_FromLong PyLong_FromLong
    #define PyInt_AsLong PyLong_AsLong
    #define PyThing_FromStringAndSize PyUnicode_FromStringAndSize
    #define PyThing_FromString PyUnicode_FromString
    #define PyThing_Check PyUnicode_Check
    #define _PyThing_AsString _PyUnicode_AsString
#else
    #define PyThing_FromStringAndSize PyString_FromStringAndSize
    #define PyThing_FromString PyString_FromString
    #define PyThing_Check PyString_Check
    #define _PyThing_AsString PyString_AsString
#endif

typedef struct {
    PyObject_HEAD
    int    foo;        /* the context holder */
    PyObject *foo_object;
    char *foo_string;
    char foo_string_inplace[5];
    short foo_short;
    long foo_long;
    unsigned short foo_ushort;
    unsigned int foo_uint;
    unsigned long foo_ulong;
    signed char foo_byte;
    unsigned char foo_ubyte;
    unsigned char foo_bool;
    float foo_float;
    double foo_double;
    long long foo_longlong;
    unsigned long long foo_ulonglong;
    Py_ssize_t foo_ssizet;
} fooobject;

static PyTypeObject fooType;

static fooobject *
newfooobject(void)
{
    fooobject *foop;

    foop = PyObject_New(fooobject, &fooType);
    if (foop == NULL)
        return NULL;

    foop->foo = 42;
    foop->foo_object = NULL;
    foop->foo_string = "Hello from PyPy";
    strncpy(foop->foo_string_inplace, "spam", 5);
    return foop;
}


/* foo methods */

static PyObject *
foo_copy(fooobject *self)
{
    fooobject *foop;

    if ((foop = newfooobject()) == NULL)
        return NULL;

    foop->foo = self->foo;

    return (PyObject *)foop;
}

static PyObject *
foo_create(fooobject *self)
{
    return (PyObject*)newfooobject();
}

static PyObject *
foo_classmeth(PyObject *cls)
{
    Py_INCREF(cls);
    return cls;
}

// for CPython
#ifndef PyMethodDescr_Check
int PyMethodDescr_Check(PyObject* method)
{
    PyObject *meth = PyObject_GetAttrString((PyObject*)&PyList_Type, "append");
    if (!meth) return 0;
    int res = PyObject_TypeCheck(method, meth->ob_type);
    Py_DECREF(meth);
    return res;
}
#endif

PyObject* make_classmethod(PyObject* method)
{
    // adapted from __Pyx_Method_ClassMethod
    if (PyMethodDescr_Check(method)) {
        PyMethodDescrObject *descr = (PyMethodDescrObject *)method;
        PyTypeObject *d_type = descr->d_common.d_type;
        return PyDescr_NewClassMethod(d_type, descr->d_method);
    }
    else if (PyMethod_Check(method)) {
        return PyClassMethod_New(PyMethod_GET_FUNCTION(method));
    }
    else {
        PyErr_SetString(PyExc_TypeError, "unknown method kind");
        return NULL;
    }
}

static PyObject *
foo_unset(fooobject *self)
{
    self->foo_string = NULL;
    Py_RETURN_NONE;
}


static PyMethodDef foo_methods[] = {
    {"copy",      (PyCFunction)foo_copy,      METH_NOARGS,  NULL},
    {"create",    (PyCFunction)foo_create,    METH_NOARGS|METH_STATIC,  NULL},
    {"classmeth", (PyCFunction)foo_classmeth, METH_NOARGS|METH_CLASS,  NULL},
    {"fake_classmeth", (PyCFunction)foo_classmeth, METH_NOARGS,  NULL},
    {"unset_string_member", (PyCFunction)foo_unset, METH_NOARGS, NULL},
    {"__class_getitem__", (PyCFunction)Py_GenericAlias, METH_O|METH_CLASS, "See PEP 585"},
    {NULL, NULL}                 /* sentinel */
};

static PyObject *
foo_get_name(PyObject *self, void *closure)
{
    return PyThing_FromStringAndSize("Foo Example", 11);
}

static PyObject *
foo_get_foo(PyObject *self, void *closure)
{
  return PyInt_FromLong(((fooobject*)self)->foo);
}

static PyGetSetDef foo_getseters[] = {
    {"name",
     (getter)foo_get_name, NULL,
     NULL,
     NULL},
     {"foo",
     (getter)foo_get_foo, NULL,
     NULL,
     NULL},
    {NULL}  /* Sentinel */
};

static PyObject *
foo_repr(PyObject *self)
{
    PyObject *format;

    format = PyThing_FromString("<Foo>");
    if (format == NULL) return NULL;
    return format;
}

static PyObject *
foo_call(PyObject *self, PyObject *args, PyObject *kwds)
{
    Py_INCREF(kwds);
    return kwds;
}

static int
foo_setattro(fooobject *self, PyObject *name, PyObject *value)
{
    char *name_str;
    if (!PyThing_Check(name)) {
        PyErr_SetObject(PyExc_AttributeError, name);
        return -1;
    }
    name_str = _PyThing_AsString(name);
    if (strcmp(name_str, "set_foo") == 0)
    {
        long v = PyInt_AsLong(value);
        if (v == -1 && PyErr_Occurred())
            return -1;
        self->foo = v;
        return 0;
    }
    return PyObject_GenericSetAttr((PyObject *)self, name, value);
}

static PyObject *
new_fooType(PyTypeObject * t, PyObject *args, PyObject *kwds)
{
    PyObject * o;
    /* copied from numpy scalartypes.c for inherited classes */
    if (t->tp_bases && (PyTuple_GET_SIZE(t->tp_bases) > 1))
    {
        PyTypeObject *sup;
        /* We are inheriting from a Python type as well so
           give it first dibs on conversion */
        sup = (PyTypeObject *)PyTuple_GET_ITEM(t->tp_bases, 1);
        /* Prevent recursion */
        if (new_fooType != sup->tp_new)
        {
            o = sup->tp_new(t, args, kwds);
            return o;
        }
    }
    o = t->tp_alloc(t, 0);
    return o;
};

static PyMemberDef foo_members[] = {
    {"int_member", T_INT, offsetof(fooobject, foo), 0,
     "A helpful docstring."},
    {"int_member_readonly", T_INT, offsetof(fooobject, foo), READONLY,
     "A helpful docstring."},
    {"broken_member", 0xaffe, 0, 0, NULL},
    {"object_member", T_OBJECT, offsetof(fooobject, foo_object), 0,
     "A Python object."},
    {"object_member_ex", T_OBJECT_EX, offsetof(fooobject, foo_object), 0,
     "A Python object."},
    {"string_member", T_STRING, offsetof(fooobject, foo_string), 0,
     "A string."},
    {"string_member_inplace", T_STRING_INPLACE,
     offsetof(fooobject, foo_string_inplace), 0, "An inplace string."},
    {"char_member", T_CHAR, offsetof(fooobject, foo_string_inplace), 0, NULL},

    {"short_member", T_SHORT, offsetof(fooobject, foo_short), 0, NULL},
    {"long_member", T_LONG, offsetof(fooobject, foo_long), 0, NULL},
    {"ushort_member", T_USHORT, offsetof(fooobject, foo_ushort), 0, NULL},
    {"uint_member", T_UINT, offsetof(fooobject, foo_uint), 0, NULL},
    {"ulong_member", T_ULONG, offsetof(fooobject, foo_ulong), 0, NULL},
    {"byte_member", T_BYTE, offsetof(fooobject, foo_byte), 0, NULL},
    {"ubyte_member", T_UBYTE, offsetof(fooobject, foo_ubyte), 0, NULL},
    {"bool_member", T_BOOL, offsetof(fooobject, foo_bool), 0, NULL},
    {"float_member", T_FLOAT, offsetof(fooobject, foo_float), 0, NULL},
    {"double_member", T_DOUBLE, offsetof(fooobject, foo_double), 0, NULL},
    {"longlong_member", T_LONGLONG, offsetof(fooobject, foo_longlong), 0, NULL},
    {"ulonglong_member", T_ULONGLONG, offsetof(fooobject, foo_ulonglong), 0, NULL},
    {"ssizet_member", T_PYSSIZET, offsetof(fooobject, foo_ssizet), 0, NULL},
    {NULL}  /* Sentinel */
};

PyDoc_STRVAR(foo_doc, "foo is for testing.");

static PyTypeObject fooType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.foo",               /*tp_name*/
    sizeof(fooobject),       /*tp_size*/
    0,                       /*tp_itemsize*/
    /* methods */
    0,                       /*tp_dealloc*/
    0,                       /*tp_print*/
    0,                       /*tp_getattr*/
    0,                       /*tp_setattr*/
    0,                       /*tp_compare*/
    foo_repr,                /*tp_repr*/
    0,                       /*tp_as_number*/
    0,                       /*tp_as_sequence*/
    0,                       /*tp_as_mapping*/
    0,                       /*tp_hash*/
    foo_call,                /*tp_call*/
    0,                       /*tp_str*/
    0,                       /*tp_getattro*/
    (setattrofunc)foo_setattro, /*tp_setattro*/
    0,                       /*tp_as_buffer*/
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /*tp_flags*/
    foo_doc,                 /*tp_doc*/
    0,                       /*tp_traverse*/
    0,                       /*tp_clear*/
    0,                       /*tp_richcompare*/
    0,                       /*tp_weaklistoffset*/
    0,                       /*tp_iter*/
    0,                       /*tp_iternext*/
    foo_methods,             /*tp_methods*/
    foo_members,             /*tp_members*/
    foo_getseters,           /*tp_getset*/
};

/* A type that inherits from 'unicode */

typedef struct {
    PyUnicodeObject HEAD;
    int val;
} UnicodeSubclassObject;


static int UnicodeSubclass_init(UnicodeSubclassObject *self, PyObject *args, PyObject *kwargs) {
    self->val = 42;
    return 0;
}

static PyObject *
UnicodeSubclass_escape(PyTypeObject* type, PyObject *args)
{
    Py_RETURN_TRUE;
}

static PyObject *
UnicodeSubclass_get_val(UnicodeSubclassObject *self) {
    return PyInt_FromLong(self->val);
}

static PyMethodDef UnicodeSubclass_methods[] = {
    {"escape", (PyCFunction) UnicodeSubclass_escape, METH_VARARGS, NULL},
    {"get_val", (PyCFunction) UnicodeSubclass_get_val, METH_NOARGS, NULL},
    {NULL}  /* Sentinel */
};

PyTypeObject UnicodeSubtype = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.fuu",
    sizeof(UnicodeSubclassObject),
    0,
    0,          /*tp_dealloc*/
    0,          /*tp_print*/
    0,          /*tp_getattr*/
    0,          /*tp_setattr*/
    0,          /*tp_compare*/
    0,          /*tp_repr*/
    0,          /*tp_as_number*/
    0,          /*tp_as_sequence*/
    0,          /*tp_as_mapping*/
    0,          /*tp_hash */

    0,          /*tp_call*/
    0,          /*tp_str*/
    0,          /*tp_getattro*/
    0,          /*tp_setattro*/
    0,          /*tp_as_buffer*/

    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /*tp_flags*/
    0,          /*tp_doc*/

    0,          /*tp_traverse*/
    0,          /*tp_clear*/

    0,          /*tp_richcompare*/
    0,          /*tp_weaklistoffset*/

    0,          /*tp_iter*/
    0,          /*tp_iternext*/

    /* Attribute descriptor and subclassing stuff */

    UnicodeSubclass_methods,/*tp_methods*/
    0,          /*tp_members*/
    0,          /*tp_getset*/
    0,          /*tp_base*/
    0,          /*tp_dict*/

    0,          /*tp_descr_get*/
    0,          /*tp_descr_set*/
    0,          /*tp_dictoffset*/

    (initproc) UnicodeSubclass_init, /*tp_init*/
    0,          /*tp_alloc  will be set to PyType_GenericAlloc in module init*/
    0,          /*tp_new*/
    0,          /*tp_free  Low-level free-memory routine */
    0,          /*tp_is_gc For PyObject_IS_GC */
    0,          /*tp_bases*/
    0,          /*tp_mro method resolution order */
    0,          /*tp_cache*/
    0,          /*tp_subclasses*/
    0           /*tp_weaklist*/
};

PyTypeObject UnicodeSubtype2 = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.fuu2",
    sizeof(UnicodeSubclassObject),
    0,
    0,          /*tp_dealloc*/
    0,          /*tp_print*/
    0,          /*tp_getattr*/
    0,          /*tp_setattr*/
    0,          /*tp_compare*/
    0,          /*tp_repr*/
    0,          /*tp_as_number*/
    0,          /*tp_as_sequence*/
    0,          /*tp_as_mapping*/
    0,          /*tp_hash */

    0,          /*tp_call*/
    0,          /*tp_str*/
    0,          /*tp_getattro*/
    0,          /*tp_setattro*/
    0,          /*tp_as_buffer*/

    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /*tp_flags*/
    0,          /*tp_doc*/

    0,          /*tp_traverse*/
    0,          /*tp_clear*/

    0,          /*tp_richcompare*/
    0,          /*tp_weaklistoffset*/

    0,          /*tp_iter*/
    0,          /*tp_iternext*/

    /* Attribute descriptor and subclassing stuff */

    0,          /*tp_methods*/
    0,          /*tp_members*/
    0,          /*tp_getset*/
    0,          /*tp_base*/
    0,          /*tp_dict*/

    0,          /*tp_descr_get*/
    0,          /*tp_descr_set*/
    0,          /*tp_dictoffset*/

    0,          /*tp_init*/
    0,          /*tp_alloc  will be set to PyType_GenericAlloc in module init*/
    0,          /*tp_new*/
    0,          /*tp_free  Low-level free-memory routine */
    0,          /*tp_is_gc For PyObject_IS_GC */
    0,          /*tp_bases*/
    0,          /*tp_mro method resolution order */
    0,          /*tp_cache*/
    0,          /*tp_subclasses*/
    0           /*tp_weaklist*/
};

PyTypeObject UnicodeSubtype3 = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.fuu3",
    sizeof(UnicodeSubclassObject)
};

/* A Metatype */

PyTypeObject MetaType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.Meta",
    sizeof(PyHeapTypeObject),/*tp_basicsize*/
    0,          /*tp_itemsize*/
    0,          /*tp_dealloc*/
    0,          /*tp_print*/
    0,          /*tp_getattr*/
    0,          /*tp_setattr*/
    0,          /*tp_compare*/
    0,          /*tp_repr*/
    0,          /*tp_as_number*/
    0,          /*tp_as_sequence*/
    0,          /*tp_as_mapping*/
    0,          /*tp_hash */

    0,          /*tp_call*/
    0,          /*tp_str*/
    0,          /*tp_getattro*/
    0,          /*tp_setattro*/
    0,          /*tp_as_buffer*/

    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /*tp_flags*/
    0,          /*tp_doc*/

    0,          /*tp_traverse*/
    0,          /*tp_clear*/

    0,          /*tp_richcompare*/
    0,          /*tp_weaklistoffset*/

    0,          /*tp_iter*/
    0,          /*tp_iternext*/

    /* Attribute descriptor and subclassing stuff */

    0,          /*tp_methods*/
    0,          /*tp_members*/
    0,          /*tp_getset*/
    0,          /*tp_base*/
    0,          /*tp_dict*/

    0,          /*tp_descr_get*/
    0,          /*tp_descr_set*/
    0,          /*tp_dictoffset*/

    0,          /*tp_init*/
    0,          /*tp_alloc*/
    0,          /*tp_new*/
    0,          /*tp_free*/
    0,          /*tp_is_gc*/
    0,          /*tp_bases*/
    0,          /*tp_mro*/
    0,          /*tp_cache*/
    0,          /*tp_subclasses*/
    0           /*tp_weaklist*/
};


/* foo functions */

static PyObject *
foo_new(PyObject *self, PyObject *args)
{
    fooobject *foop;

    if ((foop = newfooobject()) == NULL) {
        return NULL;
    }

    return (PyObject *)foop;
}

static int initerrtype_init(PyObject *self, PyObject *args, PyObject *kwargs) {
    PyErr_SetString(PyExc_ValueError, "init raised an error!");
    return -1;
}


PyTypeObject InitErrType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.InitErrType",
    sizeof(PyObject),/*tp_basicsize*/
    0,          /*tp_itemsize*/
    0,          /*tp_dealloc*/
    0,          /*tp_print*/
    0,          /*tp_getattr*/
    0,          /*tp_setattr*/
    0,          /*tp_compare*/
    0,          /*tp_repr*/
    0,          /*tp_as_number*/
    0,          /*tp_as_sequence*/
    0,          /*tp_as_mapping*/
    0,          /*tp_hash */

    0,          /*tp_call*/
    0,          /*tp_str*/
    0,          /*tp_getattro*/
    0,          /*tp_setattro*/
    0,          /*tp_as_buffer*/

    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /*tp_flags*/
    0,          /*tp_doc*/

    0,          /*tp_traverse*/
    0,          /*tp_clear*/

    0,          /*tp_richcompare*/
    0,          /*tp_weaklistoffset*/

    0,          /*tp_iter*/
    0,          /*tp_iternext*/

    /* Attribute descriptor and subclassing stuff */

    0,          /*tp_methods*/
    0,          /*tp_members*/
    0,          /*tp_getset*/
    0,          /*tp_base*/
    0,          /*tp_dict*/

    0,          /*tp_descr_get*/
    0,          /*tp_descr_set*/
    0,          /*tp_dictoffset*/

    initerrtype_init,          /*tp_init*/
    0,          /*tp_alloc*/
    0,          /*tp_new*/
    0,          /*tp_free*/
    0,          /*tp_is_gc*/
    0,          /*tp_bases*/
    0,          /*tp_mro*/
    0,          /*tp_cache*/
    0,          /*tp_subclasses*/
    0           /*tp_weaklist*/
};

PyObject * prop_descr_get(PyObject *self, PyObject *obj, PyObject *type)
{
    if (obj == NULL)
	obj = Py_None;
    if (type == NULL)
	type = Py_None;

    return PyTuple_Pack(3, self, obj, type);
}

int prop_descr_set(PyObject *self, PyObject *obj, PyObject *value)
{
    int res;
    if (value != NULL) {
	PyObject *result = PyTuple_Pack(2, self, value);
	res = PyObject_SetAttrString(obj, "y", result);
	Py_DECREF(result);
    }
    else {
	res = PyObject_SetAttrString(obj, "z", self);
    }
    return res;
}


PyTypeObject SimplePropertyType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.Property",
    sizeof(PyObject),
    0,
    0,          /*tp_dealloc*/
    0,          /*tp_print*/
    0,          /*tp_getattr*/
    0,          /*tp_setattr*/
    0,          /*tp_compare*/
    0,          /*tp_repr*/
    0,          /*tp_as_number*/
    0,          /*tp_as_sequence*/
    0,          /*tp_as_mapping*/
    0,          /*tp_hash */

    0,          /*tp_call*/
    0,          /*tp_str*/
    0,          /*tp_getattro*/
    0,          /*tp_setattro*/
    0,          /*tp_as_buffer*/

    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /*tp_flags*/
    0,          /*tp_doc*/

    0,          /*tp_traverse*/
    0,          /*tp_clear*/

    0,          /*tp_richcompare*/
    0,          /*tp_weaklistoffset*/

    0,          /*tp_iter*/
    0,          /*tp_iternext*/

    /* Attribute descriptor and subclassing stuff */

    0,          /*tp_methods*/
    0,          /*tp_members*/
    0,          /*tp_getset*/
    0,          /*tp_base*/
    0,          /*tp_dict*/

    prop_descr_get, /*tp_descr_get*/
    prop_descr_set, /*tp_descr_set*/
    0,          /*tp_dictoffset*/

    0,          /*tp_init*/
    0,          /*tp_alloc  will be set to PyType_GenericAlloc in module init*/
    PyType_GenericNew, /*tp_new*/
    0,          /*tp_free  Low-level free-memory routine */
    0,          /*tp_is_gc For PyObject_IS_GC */
    0,          /*tp_bases*/
    0,          /*tp_mro method resolution order */
    0,          /*tp_cache*/
    0,          /*tp_subclasses*/
    0           /*tp_weaklist*/
};

/* A type with a custom allocator */
static void custom_dealloc(PyObject *ob)
{
    free(ob);
}

static PyTypeObject CustomType;

static PyObject *newCustom(PyObject *self, PyObject *args)
{
    PyObject *obj = calloc(1, sizeof(PyObject));
    Py_TYPE(obj) = &CustomType;
    _Py_NewReference(obj);
    return obj;
}

static PyTypeObject CustomType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.Custom",            /*tp_name*/
    sizeof(PyObject),        /*tp_size*/
    0,                       /*tp_itemsize*/
    /* methods */
    (destructor)custom_dealloc, /*tp_dealloc*/
};

static PyTypeObject TupleLike = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.TupleLike",         /*tp_name*/
    sizeof(PyObject),        /*tp_size*/
};


static PyObject *size_of_instances(PyObject *self, PyObject *t)
{
    return PyInt_FromLong(((PyTypeObject *)t)->tp_basicsize);
}


static PyObject * is_TupleLike(PyObject *self, PyObject * t)
{
    int tf = t->ob_type == &TupleLike;
    if (t->ob_type->tp_itemsize == 0)
        return PyInt_FromLong(-1);
    return PyInt_FromLong(tf);
}

static PyTypeObject GetType1 = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.GetType1",          /*tp_name*/
    sizeof(PyObject),        /*tp_size*/
};
static PyTypeObject GetType2 = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "foo.GetType2",          /*tp_name*/
    sizeof(PyObject),        /*tp_size*/
};
static PyObject *gettype1, *gettype2;

static PyObject *gettype1_getattr(PyObject *self, char *name)
{
    char buf[200];
    strcpy(buf, "getattr:");
    strcat(buf, name);
    return PyBytes_FromString(buf);
}
static PyObject *gettype2_getattro(PyObject *self, PyObject *name)
{
    char buf[200];
    PyObject* temp;
    temp = PyUnicode_AsASCIIString(name);
    if (temp == NULL) return NULL;
    strcpy(buf, "getattro:");
    strcat(buf, PyBytes_AS_STRING(temp));
    return PyBytes_FromString(buf);
}


/* List of functions exported by this module */

static PyMethodDef foo_functions[] = {
    {"new",        (PyCFunction)foo_new, METH_NOARGS, NULL},
    {"newCustom",  (PyCFunction)newCustom, METH_NOARGS, NULL},
    {"size_of_instances", (PyCFunction)size_of_instances, METH_O, NULL},
    {"is_TupleLike", (PyCFunction)is_TupleLike, METH_O, NULL},
    {NULL,        NULL}    /* Sentinel */
};

#if PY_MAJOR_VERSION >= 3
static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "foo",
    "Module Doc",
    -1,
    foo_functions,
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
PyInit_foo(void)

#else

#define INITERROR return

/* Initialize this module. */
#ifdef __GNUC__
extern __attribute__((visibility("default")))
#else
extern __declspec(dllexport)
#endif

PyMODINIT_FUNC
initfoo(void)
#endif
{
    PyObject *d;
    PyObject *fake_classmeth, *classmeth;
#if PY_MAJOR_VERSION >= 3
    PyObject *module = PyModule_Create(&moduledef);
#else
    PyObject *module = Py_InitModule("foo", foo_functions);
#endif
    if (module == NULL)
        INITERROR;

    UnicodeSubtype.tp_base = &PyUnicode_Type;
    UnicodeSubtype2.tp_base = &UnicodeSubtype;
    MetaType.tp_base = &PyType_Type;

    fooType.tp_new = &new_fooType;
    InitErrType.tp_new = PyType_GenericNew;

    if (PyType_Ready(&fooType) < 0)
        INITERROR;
    if (PyType_Ready(&UnicodeSubtype) < 0)
        INITERROR;
    if (PyType_Ready(&UnicodeSubtype2) < 0)
        INITERROR;
    if (PyType_Ready(&MetaType) < 0)
        INITERROR;
    if (PyType_Ready(&InitErrType) < 0)
        INITERROR;
    if (PyType_Ready(&SimplePropertyType) < 0)
        INITERROR;


    Py_TYPE(&CustomType) = &MetaType;
    if (PyType_Ready(&CustomType) < 0)
        INITERROR;

    UnicodeSubtype3.tp_flags = Py_TPFLAGS_DEFAULT;
    UnicodeSubtype3.tp_base = &UnicodeSubtype;
    UnicodeSubtype3.tp_bases = Py_BuildValue("(OO)", &UnicodeSubtype,
                                                    &CustomType);
    if (PyType_Ready(&UnicodeSubtype3) < 0)
        INITERROR;

    TupleLike.tp_flags = Py_TPFLAGS_DEFAULT;
    TupleLike.tp_base = &PyTuple_Type;
    if (PyType_Ready(&TupleLike) < 0)
        INITERROR;

    GetType1.tp_flags = Py_TPFLAGS_DEFAULT;
    GetType1.tp_getattr = &gettype1_getattr;
    if (PyType_Ready(&GetType1) < 0)
        INITERROR;
    gettype1 = PyObject_New(PyObject, &GetType1);

    GetType2.tp_flags = Py_TPFLAGS_DEFAULT;
    GetType2.tp_getattro = &gettype2_getattro;
    if (PyType_Ready(&GetType2) < 0)
        INITERROR;
    gettype2 = PyObject_New(PyObject, &GetType2);

    fake_classmeth = PyDict_GetItemString((PyObject *)fooType.tp_dict, "fake_classmeth");
    classmeth = make_classmethod(fake_classmeth);
    if (classmeth == NULL)
        INITERROR;
    if (PyDict_SetItemString((PyObject *)fooType.tp_dict, "fake_classmeth", classmeth) < 0)
        INITERROR;

    d = PyModule_GetDict(module);
    if (d == NULL)
        INITERROR;
    if (PyDict_SetItemString(d, "fooType", (PyObject *)&fooType) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "UnicodeSubtype", (PyObject *) &UnicodeSubtype) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "UnicodeSubtype2", (PyObject *) &UnicodeSubtype2) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "UnicodeSubtype3", (PyObject *) &UnicodeSubtype3) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "MetaType", (PyObject *) &MetaType) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "InitErrType", (PyObject *) &InitErrType) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "Property", (PyObject *) &SimplePropertyType) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "Custom", (PyObject *) &CustomType) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "TupleLike", (PyObject *) &TupleLike) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "gettype1", gettype1) < 0)
        INITERROR;
    if (PyDict_SetItemString(d, "gettype2", gettype2) < 0)
        INITERROR;
#if PY_MAJOR_VERSION >=3
    return module;
#endif
}
