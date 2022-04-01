
/* Int object interface */

#ifndef Py_EVAL_H
#define Py_EVAL_H
#ifdef __cplusplus
extern "C" {
#endif

#include "Python.h"

#ifdef PY_SSIZE_T_CLEAN
#undef PyObject_CallFunction
#undef PyObject_CallMethod
#define PyObject_CallFunction _PyObject_CallFunction_SizeT
#define PyObject_CallMethod _PyObject_CallMethod_SizeT
#endif

#define PyEval_CallObject(func,arg) \
        PyEval_CallObjectWithKeywords(func, arg, (PyObject *)NULL)

PyAPI_FUNC(PyObject *) PyEval_CallFunction(PyObject *obj, const char *format, ...);
PyAPI_FUNC(PyObject *) PyEval_CallMethod(PyObject *obj, const char *name, const char *format, ...);
PyAPI_FUNC(PyObject *) PyObject_CallFunction(PyObject *obj, const char *format, ...);
PyAPI_FUNC(PyObject *) PyObject_CallMethod(PyObject *obj, const char *name, const char *format, ...);
PyAPI_FUNC(PyObject *) _PyObject_CallFunction_SizeT(PyObject *obj, const char *format, ...);
PyAPI_FUNC(PyObject *) _PyObject_CallMethod_SizeT(PyObject *obj, const char *name, const char *format, ...);
PyAPI_FUNC(PyObject *) PyObject_CallFunctionObjArgs(PyObject *callable, ...);
PyAPI_FUNC(PyObject *) PyObject_CallMethodObjArgs(PyObject *callable, PyObject *name, ...);

/* These constants are also defined in cpyext/eval.py */
#define Py_single_input 256
#define Py_file_input 257
#define Py_eval_input 258
#define Py_func_type_input 345

#ifdef __cplusplus
}
#endif
#endif /* !Py_EVAL_H */
