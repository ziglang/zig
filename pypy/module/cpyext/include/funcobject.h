
/* Function object interface */

#ifndef Py_FUNCOBJECT_H
#define Py_FUNCOBJECT_H
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    PyObject_HEAD
    PyObject *func_name;	/* The __name__ attribute, a string object */
} PyFunctionObject;

PyAPI_DATA(PyTypeObject) PyFunction_Type;

#define PyFunction_GET_CODE(obj) PyFunction_GetCode((PyObject*)(obj))

#define PyMethod_GET_FUNCTION(obj) PyMethod_Function((PyObject*)(obj))
#define PyMethod_GET_SELF(obj) PyMethod_Self((PyObject*)(obj))

#ifdef __cplusplus
}
#endif
#endif /* !Py_FUNCOBJECT_H */
